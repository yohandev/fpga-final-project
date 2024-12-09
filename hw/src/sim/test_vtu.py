import cocotb
import os
import sys
import logging
import vec3
import vec3i
import fixed
import numpy as np
from pathlib import Path
from cocotb.clock import Clock
from cocotb.binary import BinaryValue, BinaryRepresentation
from cocotb.triggers import ClockCycles, RisingEdge, Edge
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner


class VoxelTraversal:
    def __init__(self, ray_direction, ray_origin):
        # Re-implementation of sw/src/vtu.rs, which is known to work
        self.ray_direction_in = ray_direction
        self.ray_origin_in = ray_origin
        self.ray_direction = vec3.normalize(ray_direction)
        self.ray_position = vec3.floor(ray_origin)

        o = self.ray_origin_in
        d = self.ray_direction
        p = self.ray_position

        self.ray_step = (
            1 if fixed.f32(self.ray_direction_in[0]) > 0 else -1,
            1 if fixed.f32(self.ray_direction_in[1]) > 0 else -1,
            1 if fixed.f32(self.ray_direction_in[2]) > 0 else -1,
        )
        self.ray_t_delta = (
            fixed.abs(fixed.recip_lte1(d[0])),
            fixed.abs(fixed.recip_lte1(d[1])),
            fixed.abs(fixed.recip_lte1(d[2])),
        )
        self.ray_dist = (
            fixed.sub(fixed.fixed(1), fixed.add(o[0], p[0] << fixed.D)) \
                if self.ray_step[0] > 0 else fixed.sub(o[0], p[0] << fixed.D),
            fixed.sub(fixed.fixed(1), fixed.add(o[1], p[1] << fixed.D)) \
                if self.ray_step[1] > 0 else fixed.sub(o[1], p[1] << fixed.D),
            fixed.sub(fixed.fixed(1), fixed.add(o[2], p[2] << fixed.D)) \
                if self.ray_step[2] > 0 else fixed.sub(o[2], p[2] << fixed.D),
        )
        self.ray_t_max = (
            fixed.mul(self.ray_t_delta[0], self.ray_dist[0]) if d[0] != 0 else fixed.MAX,
            fixed.mul(self.ray_t_delta[1], self.ray_dist[1]) if d[1] != 0 else fixed.MAX,
            fixed.mul(self.ray_t_delta[2], self.ray_dist[2]) if d[2] != 0 else fixed.MAX,
        )


async def reset(rst, clk):
    """ Helper function to issue a reset signal to our module """
    rst.value = 1
    await ClockCycles(clk, 1)
    rst.value = 0
    await ClockCycles(clk, 1)


@cocotb.test()
async def test_ray_init_fuzzy(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())

    # Known edge cases
    await test_ray_init(dut, vec3.from_f32((10, 2, 0)), vec3.from_f32((20, 10, -3)))

    # Fuzzy testing
    for _ in range(1000):
        ray_direction = vec3.random(small=True)
        ray_origin = vec3.random()

        await test_ray_init(dut, ray_direction, ray_origin)
        await ClockCycles(dut.clk_in, 3)


async def test_ray_init(dut, ray_direction, ray_origin):
    """
    Tests initialization of ray parameters
    """
    dut.ray_direction.value = vec3.encode(ray_direction)
    dut.ray_origin.value = vec3.encode(ray_origin)

    await reset(dut.rst_in, dut.clk_in)

    assert dut.state.value == 0, "Expected to be in reset state!"

    await Edge(dut.state)

    assert dut.state.value == 1, "Expected to be in traversal state!"

    # Compare against ground truth
    alg = VoxelTraversal(ray_direction, ray_origin)

    # Now just compare stuff
    assert dut.init_timer.value == 13
    assert dut.ray_ori.value.binstr == vec3.encode_str(alg.ray_origin_in)
    assert dut.ray_dir.value.binstr == vec3.encode_str(alg.ray_direction)
    assert dut.ray_pos.value.binstr == vec3i.encode_str(alg.ray_position)
    assert dut.ray_step.value.binstr == vec3i.encode_str(alg.ray_step)
    assert dut.ray_d_dt.value.binstr == vec3.encode_str(alg.ray_t_delta)
    assert dut.ray_dist.value.binstr == vec3.encode_str(alg.ray_dist)
    assert dut.ray_t_max.value.binstr == vec3.encode_str(alg.ray_t_max)


def is_runner():
    """Image Sprite Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    print(proj_path)
    sources = [proj_path / "hdl" / "vtu.sv"]
    includes = [proj_path / "hdl"]
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        includes=includes,
        hdl_toplevel="VoxelTraversalUnit",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True,
        build_dir=(proj_path.parent / "sim_build")
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="VoxelTraversalUnit",
        test_module="test_vtu",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    is_runner()

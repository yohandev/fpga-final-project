import cocotb
import os
import sys
import logging
import vec3
import vec3i
import fixed
import blocks
import numpy as np
import matplotlib.pyplot as plt
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


async def mock_cache(dut):
    dut.ram_out.value = 0
    dut.ram_valid.value = 0

    with open(Path(__file__).resolve().parent / "chunk.bin", "rb") as f:
        chunk = list(int(i) for i in f.read(-1))

    def idx():
        v = dut.ram_addr.value.binstr
        pos = (int(v[i*7:(i+1)*7], base=2) for i in range(3))
        pos = tuple((i - (1 << 7) if i & (1 << (7 - 1)) else i) for i in pos)

        if not all(-40 <= i < 40 for i in pos):
            return None
        
        return 80 * ((80 * (pos[2] + 40)) + (pos[1] + 40)) + (pos[0] + 40)

    while True:
        await RisingEdge(dut.clk_in)

        dut.ram_valid.value = 0
        
        # Not reading
        if not dut.ram_read_enable.value:
            continue
        
        i = idx()
        if i != None:
            await ClockCycles(dut.clk_in, 2)

            # Good access
            dut.ram_out.value = chunk[i]
            dut.ram_valid.value = 1

            await ClockCycles(dut.clk_in, 1)
            dut.ram_valid.value = 0
        else:
            await ClockCycles(dut.clk_in, 1)

            # Out of bounds => air
            dut.ram_out.value = blocks.AIR
            dut.ram_valid.value = 1

            await ClockCycles(dut.clk_in, 1)
            dut.ram_valid.value = 0


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


@cocotb.test()
async def test_mock_render(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    # cocotb.start_soon(mock_cache(dut))

    FRAME_WIDTH = 128
    FRAME_HEIGHT = 64
    VIEWPORT_HEIGHT = fixed.fixed(2)
    VIEWPORT_WIDTH = fixed.fixed(2.0 * FRAME_WIDTH / FRAME_HEIGHT)

    img = np.zeros((FRAME_HEIGHT, FRAME_WIDTH, 3), dtype=np.uint8)

    # Re-implementation of sw/src/orchestrator.rs::Orchestrator::mock_render which is
    # known to work
    camera_heading = vec3.from_f32((0, 0, 1))
    camera_position = vec3.from_f32((0, 3, 0))


    w = vec3.normalize(camera_heading)
    u = vec3.normalize((w[2], 0, fixed.negate(w[0])))
    v = vec3.cross(w, u)

    viewport_u = vec3.mul(u, VIEWPORT_WIDTH)
    viewport_v = vec3.mul(vec3.negate(v), VIEWPORT_HEIGHT)

    pixel_delta_u = vec3.mul(u, fixed.fixed(fixed.f32(VIEWPORT_WIDTH) / FRAME_WIDTH))
    pixel_delta_v = vec3.mul(vec3.negate(v), fixed.fixed(fixed.f32(VIEWPORT_HEIGHT) / FRAME_HEIGHT))

    viewport_corner = vec3.sub(vec3.sub(camera_position, w), vec3.mul(vec3.add(viewport_u, viewport_v), fixed.fixed(0.5)))
    pixel0_loc = vec3.add(viewport_corner, vec3.mul(vec3.add(pixel_delta_u, pixel_delta_v), fixed.fixed(0.5)))

    sun = vec3.normalize(vec3.from_f32((1, -5, 2)))

    dist_traversed = 0

    dut.ray_origin.value = vec3.encode(camera_position)
    for i in range(FRAME_WIDTH * FRAME_HEIGHT):
        x = fixed.fixed(int(i % FRAME_WIDTH))
        y = fixed.fixed(int(i / FRAME_WIDTH))

        if i % FRAME_WIDTH == FRAME_WIDTH - 1:
            print(f"Rendered row {int(fixed.f32(y)) + 1}/{FRAME_HEIGHT}")
            print(f"    -> Average # steps: {dist_traversed / FRAME_WIDTH}")
            dist_traversed = 0
        
        pixel = vec3.add(pixel0_loc, vec3.add(vec3.mul(pixel_delta_u, x), vec3.mul(pixel_delta_v, y)))
        
        light = vec3.dot(vec3.decode(dut.hit_norm.value), sun)
        light = fixed.add(fixed.fixed(0.4), fixed.mul(fixed.fixed(0.2), light))
        light = fixed.f32(light)

        dut.ray_direction.value = vec3.encode(vec3.sub(pixel, camera_position))
        
        dut.rst_in.value = 1
        await ClockCycles(dut.clk_in, 1)
        dut.rst_in.value = 0

        await RisingEdge(dut.hit_valid)

        dist_traversed += dut.num_steps.value

        if dut.hit.value == blocks.AIR: col = [174, 200, 235]
        elif dut.hit.value == blocks.WATER: col = [52, 67, 138]
        elif dut.hit.value == blocks.GRASS: col = [90, 133, 77]
        elif dut.hit.value == blocks.DIRT: col = [133, 96, 77]
        elif dut.hit.value == blocks.OAK_LOG: col = [91, 58, 42]
        elif dut.hit.value == blocks.OAK_LEAVES: col = [129, 165, 118]
        else: col = [82, 70, 84]

        if dut.hit.value != blocks.AIR:
            col = (np.array(col) * light).astype(np.uint8)
        
        img[i // FRAME_WIDTH][i % FRAME_WIDTH] = col

    plt.imshow(img)
    plt.show()


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
        hdl_toplevel="voxel_traversal_unit",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True,
        build_dir=(proj_path.parent / "sim_build")
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="voxel_traversal_unit",
        test_module="test_vtu",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    is_runner()

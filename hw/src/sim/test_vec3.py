import cocotb
import os
import sys
import fixed
import vec3
from pathlib import Path
from cocotb.clock import Clock
from cocotb.binary import BinaryValue, BinaryRepresentation
from cocotb.triggers import ClockCycles, FallingEdge
from cocotb.runner import get_runner
from random import random


async def generic_test(dut, op, output, *, delay=1, small=True):
    for _ in range(1000):
        await FallingEdge(dut.clk_in)
        
        a = (
            fixed.fixed((random() - 0.5) * fixed.f32(fixed.MAX ** (0.5 if small else 1))),
            fixed.fixed((random() - 0.5) * fixed.f32(fixed.MAX ** (0.5 if small else 1))),
            fixed.fixed((random() - 0.5) * fixed.f32(fixed.MAX ** (0.5 if small else 1))),
        )
        b = (
            fixed.fixed((random() - 0.5) * fixed.f32(fixed.MAX ** (0.5 if small else 1))),
            fixed.fixed((random() - 0.5) * fixed.f32(fixed.MAX ** (0.5 if small else 1))),
            fixed.fixed((random() - 0.5) * fixed.f32(fixed.MAX ** (0.5 if small else 1))),
        )

        out = op((a, b))

        # Ignore overflows
        if not all(fixed.MIN <= o <= fixed.MAX for o in out):
            continue

        dut.a.value = vec3.encode(a)
        dut.b.value = vec3.encode(b)

        # Test pipelining by changing the inputs (throutput = 1 for every arithmetic op)
        await ClockCycles(dut.clk_in, 1, rising=False)
        dut.a.value = 0
        dut.b.value = 0

        await ClockCycles(dut.clk_in, delay - 1, rising=False)

        assert vec3.encode_str(out) == output(dut).value.binstr

@cocotb.test()
async def test_expr(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())

    print("Testing addition...")
    await generic_test(dut, lambda ab: vec3.add(*ab), lambda d: d.add)

    print("Testing subtraction...")
    await generic_test(dut, lambda ab: vec3.sub(*ab), lambda d: d.sub)

    print("Testing multiplication...")
    await generic_test(dut, lambda ab: vec3.mul(ab[0], ab[1][0]), lambda d: d.mul, small=True)

    print("Testing normalization...")
    await generic_test(dut, lambda ab: vec3.normalize(ab[0]), lambda d: d.norm, delay=6)


def is_runner():
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    print(proj_path)
    sources = [proj_path / "hdl" / "vec3.sv"]
    includes = [proj_path / "hdl"]
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        includes=includes,
        hdl_toplevel="vec3_testbench",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True,
        build_dir=(proj_path.parent / "sim_build")
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="vec3_testbench",
        test_module="test_vec3",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    is_runner()

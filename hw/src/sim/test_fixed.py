import cocotb
import os
import sys
import fixed
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge
from cocotb.runner import get_runner
from random import random

async def generic_test(dut, op, output, *, positive=False, small=False, lte1=False, delay=1):
    for i in range(1000):
        await FallingEdge(dut.clk_in)
        
        if lte1:
            a = fixed.fixed(random() - 0.5) * 2
            b = fixed.fixed(random() - 0.5) * 2
        else:
            a = fixed.fixed((random() - 0.5) * fixed.f32(fixed.MAX ** (0.5 if small else 1)))
            b = fixed.fixed((random() - 0.5) * fixed.f32(fixed.MAX ** (0.5 if small else 1)))

        if positive:
            a = abs(a)
            b = abs(b)

        # 0 can be an edge case in a lot of cases, make sure we consider it
        if i == 0:
            a = 0
            b = 0

        out = op((a, b))

        # Ignore overflows
        if not lte1 or not (fixed.MIN <= out <= fixed.MAX):
            continue

        dut.a.value = fixed.encode(a)
        dut.b.value = fixed.encode(b)

        # Test pipelining by changing the inputs (throutput = 1 for every arithmetic op)
        await ClockCycles(dut.clk_in, 1, rising=False)
        dut.a.value = 0
        dut.b.value = 0

        await ClockCycles(dut.clk_in, delay - 1, rising=False)

        assert fixed.encode_str(out) == output(dut).value.binstr

@cocotb.test()
async def test_expr(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())

    print("Testing addition...")
    await generic_test(dut, lambda ab: fixed.add(*ab), lambda d: d.add)

    print("Testing subtraction...")
    await generic_test(dut, lambda ab: fixed.sub(*ab), lambda d: d.sub)

    print("Testing multiplication...")
    await generic_test(dut, lambda ab: fixed.mul(*ab), lambda d: d.mul, small=True)
    
    print("Testing inverse square root...")
    await generic_test(dut, lambda ab: fixed.inv_sqrt(ab[0]), lambda d: d.inv_sqrt, positive=True, delay=4)

    print("Testing reciprocal...")
    await generic_test(dut, lambda ab: fixed.recip_lte1(ab[0]), lambda d: d.recip, delay=3, lte1=True)


def is_runner():
    """Image Sprite Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    print(proj_path)
    sources = [proj_path / "hdl" / "fixed.sv"]
    includes = [proj_path / "hdl"]
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        includes=includes,
        hdl_toplevel="fixed_testbench",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True,
        build_dir=(proj_path.parent / "sim_build")
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="fixed_testbench",
        test_module="test_fixed",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    is_runner()

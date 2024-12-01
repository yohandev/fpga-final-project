import cocotb
import os
import sys
from pathlib import Path
from cocotb.clock import Clock
from cocotb.binary import BinaryValue, BinaryRepresentation
from cocotb.triggers import ClockCycles, FallingEdge
from cocotb.runner import get_runner
from random import random
from math import sqrt


D = 15
FIXED_MAX = (1 << 31) - 1;
FIXED_MIN = -(1 << 31)

def fixed(f): return int(f * (1 << D))
def f32(fx): return float(fx / (1 << D))

def fixed_mul(a, b): return int((a * b) >> D)

def leading_zeros(n):
    for i in reversed(range(32)):
        if n & (1 << i):
            return 31 - i
    return 32

def fixed_inv_sqrt(fx):
    def lut(lz):
        if lz == 31:
            return fixed(1 / sqrt(f32(0b1)))
        elif 0 <= lz <= 30:
            return fixed(1 / sqrt(f32(0b11 << (30 - lz))))
    
    # First iteration (LUT)
    iter0 = lut(leading_zeros(fx) - 1)
    
    # Second iteration (Newton)
    iter1 = fixed_mul(iter0, fixed(1.5) - fixed_mul(fx >> 1, fixed_mul(iter0, iter0)))

    # Third iteration (Newton)
    # iter2 = fixed_mul(iter1, fixed(1.5) - fixed_mul(fx >> 1, fixed_mul(iter1, iter1)))

    return iter1

def twos_complement(n):
    return BinaryValue(n, 32, False, BinaryRepresentation.TWOS_COMPLEMENT).integer


async def generic_test(dut, op, output, *, positive=False, delay=1):
    for _ in range(1000):
        await FallingEdge(dut.clk_in)
        
        a = fixed((random() - 0.5) * f32(FIXED_MAX))
        b = fixed((random() - 0.5) * f32(FIXED_MAX))

        if positive:
            a = abs(a)
            b = abs(b)

        out = op((a, b))

        # Ignore overflows
        if not (FIXED_MIN <= out <= FIXED_MAX):
            continue

        dut.a.value = twos_complement(a)
        dut.b.value = twos_complement(b)

        # Test pipelining by changing the inputs (throutput = 1 for every arithmetic op)
        await ClockCycles(dut.clk_in, 1, rising=False)
        dut.a.value = 0
        dut.b.value = 0

        await ClockCycles(dut.clk_in, delay - 1, rising=False)

        assert out == output(dut).value.signed_integer

@cocotb.test()
async def test_expr(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())

    print("Testing addition...")
    await generic_test(dut, lambda ab: ab[0] + ab[1], lambda d: d.add)

    print("Testing subtraction...")
    await generic_test(dut, lambda ab: ab[0] - ab[1], lambda d: d.sub)

    print("Testing multiplication...")
    await generic_test(dut, lambda ab: fixed_mul(*ab), lambda d: d.mul)

    print("Testing mixed expressions...")
    await generic_test(dut, lambda ab: fixed_mul((fixed_mul(ab[0], ab[1]) + (ab[1] - ab[0])), (ab[0] - ab[1])), lambda d: d.mul)
    
    print("Testing inverse square root...")
    await generic_test(dut, lambda ab: fixed_inv_sqrt(ab[0]), lambda d: d.inv_sqrt, positive=True, delay=4)


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

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


D = 8
B = 20
FIXED_MAX = (1 << (B-1)) - 1;
FIXED_MIN = -(1 << (B-1))

def fixed(f): return int(f * (1 << D))
def f32(fx): return float(fx / (1 << D))

def fixed_mul(a, b): return int((a * b) >> D) & (2**B - 1)
def fixed_add(a, b) : return (a + b) & (2**B - 1)
def fixed_sub(a, b) : return (a - b) & (2**B - 1)

def leading_zeros(n):
    for i in reversed(range(B)):
        if n & (1 << i):
            return (B-1) - i
    return B

def fixed_inv_sqrt(fx):
    def lut(lz):
        if lz == B-1:
            return fixed(1 / sqrt(f32(0b1)))
        elif 0 <= lz <= B-2:
            return fixed(1 / sqrt(f32(0b11 << ((B-2) - lz))))
    
    # First iteration (LUT)
    iter0 = lut(leading_zeros(fx) - 1)
    
    # Second iteration (Newton)
    iter1 = fixed_mul(iter0, fixed(1.5) - fixed_mul(fx >> 1, fixed_mul(iter0, iter0)))

    # Third iteration (Newton)
    # iter2 = fixed_mul(iter1, fixed(1.5) - fixed_mul(fx >> 1, fixed_mul(iter1, iter1)))

    return iter1

def fixed_recip_lte1(fx):
    def lut_dbl(i):
        return fixed((1 / f32(i << (D - 6))) * 2) if i != 0 else fixed(1)
    def lut_sqr(i):
        if i == 1:
            # I modified this one manually b/c it overflowed
            return 0xFFFFF
        return fixed((1 / f32(i << (D - 6))) ** 2) if i != 0 else fixed(1)
    
    # First iteration (LUT)
    idx = (abs(fx) >> (D - 6)) & 63 # index into LUT is 6 MSB of fractional part

    iter0_dbl = lut_dbl(idx) * (1 if fx > 0 else -1)
    iter0_sqr = lut_sqr(idx)
    
    # Second iteration (Newton)
    iter1 = fixed_sub(iter0_dbl, fixed_mul(fx, iter0_sqr))

    return iter1

def twos_complement(n):
    return BinaryValue(n, B, False, BinaryRepresentation.TWOS_COMPLEMENT).integer


async def generic_test(dut, op, output, *, positive=False, small=False, lte1=False, delay=1):
    for _ in range(1000):
        await FallingEdge(dut.clk_in)
        
        if lte1:
            a = fixed(random() - 0.5) * 2
            b = fixed(random() - 0.5) * 2

            # Special case for recip, behavior is weird around 0
            if abs(f32(a)) < 0.03:
                continue
        else:
            a = fixed((random() - 0.5) * f32(FIXED_MAX ** (0.5 if small else 1)))
            b = fixed((random() - 0.5) * f32(FIXED_MAX ** (0.5 if small else 1)))

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
    await generic_test(dut, lambda ab: fixed_mul(*ab), lambda d: d.mul, small=True)
    
    print("Testing inverse square root...")
    await generic_test(dut, lambda ab: fixed_inv_sqrt(ab[0]), lambda d: d.inv_sqrt, positive=True, delay=4)

    print("Testing reciprocal...")
    await generic_test(dut, lambda ab: fixed_recip_lte1(ab[0]), lambda d: d.recip, delay=3, lte1=True)


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

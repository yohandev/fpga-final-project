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

def fixed_mul(a, b): return int((a * b) >> D) & (2**32 - 1)
def fixed_add(a, b) : return (a + b) & (2**32 - 1)

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

def fixed_recip_lte1(fx):
    def lut(i):
        return fixed(1 / f32(i << (D - 6))) if i != 0 else fixed(1)
    
    # First iteration (LUT)
    idx = (abs(fx) >> (D - 6)) & 63 # index into LUT is 6 MSB of fractional part
    iter0 = lut(idx) * (1 if fx > 0 else -1)
    
    # Second iteration (Newton)
    iter1 = (iter0 << 1) - fixed_mul(fx, fixed_mul(iter0, iter0))

    return iter1

def twos_complement(n):
    return BinaryValue(n, 32, False, BinaryRepresentation.TWOS_COMPLEMENT).binstr.zfill(32)

def encode_vec3(v):
    x, y, z = v

    return BinaryValue(twos_complement(x) + twos_complement(y) + twos_complement(z))

def vec3_normalize(v):
    x, y, z = v
    m = fixed_inv_sqrt(fixed_add(fixed_mul(x, x), fixed_add(fixed_mul(y, y), fixed_mul(z, z))))

    return (fixed_mul(x, m), fixed_mul(y, m), fixed_mul(z, m))


async def generic_test(dut, op, output, *, delay=1, small=True):
    for _ in range(1000):
        await FallingEdge(dut.clk_in)
        
        a = (
            fixed((random() - 0.5) * f32(FIXED_MAX ** (0.5 if small else 1))),
            fixed((random() - 0.5) * f32(FIXED_MAX ** (0.5 if small else 1))),
            fixed((random() - 0.5) * f32(FIXED_MAX ** (0.5 if small else 1))),
        )
        b = (
            fixed((random() - 0.5) * f32(FIXED_MAX ** (0.5 if small else 1))),
            fixed((random() - 0.5) * f32(FIXED_MAX ** (0.5 if small else 1))),
            fixed((random() - 0.5) * f32(FIXED_MAX ** (0.5 if small else 1))),
        )

        out = op((a, b))

        # Ignore overflows
        if not all(FIXED_MIN <= o <= FIXED_MAX for o in out):
            continue

        dut.a.value = encode_vec3(a)
        dut.b.value = encode_vec3(b)

        # Test pipelining by changing the inputs (throutput = 1 for every arithmetic op)
        await ClockCycles(dut.clk_in, 1, rising=False)
        dut.a.value = 0
        dut.b.value = 0

        await ClockCycles(dut.clk_in, delay - 1, rising=False)

        assert encode_vec3(out) == output(dut).value.binstr

@cocotb.test()
async def test_expr(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())

    print("Testing addition...")
    await generic_test(dut, lambda ab: [a + b for (a, b) in zip(*ab)], lambda d: d.add)

    print("Testing subtraction...")
    await generic_test(dut, lambda ab: [a - b for (a, b) in zip(*ab)], lambda d: d.sub)

    print("Testing multiplication...")
    await generic_test(dut, lambda ab: [fixed_mul(a, ab[1][0]) for a in ab[0]], lambda d: d.mul, small=True)

    print("Testing normalization...")
    await generic_test(dut, lambda ab: vec3_normalize(ab[0]), lambda d: d.norm, delay=7)


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

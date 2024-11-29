import cocotb
import os
import sys
import logging
import numpy as np
from pathlib import Path
from cocotb.clock import Clock
from cocotb.binary import BinaryValue, BinaryRepresentation
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly,with_timeout
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner


CACHE_SIZE = 16
PORTS = 4


def twos_complement(n):
    return BinaryValue(n, 7, False, BinaryRepresentation.TWOS_COMPLEMENT).binstr

def reverse_bits(n):
    if isinstance(n, BinaryValue):
        return int(n.binstr[::-1], base=2)

    out = 0
    while n:
        out = (out << 1) + (n & 1)
        n >>= 1
    
    return out


async def reset(rst, clk):
    """ Helper function to issue a reset signal to our module """
    rst.value = 1
    await ClockCycles(clk, 3)
    rst.value = 0
    await ClockCycles(clk, 3)


async def query_cache(dut, ports):
    """Query the caches

    Args:
        ports (list[int, tuple[int, int, int]]): List of (ports, xyz)

    Returns:
        list[int]: The returned blocks per port, in the order given
    """
    val = dut.addr.value
    
    for (port, (x, y, z)) in ports:
        off = (PORTS - port - 1) * 21

        val[off+0:off+6]   = twos_complement(z)
        val[off+7:off+13]  = twos_complement(y)
        val[off+14:off+20] = twos_complement(x)

    dut.addr.value = val

    await ClockCycles(dut.clk_in, 2)

    out = []
    for (port, _) in ports:
        if dut.valid.value & (1 << port):
            out.append((dut.out.value >> (5 * port)) & 0b11111)
        else:
            # Cache miss!
            out.append(None)
    
    return out


@cocotb.test()
async def test_a(dut):
    """cocotb test for image_sprite"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())

    dut.addr.value = 0

    await reset(dut.rst_in, dut.clk_in)

    # Test reset marks all entries invalid
    for i in range(CACHE_SIZE):
        assert dut.tags.value[i*7:(i+1)*7-1].signed_integer == -64

    # Test on empty cache
    # This is exploting the "INVALID" tag to get cache hits
    assert (await query_cache(dut, [(0, (-64, -64, -64))])) == [0]
    assert (await query_cache(dut, [(1, (-64, -64, -64))])) == [0]
    assert (await query_cache(dut, [(1, (0, 4, 62))])) == [None]
    assert (await query_cache(dut, [(0, (-64, -64, -64)), (1, (-64, -64, -64))])) == [0, 0]
    assert (await query_cache(dut, [(0, (0, 0, 0)), (1, (-64, -64, -64))])) == [None, 0]

    # Manually put stuff in the cache
    tags = dut.tags.value
    entries = dut.entries.value
    
    tags[0:6]   = twos_complement(-3)
    tags[7:13]  = twos_complement(42)
    tags[14:20] = twos_complement(-21)
    entries[0:4] = 0b11011

    dut.tags.value = tags
    dut.entries.value = entries

    await ClockCycles(dut.clk_in, 3)

    # Test on this new cache with one entry
    assert (await query_cache(dut, [(0, (-64, -64, -64))])) == [0]
    assert (await query_cache(dut, [(1, (-21, 42, -3))])) == [0b11011]
    assert (await query_cache(dut, [(2, (0, 0, 0))])) == [None]
    assert (await query_cache(dut, [(1, (-21, 42, -3))])) == [0b11011]
    assert (await query_cache(dut, [(0, (0, 0, 0)), (1, (-21, 42, -3))])) == [None, 0b11011]
    assert (await query_cache(dut, [(1, (0, 0, 0)), (0, (-21, 42, -3))])) == [None, 0b11011]
    assert (await query_cache(dut, [(1, (-21, 42, -3)), (0, (-21, 42, -3))])) == [0b11011, 0b11011]

    await ClockCycles(dut.clk_in, 5)


def is_runner():
    """Image Sprite Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    print(proj_path)
    sources = [proj_path / "hdl" / "l2_cache.sv"]
    includes = [proj_path / "hdl"]
    build_test_args = ["-Wall"]
    parameters = {
        "CACHE_SIZE": CACHE_SIZE,
        "PORTS": PORTS,
    }
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        includes=includes,
        hdl_toplevel="l2_cache",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True,
        build_dir=(proj_path.parent / "sim_build")
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="l2_cache",
        test_module="test_l2_cache",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    is_runner()

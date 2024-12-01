import cocotb
import os
import sys
import logging
import numpy as np
from pathlib import Path
from cocotb.clock import Clock
from cocotb.binary import BinaryValue, BinaryRepresentation
from cocotb.triggers import ClockCycles, RisingEdge
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner
from random import randint


CACHE_SIZE = 16
PORTS = 4

l3 = {}


def twos_complement(n):
    return BinaryValue(n, 7, False, BinaryRepresentation.TWOS_COMPLEMENT).binstr.rjust(7, "0")

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


async def mock_l3_cache(dut):
    dut.l3_valid.value = 0
    dut.l3_out.value = 0

    while True:
        await RisingEdge(dut.clk_in)
        if not dut.l3_read_enable.value:
            continue
        
        # Start query
        z = dut.l3_addr.value[0:6].signed_integer
        y = dut.l3_addr.value[7:13].signed_integer
        x = dut.l3_addr.value[14:20].signed_integer

        # Make-up some random value
        if (x, y, z) not in l3:
            l3[(x, y, z)] = randint(0, 31)

        await ClockCycles(dut.clk_in, randint(3, 100))

        dut.l3_out.value = l3[(x, y, z)]
        dut.l3_valid.value = 1
        await ClockCycles(dut.clk_in, 1)
        dut.l3_valid.value = 0


async def query_l2_cache(dut, port, addr, expect=None):
    x, y, z = addr
    off = (PORTS - port - 1) * 21

    print(f"querying ({x}, {y}, {z})")

    addr = dut.addr.value
    read_enable = dut.read_enable.value

    addr[off+0:off+6]   = twos_complement(z)
    addr[off+7:off+13]  = twos_complement(y)
    addr[off+14:off+20] = twos_complement(x)
    read_enable[PORTS - port - 1] = 1

    assert z == addr[off+0:off+6].signed_integer
    assert y == addr[off+7:off+13].signed_integer
    assert x == addr[off+14:off+20].signed_integer

    dut.addr.value = addr
    dut.read_enable.value = read_enable

    await ClockCycles(dut.clk_in, 1)

    # Wait for an (eventual) cache-hit
    for i in range(10_000):
        await ClockCycles(dut.clk_in, 1)
        
        # Cache-hit!
        if dut.valid.value & (1 << port):
            out = (dut.out.value >> (5 * port)) & 0b11111
            
            # Reset read flag
            read_enable = dut.read_enable.value
            read_enable[PORTS - port - 1] = 0
            dut.read_enable.value = read_enable

            # Did it read correctly?
            assert out == l3[(x, y, z)]

            # Did the hit/miss behaviour happen?
            if expect:
                assert expect == ("instant" if i < 3 else "miss")
            return
    
    raise "L2 cache timeout!"


@cocotb.test()
async def test_a(dut):
    """cocotb test for image_sprite"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    cocotb.start_soon(mock_l3_cache(dut))

    dut.addr.value = 0
    dut.read_enable.value = 0

    await reset(dut.rst_in, dut.clk_in)

    # == Test reset marks all entries invalid ==
    for i in range(CACHE_SIZE):
        assert dut.occupied.value[i] == 0

    # == Test basic serial accesses ==
    await query_l2_cache(dut, 0, (3, 4, 5), "miss")
    await query_l2_cache(dut, 0, (62, -45, -62), "miss")
    await query_l2_cache(dut, 1, (3, 4, 5), "instant")
    await query_l2_cache(dut, 0, (3, 4, 5), "instant")
    await query_l2_cache(dut, 1, (0, 22, 61), "miss")

    await ClockCycles(dut.clk_in, 10)

    # == Test concurrent accesses ==
    # They should all miss, but in the FST viewer, they should all
    # resolve at the same time
    tasks = []
    for p in range(PORTS):
        tasks.append(cocotb.start_soon(query_l2_cache(dut, p, (2, 2, 2), "miss")))
        
        # Start them a cycle apart because python race condition
        await ClockCycles(dut.clk_in, 1)
    
    await tasks[0].join()
    for task in tasks:
        # They shoud all resolve at the same time
        assert task.done()

    # == Stress test ==
    for _ in range(1000):
        port = randint(0, PORTS-1)
        addr = (randint(-64, 63), randint(-64, 63), randint(-64, 63))
        
        await query_l2_cache(dut, port, addr)
        await ClockCycles(dut.clk_in, 10)


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

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
    mk_val = lambda n: BinaryValue(n, 7, False, BinaryRepresentation.TWOS_COMPLEMENT).binstr
    
    for (port, (x, y, z)) in ports:
        off = (PORTS - port - 1) * 21

        val[off+0:off+6]   = mk_val(z)
        val[off+7:off+13]  = mk_val(y)
        val[off+14:off+20] = mk_val(x)

    dut.addr.value = val

    await ClockCycles(dut.clk_in, 2)

    out = []
    for (port, _) in ports:
        if dut.valid.value[PORTS - port - 1]:
            out.append(dut.out.value[port*5:(port+1)*5-1])
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
    # This is exploting the "INVALID" tag
    assert (await query_cache(dut, [(0, (-64, -64, -64))])) == [0]
    assert (await query_cache(dut, [(1, (-64, -64, -64))])) == [0]
    assert (await query_cache(dut, [(1, (0, 4, 62))])) == [None]
    assert (await query_cache(dut, [(0, (-64, -64, -64)), (1, (-64, -64, -64))])) == [0, 0]
    assert (await query_cache(dut, [(0, (0, 0, 0)), (1, (-64, -64, -64))])) == [None, 0]

    await ClockCycles(dut.clk_in, 10)


def is_runner():
    """Image Sprite Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    print(proj_path)
    sources = [proj_path / "hdl" / "l1_cache.sv"]
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
        hdl_toplevel="l1_cache",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="l1_cache",
        test_module="test_l1_cache",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    is_runner()

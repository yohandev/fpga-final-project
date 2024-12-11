import cocotb
import os
import sys
from pathlib import Path
from cocotb.clock import Clock
from cocotb.binary import BinaryValue, BinaryRepresentation
from cocotb.triggers import ClockCycles, FallingEdge, ReadOnly
from cocotb.runner import get_runner
import random

async def write_block_data(dut, length, width, height):
    for i in range(height):
        dut.zwrite.value = i
        for j in range(width):
            dut.ywrite.value = j
            for k in range(length):
                dut.xwrite.value = k
                dut.uart_data_in.value = random.getrandbits(8)
                dut.write_enable.value = 1
                dut.read_enable.value = 0
                dut.valid_in.value = 1
                await ClockCycles(dut.clk_in, 1)

async def read_block_data(dut, length, width, height):
    for i in range(height):
        dut.zread.value = i
        for j in range(width):
            dut.yread.value = j
            for k in range(length):
                dut.xread.value = k
                dut.read_enable.value = 1
                dut.write_enable.value = 0
                await ReadOnly()
                data_out = dut.block_data_out.value
                dut._log.info(f"Receiver Data: {data_out}")
                await ClockCycles(dut.clk_in, 1)

async def read_write_block_data(dut, length, width, height):
    for i in range(height):
        dut.zread.value = i
        dut.zwrite.value = i
        for j in range(width):
            dut.yread.value = j
            dut.ywrite.value = j
            for k in range(length):
                dut.xread.value = k
                dut.xwrite.value = k
                dut.read_enable.value = 1
                dut.write_enable.value = 1
                dut.valid_in.value = 1
                dut.uart_data_in.value = random.getrandbits(8)
                data_in = dut.uart_data_in.value
                dut._log.info(f"Write Data: {data_in[0:4]}")
                await ReadOnly()
                data_out = dut.block_data_out.value
                dut._log.info(f"Receiver Data: {data_out}")
                await ClockCycles(dut.clk_in, 1)

@cocotb.test()
async def test_a(dut):
    L = 8
    K = 8
    M = 8
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.rst_in.value = 0
    await ClockCycles(dut.clk_in,1)
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in,5)
    dut.rst_in.value = 0
    await ClockCycles(dut.clk_in, 1)
    print("this is newer version")
    # Write initial block data
    await write_block_data(dut, L, K, M)
    await ClockCycles(dut.clk_in, 100)

    # Perform read/write test
    await read_write_block_data(dut, L, K, M)
    await ClockCycles(dut.clk_in, 100)

    # Perform a read test before movement
    dut._log.info("Reading block data before movement...")
    await read_block_data(dut, L, K, M)
    await ClockCycles(dut.clk_in, 100)

    # Move forward (+X): control_input = 4'b0001
    dut._log.info("Moving forward (+X)...")
    dut.control_input.value = 0b0001
    dut.control_trigger.value = 1
    dut.valid_in.value = 1
    await ClockCycles(dut.clk_in, 1)
    dut.control_trigger.value = 0
    dut.valid_in.value = 0
    await ClockCycles(dut.clk_in, 5)

    # Move left (-Z): control_input = 4'b1000
    dut._log.info("Moving left (-Z)...")
    dut.control_input.value = 0b1000
    dut.control_trigger.value = 1
    dut.valid_in.value = 1
    await ClockCycles(dut.clk_in, 1)
    dut.control_trigger.value = 0
    dut.valid_in.value = 0
    await ClockCycles(dut.clk_in, 5)

    # After moving +X and -Z, read again from the same block data to see changes
    dut._log.info("Reading block data after movement (+X and -Z)...")
    await read_block_data(dut, L, K, M)
    await ClockCycles(dut.clk_in, 100)


def is_runner():
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    print(proj_path)
    sources = [proj_path / "hdl" / "l3_cache.sv"]
    sources += [proj_path / "hdl" / "xilinx_true_dual_port_read_first_2_clock_ram.v"]
    includes = [proj_path / "hdl"]
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        includes=includes,
        hdl_toplevel="l3_cache",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True,
        build_dir=(proj_path.parent / "sim_build")
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="l3_cache",
        test_module="test_l3_cache_update",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    is_runner()
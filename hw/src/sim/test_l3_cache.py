import cocotb
import os
import sys
from pathlib import Path
from cocotb.clock import Clock
from cocotb.binary import BinaryValue, BinaryRepresentation
from cocotb.triggers import ClockCycles, FallingEdge
from cocotb.runner import get_runner

@cocotb.test()
async def test_l3_cache(dut):
    """
    Test the functionality of the L3 cache using FPGA BRAM.
    """

    # Start a clock on the system
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Reset the DUT
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    # Test configuration
    num_entries = 16  # Number of entries to test (adjustable)

    # Step 1: Write incrementing values to the cache
    for address in range(num_entries):
        dut.write_enable.value = 1
        dut.address.value = address
        dut.data_in.value = address  # Write incrementing values
        await RisingEdge(dut.clk)
        dut.write_enable.value = 0  # Turn off write enable
        await RisingEdge(dut.clk)

    # Step 2: Read back values from the cache and verify
    for address in range(num_entries):
        dut.read_enable.value = 1
        dut.address.value = address
        await RisingEdge(dut.clk)
        dut.read_enable.value = 0  # Turn off read enable
        await RisingEdge(dut.clk)

        # Verify data
        assert dut.data_out.value == address, (
            f"Data mismatch at address {address}: "
            f"expected {address}, got {dut.data_out.value}"
        )
        print(f"Address {address}: Read {dut.data_out.value} (PASS)")


def is_runner():
    """Image Sprite Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    print(proj_path)
    sources = [proj_path / "hdl" / "l3_cache.sv"]
    includes = [proj_path / "hdl"]
    build_test_args = ["-Wall"]
    parameters = {}
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
        hdl_toplevel="l3_cache",
        test_module="test_l3_cache",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    is_runner()
import cocotb
import os
import random
import sys
from math import log
import logging
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly,with_timeout
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner

# utility function to reverse bits:
def reverse_bits(n,size):
    reversed_n = 0
    for i in range(size):
        reversed_n = (reversed_n << 1) | (n & 1)
        n >>= 1
    return reversed_n

# test spi message:
UART_MSG = 0b1_0100_0011_0       # 0x74 = 0b0111_0100
#flip them:
# UART_MSG = reverse_bits(UART_MSG,8)

# this module below is a simple "fake" spi module written in Python that we can...
# test our design against.
async def test_uart_receiver(dut):
  count = 0
  count_max = 10 #change for different sizes
  while True:
    # await FallingEdge(dut.new_data_out) #listen for valid data signal
    await ClockCycles(dut.clk_in, 100_000_000//460800)
    # dut.rx_wire_in.value = (UART_MSG>>count)&0x1 #feed in lowest bit
    # dut._log.info(f"Signal transmitted to UART: {dut.rx_wire_in.value}")
    count+=1
    count%=10
    # while dut.chip_sel_out.value.integer ==0:
    #   await RisingEdge(dut.chip_clk_out)
    #   bit = dut.chip_data_out.value.integer #grab value:
    #   dut._log.info(f"SPI peripheral Device Receiving: {bit}")
    #   await FallingEdge(dut.chip_clk_out)
    #   dut.chip_data_in.value = (UART_MSG>>count)&0x1 #feed in lowest bit
    #   dut._log.info(f"SPI peripheral Device Sending: {dut.chip_data_in.value}")
    #   count+=1
    #   count%=8

@cocotb.test()
async def test_a(dut):
    """cocotb test for seven segment controller"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    
    dut._log.info("Holding reset...")
    dut.rst_in.value = 1
    # dut.trigger_in.value = 0
    # dut.data_in.value = 0x74&0xFF #set in 16 bit input value
    await ClockCycles(dut.clk_in, 3) #wait three clock cycles
    # assert dut.chip_sel_out.value.integer==1, "cs is not 1 on reset!"
    await  FallingEdge(dut.clk_in)
    dut.rst_in.value = 0 #un reset device
    
    cocotb.start_soon(test_uart_receiver(dut))
    
    dut.rx_wire_in.value = 0x0
    await ClockCycles(dut.clk_in, 100_000_000//460800)
    dut.rx_wire_in.value = 0x1
    await ClockCycles(dut.clk_in, 100_000_000//460800)
    dut.rx_wire_in.value = 0x1
    await ClockCycles(dut.clk_in, 100_000_000//460800)
    dut.rx_wire_in.value = 0x1
    await ClockCycles(dut.clk_in, 100_000_000//460800)
    dut.rx_wire_in.value = 0x1
    await ClockCycles(dut.clk_in, 100_000_000//460800)
    dut.rx_wire_in.value = 0x1
    await ClockCycles(dut.clk_in, 100_000_000//460800)
    dut.rx_wire_in.value = 0x0
    await ClockCycles(dut.clk_in, 100_000_000//460800)
    dut.rx_wire_in.value = 0x0
    await ClockCycles(dut.clk_in, 100_000_000//460800)
    dut.rx_wire_in.value = 0x0
    await ClockCycles(dut.clk_in, 100_000_000//460800)
    dut.rx_wire_in.value = 0x1
    await ClockCycles(dut.clk_in, 100_000_000//460800)
    # await ClockCycles(dut.clk_in, 3) #wait a few 
    # dut._log.info("Setting Trigger")
    # dut.trigger_in.value = 1
    # await ClockCycles(dut.clk_in, 1,rising=False)
    # dut.data_in.value = 0xAAAA # once trigger in is off, don't expect data_in to stay the same!!
    # dut.trigger_in.value = 0
    # await with_timeout(RisingEdge(dut.new_data_out),5000,'ns')
    await ReadOnly()
    data_out = dut.data_byte_out.value
    dut._log.info(f"Receiver Data: {data_out}")
    # assert data_out==0x43, "{data_out} != 0x43}"
    await ClockCycles(dut.clk_in, 2000)
    # await FallingEdge(dut.new_data_out)

def uart_receive_runner():
    """Simulate the counter using the Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "uart_receiver.sv"]
    build_test_args = ["-Wall"]
    parameters = {'INPUT_CLOCK_FREQ': 100_000_000, 'BAUD_RATE': 460800}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="uart_receiver",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="uart_receiver",
        test_module="test_uart_receiver",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    uart_receive_runner()

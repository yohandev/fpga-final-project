import cocotb
import os
import sys
from pathlib import Path
from cocotb.clock import Clock
from cocotb.binary import BinaryValue, BinaryRepresentation
from cocotb.triggers import ClockCycles, FallingEdge
from cocotb.runner import get_runner

@cocotb.test()
async def test_uart_transmitter(dut):
    """
    Test the UART transmitter by transmitting a series of bytes and observing the TX line.
    """
    # Start a clock for the transmitter
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Reset the DUT
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    # Test configuration
    baud_rate = 9600
    clk_freq = 100_000_000
    bit_period = int(clk_freq / baud_rate)

    # Bytes to transmit
    test_bytes = [0x55, 0xAA, 0xFF, 0x00]

    for byte in test_bytes:
        # Load the data into the transmitter
        dut.data_in.value = byte
        dut.tx_start.value = 1
        await RisingEdge(dut.clk)
        dut.tx_start.value = 0

        # Observe the TX line for the serial output
        for i in range(10):  # 1 start bit + 8 data bits + 1 stop bit
            await Timer(bit_period, units="ns")
            bit = dut.tx.value
            print(f"Bit {i}: {bit}")

    print("UART Transmitter Test Completed")


@cocotb.test()
async def test_uart_receiver(dut):
    """
    Test the UART receiver by sending a series of bytes to the RX line and verifying the output.
    """
    # Start a clock for the receiver
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Reset the DUT
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    # Test configuration
    baud_rate = 9600
    clk_freq = 100_000_000
    bit_period = int(clk_freq / baud_rate)

    # Bytes to receive
    test_bytes = [0x55, 0xAA, 0xFF, 0x00]

    for byte in test_bytes:
        # Simulate the serial input on RX line
        await send_uart_byte(dut.rx, byte, bit_period)
        
        # Wait for the receiver to process the data
        await FallingEdge(dut.new_data_out)

        # Verify the received byte
        received_byte = int(dut.data_byte_out.value)
        assert received_byte == byte, f"Expected {byte}, got {received_byte}"
        print(f"Received byte: {received_byte}")

    print("UART Receiver Test Completed")


async def send_uart_byte(rx, byte, bit_period):
    """
    Helper function to simulate a UART byte transmission to the RX line.
    """
    # Start bit
    rx.value = 0
    await Timer(bit_period, units="ns")

    # Data bits (LSB first)
    for i in range(8):
        rx.value = (byte >> i) & 1
        await Timer(bit_period, units="ns")

    # Stop bit
    rx.value = 1
    await Timer(bit_period, units="ns")


def is_runner():
    """Image Sprite Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    print(proj_path)
    sources = [proj_path / "hdl" / "uart_receiver.sv"]
    includes = [proj_path / "hdl"/"uart_transmitter.sv"]
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
        hdl_toplevel="uart_receiver",
        test_module="test_uart",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    is_runner()
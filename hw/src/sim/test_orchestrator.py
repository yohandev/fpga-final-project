import cocotb
import os
import sys
import logging
import vec3
import vec3i
import fixed
import blocks
import rgb565
import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path
from cocotb.clock import Clock
from cocotb.binary import BinaryValue, BinaryRepresentation
from cocotb.triggers import ClockCycles, RisingEdge, Edge
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner


FRAME_WIDTH = 64
FRAME_HEIGHT = 32

async def reset(rst, clk):
    """ Helper function to issue a reset signal to our module """
    rst.value = 1
    await ClockCycles(clk, 1)
    rst.value = 0
    await ClockCycles(clk, 1)


sbuf = np.zeros((FRAME_HEIGHT, FRAME_WIDTH, 3), dtype=np.uint8)

async def mock_frame_buffer(dut):
    sbuf_flat = sbuf.reshape((FRAME_WIDTH*FRAME_HEIGHT, 3), copy=False)
    while True:
        await RisingEdge(dut.sbuf_write_enable)
        await RisingEdge(dut.clk_in)

        addr = dut.sbuf_addr.value.integer
        value = dut.sbuf_data.value.integer

        sbuf_flat[addr] = rgb565.into_rgb8(value)


@cocotb.test()
async def render_frame(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    cocotb.start_soon(mock_frame_buffer(dut))
    
    await ClockCycles(dut.clk_in, 10)

    dut.camera_position.value = vec3.encode(vec3.from_f32((0, 3, 0)))
    dut.camera_heading.value = vec3.encode(vec3.from_f32((0, 0, 1)))

    await reset(dut.rst_in, dut.clk_in)
    
    await RisingEdge(dut.frame_done)
    plt.imshow(sbuf)
    plt.show()


def is_runner():
    """Image Sprite Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    print(proj_path)
    sources = [proj_path / "hdl" / "orchestrator.sv"]
    includes = [proj_path / "hdl"]
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        includes=includes,
        hdl_toplevel="orchestrator",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True,
        build_dir=(proj_path.parent / "sim_build")
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="orchestrator",
        test_module="test_orchestrator",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    is_runner()
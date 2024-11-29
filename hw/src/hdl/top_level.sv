`default_nettype none

`include "types.sv"

module top_level(
    input wire clk_100mhz,
    
    input wire [15:0] sw,
    input wire [3:0] btn,

    output logic [15:0] led,
    output logic [2:0]  rgb0,
    output logic [2:0]  rgb1

    // output logic [2:0]  hdmi_tx_p,  // HDMI output signals (positives) (blue, green, red)
    // output logic [2:0]  hdmi_tx_n,  // HDMI output signals (negatives) (blue, green, red)
    // output logic        hdmi_clk_p, // Differential HDMI clock
    // output logic        hdmi_clk_n,

    // input wire 	       uart_rxd,   // UART computer-FPGA
    // output logic        uart_txd    // UART FPGA-computer
);
    // Shut up those rgb LEDs for now (active high)
    assign rgb1 = 0;
    assign rgb0 = 0;

    logic sys_rst = btn[0];

    BlockPos [3:0] addr;
    BlockType [3:0] out;
    logic     [3:0] valid;

    // For now, use the switches as "inputs" to the cache so it
    // doesn't get optimized out. Ditto for outputs
    assign addr = {sw, sw, sw, sw, sw, sw};
    // assign led = {valid, out};
    
    l2_cache l2_cache(
        .clk_in(clk_100mhz),
        .rst_in(sys_rst),
        .addr(addr),
        .out(out),
        .valid(valid)
    );
endmodule

`default_nettype wire
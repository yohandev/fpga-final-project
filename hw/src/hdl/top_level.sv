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

    BlockPos    [3:0] addr;
    logic       [3:0] read_enable;

    BlockType   [3:0] out;
    logic       [3:0] valid;

    BlockPos     l3_addr;
    logic        l3_read_enable;
    BlockType    l3_out;
    logic        l3_valid;

    // For now, use the switches as "inputs" to the cache so it
    // doesn't get optimized out. Ditto for outputs
    assign addr = {btn[1], btn[2], btn[3], sw, sw, sw, sw, sw, sw};
    assign read_enable = {btn[3], btn[1], btn[2], btn[3]};
    assign l3_out = BlockType'(sw);
    assign l3_valid = {btn[1]};
    assign led = {valid, out} | {l3_read_enable, l3_addr};

    l2_cache l2_cache(
        .clk_in(clk_100mhz),
        .rst_in(sys_rst),
        .addr(addr),
        .read_enable(read_enable),
        .out(out),
        .valid(valid),
        .l3_addr(l3_addr),
        .l3_read_enable(l3_read_enable),
        .l3_out(l3_out),
        .l3_valid(l3_valid)
    );
endmodule

`default_nettype wire
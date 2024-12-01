`default_nettype none

`include "types.sv"
`include "fixed.sv"

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

    // Testing fixed's synthesis with BS input/outputs so it doesn't get optimized out
    fixed f_expr;
    fixed f_inv_sqrt;
    fixed f_recip;

    assign led = {f_expr | f_recip[24:8]};

    fixed_testbench ftest(
        .clk_in(clk_100mhz),
        .a({sw, btn[3], sw} & {btn[1], btn[2], sw}),
        .b({sw, btn[3], sw} | {btn[1], btn[2], sw}),
        .expr(f_expr),
        .inv_sqrt(f_inv_sqrt),
        .recip(f_recip)
    );
endmodule

`default_nettype wire
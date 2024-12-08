`default_nettype none

`include "types.sv"
`include "fixed.sv"
`include "vec3.sv"

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
    vec3 a;
    vec3 b;
    vec3 c;

    vec3 c_pipe;

    vec3_normalize normalize(
        .clk_in(clk_100mhz),
        .in(a),
        .out(c)
    );

    always_ff @(posedge clk_100mhz) begin
        a <= {sw, sw, sw, btn[3], sw, sw, sw} & {sw, sw, btn[1], sw, btn[2], sw, sw};
        b <= {sw, sw, sw, btn[3], sw, sw, sw} | {sw, sw, btn[1], sw, btn[2], sw, sw};
        
        c_pipe <= vdot(a, b);
        led <= {c_pipe ^ c_pipe[19:15] + c_pipe[59:40]};

        // c <= fmul(a, b);
    end

    // vec3_testbench vtest(
    //     .clk_in(clk_100mhz),
    //     .a(a),
    //     .b(b),
    //     .norm(v_norm)
    // );
endmodule

`default_nettype wire
`timescale 1ns / 1ps
`default_nettype none
`include "types.sv"

module l3_cache #(
    parameter           LENGTH = 64,
    parameter           WIDTH = 64,
    parameter           HEIGHT = 16
) 
( 
    input wire                          clk_in,
    input wire                          rst_in,

    // input
    input wire  [$clog2(length)-1:0]    xinput,
    input wire  [$clog2(width)-1:0]     yinput,
    input wire  [$clog2(height)-1:0]    zinput,
    input wire  [7:0]                   uart_data_in,
    input wire                          valid_in,
    
    // write and read enable signal input
    input wire                          write_enable,
    input wire                          read_enable,

    // output
    output logic                        valid_out,
    output BlockType                    block_data_out
);
localparam DEPTH = LENGTH*WIDTH*HEIGHT;

parameter BRAM_WIDTH = 5;
parameter BRAM_DEPTH = LENGTH*WIDTH*HEIGHT; // The plan is to store 64 x 64 x 16 blocks
parameter ADDR_WIDTH = $clog2(BRAM_DEPTH);

// only using port a for reads: we only use dout
logic [BRAM_WIDTH-1:0]     douta;
logic [ADDR_WIDTH-1:0]     addra;

// only using port b for writes: we only use din
logic [BRAM_WIDTH-1:0]     dinb;
logic [ADDR_WIDTH-1:0]     addrb;

// convert input coordinates into address
always_comb begin
    if (write_enable && !read_enable) begin
        addrb = xinput*(WIDTH*HEIGHT) + yinput*WIDTH + zinput;
    end else if (!write_enable && read_enable) begin
        addra = xinput*(WIDTH*HEIGHT) + yinput*WIDTH + zinput;
    end
end

xilinx_true_dual_port_read_first_2_clock_ram
     #(.RAM_WIDTH(BRAM_WIDTH),
       .RAM_DEPTH(BRAM_DEPTH)) cache_bram
       (
        // PORT A
        .addra(addra),
        .dina(0), // we only use port A for reads!
        .clka(clk_in),
        .wea(1'b0), // read only
        .ena(1'b1),
        .rsta(sys_rst),
        .regcea(1'b1),
        .douta(douta),
        // PORT B
        .addrb(addrb),
        .dinb(dinb),
        .clkb(clk_in),
        .web(1'b1), // write always
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb() // we only use port B for writes!
        );

    // not sure if port A needs a counter(???)
    evt_counter #(.MAX_COUNT(BRAM_DEPTH)) countA (.clk_in(clk_in),
                                                .rst_in(rst_in),
                                                .evt_in(),
                                                .count_out(addra));

    // a counter for every valid data sample input from UART receiver; for port B
    evt_counter #(.MAX_COUNT(BRAM_DEPTH)) countB (.clk_in(clk_in),
                                                .rst_in(rst_in),
                                                .evt_in(valid_in),
                                                .count_out(addrb));


always_ff @(posedge clk_in) begin
    if (rst_in) begin
        valid_out <= 0;
        block_data_out <= 0;
    end else begin
        if (write_enable) begin
            dinb <= uart_data_in[4:0];
        end else if (read_enable) begin
            block_data_out <= douta;
        end
    end
end

endmodule

`default_nettype wire
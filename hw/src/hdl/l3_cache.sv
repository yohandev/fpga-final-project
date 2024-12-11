`timescale 1ns / 1ps
`default_nettype none
`include "types.sv"

module l3_cache #(
    parameter           LENGTH = 64,
    parameter           WIDTH = 64,
    parameter           HEIGHT = 64
) 
( 
    input wire                          clk_in,
    input wire                          rst_in,

    // input
    input wire  [$clog2(LENGTH)-1:0]    xread,
    input wire  [$clog2(HEIGHT)-1:0]    yread,
    input wire  [$clog2(WIDTH)-1:0]     zread,

    input wire  [$clog2(LENGTH)-1:0]    xwrite,
    input wire  [$clog2(HEIGHT)-1:0]    ywrite,
    input wire  [$clog2(WIDTH)-1:0]     zwrite,

    input wire  [7:0]                   uart_data_in,
    input wire  [3:0]                   control_input,
    input wire                          control_trigger,
    input wire                          valid_in,
    
    // write and read enable signal input
    input wire                          write_enable,
    input wire                          read_enable,

    // output
    output logic                        valid_out,
    output logic [4:0]                  block_data_out
);
    localparam DEPTH = LENGTH*WIDTH*HEIGHT;

    parameter BRAM_WIDTH = 5;
    parameter BRAM_DEPTH = LENGTH*WIDTH*HEIGHT; // The plan is to store 64 x 64 x 16 blocks
    parameter ADDR_WIDTH = $clog2(BRAM_DEPTH);

    // Offsets for cache update behavior along X and Z dimensions
    logic [$clog2(LENGTH)-1:0] x_offset;
    logic [$clog2(WIDTH)-1:0]  z_offset;

    // only using port a for reads: we only use dout
    logic [BRAM_WIDTH-1:0]     douta;
    logic [ADDR_WIDTH-1:0]     addra;

    // only using port b for writes: we only use din
    logic [BRAM_WIDTH-1:0]     dinb;
    logic [ADDR_WIDTH-1:0]     addrb;

    logic [$clog2(LENGTH)-1:0] xpointer;
    logic [$clog2(WIDTH)-1:0]  zpointer;

    // convert input coordinates into address
    always_comb begin
        if (write_enable && !read_enable) begin
            addrb = ((((xpointer + xwrite) % LENGTH) * (WIDTH*HEIGHT)) + (ywrite * WIDTH) + ((zpointer + zwrite) % WIDTH));
        end else if (!write_enable && read_enable) begin
            addra = ((((xpointer + xread) % LENGTH) * (WIDTH*HEIGHT)) + (yread * WIDTH) + ((zpointer + zread) % WIDTH));
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
            .rsta(rst_in),
            .regcea(1'b1),
            .douta(douta),
            // PORT B
            .addrb(addrb),
            .dinb(dinb),
            .clkb(clk_in),
            .web(1'b1), // write always
            .enb(1'b1),
            .rstb(rst_in),
            .regceb(1'b1),
            .doutb() // we only use port B for writes!
            );



    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            valid_out <= 0;
            block_data_out <= 0;
            xpointer <= 0;
            zpointer <= 0;
        end else begin
            if (valid_in && control_trigger) begin
                case (control_input)
                    4'b0001: xpointer <= (xpointer + 1) % LENGTH;                     // forward (+X)
                    4'b0010: xpointer <= (xpointer + LENGTH - 1) % LENGTH;            // backward (-X)
                    4'b0100: zpointer <= (zpointer + 1) % WIDTH;                      // right (+Z)
                    4'b1000: zpointer <= (zpointer + WIDTH - 1) % WIDTH;              // left (-Z)
                    default: ; // no change
                endcase
            end
            if (write_enable) begin
                dinb <= uart_data_in[4:0];
            end else if (read_enable) begin
                block_data_out <= douta;
            end
        end
    end

endmodule

`default_nettype wire
`include "types.sv"
`include "xilinx_single_port_ram_read_first.v"

/// A ROM version of the L3 cache. For now, assume the inputs are held until valid is high
module chunk(
    input wire clk_in,
    input wire rst_in,

    input BlockPos addr,
    input logic read_enable,

    output BlockType out,
    output logic valid
);
    logic [$clog2(CHUNK_WIDTH*CHUNK_WIDTH*CHUNK_WIDTH)-1:0] flat_addr;

    logic oob;
    assign oob = ($signed(addr.x) >= $signed({1'b0, CHUNK_WIDTH})) | ($signed(addr.x) < -$signed({1'b0, CHUNK_WIDTH}))
               | ($signed(addr.y) >= $signed({1'b0, CHUNK_WIDTH})) | ($signed(addr.y) < -$signed({1'b0, CHUNK_WIDTH}))
               | ($signed(addr.z) >= $signed({1'b0, CHUNK_WIDTH})) | ($signed(addr.z) < -$signed({1'b0, CHUNK_WIDTH}));
    
    assign flat_addr = (($signed(addr.z) + 7'sd40) * $signed({1'b0, 13'(CHUNK_WIDTH * CHUNK_WIDTH)}))
                     + (($signed(addr.y) + 7'sd40) * $signed({1'b0, 7'(CHUNK_WIDTH)}))
                     + (($signed(addr.x) + 7'sd40));

    BlockPos [1:0] addr_pipe;
    logic [4:0] rom_out;

    assign out = BlockType'(oob ? BLOCK_AIR : rom_out);
    assign valid = read_enable & (oob | (addr == addr_pipe[1]));

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(5),
        .RAM_DEPTH(CHUNK_WIDTH*CHUNK_WIDTH*CHUNK_WIDTH),
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
        // Don't know how else to get this to work in cocotb...
        .INIT_FILE("/Users/yohan/Documents/MIT/6.2050/final/hw/src/data/chunk.mem")
    ) rom (
        .addra(oob ? 19'b0 : flat_addr),
        .dina(5'b0),
        .clka(clk_in),
        .wea(1'b0),
        .ena(1'b1),
        .rsta(rst_in),
        .regcea(1'b1),
        .douta(rom_out)
    );

    always_ff @(posedge clk_in) if (rst_in) begin
        addr_pipe <= 0;
    end else begin
        addr_pipe[1] <= addr_pipe[0];
        addr_pipe[0] <= addr;
    end

endmodule
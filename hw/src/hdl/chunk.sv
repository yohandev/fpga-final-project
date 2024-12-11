`include "types.sv"

/// A ROM version of the L3 cache
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
    assign oob = $signed(addr.x) >= CHUNK_WIDTH | $signed(addr.x) < -CHUNK_WIDTH
               | $signed(addr.y) >= CHUNK_WIDTH | $signed(addr.y) < -CHUNK_WIDTH
               | $signed(addr.z) >= CHUNK_WIDTH | $signed(addr.z) < -CHUNK_WIDTH;
    
    assign flat_addr = ($signed(addr.z) * 13'(CHUNK_WIDTH * CHUNK_WIDTH))
                     + ($signed(addr.y) * 7'(CHUNK_WIDTH))
                     + ($signed(addr.z));

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(5),
        .RAM_DEPTH(CHUNK_WIDTH*CHUNK_WIDTH*CHUNK_WIDTH),
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
        .INIT_FILE("chunk.mem")
    ) rom (
        .addra(oob ? 0 : flat_addr),
        .dina(0),
        .clka(clk_in),
        .wea(1'b0),
        .ena(1'b1),
        .rsta(rst_in),
        .regcea(1'b1),
        .douta(out)
    );

endmodule
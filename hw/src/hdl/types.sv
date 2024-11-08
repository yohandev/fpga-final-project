`ifndef TYPES_SV
`define TYPES_SV

// At any given time, we store one chunk of width 128³ (-64..=64 in all dimensions)
`define CHUNK_WIDTH 128

// For now we can support up to 32 blocks
typedef enum logic [4:0] {
    BLOCK_AIR       = 'd0,
    BLOCK_GRASS     = 'd1,
    BLOCK_STONE     = 'd2,
    BLOCK_DIRT      = 'd3
} BlockType;

// The position of a block (-64..=64 in all dimensions)
typedef struct packed {
    logic signed [$clog2(`CHUNK_WIDTH)-1:0] x;
    logic signed [$clog2(`CHUNK_WIDTH)-1:0] y;
    logic signed [$clog2(`CHUNK_WIDTH)-1:0] z;
} BlockPos;

`endif
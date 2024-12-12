`ifndef TYPES_SV
`define TYPES_SV

// At any given time, we store one chunk of width 80 (-40..=39 in all dimensions)
parameter CHUNK_WIDTH = 64;

// Framebuffer size, in pixels. MUST be a power of 2!!!
parameter FRAME_WIDTH = 64;
parameter FRAME_HEIGHT = 32;
parameter FRAME_AREA = FRAME_WIDTH * FRAME_HEIGHT;

// For now we can support up to 32 blocks
typedef enum logic [4:0] {
    BLOCK_AIR           = 'd0,
    BLOCK_STONE         = 'd1,
    BLOCK_GRASS         = 'd2,
    BLOCK_DIRT          = 'd3,
    BLOCK_COBBLESTONE   = 'd4,
    BLOCK_OAK_PLANKS    = 'd5,
    BLOCK_SPRUCE_PLANKS = 'd6,
    BLOCK_BIRCH_PLANKS  = 'd7,
    BLOCK_WATER         = 'd8,
    BLOCK_SAND          = 'd9,
    BLOCK_OAK_LOG       = 'd10,
    BLOCK_GRAVEL        = 'd11,
    BLOCK_SPRUCE_LOG    = 'd12,
    BLOCK_BIRC_HLOG     = 'd13,
    BLOCK_OAK_LEAVES    = 'd14,
    BLOCK_SPRUCE_LEAVES = 'd15,
    BLOCK_BIRCH_LEAVES  = 'd16,
    BLOCK_GLASS         = 'd17
} BlockType;

// The position of a block (-64..=64 in all dimensions)
typedef struct packed {
    logic signed [$clog2(CHUNK_WIDTH)-1:0] x;
    logic signed [$clog2(CHUNK_WIDTH)-1:0] y;
    logic signed [$clog2(CHUNK_WIDTH)-1:0] z;
} BlockPos;

`endif
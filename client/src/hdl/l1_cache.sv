`include "types.sv"

// A single-cycle block cache with N ports
//  - Start simple with cyclic replacement, then experiment with LRU policy (might be overkill)
//  - Fully associative cache
//
// consider direct mapped cache? 
module l1_cache #(PORTS=4, CACHE_SIZE=16)(
    input wire clk_in,
    input wire rst_in,

    // N-Ports Interface
    input  BlockPos  [PORTS-1:0] addr,  // Index into the cache
    output BlockType [PORTS-1:0] out,   // Output from the cache
    output logic     [PORTS-1:0] valid  // Is the output a cache hit? That is, does the block returned
                                        // correspond to the position from the last cycle?
);
    // Signed numbers are asymmetric (i.e. -128 to 127, inclusive) so use that to
    // represent an invalid cache entry
    parameter [$clog2(`CHUNK_WIDTH)-1:0] TAG_INVALID = $signed(1 << ($clog2(`CHUNK_WIDTH) - 1));

    BlockPos [CACHE_SIZE-1:0]   tags;
    BlockType [CACHE_SIZE-1:0]  entries;

    /* === LOOKUP === */
    logic       [PORTS-1:0][CACHE_SIZE-1:0] lookup_cmp; // "Cache hit?" for each cache entry for each port
    logic       [PORTS-1:0]                 lookup_hit; // "Cache hit?" for each port

    BlockType   [PORTS-1:0][CACHE_SIZE-1:0] lookup_tmp; // Data of (or 0) for each cache entry for each port
    BlockType   [PORTS-1:0]                 lookup_mux; // Data out for each port

    genvar i, j, k;
    generate
        // Compute every port in parallel...
        for (i = 0; i < PORTS; i++) begin
            // Compare against each entry in parallel...
            for (j = 0; j < CACHE_SIZE; j++) begin
                assign lookup_cmp[i][j] = addr[i] == tags[j];
                assign lookup_tmp[i][j] = lookup_cmp[i][j] ? entries[j] : BlockType'(0);
            end
            // Finally, merge all the lookups:
            always_comb begin
                lookup_hit[i] = |lookup_cmp[i];
                lookup_mux[i] = BlockType'(0);
            end
            for (k = 0; k < CACHE_SIZE; k++) begin
                always_comb begin
                    lookup_mux[i] |= lookup_tmp[i][k];
                end
            end

            always_ff @(posedge clk_in) begin
                valid[i] <= lookup_hit[i];
                out[i] <= lookup_mux[i];
            end
        end
    endgenerate

    /* === RESET === */
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            for (int i = 0; i < CACHE_SIZE; i++) begin
                // Reset cache
                tags[i] <= {TAG_INVALID, TAG_INVALID, TAG_INVALID};
                entries[i] <= BLOCK_AIR;
            end
            for (int i = 0; i < PORTS; i++) begin
                // Reset outputs
                out[i] <= BLOCK_AIR;
                valid[i] <= 0;
            end
        end
    end

endmodule
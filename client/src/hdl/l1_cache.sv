`include "types.sv"

// A single-cycle block cache with N ports
//  - Start simple with cyclic replacement, then experiment with LRU policy (might be overkill)
//  - Fully associative cache
module l1_cache #(N=4)(
    input wire clk_in,
    input wire rst_in,

    output logic [N-1:0] valid  // Is the output a cache hit? That is, does the block returned
                                // correspond to the position from the last cycle?
);
    // Signed numbers are asymmetric (i.e. -128 to 127, inclusive) so use that to
    // represent an invalid cache entry
    parameter [$clog2(`CHUNK_WIDTH):0] TAG_INVALID = $signed(1 << ($clog2(`CHUNK_WIDTH) - 1));

    BlockPos [N-1:0]    tags;
    BlockType [N-1:0]   entries;

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            for (int i = 0; i < N; i++) begin
                // Reset cache
                tags[i] <= {TAG_INVALID, TAG_INVALID, TAG_INVALID};
                entries[i] <= BLOCK_AIR;
                
                // Reset outputs
                valid[i] = 0;
            end
        end
    end

endmodule
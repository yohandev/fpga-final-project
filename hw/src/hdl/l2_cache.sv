`include "types.sv"

module l2_cache #(PORTS=4, CACHE_SIZE=16)(
    input wire clk_in,
    input wire rst_in,

    // N-Ports interface
    input  BlockPos     [PORTS-1:0] addr,           // Index into the cache
    input  logic        [PORTS-1:0] read_enable,    // Is this port actually reading anything?
    output BlockType    [PORTS-1:0] out,            // Output from the cache
    output logic        [PORTS-1:0] valid,          // Is the output a cache hit?

    // L3 interface for cache misses
    output BlockPos     l3_addr,                    // Address of the current cache-miss, indexing into L3 cache
    output logic        l3_read_enable,             // Whether to read L3 or not
    input  BlockType    l3_out,                     // Output of L3 cache, and input into L2 cache
    input  logic        l3_valid                    // Whether output of L3 cache is valid
);
    // Internal state
    BlockPos    [CACHE_SIZE-1:0] tags;
    BlockType   [CACHE_SIZE-1:0] entries;
    logic       [CACHE_SIZE-1:0] occupied;

    logic [$clog2(CACHE_SIZE)-1:0] next_replacement;

    // Combinatorial helpers
    logic [PORTS-1:0][CACHE_SIZE-1:0] lookup;
    logic [PORTS-1:0]                 misses;
    
    for (genvar p = 0; p < PORTS; p++) begin
        for (genvar e = 0; e < CACHE_SIZE; e++) begin
            assign lookup[p][e] = occupied[e] && tags[e] == addr[p];
        end

        assign misses[p] = !(|lookup[p]);
    end

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            // Internal state
            for (int i = 0; i < CACHE_SIZE; i++) begin
                tags[i] <= BlockPos'(0);
                entries[i] <= BlockType'(0);
                occupied[i] <= 0;
            end
            next_replacement <= 0;

            // L3 interface
            l3_addr <= BlockPos'(0);
            l3_read_enable <= 0;

            // Outputs
            for (int i = 0; i < PORTS; i++) begin
                out[i] <= BlockType'(0);
                valid <= 0;
            end
        end else begin
            // For every port...
            for (int p = 0; p < PORTS; p++) begin
                valid[p] <= read_enable[p] && !misses[p];

                if (read_enable[p]) begin
                    // ...look-up every entry
                    for (int e = 0; e < CACHE_SIZE; e++) begin
                        // Cache-hit!
                        if (occupied[e] && tags[e] == addr[p]) begin
                            out[p] <= entries[e];
                        end
                    end

                    // Cache-miss: static priority arbitration, last assigned gets resolved first
                    if (misses[p]) begin
                        l3_addr <= addr[p];
                        l3_read_enable <= 1;
                    end
                end
            end

            // Resolve a cache-miss, if possible
            if (l3_valid && l3_read_enable) begin
                // Note:
                // This implementation wastes one cycle when a cache-miss is resolved, e.g. if there is
                // a pending cache-miss, read_enable will go low for one cycle and then serve that, instead
                // of keeping read_enable high and just changing l3_addr.
                tags[next_replacement] <= l3_addr;
                entries[next_replacement] <= l3_out;
                occupied[next_replacement] <= 1;

                next_replacement <= (next_replacement == CACHE_SIZE-1) ? 0 : (next_replacement + 1);
                l3_read_enable <= 0;
            end
        end
    end

endmodule
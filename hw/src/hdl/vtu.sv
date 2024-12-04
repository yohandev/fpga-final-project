`include "types.sv"

module VoxelTraversalUnit(
    input wire clk_in,
    input wire rst_in,

    // Ray parameters
    

    // L2 interface
    output BlockPos l2_addr,
    output logic    l2_read_enable,
    input BlockType l2_out,
    input logic     l2_valid
);
endmodule
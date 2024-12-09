`include "types.sv"
`include "fixed.sv"
`include "vec3.sv"
`include "vec3i.sv"

module VoxelTraversalUnit(
    input wire clk_in,
    input wire rst_in,

    // Ray parameters (assume these are held, and rst_in is asserted whenever they change)
    input vec3  ray_origin,
    input vec3  ray_direction,

    // Ray hit
    output BlockType    hit,
    output vec3         hit_norm,
    output logic        hit_valid,

    // Memory interface
    output BlockPos ram_addr,
    output logic    ram_read_enable,
    input BlockType ram_out,
    input logic     ram_valid
);
    // This module is implemented as a state machine
    typedef enum bit[1:0] {
        INIT,
        TRAVERSING
    } State;

    // Internal state
    State       state;
    logic [4:0] init_timer; // Time since we're in the INITIALIZING state
    vec3        ray_ori;    // Ray origin
    vec3        ray_dir;    // Normalized ray direction
    vec3i       ray_pos;    // Current ray/block position
    vec3i       ray_step;   // Change in ray/block position
    vec3        ray_d_dt;   // Movement along each axis per unit t
    vec3        ray_dist;   // Movement along each axis per unit t
    vec3        ray_t_max;  // Nearest voxel boundary in units of t

    vec3 ray_direction_normalized;
    vec3_normalize normalize_ray_dir(
        .clk_in(clk_in),
        .in(ray_direction),
        .out(ray_direction_normalized)
    );

    fixed recip_in;
    fixed recip_out;
    fixed_recip_lte1 recip(
        .clk_in(clk_in),
        .in(recip_in),
        .out(recip_out)
    );

    always_ff @(posedge clk_in) if (rst_in) begin
    // Reset:
        hit <= BLOCK_AIR;
        hit_norm <= vec3'(0);
        hit_valid <= 0;

        ram_addr <= BlockPos'(0);
        ram_read_enable <= 0;

        recip_in <= fixed'(0);

        state <= INIT;
        init_timer <= 0;
        ray_ori <= ray_origin;
        ray_pos <= vfloor(ray_origin);
        ray_step.x <= $signed(ray_direction.x) > 0 ? 1 : -1;
        ray_step.y <= $signed(ray_direction.y) > 0 ? 1 : -1;
        ray_step.z <= $signed(ray_direction.z) > 0 ? 1 : -1;
        
        // Everything else is initialized a few cycles later in INIT state...
        ray_dir <= vec3'(0);
        ray_d_dt <= vec3'(0);
        ray_dist <= vec3'(0);
        ray_t_max <= vec3'(0);
    end else unique case (state)
    // State machine:
        INIT: begin
            // Use the timer to synchronize operations that should happen sequentially
            init_timer <= init_timer + 1;

            // Cycles #0-4: Ray direction is being normalized
            // (stall)

            // Cycles #5-7: Start calculating ray_d_dt, one component at a time
            // Cycle #5: Calculate ray_dist all at once
            if (init_timer == 5) begin
                ray_dir <= ray_direction_normalized;
                recip_in <= ray_direction_normalized.x;

                // me when in a illegible verilog competition and your opponent is:
                if (!ray_step.x[B-D-1])
                    ray_dist.x <= fsub(`FIXED_1, fadd(ray_ori.x, fixed'({ray_pos.x, D'(0)})));
                else
                    ray_dist.x <= fsub(ray_ori.x, fixed'({ray_pos.x, D'(0)}));
                if (!ray_step.y[B-D-1])
                    ray_dist.y <= fsub(`FIXED_1, fadd(ray_ori.y, fixed'({ray_pos.y, D'(0)})));
                else
                    ray_dist.y <= fsub(ray_ori.y, fixed'({ray_pos.y, D'(0)}));
                if (!ray_step.z[B-D-1])
                    ray_dist.z <= fsub(`FIXED_1, fadd(ray_ori.z, fixed'({ray_pos.z, D'(0)})));
                else
                    ray_dist.z <= fsub(ray_ori.z, fixed'({ray_pos.z, D'(0)}));
            end
            if (init_timer == 6) begin
                recip_in <= ray_dir.y;
            end
            if (init_timer == 7) begin
                recip_in <= ray_dir.z;
            end

            // Cycle #9-11: Components of ray_d_dt are ready
            if (init_timer == 9) begin
                ray_d_dt.x <= recip_out[B-1] ? (-recip_out) : (recip_out);
            end
            if (init_timer == 10) begin
                ray_d_dt.y <= recip_out[B-1] ? (-recip_out) : (recip_out);
            end
            if (init_timer == 11) begin
                ray_d_dt.z <= recip_out[B-1] ? (-recip_out) : (recip_out);
            end

            // Cycle #12: Calculate ray_t_max and we're done!
            if (init_timer == 12) begin
                if (ray_dir.x != 0)
                    ray_t_max.x <= fmul(ray_d_dt.x, ray_dist.x);
                else
                    ray_t_max.x <= `FIXED_MAX;
                if (ray_dir.y != 0)
                    ray_t_max.y <= fmul(ray_d_dt.y, ray_dist.y);
                else
                    ray_t_max.y <= `FIXED_MAX;
                if (ray_dir.z != 0)
                    ray_t_max.z <= fmul(ray_d_dt.z, ray_dist.z);
                else
                    ray_t_max.z <= `FIXED_MAX;

                // ray_t_max.x <= ray_dir.x != 0 ? fmul(ray_d_dt.x, ray_dist.x) : `FIXED_MAX;
                // ray_t_max.y <= ray_dir.y != 0 ? fmul(ray_d_dt.y, ray_dist.y) : `FIXED_MAX;
                // ray_t_max.z <= ray_dir.z != 0 ? fmul(ray_d_dt.z, ray_dist.z) : `FIXED_MAX;

                state <= TRAVERSING;
            end
        end
        TRAVERSING: begin
            // TODO
        end
    endcase

endmodule
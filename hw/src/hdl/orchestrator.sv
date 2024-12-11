`include "fixed.sv"
`include "vec3.sv"
`include "types.sv"

// Orchestrator renders a single frame right after rst_in has a falling edge. Keep on
// resetting it to render more frames, making sure to throttle according to frame_done
module Orchestrator #(NUM_VTU=1) (
    input wire clk_in,
    input wire rst_in,

    // These inputs are latched and a frame starts rendering when rst_in is asserted
    input vec3 camera_position,             // Camera position
    input vec3 camera_heading,              // Camera heading

    output logic [15:0] sbuf_data,          // Pixel (RGB565) to write to screen buffer 
    output logic [15:0] sbuf_addr,          // Row-major address of pixel to write to screen buffer
    output logic        sbuf_write_enable,  // Whether or not we should write to the screen buffer

    output logic frame_done                 // High for one cycle when the frame is done rendering
);
    // This module is implemented as a state machine
    typedef enum bit[1:0] {
        INIT,
        RENDERING,
        IDLE
    } State;

    // Voxel traversal unit instances
    for (genvar i = 0; i < NUM_VTU; i++) begin:vtu
        // Input/state management
        logic       rst;
        vec3        ray_direction;
       
        // VTU output
        BlockType   hit;
        vec3        hit_norm;
        logic       hit_valid;

        // Memory interface
        BlockPos    ram_addr;
        logic       ram_read_enable;
        BlockType   ram_out;
        logic       ram_valid;

        voxel_traversal_unit vtu(
            .clk_in(clk_in),
            .rst_in(rst_in | rst),
            .ray_origin(camera_pos),
            .ray_direction(ray_direction),
            .hit(hit),
            .hit_norm(hit_norm),
            .hit_valid(hit_valid),
            .ram_addr(ram_addr),
            .ram_read_enable(ram_read_enable),
            .ram_out(ram_out),
            .ram_valid(ram_valid)
        );
        chunk chunk(
            .clk_in(clk_in),
            .rst_in(rst_in),
            .addr(ram_addr),
            .read_enable(ram_read_enable),
            .out(ram_out),
            .valid(ram_valid)
        );
    end

    // Orchestrator state
    State       state;
    logic [5:0] init_timer; // Time since we're in the INIT state
    vec3        camera_pos; // Camera position for this frame
    vec3        w;          // Normalized camera forward vector
    vec3        u;          // Normalized camera up vector
    vec3        v;          // Normalized camera right vector
    vec3        viewport_u; // Vector in world space that span the camera's viewport
    vec3        viewport_v; // Vector in world space that span the camera's viewport
    vec3        pixel_du;   // Change along u axis per pixel
    vec3        pixel_dv;   // Change along v axis per pixel
    vec3        pixel0_loc; // World coordinate of the top-left pixel
    
    logic [$clog2(FRAME_AREA)-1:0]  next_pixel_addr;
    fixed                           next_pixel_x;
    fixed                           next_pixel_y;
    vec3                            pixel_loc;

    // = next_pixel_addr % FRAME_WIDTH
    assign next_pixel_x = fixed'({1'sh0, next_pixel_addr[$clog2(FRAME_WIDTH)-1:0], D'(0)});
    // = next_pixel_addr // FRAME_WIDTH
    assign next_pixel_y = fixed'({1'sh0, next_pixel_addr[$clog2(FRAME_AREA)-1:$clog2(FRAME_WIDTH)], D'(0)});
    assign pixel_loc = vadd(pixel0_loc, vadd(vmul(pixel_du, next_pixel_x), vmul(pixel_dv, next_pixel_y)));

    // A single (pipelined) normalization module is needed; saves on resource usage!
    vec3 normalize_in;
    vec3 normalize_out;
    vec3_normalize normalize(
        .clk_in(clk_in),
        .in(normalize_in),
        .out(normalize_out)
    );

    always_ff @(posedge clk_in) if (rst_in) begin
    // Initialize parameters (prepare for a frame):
        frame_done <= 0;
        sbuf_data <= 0;
        sbuf_addr <= 0;
        sbuf_write_enable <= 0;

        state <= INIT;
        init_timer <= 0;

        camera_pos <= camera_position;
        normalize_in <= camera_heading;
    end else unique case (state)
    // State machine:
        INIT: begin
            // Use the timer to synchronize operations that should happen sequentially
            init_timer <= init_timer + 1;

            // Cycles #0-5: w is being normalized
            // (stall)

            // Cycle #6: w is normalized, start normalizing u
            if (init_timer == 6) begin
                w <= normalize_out;

                // Vec3::UP.cross(w)
                normalize_in.x <= w.z;
                normalize_in.y <= 0;
                normalize_in.z <= -$signed(w.x);
            end

            // Cycles #7-11: u is being normalized
            // (stall)

            // Cycle #12: Latch normalized u
            if (init_timer == 12) begin
                u <= normalize_out;
            end

            // Cycle #13: v = w.cross(u)
            if (init_timer == 13) begin
                v.x <= fsub(fmul(w.y, u.z), fmul(w.z, u.y));
                v.y <= fsub(fmul(w.z, u.x), fmul(w.x, u.z));
                v.z <= fsub(fmul(w.x, u.y), fmul(w.y, u.x));
            end

            // Cycle #14: Calculate viewport UV, pixel delta UV
            if (init_timer == 14) begin
                // These magic values are analogous to fixed'(VIEWPORT_[WIDTH/HEIGHT])
                viewport_u <= vmul(u, 20'sh400);
                viewport_v <= vmul(vneg(v), 20'sh200);

                // Magic numbers are analogous to fixed'(VIEWPORT_[WIDTH/HEIGHT] / FRAME_[WIDTH/HEIGHT])
                pixel_du <= vmul(u, 20'sh4);
                pixel_dv <= vmul(vneg(v), 20'sh4);
            end

            // Cycle #15: Calculate upper left pixel location and we're ready to start
            if (init_timer == 15) begin
                pixel0_loc <= vadd(
                    vsub(vsub(camera_pos, w), vdiv2(vadd(viewport_u, viewport_v))), // Viewport corner
                    vdiv2(vadd(pixel_du, pixel_dv))                                 // Center of pixel
                );

                state <= RENDERING;
            end
        end
        RENDERING: begin
        end
        IDLE: begin
            // Nothing to do
        end
    endcase
endmodule
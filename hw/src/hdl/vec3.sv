`ifndef VEC3_SV
`define VEC3_SV

`include "fixed.sv"
`include "util.sv"

typedef struct packed {
    fixed x;
    fixed y;
    fixed z;
} vec3;

// Vector addition
function automatic vec3 vadd(
    input vec3 a,
    input vec3 b
);
    vadd.x = fadd(a.x, b.x);
    vadd.y = fadd(a.y, b.y);
    vadd.z = fadd(a.z, b.z);
endfunction

// Vector subtraction
function automatic vec3 vsub(
    input vec3 a,
    input vec3 b
);
    vsub.x = fsub(a.x, b.x);
    vsub.y = fsub(a.y, b.y);
    vsub.z = fsub(a.z, b.z);
endfunction

// Vector-scalar multiplication
function automatic vec3 vmul(
    input vec3 v,
    input fixed s
);
    vmul.x = fmul(v.x, s);
    vmul.y = fmul(v.y, s);
    vmul.z = fmul(v.z, s);
endfunction

function automatic fixed vdot(
    input vec3 a,
    input vec3 b
);
    vdot = fadd(fmul(a.x, b.x), fadd(fmul(a.y, b.y), fmul(a.z, b.z)));
endfunction

// Pipelined vector normalize
// Delay = 6 cycles
// Throughput = 1 cycle
module vec3_normalize(
    input wire clk_in,

    input vec3 in,
    output vec3 out
);
    fixed magnitude_inv;
    fixed magnitude_sqr;
    
    fixed_inv_sqrt fixed_inv_sqrt(
        .clk_in(clk_in),
        .in(magnitude_sqr),
        .out(magnitude_inv)
    );

    // Pipe inputs once and use right away, then pipe 4 more times for inv_sqrt's delay
    vec3 in_pipe0;
    vec3 in_pipe4;
    assign in_pipe4 = `pipe(vec3, in_pipe0, 4);

    assign magnitude_sqr = vdot(in_pipe0, in_pipe0);

    always_ff @(posedge clk_in) begin
        // Cycle #1: Pipe inputs
        in_pipe0 <= in;

        // Cycle #2-5: (calculate magnitude)

        // Cycle #6: Scale vector
        out <= vmul(in_pipe4, magnitude_inv);
    end

endmodule

module vec3_testbench(
    input wire clk_in,

    input vec3 a,
    input vec3 b,

    output vec3 add,
    output vec3 sub,
    output vec3 mul,
    output vec3 norm
);
    vec3_normalize normalize(
        .clk_in(clk_in),
        .in(a),
        .out(norm)
    );

    always_ff @(posedge clk_in) begin
        add <= vadd(a, b);
        sub <= vsub(a, b);
        mul <= vmul(a, b.x);
    end
endmodule

`endif
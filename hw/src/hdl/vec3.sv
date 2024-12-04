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

// Pipelined vector normalize
// Delay = 7 cycles
// Throughput = 1 cycle
module vec3_normalize(
    input wire clk_in,

    input vec3 in,
    output vec3 out
);
    // Magnitudes squared
    fixed mx2, my2, mz2, m2;

    // Fixed inverse square root takes 4 cycles + 2 cycle for magnitude squared
    fixed inv_sqrt;
    vec3 in_piped;
    assign in_piped = `pipe(vec3, in, 6);

    fixed_inv_sqrt fixed_inv_sqrt(
        .clk_in(clk_in),
        .in(m2),
        .out(inv_sqrt)
    );

    always_ff @(posedge clk_in) begin
        mx2 <= fmul(in.x, in.x);
        my2 <= fmul(in.y, in.y);
        mz2 <= fmul(in.z, in.z);
        m2 <= fadd(mx2, fadd(my2, mz2));
        out <= vmul(in_piped, inv_sqrt);
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
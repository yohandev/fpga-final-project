`ifndef VEC3I_SV
`define VEC3I_SV

`include "vec3.sv"

typedef struct packed {
    logic signed [B-D-1:0] x;
    logic signed [B-D-1:0] y;
    logic signed [B-D-1:0] z;
} vec3i;

// Vector addition
function automatic vec3i viadd(
    input vec3i a,
    input vec3i b
);
    viadd.x = a.x + b.x;
    viadd.y = a.y + b.y;
    viadd.z = a.z + b.z;
endfunction

// Vector subtraction
function automatic vec3i visub(
    input vec3i a,
    input vec3i b
);
    visub.x = a.x - b.x;
    visub.y = a.y - b.y;
    visub.z = a.z - b.z;
endfunction

// Fixed vec3 -> integer vec3i
function automatic vec3i vfloor(
    input vec3 v
);
    // vfloor.x = v.x[B-D-1:D];
    // vfloor.y = v.y[B-D-1:D];
    // vfloor.z = v.z[B-D-1:D];
    vfloor.x = v.x >>> D;
    vfloor.y = v.y >>> D;
    vfloor.z = v.z >>> D;
endfunction

`endif
`ifndef FIXED_SV
`define FIXED_SV

typedef struct packed {
    logic signed [31:0] inner;
} fixed;

// Number of bits in the decimal portion of fixed numbers
parameter D = 15;

// Fixed point addition
function automatic fixed fadd(input fixed a, input fixed b);
    fadd = fixed'(signed'(a) + signed'(b));
endfunction

// Fixed point subtraction
function automatic fixed fsub(input fixed a, input fixed b);
    fsub = fixed'(signed'(a) - signed'(b));
endfunction

// Fixed point multiplication
function automatic fixed fmul(input fixed a, input fixed b);
    fmul = fixed'(32'((64'(signed'(a)) * 64'(signed'(b))) >>> D));
endfunction

`define FIXED_1 fixed'(32'sh8000)
`define FIXED_1_5 fixed'(32'shC000)

// Pipelined fast inverse square root.
// Delay = 4 cycles
// Throughput = 1 cycle
module fixed_inv_sqrt(
    input wire clk_in,

    input fixed in,
    output fixed out
);
    fixed lut;

    always_comb begin
        // Generated with fixed_inv_sqrt.py [D=15]
        unique casez (in)
            32'sb?01?????????????????????????????: lut = 32'sh93;
            32'sb?001????????????????????????????: lut = 32'shd1;
            32'sb?0001???????????????????????????: lut = 32'sh127;
            32'sb?00001??????????????????????????: lut = 32'sh1a2;
            32'sb?000001?????????????????????????: lut = 32'sh24f;
            32'sb?0000001????????????????????????: lut = 32'sh344;
            32'sb?00000001???????????????????????: lut = 32'sh49e;
            32'sb?000000001??????????????????????: lut = 32'sh688;
            32'sb?0000000001?????????????????????: lut = 32'sh93c;
            32'sb?00000000001????????????????????: lut = 32'shd10;
            32'sb?000000000001???????????????????: lut = 32'sh1279;
            32'sb?0000000000001??????????????????: lut = 32'sh1a20;
            32'sb?00000000000001?????????????????: lut = 32'sh24f3;
            32'sb?000000000000001????????????????: lut = 32'sh3441;
            32'sb?0000000000000001???????????????: lut = 32'sh49e6;
            32'sb?00000000000000001??????????????: lut = 32'sh6882;
            32'sb?000000000000000001?????????????: lut = 32'sh93cd;
            32'sb?0000000000000000001????????????: lut = 32'shd105;
            32'sb?00000000000000000001???????????: lut = 32'sh1279a;
            32'sb?000000000000000000001??????????: lut = 32'sh1a20b;
            32'sb?0000000000000000000001?????????: lut = 32'sh24f34;
            32'sb?00000000000000000000001????????: lut = 32'sh34417;
            32'sb?000000000000000000000001???????: lut = 32'sh49e69;
            32'sb?0000000000000000000000001??????: lut = 32'sh6882f;
            32'sb?00000000000000000000000001?????: lut = 32'sh93cd3;
            32'sb?000000000000000000000000001????: lut = 32'shd105e;
            32'sb?0000000000000000000000000001???: lut = 32'sh1279a7;
            32'sb?00000000000000000000000000001??: lut = 32'sh1a20bd;
            32'sb?000000000000000000000000000001?: lut = 32'sh24f34e;
            32'sb?0000000000000000000000000000001: lut = 32'sh34417a;
            default: lut = 32'sh5a8279;
        endcase
    end

    fixed in_pipe0, in_pipe1;
    fixed iter0, iter0_pipe0, iter0_pipe1;
    fixed iter1, iter1_pipe0, iter1_pipe1;

    assign out = iter1;

    always_ff @(posedge clk_in) begin
        // Look-up table
        iter0 <= lut;
        in_pipe0 <= in;

        // Newton's method, first iteration (first intermediate)
        iter1_pipe0 <= fmul(iter0, iter0);
        iter0_pipe0 <= iter0;
        in_pipe1 <= in_pipe0;

        // Neton's method, first iteration (second intermediate)
        iter0_pipe1 <= iter0_pipe0;
        iter1_pipe1 <= fmul(fixed'(in_pipe1 >> 1), iter1_pipe0);

        // Newton's method, second iteration (done)
        iter1 <= fmul(iter0_pipe1, fsub(`FIXED_1_5, iter1_pipe1));
    end
endmodule

// Pipelined fast reciprocal for numbers <= 1.
// Delay = 3 cycles
// Throughput = 1 cycle
module fixed_recip_lte1(
    input wire clk_in,

    input fixed in,
    output fixed out
);
    fixed lut;
    fixed idx;

    always_comb begin
        idx = in[31] ? (-in) : (in);

        // Generated with fixed_recip.py [D=15]
        unique case (idx[D-1:D-6])
            6'd63: lut = 32'sh8208;
            6'd62: lut = 32'sh8421;
            6'd61: lut = 32'sh864b;
            6'd60: lut = 32'sh8888;
            6'd59: lut = 32'sh8ad8;
            6'd58: lut = 32'sh8d3d;
            6'd57: lut = 32'sh8fb8;
            6'd56: lut = 32'sh9249;
            6'd55: lut = 32'sh94f2;
            6'd54: lut = 32'sh97b4;
            6'd53: lut = 32'sh9a90;
            6'd52: lut = 32'sh9d89;
            6'd51: lut = 32'sha0a0;
            6'd50: lut = 32'sha3d7;
            6'd49: lut = 32'sha72f;
            6'd48: lut = 32'shaaaa;
            6'd47: lut = 32'shae4c;
            6'd46: lut = 32'shb216;
            6'd45: lut = 32'shb60b;
            6'd44: lut = 32'shba2e;
            6'd43: lut = 32'shbe82;
            6'd42: lut = 32'shc30c;
            6'd41: lut = 32'shc7ce;
            6'd40: lut = 32'shcccc;
            6'd39: lut = 32'shd20d;
            6'd38: lut = 32'shd794;
            6'd37: lut = 32'shdd67;
            6'd36: lut = 32'she38e;
            6'd35: lut = 32'shea0e;
            6'd34: lut = 32'shf0f0;
            6'd33: lut = 32'shf83e;
            6'd32: lut = 32'sh10000;
            6'd31: lut = 32'sh10842;
            6'd30: lut = 32'sh11111;
            6'd29: lut = 32'sh11a7b;
            6'd28: lut = 32'sh12492;
            6'd27: lut = 32'sh12f68;
            6'd26: lut = 32'sh13b13;
            6'd25: lut = 32'sh147ae;
            6'd24: lut = 32'sh15555;
            6'd23: lut = 32'sh1642c;
            6'd22: lut = 32'sh1745d;
            6'd21: lut = 32'sh18618;
            6'd20: lut = 32'sh19999;
            6'd19: lut = 32'sh1af28;
            6'd18: lut = 32'sh1c71c;
            6'd17: lut = 32'sh1e1e1;
            6'd16: lut = 32'sh20000;
            6'd15: lut = 32'sh22222;
            6'd14: lut = 32'sh24924;
            6'd13: lut = 32'sh27627;
            6'd12: lut = 32'sh2aaaa;
            6'd11: lut = 32'sh2e8ba;
            6'd10: lut = 32'sh33333;
            6'd9: lut = 32'sh38e38;
            6'd8: lut = 32'sh40000;
            6'd7: lut = 32'sh49249;
            6'd6: lut = 32'sh55555;
            6'd5: lut = 32'sh66666;
            6'd4: lut = 32'sh80000;
            6'd3: lut = 32'shaaaaa;
            6'd2: lut = 32'sh100000;
            6'd1: lut = 32'sh200000;
            default: lut = 32'sh8000;
        endcase
    end

    fixed in_pipe0, in_pipe1;
    fixed iter0, iter0_pipe0;
    fixed iter1, iter1_pipe1;

    assign out = iter1;

    always_ff @(posedge clk_in) begin
        // Look-up table
        iter0 <= in[31] ? (-lut) : (lut);
        in_pipe0 <= in;

        // Newton's method (first intermediate)
        iter1_pipe1 <= fmul(iter0, iter0);
        iter0_pipe0 <= iter0;
        in_pipe1 <= in_pipe0;

        // Newton's method (second intermediate)
        iter1 <= (iter0_pipe0 <<< 1) - fmul(in_pipe1, iter1_pipe1);
    end
endmodule

module fixed_testbench(
    input wire clk_in,

    input fixed a,
    input fixed b,

    output fixed add,
    output fixed sub,
    output fixed mul,
    output fixed expr,
    output fixed inv_sqrt,
    output fixed recip
);
    fixed_inv_sqrt fixed_inv_sqrt(
        .clk_in(clk_in),
        .in(a),
        .out(inv_sqrt)
    );
    fixed_recip_lte1 fixed_recip(
        .clk_in(clk_in),
        .in(a),
        .out(recip)
    );

    always_ff @(posedge clk_in) begin
        add <= fadd(a, b);
        sub <= fsub(a, b);
        mul <= fmul(a, b);
        expr <= fmul(fadd(fmul(a, b), fsub(b, a)), fsub(a, b));
    end
endmodule

`endif
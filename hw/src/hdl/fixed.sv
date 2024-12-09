`ifndef FIXED_SV
`define FIXED_SV

// Number of bits total in fixed numbers
parameter B = 20;
// Number of bits in the decimal portion of fixed numbers
parameter D = 8;

typedef struct packed {
    logic signed [B-1:0] inner;
} fixed;

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
    reg signed [(B*2)-1:0] prod;
    begin
        prod = $signed(a) * $signed(b);
        fmul = prod >>> D;
    end
    // fmul = fixed'(B'(($signed((B*2)'($signed(a))) * $signed((B*2)'($signed(b)))) >>> D));
    // fmul = fixed'(B'((((B*2)'(a)) * ((B*2)'(b))) >>> D));
endfunction

`define FIXED_1 fixed'(20'sh100)
`define FIXED_1_5 fixed'(20'sh180)
`define FIXED_MAX fixed'(20'sh7FFFF)

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
        // Generated with fixed_inv_sqrt.py [D=8]
        unique casez (in_pipe[0])
            20'sb?1??????????????????: lut = 20'sh4;
            20'sb?01?????????????????: lut = 20'sh6;
            20'sb?001????????????????: lut = 20'sh9;
            20'sb?0001???????????????: lut = 20'shd;
            20'sb?00001??????????????: lut = 20'sh12;
            20'sb?000001?????????????: lut = 20'sh1a;
            20'sb?0000001????????????: lut = 20'sh24;
            20'sb?00000001???????????: lut = 20'sh34;
            20'sb?000000001??????????: lut = 20'sh49;
            20'sb?0000000001?????????: lut = 20'sh68;
            20'sb?00000000001????????: lut = 20'sh93;
            20'sb?000000000001???????: lut = 20'shd1;
            20'sb?0000000000001??????: lut = 20'sh127;
            20'sb?00000000000001?????: lut = 20'sh1a2;
            20'sb?000000000000001????: lut = 20'sh24f;
            20'sb?0000000000000001???: lut = 20'sh344;
            20'sb?00000000000000001??: lut = 20'sh49e;
            20'sb?000000000000000001?: lut = 20'sh688;
            20'sb?0000000000000000001: lut = 20'sh93c;
            default: lut = 20'sh1000;
        endcase
    end

    fixed [2:0] in_pipe;
    fixed [1:0] iter0;
    fixed [1:0] iter1;

    assign out = iter1[1];

    always_ff @(posedge clk_in) begin
        // Cycle #1: Pipe input
        in_pipe[0] <= in;

        // Cycle #2: LUT
        in_pipe[1] <= in_pipe[0];
        iter0[0] <= lut;

        // Cycle #3: Newton's method (intermediate)
        iter1[0] <= fmul(fmul(iter0[0], iter0[0]), fixed'(in_pipe[1] >>> 1));
        iter0[1] <= iter0[0];

        // Cycle #4: Newton's method (done)
        iter1[1] <= fmul(iter0[1], fsub(`FIXED_1_5, iter1[0]));
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
    // LUT*2 and LUT*LUT are pre-computed
    fixed lut_dbl;
    fixed lut_sqr;
    fixed idx;
    always_comb begin
        idx = in_pipe[0][B-1] ? (-in_pipe[0]) : (in_pipe[0]);

        // Generated with fixed_recip.py [D=8]
        unique case (idx[D-1:D-6])
            6'd63: begin lut_dbl = 20'sh208; lut_sqr = 20'sh108; end
            6'd62: begin lut_dbl = 20'sh210; lut_sqr = 20'sh110; end
            6'd61: begin lut_dbl = 20'sh219; lut_sqr = 20'sh119; end
            6'd60: begin lut_dbl = 20'sh222; lut_sqr = 20'sh123; end
            6'd59: begin lut_dbl = 20'sh22b; lut_sqr = 20'sh12d; end
            6'd58: begin lut_dbl = 20'sh234; lut_sqr = 20'sh137; end
            6'd57: begin lut_dbl = 20'sh23e; lut_sqr = 20'sh142; end
            6'd56: begin lut_dbl = 20'sh249; lut_sqr = 20'sh14e; end
            6'd55: begin lut_dbl = 20'sh253; lut_sqr = 20'sh15a; end
            6'd54: begin lut_dbl = 20'sh25e; lut_sqr = 20'sh167; end
            6'd53: begin lut_dbl = 20'sh26a; lut_sqr = 20'sh175; end
            6'd52: begin lut_dbl = 20'sh276; lut_sqr = 20'sh183; end
            6'd51: begin lut_dbl = 20'sh282; lut_sqr = 20'sh193; end
            6'd50: begin lut_dbl = 20'sh28f; lut_sqr = 20'sh1a3; end
            6'd49: begin lut_dbl = 20'sh29c; lut_sqr = 20'sh1b4; end
            6'd48: begin lut_dbl = 20'sh2aa; lut_sqr = 20'sh1c7; end
            6'd47: begin lut_dbl = 20'sh2b9; lut_sqr = 20'sh1da; end
            6'd46: begin lut_dbl = 20'sh2c8; lut_sqr = 20'sh1ef; end
            6'd45: begin lut_dbl = 20'sh2d8; lut_sqr = 20'sh205; end
            6'd44: begin lut_dbl = 20'sh2e8; lut_sqr = 20'sh21d; end
            6'd43: begin lut_dbl = 20'sh2fa; lut_sqr = 20'sh237; end
            6'd42: begin lut_dbl = 20'sh30c; lut_sqr = 20'sh252; end
            6'd41: begin lut_dbl = 20'sh31f; lut_sqr = 20'sh26f; end
            6'd40: begin lut_dbl = 20'sh333; lut_sqr = 20'sh28f; end
            6'd39: begin lut_dbl = 20'sh348; lut_sqr = 20'sh2b1; end
            6'd38: begin lut_dbl = 20'sh35e; lut_sqr = 20'sh2d6; end
            6'd37: begin lut_dbl = 20'sh375; lut_sqr = 20'sh2fd; end
            6'd36: begin lut_dbl = 20'sh38e; lut_sqr = 20'sh329; end
            6'd35: begin lut_dbl = 20'sh3a8; lut_sqr = 20'sh357; end
            6'd34: begin lut_dbl = 20'sh3c3; lut_sqr = 20'sh38b; end
            6'd33: begin lut_dbl = 20'sh3e0; lut_sqr = 20'sh3c2; end
            6'd32: begin lut_dbl = 20'sh400; lut_sqr = 20'sh400; end
            6'd31: begin lut_dbl = 20'sh421; lut_sqr = 20'sh443; end
            6'd30: begin lut_dbl = 20'sh444; lut_sqr = 20'sh48d; end
            6'd29: begin lut_dbl = 20'sh469; lut_sqr = 20'sh4de; end
            6'd28: begin lut_dbl = 20'sh492; lut_sqr = 20'sh539; end
            6'd27: begin lut_dbl = 20'sh4bd; lut_sqr = 20'sh59e; end
            6'd26: begin lut_dbl = 20'sh4ec; lut_sqr = 20'sh60f; end
            6'd25: begin lut_dbl = 20'sh51e; lut_sqr = 20'sh68d; end
            6'd24: begin lut_dbl = 20'sh555; lut_sqr = 20'sh71c; end
            6'd23: begin lut_dbl = 20'sh590; lut_sqr = 20'sh7be; end
            6'd22: begin lut_dbl = 20'sh5d1; lut_sqr = 20'sh876; end
            6'd21: begin lut_dbl = 20'sh618; lut_sqr = 20'sh949; end
            6'd20: begin lut_dbl = 20'sh666; lut_sqr = 20'sha3d; end
            6'd19: begin lut_dbl = 20'sh6bc; lut_sqr = 20'shb58; end
            6'd18: begin lut_dbl = 20'sh71c; lut_sqr = 20'shca4; end
            6'd17: begin lut_dbl = 20'sh787; lut_sqr = 20'she2c; end
            6'd16: begin lut_dbl = 20'sh800; lut_sqr = 20'sh1000; end
            6'd15: begin lut_dbl = 20'sh888; lut_sqr = 20'sh1234; end
            6'd14: begin lut_dbl = 20'sh924; lut_sqr = 20'sh14e5; end
            6'd13: begin lut_dbl = 20'sh9d8; lut_sqr = 20'sh183c; end
            6'd12: begin lut_dbl = 20'shaaa; lut_sqr = 20'sh1c71; end
            6'd11: begin lut_dbl = 20'shba2; lut_sqr = 20'sh21d9; end
            6'd10: begin lut_dbl = 20'shccc; lut_sqr = 20'sh28f5; end
            6'd9: begin lut_dbl = 20'she38; lut_sqr = 20'sh3291; end
            6'd8: begin lut_dbl = 20'sh1000; lut_sqr = 20'sh4000; end
            6'd7: begin lut_dbl = 20'sh1249; lut_sqr = 20'sh5397; end
            6'd6: begin lut_dbl = 20'sh1555; lut_sqr = 20'sh71c7; end
            6'd5: begin lut_dbl = 20'sh1999; lut_sqr = 20'sha3d7; end
            6'd4: begin lut_dbl = 20'sh2000; lut_sqr = 20'sh10000; end
            6'd3: begin lut_dbl = 20'sh2aaa; lut_sqr = 20'sh1c71c; end
            6'd2: begin lut_dbl = 20'sh4000; lut_sqr = 20'sh40000; end
            6'd1: begin lut_dbl = 20'sh8000; lut_sqr = 20'sh7FFFF; end
            default: begin lut_dbl = 20'sh100; lut_sqr = 20'sh100; end
        endcase
    end

    fixed [1:0] in_pipe;
    fixed iter0_sqr, iter0_dbl;
    fixed iter1;

    assign out = iter1;

    always_ff @(posedge clk_in) begin
        // Cycle #1: Pipe inputs (trim bits above 1.0 for better routing)
        in_pipe[0] <= in; // fixed'(signed'(in[D:0]));

        // Cycle #2: LUT
        iter0_sqr <= lut_sqr;
        iter0_dbl <= in_pipe[0][B-1] ? (-lut_dbl) : (lut_dbl);
        in_pipe[1] <= in_pipe[0];

        // Cycle #3: Newton's method
        iter1 <= fsub(iter0_dbl, fmul(in_pipe[1], iter0_sqr));
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
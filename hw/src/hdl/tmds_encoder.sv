`timescale 1ns / 1ps
`default_nettype none
 
module tmds_encoder(
    input wire clk_in,
    input wire rst_in,
    input wire [7:0] data_in,       // video data (red, green or blue)
    input wire [1:0] control_in,    // for blue set to {vs,hs}, else will be 0
    input wire ve_in,               // video data enable, to choose between control or video signal
    output logic [9:0] tmds_out
);
    logic [4:0] tally;
    logic [8:0] q_m;
    logic [9:0] q_out;

    assign tmds_out = q_out;
 
    tm_choice mtm(
        .data_in(data_in),
        .qm_out(q_m)
    );

    logic [4:0] n0;
    logic [4:0] n1;

    always_comb begin
        n1 = 0;
        for (int i = 0; i < 8; i++) begin
            n1 += q_m[i];
        end
        n0 = 8 - n1;
    end

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            // Reset
            tally <= 0;
            q_out <= 0;

        end else if (!ve_in) begin
            // Video disabled
            tally <= 0;
            case (control_in)
                2'b00: q_out <= 10'b1101010100;
                2'b01: q_out <= 10'b0010101011;
                2'b10: q_out <= 10'b0101010100;
                2'b11: q_out <= 10'b1010101011;
            endcase

        end else begin
            // Video enabled
            if (tally == 0 || n0 == n1) begin
                q_out[9] <= ~q_m[8];
                q_out[8] <= q_m[8];
                q_out[7:0] <= q_m[8] ? q_m[7:0] : ~q_m[7:0];

                if (q_m[8] == 0) begin
                    tally <= tally + (n0 - n1);
                end else begin
                    tally <= tally + (n1 - n0);
                end
            end else begin
                if ((!tally[4] && n1 > n0) || (tally[4] && n0 > n1)) begin
                    q_out[9] <= 1;
                    q_out[8] <= q_m[8];
                    q_out[7:0] <= ~q_m[7:0];
                    tally <= tally + {3'b0, q_m[8], 1'b0} + (n0 - n1);
                end else begin
                    q_out[9] <= 0;
                    q_out[8] <= q_m[8];
                    q_out[7:0] <= q_m[7:0];
                    tally <= tally - {3'b0, ~q_m[8], 1'b0} + (n1 - n0);
                end
            end
        end
    end
 
endmodule
 
`default_nettype wire
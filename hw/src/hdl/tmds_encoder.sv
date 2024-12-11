`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)
 
module tmds_encoder(
  input wire clk_in,
  input wire rst_in,
  input wire [7:0] data_in,  // video data (red, green or blue)
  input wire [1:0] control_in, //for blue set to {vs,hs}, else will be 0
  input wire ve_in,  // video data enable, to choose between control or video signal
  output logic [9:0] tmds_out
);
 
  logic [8:0] q_m;
  logic [9:0] q_out;
  logic [4:0] tally;
  logic [3:0] n0;
  logic [3:0] n1;
  logic tm_bit;
  logic tm_bit_rev;

 
  tm_choice mtm(
    .data_in(data_in),
    .qm_out(q_m));

  
  always_comb begin
    n0 = !q_m[0] + !q_m[1] + !q_m[2] + !q_m[3] + !q_m[4] + !q_m[5] + !q_m[6] + !q_m[7];
    n1 = q_m[0] + q_m[1] + q_m[2] + q_m[3] + q_m[4] + q_m[5] + q_m[6] + q_m[7];
    tm_bit = q_m[8];
    tm_bit_rev = ~tm_bit;
  end

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
        tally <= 0;
        tmds_out <= 0;
    end else begin
        if (!ve_in) begin
            tally <= 0;
            case (control_in)
                2'b00: tmds_out <= 10'b1101010100;
                2'b01: tmds_out <= 10'b0010101011;
                2'b10: tmds_out <= 10'b0101010100;
                2'b11: tmds_out <= 10'b1010101011; 
                default: tmds_out <= 10'b1101010100;
            endcase
        end else begin
            if ((tally == 0) || (n0 == n1)) begin
                if (q_m[8]) begin
                    tmds_out <= {tm_bit_rev, tm_bit, q_m[7:0]};
                    tally <= tally + n1 - n0;
                end else begin
                    tmds_out <= {tm_bit_rev, tm_bit, ~q_m[7:0]};
                    tally <= tally + n0 - n1;
                end
            end else begin
                if ((!tally[4] && (n1 > n0)) || (tally[4] && (n0 > n1))) begin
                    tmds_out <= {1'b1, tm_bit, ~q_m[7:0]};
                    tally <= tally + 2*tm_bit + (n0 - n1);
                end else begin
                    tmds_out <= {1'b0, tm_bit, q_m[7:0]};
                    tally <= tally - 2*(tm_bit_rev) + (n1 - n0);
                end
            end
        end
    end
  end
 
endmodule
 
`default_nettype wire
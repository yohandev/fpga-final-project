
module tm_choice (
  input wire [7:0] data_in,
  output logic [8:0] qm_out
  );



  //your code here, friend
  logic [7:0] in;
  logic [7:0] option1;
  logic [7:0] option1_trans;
  logic [7:0] option2;
  logic [7:0] option2_trans;


  always_comb begin
    in = data_in;
    option1[0] = in[0];
    option2[0] = in[0];
    option1_trans = 0;
    option2_trans = 0;
    for (integer i = 1; i < 8; i = i + 1) begin
      option1[i] = in[i] ^ option1[i-1];
      if (option1[i] != option1[i-1]) begin
        option1_trans = option1_trans + 1;
      end
      option2[i] = ~(in[i] ^ option2[i-1]);
      if (option2[i] != option2[i-1]) begin
        option2_trans = option2_trans + 1;
      end
    end
    if (option1_trans < option2_trans) begin
      qm_out = {1'b1, option1};
    end else begin
      qm_out = {1'b0, option2};
    end
  end



endmodule //end tm_choice

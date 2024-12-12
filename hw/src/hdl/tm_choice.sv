module tm_choice(
    input wire [7:0] data_in,
    output logic [8:0] qm_out
);
    logic [3:0] bsum;
    logic lsb;
    logic opt; // option 1 => 1 ; option 2 => 0

    always_comb begin
        bsum = 0;
        for (int i = 0; i < 8; i++) begin
            bsum += data_in[i];
        end

        lsb = data_in[0];
        opt = !(bsum > 4 || (bsum == 4 && !lsb));

        qm_out[0] = lsb;
        qm_out[8] = opt;

        if (opt) begin
            // Option 1
            for (int i = 1; i < 8; i++) begin
                qm_out[i] = data_in[i] ^ qm_out[i - 1];
            end
        end else begin
            // Option 2
            for (int i = 1; i < 8; i++) begin
                qm_out[i] = !(data_in[i] ^ qm_out[i - 1]);
            end
        end
    end

endmodule
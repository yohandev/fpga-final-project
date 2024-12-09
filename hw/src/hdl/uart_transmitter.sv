`timescale 1ns / 1ps
`default_nettype none

module uart_transmit 
  #(
    parameter INPUT_CLOCK_FREQ = 100_000_000,
    parameter BAUD_RATE = 460800
    )
   (
    input wire 	     clk_in,
    input wire 	     rst_in,
    input wire [7:0] data_byte_in,
    input wire 	     trigger_in,
    output logic     busy_out,
    output logic     tx_wire_out
    );
   
   localparam BAUD_BIT_PERIOD  = INPUT_CLOCK_FREQ/BAUD_RATE;
   logic [$clog2(BAUD_BIT_PERIOD):0] clock_cycle_count;         // tally the number of clock cycle that has passed
   logic [7:0] bit_count;                                       // keeps track the the index of the byte
   logic [7:0] data_in_buffer;

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            busy_out <= 0;
            tx_wire_out <= 1;
            clock_cycle_count <= 0;
            bit_count <= 0;
            data_in_buffer <= 0;
        end else begin
            if (busy_out) begin                                 // only run when busy_out has been initiated by trigger_in
               clock_cycle_count <= clock_cycle_count + 1;      // 
               if (clock_cycle_count == BAUD_BIT_PERIOD - 1) begin  // 1 baud has been reached when the clock = to the number of clock cycle per baud
                    if (bit_count == 9) begin                   // when the index = 8, the message is complete, and the sequence should wrap up
                        busy_out <= 0;                          // transmission is done, so busy_out is reset
                        bit_count <= 0;
                        tx_wire_out <= 1;
                        data_in_buffer <= 0;
                    end else if (bit_count == 8) begin
                        tx_wire_out <= 1;
                        bit_count <= bit_count + 1;
                    end else begin
                        tx_wire_out <= data_in_buffer[bit_count]; // load in current index (lsb to msb) to transmit
                        bit_count <= bit_count + 1;             // increment index
                    end
                    clock_cycle_count <= 0;                     // reset clock cycle count
               end
            end else begin
                if (trigger_in) begin                           // if busy_out is low and trigger_in is high, signify the start of a transmission
                    busy_out <= 1;                          // busy_out set to high to indicated ongoing transmission
                    tx_wire_out <= 0;                       // transmit the START bit   
                    clock_cycle_count <= 0;                 // first increment of the clock cycle count towards the next baud
                    data_in_buffer <= data_byte_in;
                end 
            end
        end
    end

endmodule // uart_transmit

`default_nettype wire

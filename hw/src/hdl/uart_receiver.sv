`default_nettype none

module uart_receiver
  #(
    parameter INPUT_CLOCK_FREQ = 100_000_000,
    parameter BAUD_RATE = 460800
    )
   (
    input wire 	       clk_in,
    input wire 	       rst_in,
    input wire 	       rx_wire_in,
    output logic       new_data_out,
    output logic [7:0] data_byte_out
    );

   localparam UART_BIT_PERIOD  = INPUT_CLOCK_FREQ/BAUD_RATE;
   logic busy_in;                                                 // signal for DATA state
   logic idle;                                                    // signal for IDLE state
   logic [$clog2(UART_BIT_PERIOD):0] clock_cycle_count;           // keeps track the clock cycle
   logic [3:0] bit_index;                                         // index for where to place rx_wire_in into data_byte_out
   logic check_start_bit;
   logic [7:0] data_out_buffer;                                   // a buffer to store received message before dropping it to output
   

   always_ff @(posedge clk_in)begin
      if (rst_in) begin                                             // reset condition
        new_data_out <= 0;
        data_byte_out <= 0;
        busy_in <= 0;
        idle <= 1;                                                  // default to idle state when reset
        bit_index <= 0;
        clock_cycle_count <= 0;
        check_start_bit <= 0;
        data_out_buffer <= 0;
      end else begin
        if (idle) begin                                             // idle state
          if (!rx_wire_in) begin                                    // if there is a falling edge in rx_wire_in, move out from IDLE state
            idle <= 0;
          end
          new_data_out <= 0;
        end else begin
          clock_cycle_count <= clock_cycle_count + 1;
          if (!check_start_bit) begin                               // check if the start bit has been retrieved; if so, program can check every baud rate instead of baud/2
            if (clock_cycle_count == UART_BIT_PERIOD/2 - 1) begin   // check the start bit in mid-baud rate; also, add 1/2 phase shift to baud
              if (!rx_wire_in) begin                                // START state; if rx_wire_in == 0, a valid start signal, move to DATA state
                  busy_in <= 1;                                     // if wire reads 0 for START, which is valid bit, move to out of START and go to data
                  check_start_bit <= 1;                             // a signal to have program check wire every 1 baud after the initial 1/2 baud check
                end else begin                                      // otherwise, move back to IDLE state
                  idle <= 1;
                end
                clock_cycle_count <= 0;                             // reset clock cycle count
            end
          end else begin
            if (clock_cycle_count == UART_BIT_PERIOD - 1) begin     // after the start bit has been checked, program should check every 1 baud
              if (busy_in) begin                                    
                if (bit_index == 8) begin                           // STOP state when a byte has been collected
                  if (rx_wire_in) begin                             // if the STOP bit is valid, without waiting for it to fully process, send signal
                    data_byte_out <= data_out_buffer;               // load buffer into output
                    new_data_out <= 1;
                  end
                  data_out_buffer <= 0;
                  bit_index <= 0;                                   // reset index
                  busy_in <= 0;                                     // hop out of DATA state
                  idle <= 1;                                        // signify back to IDLE state
                  check_start_bit <= 0;
                end else begin                                      // DATA state
                  data_out_buffer[bit_index] <= rx_wire_in;         // rx signal is being transmitted lsb, so signal should be stored into buffer
                  bit_index <= bit_index + 1;                       // increment index
                end
              end
              clock_cycle_count <= 0;
            end
          end
        end
      end
   end

endmodule // uart_receive

`default_nettype wire

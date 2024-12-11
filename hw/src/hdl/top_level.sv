`default_nettype none

`include "types.sv"
`include "fixed.sv"
`include "vec3.sv"

module top_level(
    input wire clk_100mhz,
    
    input wire [15:0] sw,
    input wire [3:0] btn,

    output logic [15:0] led,
    output logic [2:0]  rgb0,
    output logic [2:0]  rgb1

    // output logic [2:0]  hdmi_tx_p,  // HDMI output signals (positives) (blue, green, red)
    // output logic [2:0]  hdmi_tx_n,  // HDMI output signals (negatives) (blue, green, red)
    // output logic        hdmi_clk_p, // Differential HDMI clock
    // output logic        hdmi_clk_n,

    // input wire 	        uart_rxd,   // UART computer-FPGA
    // output logic        uart_txd    // UART FPGA-computer
);
    // Shut up those rgb LEDs for now (active high)
    assign rgb1 = 0;
    assign rgb0 = 0;

    logic sys_rst = btn[0];

    // player's input command from joystick
    logic [3:0] input_command;
    // if one of the joystick's button is pushed, signifies a trigger for transmission
    logic button_trigger = input_command[0] || input_command[1] || input_command[2] || input_command[3];

    // Player input
    logic [7:0] uart_data_in;
    logic       uart_data_valid;
    logic       uart_busy;
    logic       uart_data_out;
    logic       player_input_ready; // TODO(winwin): ???
    logic       player_input_busy;

    // UART Transmitter
    always_ff @(posedge clk_100mhz) begin
        if (sys_rst) begin
            uart_data_in <= 0;
        end else begin
            if (player_input_ready) begin
                player_input_busy <= 1;
                uart_data_valid <= 0;
            end else begin
                if (player_input_busy & sw[0] & !uart_busy) begin
                    uart_data_in <= input_command;
                    uart_data_valid <= 1;
                    player_input_busy <= 0;
                end
            end
        end
    end

    // uart_transmit #(
    //     .INPUT_CLOCK_FREQ(100_000_000),
    //     .BAUD_RATE(9646080000)
    // ) transmitter (
    //     .clk_in(clk_100mhz),
    //     .rst_in(sys_rst),
    //     .data_byte_in(uart_data_in),
    //     .trigger_in(button_trigger),
    //     .busy_out(uart_busy),
    //     .tx_wire_out(uart_txd)
    // );

    // UART Receiver
    logic uart_rx_buf0, uart_rx_buf1;
    logic uart_receive_data_valid;

    // always_ff @(posedge clk_100mhz) begin
    //     if (sys_rst) begin
    //         uart_rx_buf0 <= 0;
    //         uart_rx_buf1 <= 0;
    //     end else begin
    //         uart_rx_buf0 <= uart_rxd;
    //         uart_rx_buf1 <= uart_rx_buf0;
    //     end
    // end

    // uart_receive #(
    //     .INPUT_CLOCK_FREQ(100_000_000),
    //     .BAUD_RATE(460800)
    // ) receiver (
    //     .clk_in(clk_100mhz),
    //     .rst_in(sys_rst),
    //     .rx_wire_in(uart_rx_buf1),
    //     .new_data_out(uart_receive_data_valid),
    //     .data_byte_out(uart_data_out)
    // );

    logic               cache_stored_valid;
    BlockType           block_sample_data;
    logic               initialized;
    logic [$clog2(65536)-1:0] stored_counter;

    // evt_counter #(.MAX_COUNT(BRAM_DEPTH)) storing (
    //     .clk_in(clk_in),
    //     .rst_in(rst_in),
    //     .evt_in(valid_in),
    //     .count_out(stored_counter)
    // );

    // Upon initiating, block data should be stored first
    always_ff @(posedge clk_100mhz) begin
        if (sys_rst) begin
            initialized <= 0;
        end else begin
            if (!initialized) begin
                if (stored_counter == 65535) begin
                    initialized <= 1;
                end
            end
        end
    end    

    // Take the data received from UART transmission with the server plugin and store it into the L3 cache
    // l3_cache #(
    //     .LENGTH(64),
    //     .WIDTH(64),
    //     .HEIGHT(16)
    // ) l3_cache (
    //     .clk_in(clk_100mhz),
    //     .rst_in(sys_rst),
    //     .xinput(xcoord),
    //     .yinput(ycoord),
    //     .zinput(zcoord),
    //     .uart_data_in(uart_data_out),
    //     .valid_in(uart_receive_data_valid),
    //     .write_enable(1'b1),
    //     .read_enable(1'b0),
    //     .valid_out(cache_stored_valid),
    //     .block_data_out(block_sample_data)
    // );


    vec3        ray_origin;
    vec3        ray_direction;
    BlockType   hit;
    vec3        hit_norm;
    logic       hit_valid;
    BlockPos    ram_addr;
    logic       ram_read_enable;
    BlockType   ram_out;
    logic       ram_valid;

    voxel_traversal_unit vtu(
        .clk_in(clk_100mhz),
        .rst_in(sys_rst),
        .ray_origin(ray_origin),
        .ray_direction(ray_direction),
        .hit(hit),
        .hit_norm(hit_norm),
        .hit_valid(hit_valid),
        .ram_addr(ram_addr),
        .ram_read_enable(ram_read_enable),
        .ram_out(ram_out),
        .ram_valid(ram_valid)
    );

    always_ff @(posedge clk_100mhz) begin
        // Testing fixed's synthesis with BS input/outputs so it doesn't get optimized out
        ray_origin <= {sw, sw, sw, sw};
        ray_direction <= {sw, sw, sw, sw};
        ram_out <= BlockType'(sw);
        ram_valid <= btn[0];

        led <= hit ^ hit_norm & hit_valid | ram_addr;
    end
endmodule

`default_nettype wire
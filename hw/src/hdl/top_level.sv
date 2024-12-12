`include "types.sv"
`include "fixed.sv"
`include "vec3.sv"

module top_level(
    input wire clk_100mhz,
    
    input wire [15:0] sw,
    input wire [3:0] btn,

    output logic [15:0] led,
    output logic [2:0]  rgb0,
    output logic [2:0]  rgb1,

    output logic [2:0]  hdmi_tx_p,  // HDMI output signals (positives) (blue, green, red)
    output logic [2:0]  hdmi_tx_n,  // HDMI output signals (negatives) (blue, green, red)
    output logic        hdmi_clk_p, // Differential HDMI clock
    output logic        hdmi_clk_n,

    input wire 	        uart_rxd,   // UART computer-FPGA
    output logic        uart_txd,    // UART FPGA-computer

    input wire [3:0]   pmoda
);
    // Shut up those rgb LEDs for now (active high)
    assign rgb1 = 0;
    assign rgb0 = 0;


    logic sys_rst = btn[0];

    logic          clk_camera;
    logic          clk_pixel;
    logic          clk_5x;
    logic          clk_xc;

    logic          clk_100_passthrough;

    cw_hdmi_clk_wiz wizard_hdmi
    (.sysclk(clk_100_passthrough),
     .clk_pixel(clk_pixel),
     .clk_tmds(clk_5x),
     .reset(0));

    cw_fast_clk_wiz wizard_migcam
        (.clk_in1(clk_100mhz),
        .clk_camera(clk_camera),
        .clk_xc(clk_xc),
        .clk_100(clk_100_passthrough),
        .reset(0));

    // Dimensional parameter
    parameter LENGTH = 64;
    parameter WIDTH = 64;
    parameter HEIGHT = 16;

    // BRAM parameter
    parameter BRAM_WIDTH = 5;
    parameter BRAM_DEPTH = LENGTH*WIDTH*HEIGHT; 

    // button controls
    
    logic up, down, right, left;

    debouncer #(.CLK_PERIOD_NS(10),
                .DEBOUNCE_TIME_MS(5)
                ) move_up (
                .clk_in(clk_100_passthrough),
                .rst_in(sys_rst),
                .dirty_in(!pmoda[0]),
                .clean_out(up)    
                );

    debouncer #(.CLK_PERIOD_NS(10),
                .DEBOUNCE_TIME_MS(5)
                ) move_down (
                .clk_in(clk_100_passthrough),
                .rst_in(sys_rst),
                .dirty_in(!pmoda[1]),
                .clean_out(down)    
                );

    debouncer #(.CLK_PERIOD_NS(10),
                .DEBOUNCE_TIME_MS(5)
                ) move_right (
                .clk_in(clk_100_passthrough),
                .rst_in(sys_rst),
                .dirty_in(!pmoda[2]),
                .clean_out(right)    
                );

    debouncer #(.CLK_PERIOD_NS(10),
                .DEBOUNCE_TIME_MS(5)
                ) move_left (
                .clk_in(clk_100_passthrough),
                .rst_in(sys_rst),
                .dirty_in(!pmoda[3]),
                .clean_out(left)    
                );

    // if one of the joystick's button is pushed, signifies a trigger for transmission
    logic button_trigger = up || down || right || left;
    logic [3:0] ctrl_input = {left, right, down, up};

    // Player input
    logic [7:0] uart_data_in;
    logic       uart_data_valid;
    logic       uart_busy;
    logic       uart_data_out;

    // UART Transmitter
    always_comb begin
        if (button_trigger && !uart_busy) begin
            uart_data_in[3:0] = ctrl_input;
        end
    end

    uart_transmit #(
        .INPUT_CLOCK_FREQ(100_000_000),
        .BAUD_RATE(460800)
    ) transmitter (
        .clk_in(clk_100_passthrough),
        .rst_in(sys_rst),
        .data_byte_in(uart_data_in),
        .trigger_in(button_trigger),
        .busy_out(uart_busy),
        .tx_wire_out(uart_txd)
    );

    // UART Receiver
    logic uart_rx_buf0, uart_rx_buf1;
    logic uart_receive_data_valid;

    always_ff @(posedge clk_100_passthrough) begin
        if (sys_rst) begin
            uart_rx_buf0 <= 0;
            uart_rx_buf1 <= 0;
        end else begin
            uart_rx_buf0 <= uart_rxd;
            uart_rx_buf1 <= uart_rx_buf0;
        end
    end

    uart_receiver #(
        .INPUT_CLOCK_FREQ(100_000_000),
        .BAUD_RATE(460800)
    ) receiver (
        .clk_in(clk_100_passthrough),
        .rst_in(sys_rst),
        .rx_wire_in(uart_rx_buf1),
        .new_data_out(uart_receive_data_valid),
        .data_byte_out(uart_data_out)
    );

    logic               cache_stored_valid;
    BlockType           block_sample_data;
    logic               initialized;
    logic [$clog2(BRAM_DEPTH)-1:0] init_counter;
    logic [$clog2(LENGTH)-1:0] x_write_pos;
    logic [$clog2(WIDTH)-1:0] y_write_pos;
    logic [$clog2(HEIGHT)-1:0] z_write_pos;

    // Upon initiating, block data should be stored first
    always_ff @(posedge clk_100_passthrough) begin
        if (sys_rst) begin
            initialized <= 0;
            x_write_pos <= 0;
            y_write_pos <= 0;
            z_write_pos <= 0;
        end else begin
            if (!initialized) begin
                if (y_write_pos == LENGTH-1) begin
                    y_write_pos <= 0;
                    if (z_write_pos == WIDTH-1) begin
                        z_write_pos <= 0;
                        if (x_write_pos == HEIGHT-1) begin
                            x_write_pos <= 0;
                            initialized <= 1;
                        end else begin
                            x_write_pos <= x_write_pos + 1;
                        end
                    end else begin
                        z_write_pos <= z_write_pos + 1;
                    end
                end else begin
                    y_write_pos <= y_write_pos + 1;
                end
            end
        end
    end


    logic write_enable;
    logic read_enable;

    // Take the data received from UART transmission with the server plugin and store it into the L3 cache
    l3_cache #(
        .LENGTH(64),
        .WIDTH(64),
        .HEIGHT(16)
    ) l3_cache (
        .clk_in(clk_100_passthrough),
        .rst_in(sys_rst),
        .xread(x_read_coord),                   // coordinates for read
        .yread(y_read_coord),
        .zread(z_read_coord),
        .xwrite(x_write_pos),                 // coordinates for write
        .ywrite(y_write_pos),
        .zwrite(z_write_pos),
        .uart_data_in(uart_data_out),
        .control_input(ctrl_input),
        .control_trigger(button_trigger),
        .valid_in(uart_receive_data_valid),
        .write_enable(write_enable),
        .read_enable(read_enable && initialized),       // the cache will not read until it has fully initialized the cache
        .valid_out(cache_stored_valid),
        .block_data_out(block_sample_data)
    );

    logic [15:0] sbuf_data;
    logic [15:0] sbuf_addr;
    logic        sbuf_write_enable;
    logic        frame_done;

    orchestrator #(.NUM_VTU(1)) orchestrator(
        .clk_in(clk_100_passthrough),
        .rst_in(sys_rst),
        // TODO: these, but not hard coded
        .camera_position('h30000000),
        .camera_heading('h100),
        .sbuf_data(sbuf_data),
        .sbuf_addr(sbuf_addr),
        .sbuf_write_enable(sbuf_write_enable),
        .frame_done(frame_done)
    );
    
    logic [15:0] frame_buff_raw;
    localparam FB_DEPTH = FRAME_WIDTH*FRAME_HEIGHT;
    localparam FB_SIZE = $clog2(FB_DEPTH);
    logic [FB_SIZE-1:0] addrb;
    logic good_addrb;

    always_ff @(posedge clk_pixel)begin
        addrb <= (hcount_hdmi>>2) + FRAME_WIDTH*(vcount_hdmi>>2);
        good_addrb <= ((hcount_hdmi>>2) < FRAME_WIDTH) && ((vcount_hdmi>>2) < FRAME_HEIGHT);
    end

    blk_mem_gen_0 frame_buffer(
        .addra(sbuf_addr), //pixels are stored using this math
        .clka(clk_camera),
        .wea(sbuf_write_enable),
        .dina(sbuf_data),
        .ena(1'b1),
        .douta(), //never read from this side
        .addrb(addrb),//transformed lookup pixel
        .dinb(16'b0),
        .clkb(clk_pixel),
        .web(1'b0),
        .enb(1'b1),
        .doutb(frame_buff_raw)
    );

    logic [7:0] red, green, blue;
    logic [7:0] red_pipe [2:0];
    logic [7:0] green_pipe [2:0];
    logic [7:0] blue_pipe [2:0];
  
    always_ff @(posedge clk_pixel)begin
        red <= {frame_buff_raw[15:11],3'b0};
        green <= {frame_buff_raw[10:5], 2'b0};
        blue <= {frame_buff_raw[4:0],3'b0};
    end

    // hdmi
    logic          hsync_hdmi;
    logic          vsync_hdmi;
    logic [10:0]   hcount_hdmi;
    logic [9:0]    vcount_hdmi;
    logic          active_draw_hdmi;
    logic          new_frame_hdmi;
    logic [5:0]    frame_count_hdmi;
    logic          nf_hdmi;
    logic [9:0]    tmds_10b [0:2]; //output of each TMDS encoder!
    logic          tmds_signal [2:0]; //output of each TMDS serializer!

    // logic [10:0] hcount_pipe [7:0];
    // logic [9:0] vcount_pipe [7:0];
    // logic nf_pipe [7:0];
    // logic hsync_pipe [7:0];
    // logic vsync_pipe [7:0];
    // logic active_draw_pipe [7:0];

    // always_ff @(posedge clk_pixel) begin
    //     hcount_pipe[0] <= hcount_hdmi;
    //     vcount_pipe[0] <= vcount_hdmi;
    //     nf_pipe[0] <= nf_hdmi;
    //     hsync_pipe[0] <= hsync_hdmi;
    //     vsync_pipe[0] <= vsync_hdmi;
    //     active_draw_pipe[0] <= active_draw_hdmi;
    //     for (int i = 1; i < PS3; i = i + 1) begin
    //         hcount_pipe[i] <= hcount_pipe[i-1];
    //         vcount_pipe[i] <= vcount_pipe[i-1];
    //         nf_pipe[i] <= nf_pipe[i-1];
    //         hsync_pipe[i] <= hsync_pipe[i-1];
    //         vsync_pipe[i] <= vsync_pipe[i-1];
    //         active_draw_pipe[i] <= active_draw_pipe[i-1];
    //     end
    // end

    video_sig_gen vsg(
        .pixel_clk_in(clk_pixel),
        .rst_in(sys_rst_pixel),
        .hcount_out(hcount_hdmi),
        .vcount_out(vcount_hdmi),
        .vs_out(vsync_hdmi),
        .hs_out(hsync_hdmi),
        .nf_out(nf_hdmi),
        .ad_out(active_draw_hdmi),
        .fc_out(frame_count_hdmi)
    );

    // Three tmds_encoders (blue, green, red)
    tmds_encoder tmds_red(
        .clk_in(clk_pixel),
        .rst_in(sys_rst_pixel),
        .data_in(red),
        .control_in(2'b0),
        .ve_in(active_draw),
        .tmds_out(tmds_10b[2])
    );
    tmds_encoder tmds_green(
        .clk_in(clk_pixel),
        .rst_in(sys_rst_pixel),
        .data_in(green),
        .control_in(2'b0),
        .ve_in(active_draw),
        .tmds_out(tmds_10b[1])
    );
    tmds_encoder tmds_blue(
        .clk_in(clk_pixel),
        .rst_in(sys_rst_pixel),
        .data_in(blue),
        .control_in({vsync,hsync}),
        .ve_in(active_draw),
        .tmds_out(tmds_10b[0])
    );

    // Three tmds_serializers (blue, green, red):
    tmds_serializer red_ser(
        .clk_pixel_in(clk_pixel),
        .clk_5x_in(clk_5x),
        .rst_in(sys_rst_pixel),
        .tmds_in(tmds_10b[2]),
        .tmds_out(tmds_signal[2])
    );
    tmds_serializer green_ser(
        .clk_pixel_in(clk_pixel),
        .clk_5x_in(clk_5x),
        .rst_in(sys_rst_pixel),
        .tmds_in(tmds_10b[1]),
        .tmds_out(tmds_signal[1])
    );
    tmds_serializer blue_ser(
        .clk_pixel_in(clk_pixel),
        .clk_5x_in(clk_5x),
        .rst_in(sys_rst_pixel),
        .tmds_in(tmds_10b[0]),
        .tmds_out(tmds_signal[0])
    );

    OBUFDS OBUFDS_blue (.I(tmds_signal[0]), .O(hdmi_tx_p[0]), .OB(hdmi_tx_n[0]));
    OBUFDS OBUFDS_green(.I(tmds_signal[1]), .O(hdmi_tx_p[1]), .OB(hdmi_tx_n[1]));
    OBUFDS OBUFDS_red  (.I(tmds_signal[2]), .O(hdmi_tx_p[2]), .OB(hdmi_tx_n[2]));
    OBUFDS OBUFDS_clock(.I(clk_pixel), .O(hdmi_clk_p), .OB(hdmi_clk_n));
endmodule

`default_nettype wire
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
    output logic [2:0]  rgb1,

    output logic [2:0]  hdmi_tx_p,
    output logic [2:0]  hdmi_tx_n,
    output logic        hdmi_clk_p,
    output logic        hdmi_clk_n,

    input wire 	        uart_rxd,
    output logic        uart_txd,

    input wire [3:0]   pmoda
);
    // Shut up those rgb LEDs for now (active high)
    assign rgb1 = 0;
    assign rgb0 = 0;

    logic sys_rst;
    assign sys_rst = btn[0];

    logic clk_pixel, clk_5x;
    logic locked;               // Locked signal (we'll leave unused but still hook it up)

    hdmi_clk_wiz_720p mhdmicw(
        .reset(0),
        .locked(locked),
        .clk_ref(clk_100mhz),
        .clk_pixel(clk_pixel),
        .clk_tmds(clk_5x)
    );

    logic [10:0] hcount;        // hcount of system!
    logic [9:0] vcount;         // vcount of system!
    logic hor_sync;             // horizontal sync signal
    logic vert_sync;            // vertical sync signal
    logic active_draw;          // ative draw! 1 when in drawing region.0 in blanking/sync
    logic new_frame;            // one cycle active indicator of new frame of info!
    logic [5:0] frame_count;    // 0 to 59 then rollover frame counter
 
    // Making signals for 720p
    video_sig_gen mvg(
        .pixel_clk_in(clk_pixel),
        .rst_in(sys_rst),
        .hcount_out(hcount),
        .vcount_out(vcount),
        .vs_out(vert_sync),
        .hs_out(hor_sync),
        .ad_out(active_draw),
        .nf_out(new_frame),
        .fc_out(frame_count)
    );
 
    logic [7:0] red, green, blue; // red green and blue pixel values for output

    logic [$clog2(FRAME_AREA)-1:0]  sbuf_w_addr;    // Frame buffer write address
    logic                           sbuf_w_valid;   // Enable writing to frame buffer
    logic [15:0]                    sbuf_w_data;    // RGB565 to write to frame buffer

    logic [$clog2(FRAME_AREA)-1:0]  sbuf_r_addr;    // Frame buffer read address
    logic [15:0]                    sbuf_r_data;    // RGB565 read from frame buffer
    logic                           sbuf_r_valid;   // Is value read from buffer valid?

    // TODO: orchestrator goes here
    // for now: white

    //frame buffer from IP
    blk_mem_gen_0 frame_buffer(
        .addra(sbuf_w_addr),
        .clka(clk_pixel), // TODO: (yohang): change this to clk_100mhz
        .wea(sbuf_w_valid),
        .dina(sbuf_w_data),
        .ena(1'b1),
        .douta(),           // Never read from this side
        .addrb(sbuf_r_addr),
        .dinb(16'b0),
        .clkb(clk_pixel),
        .web(1'b0),
        .enb(1'b1),
        .doutb(sbuf_r_data)
    );

    // Scale-up frame buffer
    always_ff @(posedge clk_pixel) begin
        // 4x scaling
        sbuf_r_addr <= hcount[10:2] + (FRAME_WIDTH * vcount[9:2]);
        sbuf_r_valid <= (hcount < 1280) && (vcount < 720);

        sbuf_w_addr <= hcount[8:0] + (FRAME_WIDTH * vcount[7:0]);
        sbuf_w_valid <= 1;
        sbuf_w_data <= 16'hAE5D;
    end

    // RGB565 -> R, G, B
    logic [7:0] fb_red, fb_green, fb_blue;
    always_ff @(posedge clk_pixel) begin
        red     <= sbuf_r_valid ? { sbuf_r_data[15:11], 3'b0} : 8'b0;
        green   <= sbuf_r_valid ? { sbuf_r_data[10:5], 2'b0} : 8'b0;
        blue    <= sbuf_r_valid ? { sbuf_r_data[4:0], 3'b0} : 8'b0;
    end

    logic [9:0] tmds_10b    [0:2];  // Output of each TMDS encoder!
    logic       tmds_signal [2:0];  // Output of each TMDS serializer!
 
    // three tmds_encoders (blue, green, red)
    // note green should have no control signal like red
    // the blue channel DOES carry the two sync signals:
    //    * control_in[0] = horizontal sync signal
    //    * control_in[1] = vertical sync signal
    tmds_encoder tmds_red(
        .clk_in(clk_pixel),
        .rst_in(sys_rst),
        .data_in(red),
        .control_in(2'b0),
        .ve_in(active_draw),
        .tmds_out(tmds_10b[2])
    );
    tmds_serializer red_ser(
        .clk_pixel_in(clk_pixel),
        .clk_5x_in(clk_5x),
        .rst_in(sys_rst),
        .tmds_in(tmds_10b[2]),
        .tmds_out(tmds_signal[2])
    );

    tmds_encoder tmds_green(
        .clk_in(clk_pixel),
        .rst_in(sys_rst),
        .data_in(green),
        .control_in(2'b0),
        .ve_in(active_draw),
        .tmds_out(tmds_10b[1])
    );
    tmds_serializer green_ser(
        .clk_pixel_in(clk_pixel),
        .clk_5x_in(clk_5x),
        .rst_in(sys_rst),
        .tmds_in(tmds_10b[1]),
        .tmds_out(tmds_signal[1])
    );

    tmds_encoder tmds_blue(
        .clk_in(clk_pixel),
        .rst_in(sys_rst),
        .data_in(blue),
        .control_in({vert_sync, hor_sync}),
        .ve_in(active_draw),
        .tmds_out(tmds_10b[0])
    );
    tmds_serializer blue_ser(
        .clk_pixel_in(clk_pixel),
        .clk_5x_in(clk_5x),
        .rst_in(sys_rst),
        .tmds_in(tmds_10b[0]),
        .tmds_out(tmds_signal[0])
    );
 
    //output buffers generating differential signals:
    //three for the r,g,b signals and one that is at the pixel clock rate
    //the HDMI receivers use recover logic coupled with the control signals asserted
    //during blanking and sync periods to synchronize their faster bit clocks off
    //of the slower pixel clock (so they can recover a clock of about 742.5 MHz from
    //the slower 74.25 MHz clock)
    OBUFDS OBUFDS_blue (.I(tmds_signal[0]), .O(hdmi_tx_p[0]), .OB(hdmi_tx_n[0]));
    OBUFDS OBUFDS_green(.I(tmds_signal[1]), .O(hdmi_tx_p[1]), .OB(hdmi_tx_n[1]));
    OBUFDS OBUFDS_red    (.I(tmds_signal[2]), .O(hdmi_tx_p[2]), .OB(hdmi_tx_n[2]));
    OBUFDS OBUFDS_clock(.I(clk_pixel), .O(hdmi_clk_p), .OB(hdmi_clk_n));

endmodule

`default_nettype wire
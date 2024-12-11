module video_sig_gen
#(
  parameter ACTIVE_H_PIXELS = 1280,
  parameter H_FRONT_PORCH = 110,
  parameter H_SYNC_WIDTH = 40,
  parameter H_BACK_PORCH = 220,
  parameter ACTIVE_LINES = 720,
  parameter V_FRONT_PORCH = 5,
  parameter V_SYNC_WIDTH = 5,
  parameter V_BACK_PORCH = 20,
  parameter FPS = 60)
(
  input wire pixel_clk_in,
  input wire rst_in,
  output logic [$clog2(TOTAL_PIXELS)-1:0] hcount_out,
  output logic [$clog2(TOTAL_LINES)-1:0] vcount_out,
  output logic vs_out, //vertical sync out
  output logic hs_out, //horizontal sync out
  output logic ad_out,
  output logic nf_out, //single cycle enable signal
  output logic [5:0] fc_out); //frame

  localparam TOTAL_PIXELS = (ACTIVE_H_PIXELS + H_FRONT_PORCH + H_SYNC_WIDTH + H_BACK_PORCH); //*(ACTIVE_LINES + V_FRONT_PORCH + V_SYNC_WIDTH + V_BACK_PORCH); //figure this out
  localparam H_SYNC_HI = TOTAL_PIXELS - H_SYNC_WIDTH - H_BACK_PORCH - 1;
  localparam H_SYNC_LO = TOTAL_PIXELS - H_BACK_PORCH - 1;
  localparam TOTAL_LINES = ACTIVE_LINES + V_FRONT_PORCH + V_SYNC_WIDTH + V_BACK_PORCH; //figure this out
  localparam V_SYNC_HI = TOTAL_LINES - V_SYNC_WIDTH - V_BACK_PORCH;
  localparam V_SYNC_LO = TOTAL_LINES - V_BACK_PORCH;


  logic [$clog2(TOTAL_PIXELS)-2:0] hcount;
  logic [$clog2(TOTAL_LINES)-2:0] vcount;

  always_ff @(posedge pixel_clk_in) begin
    if (rst_in) begin
      hcount_out <= 0;
      vcount_out <= 0;
      vs_out <= 0;
      hs_out <= 0;
      nf_out <= 0;
      fc_out <= 0;
      ad_out <= 1;
    end else begin
      if (ad_out) begin                                                       // not much should happen when ad is high than to turn it low when no longer in ad region                          
        if (vcount_out < ACTIVE_LINES) begin
          if (hcount_out >= ACTIVE_H_PIXELS-1) begin
            ad_out <= 0;                                                      // ad_out should be low when hcount goes beyond 1280
          end
        end else begin
          ad_out <= 0;                                                        // ad_out will be low when vcount > ACTIVE_LINES
        end
        hcount_out <= hcount_out + 1;  
      end else begin                                                          // things that should happen when ad is low
        hs_out <= (hcount_out >= H_SYNC_HI) && (hcount_out < H_SYNC_LO);      // hs is high if in range H_SYNC_HI <= hcount < H_SYNC_LO
        // vs_out <= (vcount_out >= V_SYNC_HI -1) && (vcount_out < V_SYNC_LO);      // vs is high if in range V_SYNC_HI <= vcount < V_SYNC_LO
        if (vcount_out < ACTIVE_LINES) begin                                  // {general blank/sync horizontal region}
          if (hcount_out == TOTAL_PIXELS - 1) begin                           // when hcount reach the end of a line, some things should happen:
            hcount_out <= 0;                                                  // hcount reset
            vcount_out <= vcount_out + 1;                                     // vcount increments
            if (vcount_out < ACTIVE_LINES - 1) begin
              ad_out <= 1;                                                    // ad signal reset back high
            end
            if (vcount_out + 1 == V_SYNC_HI) begin
              vs_out <= 1;
            end
          end else begin
            hcount_out <= hcount_out + 1;  
          end
        end else if (vcount_out == TOTAL_LINES - 1) begin                     // frame's last pixel behavior
          if (hcount_out == TOTAL_PIXELS - 1) begin                           // when the very last pixel of the frame is reached, these should happen:
            hcount_out <= 0;                                                  // hcount resets
            vcount_out <= 0;                                                  // vcount resets
            if (vcount_out >= ACTIVE_LINES) begin
              ad_out <= 1;                                                      // ad turn high again for immediate ad in next frame
            end
          end else begin
            hcount_out <= hcount_out + 1;
          end
        end else if (vcount_out == ACTIVE_LINES) begin                        // pixel (1280, 720) behavior
          if (hcount_out == ACTIVE_H_PIXELS - 1) begin
            nf_out <= 1;                                                      // nf should be high at (1280, 720)
            fc_out <= fc_out + 1;                                             // fc should increment at (1280, 720)
            hcount_out <= hcount_out + 1; 
          end else if (hcount_out == TOTAL_PIXELS - 1) begin                  // end of line behavior
            hcount_out <= 0;                                                  // reset hcount
            vcount_out <= vcount_out + 1;                                     // increment vcount
            if (vcount_out + 1 == V_SYNC_HI) begin
              vs_out <= 1;
            end
          end else begin
            if (nf_out) begin
              nf_out <= 0;
            end
            hcount_out <= hcount_out + 1; 
          end 
          
        end else begin                                                        // {general blank/sync vertical region} 
          if (hcount_out == TOTAL_PIXELS - 1) begin                           // end of line behavior
            hcount_out <= 0;                                                  // hcount reset
            vcount_out <= vcount_out + 1;                                     // increment vcount
            if (vcount_out + 1 == V_SYNC_HI) begin
              vs_out <= 1;
            end else if (vcount_out + 1 == V_SYNC_LO) begin
              vs_out <= 0;
            end
          end else begin
            hcount_out <= hcount_out + 1;
          end
        end
      end
    end
  end

endmodule

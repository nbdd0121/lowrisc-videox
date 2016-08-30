/*
* Input is Packed Y'UV 444:
*  -------------------------------------------------------------------------
*  |   U    |   Y0   |   V    | 0 Byte |   U    |   Y1   |   V    | 0 Byte |
*  -------------------------------------------------------------------------
*  | Byte 0 | Byte 1 | Byte 2 | Byte 3 | Byte 4 | Byte 5 | Byte 6 | Byte 7 |
*  -------------------------------------------------------------------------
*
* Output is  RGB:
*  -------------------------------------------------------------------------
*  |   R    |   G    |   B    | 0 Byte |   R    |   G    |   B    | 0 Byte |
*  -------------------------------------------------------------------------
*  | Byte 0 | Byte 1 | Byte 2 | Byte 3 | Byte 4 | Byte 5 | Byte 6 | Byte 7 |
*  -------------------------------------------------------------------------
*
*
*  Conversion taken from wikipedia: https://en.wikipedia.org/wiki/YUV#Y.E2.80.B2UV444_to_RGB888_conversion
*
*/
module yuv444toRGB # (
   DATA_WIDTH = 64,
   USER_WIDTH = 1,
   DEST_WIDTH = 1,
   CHAIN_ID   = 0
) (
   input aclk,
   input aresetn,

   nasti_stream_channel.slave src,
   nasti_stream_channel.master dst
   );

   nasti_stream_channel # (
      .DATA_WIDTH(DATA_WIDTH),
      .USER_WIDTH(USER_WIDTH)
   ) buf_ch ();

   // We have a timing cycle in which the t_ready signal is forwarded through the crossbar. Prevent this using a buffer.
   nasti_stream_buf # (
      .USER_WIDTH(USER_WIDTH),
      .BUF_SIZE(1)
   ) input_buf (
      .aclk(aclk),
      .aresetn(aresetn),

      .src(src),
      .dest(buf_ch)
   );

   logic signed [31:0] c_0, d_0, e_0, c_1, d_1, e_1;
   logic last_latch_read;
   logic [USER_WIDTH-1:0] user_latch_read;

   logic signed [31:0] x_0, y_0_0, y_0_1, z_0_0, z_0_1,
                  x_1, y_1_0, y_1_1, z_1_0, z_1_1;
   logic last_latch_mult;
   logic [USER_WIDTH-1:0] user_latch_mult;

   logic signed [31:0] r_0, g_0, b_0, r_1, g_1, b_1;
   logic last_latch_add;
   logic [USER_WIDTH-1:0] user_latch_add;

   logic can_read, can_mult, can_add, can_clamp, can_write;
   logic to_mult, to_add, to_clamp;

   function [7:0] clamp(input integer x);
      clamp = x < 0 ? 0 : (x > 255 ? 255 : x);
   endfunction

   always_comb begin
      can_write = dst.t_valid && dst.t_ready;
      can_clamp = (can_write  || !dst.t_valid) && to_clamp;
      can_add   = (can_clamp  || !to_clamp   ) && to_add;
      can_mult  = (can_add    || !to_add     ) && to_mult;
      can_read  = buf_ch.t_valid && buf_ch.t_ready;
   end

   assign dst.t_strb = '1;
   assign dst.t_keep = '1;

   assign buf_ch.t_ready = can_mult || !to_mult;

   always_ff @(posedge aclk or negedge aresetn) begin
      if(!aresetn) begin
         dst.t_valid <= 0;
         dst.t_last  <= 0;

         to_mult     <= 0;
         to_add      <= 0;
         to_clamp    <= 0;
      end
      else begin
         if (can_read) begin
            assert(&buf_ch.t_keep && &buf_ch.t_strb) else $error("Null byte not supported");

            c_0 <= buf_ch.t_data[0][23:16] - 16;  // Y
            d_0 <= buf_ch.t_data[0][15: 8] - 128; // U
            e_0 <= buf_ch.t_data[0][ 7: 0] - 128; // V

            c_1 <= buf_ch.t_data[0][55:48] - 16;  // Y
            d_1 <= buf_ch.t_data[0][47:40] - 128; // U
            e_1 <= buf_ch.t_data[0][39:32] - 128; // V

            last_latch_read <= buf_ch.t_last;
            user_latch_read <= buf_ch.t_user;

            to_mult <= 1;
         end else if (can_mult) begin
            to_mult <= 0;
         end

         if (can_mult) begin
            x_0   <= 298 * c_0;
            y_0_0 <= 100 * d_0;
            y_0_1 <= 516 * d_0;
            z_0_0 <= 409 * e_0;
            z_0_1 <= 208 * e_0;

            x_1   <= 298 * c_1;
            y_1_0 <= 100 * d_1;
            y_1_1 <= 516 * d_1;
            z_1_0 <= 409 * e_1;
            z_1_1 <= 208 * e_1;

            last_latch_mult <= last_latch_read;
            user_latch_mult <= user_latch_read;

            to_add <= 1;
         end else if (can_add) begin
            to_add <= 0;
         end

         if (can_add) begin
            r_0 <= (x_0         + z_0_0 + 128) >>> 8;
            g_0 <= (x_0 - y_0_0 - z_0_1 + 128) >>> 8;
            b_0 <= (x_0         + y_0_1 + 128) >>> 8;

            r_1 <= (x_1         + z_1_0 + 128) >>> 8;
            g_1 <= (x_1 - y_1_0 - z_1_1 + 128) >>> 8;
            b_1 <= (x_1         + y_1_1 + 128) >>> 8;
         
            last_latch_add <= last_latch_mult;
            user_latch_add <= user_latch_mult;

            to_clamp <= 1;
         end else if (can_clamp) begin
            to_clamp <= 0;
         end

         if (can_clamp) begin
            dst.t_data[0][ 7: 0] <= clamp(b_0);
            dst.t_data[0][15: 8] <= clamp(g_0);
            dst.t_data[0][23:16] <= clamp(r_0);
            dst.t_data[0][31:24] <= 8'd255;

            dst.t_data[0][39:32] <= clamp(b_1);
            dst.t_data[0][47:40] <= clamp(g_1);
            dst.t_data[0][55:48] <= clamp(r_1);
            dst.t_data[0][63:56] <= 8'd255;

            dst.t_last <= last_latch_add;
            dst.t_user <= user_latch_add >> 1;
            dst.t_dest <= (user_latch_add & 1) ? CHAIN_ID : 0;

            dst.t_valid <= 1;
         end else if (can_write) begin
            dst.t_valid <= 0;
         end

      end
   end
endmodule

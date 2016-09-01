/* MUST INTERLEAVE YUV BEFORE SENDING TO THIS STREAM PROCESSOR
*  Input is packed Y'UV422:
*  -------------------------------------
*  |   Y0   |   U    |   Y1   |   V    |
*  -------------------------------------
*  | Byte 0 | Byte 1 | Byte 2 | Byte 3 |
*  -------------------------------------
*
* Output is packed Y'UV444:
*  -------------------------------------------------------------------------
*  |   V    |   U    |   Y0   | 0 Byte |   V    |   U    |   Y1   | 0 Byte |
*  -------------------------------------------------------------------------
*  | Byte 0 | Byte 1 | Byte 2 | Byte 3 | Byte 4 | Byte 5 | Byte 6 | Byte 7 |
*  -------------------------------------------------------------------------
*
*/
module yuv422to444_noninterp # (
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
      .DATA_WIDTH(DATA_WIDTH / 2),
      .USER_WIDTH(USER_WIDTH),
      .DEST_WIDTH(DEST_WIDTH)
   ) narrower_ch();

   nasti_stream_narrower # (
      .MASTER_DATA_WIDTH(DATA_WIDTH),
      .SLAVE_DATA_WIDTH(DATA_WIDTH / 2),
      .USER_WIDTH(USER_WIDTH),
      .DEST_WIDTH(DEST_WIDTH)
   ) narrower (
      .aclk    (aclk),
      .aresetn (aresetn),
      .master  (src),
      .slave   (narrower_ch)
   );

   logic [31:0] buffer;
   logic can_read, can_write, can_output;
   logic to_write;
   logic last_latch;
   logic user_latch;

   always_comb begin
      can_write = dst.t_valid && dst.t_ready;
      can_output = (can_write || !dst.t_valid) && to_write;
      can_read  = narrower_ch.t_valid && narrower_ch.t_ready;
   end

   assign narrower_ch.t_ready = can_write || !to_write;

   assign dst.t_strb = '1;
   assign dst.t_keep = '1;
   assign dst.t_id   = '0;
   assign dst.t_user = user_latch >> 1;
   assign dst.t_dest = (user_latch & 1) ? CHAIN_ID : 0;

   always_ff @(posedge aclk or negedge aresetn) begin
      if (!aresetn) begin
         dst.t_valid <= 0;

         last_latch <= 0;
         user_latch <= 0;

         to_write <= 0;
      end
      else begin
         if (can_read) begin
            assert(&narrower_ch.t_keep && &narrower_ch.t_strb) else $error("Null byte not supported");

            buffer <= narrower_ch.t_data;
            last_latch <= narrower_ch.t_last;
            user_latch <= narrower_ch.t_user;

            to_write <= 1;
         end else if (can_output) begin
            to_write <= 0;
         end

         if (can_output) begin
            dst.t_data[0][ 7: 0] <= buffer[31:24]; // v
            dst.t_data[0][15: 8] <= buffer[15: 8]; // u
            dst.t_data[0][23:16] <= buffer[ 7: 0]; // y0
            dst.t_data[0][31:24] <= 8'b0;

            dst.t_data[0][39:32] <= buffer[31:24]; // v
            dst.t_data[0][47:40] <= buffer[15: 8]; // u
            dst.t_data[0][55:48] <= buffer[23:16]; // y1
            dst.t_data[0][63:56] <= 8'b0;

            dst.t_last <= last_latch;
            dst.t_valid <= 1;
         end else if (can_write) begin
            dst.t_valid <= 0;
         end
      end
   end
endmodule

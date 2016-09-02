module saturate # (
   COEF_WIDTH = 16,
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

   localparam MULTIPLE = DATA_WIDTH / COEF_WIDTH;
   localparam EFFECTIVE_WIDTH = COEF_WIDTH / 4 * 3;
   localparam signed COEF_MAX = 2 ** (EFFECTIVE_WIDTH - 1) - 1;
   localparam signed COEF_MIN = -(2 ** (EFFECTIVE_WIDTH - 1));

   logic [MULTIPLE-1:0][COEF_WIDTH-1:0] src_data;

   logic [MULTIPLE-1:0][COEF_WIDTH-1:0] clamped;
   logic last_latch_clamp;
   logic [USER_WIDTH-1:0] user_latch_clamp;

   logic [MULTIPLE-1:0][COEF_WIDTH-1:0] dst_data;
   logic [7:0] cnt;
   logic [MULTIPLE-1:0] comb_parity;
   logic parity;
   logic last_latch_mismatch;
   logic [USER_WIDTH-1:0] user_latch_mismatch;

   logic can_read, can_mismatch, can_write;
   logic to_mismatch;

   function signed [COEF_WIDTH-1:0] clamp(input signed [COEF_WIDTH-1:0] x);
      clamp = x < COEF_MIN ? COEF_MIN : (x > COEF_MAX ? COEF_MAX : x);
   endfunction

   always_comb begin
      can_write    = dst.t_valid && dst.t_ready;
      can_mismatch = (can_write  || !dst.t_valid) && to_mismatch;
      can_read     = src.t_valid && src.t_ready;
   end

   always_comb begin
      foreach (clamped[i]) comb_parity[i] = clamped[i][0];
   end

   assign dst.t_data = dst_data;
   assign dst.t_strb = '1;
   assign dst.t_keep = '1;
   assign dst.t_id   = '0;

   assign src_data = src.t_data;
   assign src.t_ready = can_mismatch || !to_mismatch;

   always_ff @(posedge aclk or negedge aresetn) begin
      if(!aresetn) begin
         dst.t_valid <= 0;
         dst.t_last  <= 0;

         to_mismatch <= 0;
         cnt         <= 0;
         parity      <= 0;
      end
      else begin
         if (can_read) begin
            assert(&src.t_keep && &src.t_strb) else $error("Null byte not supported");

            foreach(clamped[i]) clamped[i] <= clamp(src_data[i]);

            last_latch_mismatch <= src.t_last;
            user_latch_mismatch <= src.t_user;

            to_mismatch <= 1;
         end else if (can_mismatch) begin
            to_mismatch <= 0;
         end

         if (can_mismatch) begin
            if (last_latch_mismatch || cnt + MULTIPLE == 64) begin
               foreach (clamped[i]) begin
                  if (i == MULTIPLE - 1 && parity)
                     dst_data[i] <= clamped[i] ^ 1;
                  else
                     dst_data[i] <= clamped[i];
               end

               // Last one, do parity correction and reset
               cnt    <= 0;
               parity <= 0;
            end else begin
               foreach (clamped[i]) dst_data[i] <= clamped[i];
               cnt    <= cnt + MULTIPLE; 
               parity <= cnt ^ ^comb_parity;
            end

            dst.t_last  <= last_latch_mismatch;
            dst.t_user  <= user_latch_mismatch >> 1;
            dst.t_dest  <= (user_latch_mismatch & 1) ? CHAIN_ID : 0;

            dst.t_valid <= 1;
         end else if (can_write) begin
            dst.t_valid <= 0;
         end

      end
   end
endmodule

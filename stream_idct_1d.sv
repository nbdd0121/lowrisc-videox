// This module is a 5-stage 1D-IDCT implementation.
// It must be enabled one clock before the first input and the en must be
// kept high until the clock you provide the last input.
// The output is kept at 0 when out_en is not high.
// Implementation is a slight modification on the one provied in:
// Arun N. Netravali,Barry G. Haskell
// "Digital Pictures Representation, Compression, and Standards" P.512
module stream_idct_1d #(
   parameter COEF_WIDTH = 16
) (
   input  aclk,
   input  aresetn,

   nasti_stream_channel.slave  in_ch,
   nasti_stream_channel.master out_ch
);

   function signed [COEF_WIDTH - 1: 0] round(signed [COEF_WIDTH + 1: 0] x);
      round = x < 0 ? (((x <<< 1) - 1) >>> 1) : (((x <<< 1) + 1) >>> 1);
   endfunction

   logic [7:0][COEF_WIDTH - 1:0] row, row_out;
   logic signed [COEF_WIDTH + 1:0] temp_a [0:7];
   logic signed [COEF_WIDTH + 1:0] temp_b [0:7];
   logic signed [COEF_WIDTH + 1:0] temp_c [0:7];
   logic signed [COEF_WIDTH + 1:0] temp_d [0:7];
   logic can_s1, can_s2, can_s3, can_s4, can_s5, can_write;
   logic to_s2, to_s3, to_s4, to_s5;
   logic last_latch_s1, last_latch_s2, last_latch_s3, last_latch_s4;

   assign out_ch.t_strb = '1;
   assign out_ch.t_keep = '1;
   assign out_ch.t_dest = '0;

   assign in_ch.t_ready = can_s2 || !to_s2;

   always_comb begin
      can_write = out_ch.t_valid && out_ch.t_ready;
      can_s5    = (can_write || !out_ch.t_valid) && to_s5;
      can_s4    = (can_s5    || !to_s5         ) && to_s4;
      can_s3    = (can_s4    || !to_s4         ) && to_s3;
      can_s2    = (can_s3    || !to_s3         ) && to_s2;
      can_s1    = in_ch.t_valid && in_ch.t_ready;
   end

   assign row = in_ch.t_data;
   assign out_ch.t_data = row_out;

   always_ff @(posedge aclk or negedge aresetn) begin
      if (!aresetn) begin
         foreach (temp_a[i]) begin
            temp_a   [i] = {COEF_WIDTH{1'b0}};
            temp_b   [i] = {COEF_WIDTH{1'b0}};
            temp_c   [i] = {COEF_WIDTH{1'b0}};
            temp_d   [i] = {COEF_WIDTH{1'b0}};
         end

         out_ch.t_valid <= 'd0;
         out_ch.t_last  <= 'd0;

         to_s2 <= 'd0;
         to_s3 <= 'd0;
         to_s4 <= 'd0;
         to_s5 <= 'd0;
      end else begin
         // Stage 1
         if (can_s1) begin
            $display("IDCT IN: %d, %d, %d, %d, %d, %d, %d, %d,",
                     $signed(row[0]),$signed(row[1]),$signed(row[2]),$signed(row[3]),
                     $signed(row[4]),$signed(row[5]),$signed(row[6]),$signed(row[7]));
            temp_a[0] <= (362 * ($signed(row[4]) + $signed(row[0]))) >>> 8;
            temp_a[1] <= (473 * $signed(row[2]) + 196 * $signed(row[6])) >>> 8;
            temp_a[2] <= (362 * ($signed(row[0]) - $signed(row[4]))) >>> 8;
            temp_a[3] <= (473 * $signed(row[6]) - 196 * $signed(row[2])) >>> 8;
            temp_a[4] <= (502 * $signed(row[1]) + 100 * $signed(row[7])) >>> 8;
            temp_a[5] <= (425 * $signed(row[3]) + 285 * $signed(row[5])) >>> 8;
            temp_a[6] <= (502 * $signed(row[7]) - 100 * $signed(row[1])) >>> 8;
            temp_a[7] <= (425 * $signed(row[5]) - 285 * $signed(row[3])) >>> 8;

            last_latch_s1 <= in_ch.t_last;

            to_s2 <= 'd1;
         end else if (can_s2) begin
            to_s2 <= 'd0;
         end

         // Stage 2
         if (can_s2) begin
            temp_b[0] <= (temp_a[4] + temp_a[5]) >>> 1;
            temp_b[1] <= (temp_a[6] - temp_a[7]) >>> 1;
            temp_b[2] <= temp_a[0];
            temp_b[3] <= temp_a[1];
            temp_b[4] <= temp_a[2];
            temp_b[5] <= 724 * (temp_a[4] - temp_a[5]) >>> 10;
            temp_b[6] <= temp_a[3];
            temp_b[7] <= 724 * (temp_a[6] + temp_a[7]) >>> 10;

            last_latch_s2 <= last_latch_s1;

            to_s3 <= 'd1;
         end else if (can_s3) begin
            to_s3 <= 'd0;
         end

         // Stage 3
         if (can_s3) begin
            temp_c[0] <= (temp_b[2] + temp_b[3]) >>> 1;
            temp_c[1] <= temp_b[0];
            temp_c[2] <= (temp_b[4] + temp_b[5]) >>> 1;
            temp_c[3] <= (temp_b[6] + temp_b[7]) >>> 1;
            temp_c[4] <= (temp_b[2] - temp_b[3]) >>> 1;
            temp_c[5] <= temp_b[1];
            temp_c[6] <= (temp_b[4] - temp_b[5]) >>> 1;
            temp_c[7] <= (temp_b[6] - temp_b[7]) >>> 1;

            last_latch_s3 <= last_latch_s2;

            to_s4 <= 'd1;
         end else if (can_s4) begin
            to_s4 <= 'd0;
         end

         // Stage 4
         if (can_s4) begin
            temp_d[0] <= (temp_c[0] + temp_c[1]) >>> 1;
            temp_d[1] <= (temp_c[2] - temp_c[3]) >>> 1;
            temp_d[2] <= (temp_c[2] + temp_c[3]) >>> 1;
            temp_d[3] <= (temp_c[4] - temp_c[5]) >>> 1;
            temp_d[4] <= (temp_c[4] + temp_c[5]) >>> 1;
            temp_d[5] <= (temp_c[6] + temp_c[7]) >>> 1;
            temp_d[6] <= (temp_c[6] - temp_c[7]) >>> 1;
            temp_d[7] <= (temp_c[0] - temp_c[1]) >>> 1;

            last_latch_s4 <= last_latch_s3;

            to_s5 <= 'd1;
         end else if (can_s5) begin
            to_s5 <= 'd0;
         end

         // Stage 5
         if (can_s5) begin
            $display("IDCT OUT: %d, %d, %d, %d, %d, %d, %d, %d,",
                     round(temp_d[0]),round(temp_d[1]),round(temp_d[2]),round(temp_d[3]),
                     round(temp_d[4]),round(temp_d[5]),round(temp_d[6]),round(temp_d[7]));
            row_out[0] <= round(temp_d[0]);
            row_out[1] <= round(temp_d[1]);
            row_out[2] <= round(temp_d[2]);
            row_out[3] <= round(temp_d[3]);
            row_out[4] <= round(temp_d[4]);
            row_out[5] <= round(temp_d[5]);
            row_out[6] <= round(temp_d[6]);
            row_out[7] <= round(temp_d[7]);

            out_ch.t_last  <= last_latch_s4;
            out_ch.t_valid <= 'd1;
         end else if (can_write) begin
            out_ch.t_valid <= 'd0;
         end
      end
   end
endmodule

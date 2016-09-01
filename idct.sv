// This module is a 5-stage 1D-IDCT implementation.
// It must be enabled one clock before the first input and the en must be
// kept high until the clock you provide the last input.
// The output is kept at 0 when out_en is not high.
// Implementation is a slight modification on the one provied in:
// Arun N. Netravali,Barry G. Haskell
// "Digital Pictures Representation, Compression, and Standards" P.512
module idct #(
      parameter COEF_WIDTH = 32
   )
   (
      input signed      [COEF_WIDTH - 1:0] row      [0:7],
      output reg signed [COEF_WIDTH - 1:0] idct_row [0:7],

      input  aclk,
      input  en,
      output reg out_en,
      input  aresetn,
      input  locked
   );

   logic signed [COEF_WIDTH - 1:0] temp_a [0:7];
   logic signed [COEF_WIDTH - 1:0] temp_b [0:7];
   logic signed [COEF_WIDTH - 1:0] temp_c [0:7];
   logic signed [COEF_WIDTH - 1:0] temp_d [0:7];
   logic [7:0] delay_line_en;

   always_ff @(posedge aclk or negedge aresetn) begin
      if (!aresetn) begin
         foreach (temp_a[i]) begin
            temp_a   [i] = {COEF_WIDTH{1'b0}};
            temp_b   [i] = {COEF_WIDTH{1'b0}};
            temp_c   [i] = {COEF_WIDTH{1'b0}};
            temp_d   [i] = {COEF_WIDTH{1'b0}};
            idct_row [i] = {COEF_WIDTH{1'b0}};
         end
         delay_line_en <= 8'b0;
         out_en        <= 'd0;
      end else if (!locked) begin
         delay_line_en[0]   <= en;
         delay_line_en[7:1] <= delay_line_en[6:0];
         out_en             <= delay_line_en[3];
         if (!en && !out_en) begin
            foreach (temp_a[i]) begin
               temp_a   [i] = {COEF_WIDTH{1'b0}};
               temp_b   [i] = {COEF_WIDTH{1'b0}};
               temp_c   [i] = {COEF_WIDTH{1'b0}};
               temp_d   [i] = {COEF_WIDTH{1'b0}};
               idct_row [i] = {COEF_WIDTH{1'b0}};
            end
         end else begin
            // Stage 1
            temp_a[0] <= (362 * (row[4] + row[0])) >>> 8;
            temp_a[1] <= (473 * row[2] + 196 * row[6]) >>> 8;
            temp_a[2] <= (362 * (row[0] - row[4])) >>> 8;
            temp_a[3] <= (473 * row[6] - 196 * row[2]) >>> 8;
            temp_a[4] <= (502 * row[1] + 100 * row[7]) >>> 8;
            temp_a[5] <= (425 * row[3] + 285 * row[5]) >>> 8;
            temp_a[6] <= (502 * row[7] - 100 * row[1]) >>> 8;
            temp_a[7] <= (425 * row[5] - 285 * row[3]) >>> 8;
            // Stage 2
            temp_b[0] <= (temp_a[4] + temp_a[5]) >>> 1;
            temp_b[1] <= (temp_a[6] - temp_a[7]) >>> 1;
            temp_b[2] <= temp_a[0];
            temp_b[3] <= temp_a[1];
            temp_b[4] <= temp_a[2];
            temp_b[5] <= 724 * (temp_a[4] - temp_a[5]) >>> 10;
            temp_b[6] <= temp_a[3];
            temp_b[7] <= 724 * (temp_a[6] + temp_a[7]) >>> 10;
            // Stage 3
            temp_c[0] <= (temp_b[2] + temp_b[3]) >>> 1;
            temp_c[1] <= temp_b[0];
            temp_c[2] <= (temp_b[4] + temp_b[5]) >>> 1;
            temp_c[3] <= (temp_b[6] + temp_b[7]) >>> 1;
            temp_c[4] <= (temp_b[2] - temp_b[3]) >>> 1;
            temp_c[5] <= temp_b[1];
            temp_c[6] <= (temp_b[4] - temp_b[5]) >>> 1;
            temp_c[7] <= (temp_b[6] - temp_b[7]) >>> 1;
            // Stage 4
            temp_d[0] <= (temp_c[0] + temp_c[1]) >>> 1;
            temp_d[1] <= (temp_c[2] - temp_c[3]) >>> 1;
            temp_d[2] <= (temp_c[2] + temp_c[3]) >>> 1;
            temp_d[3] <= (temp_c[4] - temp_c[5]) >>> 1;
            temp_d[4] <= (temp_c[4] + temp_c[5]) >>> 1;
            temp_d[5] <= (temp_c[6] + temp_c[7]) >>> 1;
            temp_d[6] <= (temp_c[6] - temp_c[7]) >>> 1;
            temp_d[7] <= (temp_c[0] - temp_c[1]) >>> 1;
            // Stage 5
            if (delay_line_en[3]) begin
               idct_row[0] <= temp_d[0] < 0 ? (((temp_d[0] <<< 1) - 1) >>> 1) : (((temp_d[0] <<< 1) + 1) >>> 1);
               idct_row[1] <= temp_d[1] < 0 ? (((temp_d[1] <<< 1) - 1) >>> 1) : (((temp_d[1] <<< 1) + 1) >>> 1);
               idct_row[2] <= temp_d[2] < 0 ? (((temp_d[2] <<< 1) - 1) >>> 1) : (((temp_d[2] <<< 1) + 1) >>> 1);
               idct_row[3] <= temp_d[3] < 0 ? (((temp_d[3] <<< 1) - 1) >>> 1) : (((temp_d[3] <<< 1) + 1) >>> 1);
               idct_row[4] <= temp_d[4] < 0 ? (((temp_d[4] <<< 1) - 1) >>> 1) : (((temp_d[4] <<< 1) + 1) >>> 1);
               idct_row[5] <= temp_d[5] < 0 ? (((temp_d[5] <<< 1) - 1) >>> 1) : (((temp_d[5] <<< 1) + 1) >>> 1);
               idct_row[6] <= temp_d[6] < 0 ? (((temp_d[6] <<< 1) - 1) >>> 1) : (((temp_d[6] <<< 1) + 1) >>> 1);
               idct_row[7] <= temp_d[7] < 0 ? (((temp_d[7] <<< 1) - 1) >>> 1) : (((temp_d[7] <<< 1) + 1) >>> 1);
            end else
               foreach (idct_row[i])
                  idct_row [i] = {COEF_WIDTH{1'b0}};
         end
      end
   end
endmodule

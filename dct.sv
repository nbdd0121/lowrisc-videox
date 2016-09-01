// This module is a 4-stage 1D-DCT implementation.
// It must be enabled one clock before the first input and the en must be
// kept high until the clock you provide the last input.
// The output is kept at 0 when out_en is not high.
module dct #(
      parameter COEF_WIDTH = 32
   )
   (
      input signed      [COEF_WIDTH - 1:0] row     [0:7],
      output reg signed [COEF_WIDTH + 1:0] dct_row [0:7],

      input  aclk,
      input  en,
      output reg out_en,
      input  aresetn,
      input  locked
   );

   logic signed [COEF_WIDTH + 1:0] temp_a [0:7];
   logic signed [COEF_WIDTH + 1:0] temp_b [0:7];
   logic signed [COEF_WIDTH + 1:0] temp_c [0:7];
   logic [7:0] delay_line_en;

   always_ff @(posedge aclk or negedge aresetn) begin
      if (!aresetn) begin
         foreach (temp_a[i]) begin
            temp_a  [i] <= {COEF_WIDTH{1'b0}};
            temp_b  [i] <= {COEF_WIDTH{1'b0}};
            temp_c  [i] <= {COEF_WIDTH{1'b0}};
            dct_row [i] <= {COEF_WIDTH{1'b0}};
         end
         delay_line_en <= 8'b0;
         out_en        <= 'd0;
      end else if (!locked) begin
         delay_line_en[0]   <= en;
         delay_line_en[7:1] <= delay_line_en[6:0];
         out_en             <= delay_line_en[3];
         if (!en && !out_en) begin
           foreach (temp_a[i]) begin
                 temp_a  [i] <= {COEF_WIDTH{1'b0}};
                 temp_b  [i] <= {COEF_WIDTH{1'b0}};
                 temp_c  [i] <= {COEF_WIDTH{1'b0}};
                 dct_row [i] <= {COEF_WIDTH{1'b0}};
              end
         end else begin
            // Stage 1 of DCT
            temp_a[0] <= row[0] + row[7];
            temp_a[1] <= row[1] + row[6];
            temp_a[2] <= row[2] + row[5];
            temp_a[3] <= row[3] + row[4];
            temp_a[4] <= row[3] - row[4];
            temp_a[5] <= row[2] - row[5];
            temp_a[6] <= row[1] - row[6];
            temp_a[7] <= row[0] - row[7];
            // Stage 2 of DCT
            temp_b[0] <= temp_a[0] + temp_a[3];
            temp_b[1] <= temp_a[1] + temp_a[2];
            temp_b[2] <= temp_a[1] - temp_a[2];
            temp_b[3] <= temp_a[0] - temp_a[3];
            temp_b[4] <= (425 * temp_a[3] + 285 * temp_a[7]) >>> 9;
            temp_b[5] <= (502 * temp_a[5] + 100 * temp_a[6]) >>> 9;
            temp_b[6] <= (502 * temp_a[6] - 100 * temp_a[5]) >>> 9;
            temp_b[7] <= (425 * temp_a[7] - 285 * temp_a[4]) >>> 9;
            // Stage 3 of DCT
            temp_c[0] <= temp_b[0] + temp_b[1];
            temp_c[1] <= temp_b[0] - temp_b[1];
            temp_c[2] <= (196 * temp_b[2] + 473 * temp_b[3]) >>> 9;
            temp_c[3] <= (196 * temp_b[3] - 473 * temp_b[2]) >>> 9;
            temp_c[4] <= temp_b[4] + temp_b[6];
            temp_c[5] <= temp_b[5] - temp_b[7];
            temp_c[6] <= temp_b[4] - temp_b[6];
            temp_c[7] <= temp_b[5] + temp_b[7];
            // Stage 4 of DCT
            if (delay_line_en[2]) begin
               dct_row[0] <= temp_c[0];
               dct_row[4] <= temp_c[1];
               dct_row[2] <= temp_c[2];
               dct_row[6] <= temp_c[3];
               dct_row[7] <= temp_c[7] - temp_c[4];
               dct_row[3] <= (724 * temp_c[5]) >>> 9;
               dct_row[5] <= (724 * temp_c[6]) >>> 9;
               dct_row[1] <= temp_c[7] + temp_c[4];
            end else
               foreach (dct_row[i])
                  dct_row [i] <= {COEF_WIDTH{1'b0}};
         end
      end
   end
endmodule

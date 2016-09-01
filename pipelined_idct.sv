// This module uses 2 1D-IDCT transforms and 2 transpose buffers to compute the 2D version.
// It acts as a control plane for the smaller modules provided it is fed data.
// The enable signal should go high one cycle before the first input
// and must be kept until the cycle of the last input.
// The busy signal must be checked before enabling the module
// as the pipelines must be cleared of data before a new input stream is given.
module pipelined_idct #(
      parameter COEF_WIDTH = 32
   )
   (
      input signed      [COEF_WIDTH - 1:0] row      [0:7],
      output reg signed [COEF_WIDTH + 3:0] idct_row [0:7],

      input en,
      input aclk,
      input aresetn,
      input locked,
      output reg busy,
      output reg out_en
   );

   logic signed [COEF_WIDTH + 3:0] in_row               [0:7];
   logic signed [COEF_WIDTH + 3:0] idct_row_internal    [0:7];
   logic signed [COEF_WIDTH + 3:0] column_internal      [0:7];
   logic signed [COEF_WIDTH + 3:0] idct_column_internal [0:7];
   logic signed [COEF_WIDTH + 3:0] pre_clip_idct_row    [0:7];
   logic transpose_en, idct2_en, out_t_en, busy_latch;

   // Clip to [-256,255]
   function signed [COEF_WIDTH + 3:0] clip(signed [COEF_WIDTH + 3:0] to_clip);
      clip = (to_clip < -256) ? -'d256 : (to_clip > 255) ? 255 : to_clip;
   endfunction

   assign idct_row[0] = clip(pre_clip_idct_row[0]);
   assign idct_row[1] = clip(pre_clip_idct_row[1]);
   assign idct_row[2] = clip(pre_clip_idct_row[2]);
   assign idct_row[3] = clip(pre_clip_idct_row[3]);
   assign idct_row[4] = clip(pre_clip_idct_row[4]);
   assign idct_row[5] = clip(pre_clip_idct_row[5]);
   assign idct_row[6] = clip(pre_clip_idct_row[6]);
   assign idct_row[7] = clip(pre_clip_idct_row[7]);

   // This is done to allow signed expansion to avoid array size mismatches.
   assign in_row[0] = row[0];
   assign in_row[1] = row[1];
   assign in_row[2] = row[2];
   assign in_row[3] = row[3];
   assign in_row[4] = row[4];
   assign in_row[5] = row[5];
   assign in_row[6] = row[6];
   assign in_row[7] = row[7];

   // Busy latch logic to make sure we go high when we are enabled and low after
   // final output.
   assign busy = en ? 1 : busy_latch ? 1 : out_en;

   always_ff @(posedge aclk or negedge aresetn) begin
      if (!aresetn) begin
         busy_latch <= 'd0;
      end else begin
         busy_latch <= busy;
         if (out_en)
            busy_latch <= 'd0;
      end
   end

   // ROW IDCT
   idct #(
         .COEF_WIDTH(COEF_WIDTH + 4)
        ) idct_1 (
         .row(in_row),
         .idct_row(idct_row_internal),

         .aclk(aclk),
         .en(en),
         .out_en(transpose_en),
         .aresetn(aresetn),
         .locked(locked)
      );

   // Transpose buffer.
   transpose #(
         .COEF_WIDTH(COEF_WIDTH + 4),
         .WITH_STAGING(0)
        ) transpose (
         .row(idct_row_internal),
         .column(column_internal),

         .en(transpose_en),
         .out_en(idct2_en),
         .aclk(aclk),
         .aresetn(aresetn),
         .locked(locked)
      );

   // Column IDCT
   idct #(
         .COEF_WIDTH(COEF_WIDTH + 4)
        ) idct_2 (
         .row(column_internal),
         .idct_row(idct_column_internal),

         .aclk(aclk),
         .en(idct2_en),
         .out_en(out_t_en),
         .aresetn(aresetn),
         .locked(locked)
      );

   // Output transpose buffer for transparancy with the Software Implementation.
   transpose #(
         .COEF_WIDTH(COEF_WIDTH + 4),
         .WITH_STAGING(0)
        ) transpose_out (
         .row(idct_column_internal),
         .column(pre_clip_idct_row),

         .en(out_t_en),
         .out_en(out_en),
         .aclk(aclk),
         .aresetn(aresetn),
         .locked(locked)
      );
endmodule

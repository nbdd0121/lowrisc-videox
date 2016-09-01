// This module uses 2 1D-DCT transforms and 2 transpose buffers to compute the 2D version.
// It acts as a control plane for the smaller modules provided it is fed data.
// The enable signal should go high one cycle before the first input
// and must be kept until the cycle of the last input.
// The busy signal must be checked before enabling the module
// as the pipelines must be cleared of data before a new input stream is given.
module pipelined_dct #(
      parameter COEF_WIDTH = 32
   )
   (
      input signed      [COEF_WIDTH - 1:0] row     [0:7],
      output reg signed [COEF_WIDTH + 3:0] dct_row [0:7],

      input en,
      input aclk,
      input aresetn,
      input locked,
      output reg busy,
      output reg out_en
   );

   logic signed [COEF_WIDTH + 1:0] dct_row_internal    [0:7];
   logic signed [COEF_WIDTH + 1:0] column_internal     [0:7];
   logic signed [COEF_WIDTH + 3:0] dct_column_internal [0:7];
   logic signed [COEF_WIDTH + 3:0] prescale_row        [0:7];
   logic transpose_en, dct2_en, out_t_en, busy_latch;

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

   // Scale results for orthonormal basis
   assign dct_row[0] = prescale_row[0] >>> 3;
   assign dct_row[1] = prescale_row[1] >>> 3;
   assign dct_row[2] = prescale_row[2] >>> 3;
   assign dct_row[3] = prescale_row[3] >>> 3;
   assign dct_row[4] = prescale_row[4] >>> 3;
   assign dct_row[5] = prescale_row[5] >>> 3;
   assign dct_row[6] = prescale_row[6] >>> 3;
   assign dct_row[7] = prescale_row[7] >>> 3;

   // Row DCT
   dct #(
         .COEF_WIDTH(COEF_WIDTH)
        ) dct_1 (
         .row(row),
         .dct_row(dct_row_internal),

         .aclk(aclk),
         .en(en),
         .out_en(transpose_en),
         .aresetn(aresetn),
         .locked(locked)
      );

   // Transpose buffer
   transpose #(
         .COEF_WIDTH(COEF_WIDTH + 2),
         .WITH_STAGING(1)
        ) transpose (
         .row(dct_row_internal),
         .column(column_internal),

         .en(transpose_en),
         .out_en(dct2_en),
         .aclk(aclk),
         .aresetn(aresetn),
         .locked(locked)
      );

   // Column DCT
   dct #(
         .COEF_WIDTH(COEF_WIDTH + 2)
        ) dct_2 (
         .row(column_internal),
         .dct_row(dct_column_internal),

         .aclk(aclk),
         .en(dct2_en),
         .out_en(out_t_en),
         .aresetn(aresetn),
         .locked(locked)
      );

   // Output transpose buffer for transparancy with the Software Implementation.
   transpose #(
         .COEF_WIDTH(COEF_WIDTH + 4),
         .WITH_STAGING(1)
        ) out_transpose (
         .row(dct_column_internal),
         .column(prescale_row),

         .en(out_t_en),
         .out_en(out_en),
         .aclk(aclk),
         .aresetn(aresetn),
         .locked(locked)
      );

endmodule

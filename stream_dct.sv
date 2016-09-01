module stream_dct (
      nasti_stream_channel.slave  in_ch,
      nasti_stream_channel.master out_ch,

      input aclk,
      input aresetn
   );

   localparam COEF_WIDTH = 16;

   // In/Out staging registers.
   logic signed [COEF_WIDTH - 1:0] row_dct_in    [0:7];
   logic signed [COEF_WIDTH + 3:0] row_dct_out   [0:7];
   logic signed [COEF_WIDTH - 1:0] row_dct_out_h [0:7];
   logic dct_en, lock_dct, busy_dct, out_en;

   // This is used to perform signed truncation to avoid array size mismatches.
   assign row_dct_out_h[0] = row_dct_out[0];
   assign row_dct_out_h[1] = row_dct_out[1];
   assign row_dct_out_h[2] = row_dct_out[2];
   assign row_dct_out_h[3] = row_dct_out[3];
   assign row_dct_out_h[4] = row_dct_out[4];
   assign row_dct_out_h[5] = row_dct_out[5];
   assign row_dct_out_h[6] = row_dct_out[6];
   assign row_dct_out_h[7] = row_dct_out[7];

   stream_dct_handler handler(
      .in_ch(in_ch),
      .out_ch(out_ch),

      .row_dct_in(row_dct_in),
      .row_dct_out(row_dct_out_h),
      .dct_en(dct_en),
      .lock_dct(lock_dct),
      .busy_dct(busy_dct),
      .out_en(out_en),

      .aclk(aclk),
      .aresetn(aresetn)
   );

   // DCT Pipeline
   pipelined_dct #(
      .COEF_WIDTH(COEF_WIDTH)
   ) dct_pl(
      .row(row_dct_in),
      .dct_row(row_dct_out),

      .en(dct_en),
      .aclk(aclk),
      .aresetn(aresetn),
      .locked(lock_dct),
      .busy(busy_dct),
      .out_en(out_en)
   );
endmodule

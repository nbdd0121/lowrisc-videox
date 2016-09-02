module stream_idct #(
   parameter COEF_WIDTH = 32
) (
   input  aclk,
   input  aresetn,

   nasti_stream_channel.slave  in_ch,
   nasti_stream_channel.master out_ch
);

   nasti_stream_channel #(
      .DATA_WIDTH(8*COEF_WIDTH)
   )
   to_idct1_ch(), from_idct1_ch(),
   to_idct2_ch(), from_idct2_ch();

   nasti_stream_channel #(
      .DATA_WIDTH(64*COEF_WIDTH)
   )
   to_transpose1_ch(), from_transpose1_ch(),
   to_transpose2_ch(), from_transpose2_ch();

   nasti_stream_widener #(
      .MASTER_DATA_WIDTH(64),
      .SLAVE_DATA_WIDTH(8*COEF_WIDTH)
   ) widener (
      .aclk(aclk),
      .aresetn(aresetn),
      .master(in_ch),
      .slave(to_idct1_ch)
   );

   stream_idct_1d #(
      .COEF_WIDTH(COEF_WIDTH)
   ) idct_st_1 (
      .aclk(aclk),
      .aresetn(aresetn),
      .in_ch(to_idct1_ch),
      .out_ch(from_idct1_ch)
   );

   nasti_stream_widener #(
      .MASTER_DATA_WIDTH(8*COEF_WIDTH),
      .SLAVE_DATA_WIDTH(64*COEF_WIDTH)
   ) widener_t1 (
      .aclk(aclk),
      .aresetn(aresetn),
      .master(from_idct1_ch),
      .slave(to_transpose1_ch)
   );

   stream_transpose #(
      .COEF_WIDTH(COEF_WIDTH)
   ) transpose_stream_1 (
      .aclk(aclk),
      .aresetn(aresetn),
      .in_ch(to_transpose1_ch),
      .out_ch(from_transpose1_ch)
   );

   nasti_stream_narrower #(
      .MASTER_DATA_WIDTH(64*COEF_WIDTH),
      .SLAVE_DATA_WIDTH(8*COEF_WIDTH)
   ) narrower_t1 (
      .aclk(aclk),
      .aresetn(aresetn),
      .master(from_transpose1_ch),
      .slave(to_idct2_ch)
   );

   stream_idct_1d #(
      .COEF_WIDTH(COEF_WIDTH)
   ) idct_st_2 (
      .aclk(aclk),
      .aresetn(aresetn),
      .in_ch(to_idct2_ch),
      .out_ch(from_idct2_ch)
   );

   nasti_stream_widener #(
      .MASTER_DATA_WIDTH(8*COEF_WIDTH),
      .SLAVE_DATA_WIDTH(64*COEF_WIDTH)
   ) widener_t2 (
      .aclk(aclk),
      .aresetn(aresetn),
      .master(from_idct2_ch),
      .slave(to_transpose2_ch)
   );

   stream_transpose #(
      .COEF_WIDTH(COEF_WIDTH)
   ) transpose_stream_2 (
      .aclk(aclk),
      .aresetn(aresetn),
      .in_ch(to_transpose2_ch),
      .out_ch(from_transpose2_ch)
   );

   nasti_stream_narrower #(
      .MASTER_DATA_WIDTH(64*COEF_WIDTH),
      .SLAVE_DATA_WIDTH(64)
   ) narrower_t2 (
      .aclk(aclk),
      .aresetn(aresetn),
      .master(from_transpose2_ch),
      .slave(out_ch)
   );
endmodule

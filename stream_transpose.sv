module stream_transpose # (
   parameter COEF_WIDTH = 16
) (
   input  aclk,
   input  aresetn,

   nasti_stream_channel.slave  in_ch,
   nasti_stream_channel.master out_ch
);

   assign in_ch.t_ready  = out_ch.t_ready;
   assign out_ch.t_valid = in_ch.t_valid;
   assign out_ch.t_keep  = in_ch.t_keep;
   assign out_ch.t_strb  = in_ch.t_strb;
   assign out_ch.t_id    = in_ch.t_id;
   assign out_ch.t_dest  = in_ch.t_dest;
   assign out_ch.t_user  = in_ch.t_user;

   logic [7:0][7:0][COEF_WIDTH-1:0] in_data;
   logic [7:0][7:0][COEF_WIDTH-1:0] out_data;

   assign out_ch.t_data = out_data;
   assign in_data = in_ch.t_data;

   genvar i, j;
   generate
      for (i = 0; i < 8; i++)
         for (j = 0;j < 8; j++)
            assign out_data[i][j] = in_data[j][i];
   endgenerate

endmodule

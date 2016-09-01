module rgb32to16 # (
   DATA_WIDTH = 64,
   DEST_WIDTH = 1,
   USER_WIDTH = 1
) (
   input aclk,
   input aresetn,

   nasti_stream_channel.slave src,
   nasti_stream_channel.master dst
   );

   nasti_stream_channel # (
      .DATA_WIDTH(DATA_WIDTH/2),
      .DEST_WIDTH(DEST_WIDTH)
   ) widener_ch();

   nasti_stream_widener # (
      .DEST_WIDTH(DEST_WIDTH),
      .MASTER_DATA_WIDTH(DATA_WIDTH/2),
      .SLAVE_DATA_WIDTH(DATA_WIDTH)
   ) widener (
      .aclk(aclk),
      .aresetn(aresetn),
      .master(widener_ch),
      .slave(dst)
   );

   assign src.t_ready = widener_ch.t_ready;
   assign widener_ch.t_strb  = '1;
   assign widener_ch.t_keep  = '1;
   assign widener_ch.t_dest  = '0;
   assign widener_ch.t_id    = '0;
   assign widener_ch.t_user  = '0;
   assign widener_ch.t_valid = src.t_valid;
   assign widener_ch.t_last  = src.t_last;
   assign widener_ch.t_data  = {src.t_data[0][55:51], src.t_data[0][47:42], src.t_data[0][39:35], 
                                src.t_data[0][23:19], src.t_data[0][15:10], src.t_data[0][ 7: 3]};

endmodule // rgb32to16
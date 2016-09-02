module transpose_stream # (
      parameter COEF_WIDTH = 32
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


   always_comb begin
      out_ch.t_data[0][8*COEF_WIDTH  - 1:             0] = {in_ch.t_data[0][57*COEF_WIDTH - 1:56*COEF_WIDTH], in_ch.t_data[0][49*COEF_WIDTH - 1:48*COEF_WIDTH], in_ch.t_data[0][41*COEF_WIDTH - 1:40*COEF_WIDTH], in_ch.t_data[0][33*COEF_WIDTH - 1:32*COEF_WIDTH], in_ch.t_data[0][25*COEF_WIDTH - 1:24*COEF_WIDTH], in_ch.t_data[0][17*COEF_WIDTH - 1:16*COEF_WIDTH], in_ch.t_data[0][9 *COEF_WIDTH - 1:8 *COEF_WIDTH], in_ch.t_data[0][  COEF_WIDTH - 1:           0]};
      out_ch.t_data[0][16*COEF_WIDTH - 1:  8*COEF_WIDTH] = {in_ch.t_data[0][58*COEF_WIDTH - 1:57*COEF_WIDTH], in_ch.t_data[0][50*COEF_WIDTH - 1:49*COEF_WIDTH], in_ch.t_data[0][42*COEF_WIDTH - 1:41*COEF_WIDTH], in_ch.t_data[0][34*COEF_WIDTH - 1:33*COEF_WIDTH], in_ch.t_data[0][26*COEF_WIDTH - 1:25*COEF_WIDTH], in_ch.t_data[0][18*COEF_WIDTH - 1:17*COEF_WIDTH], in_ch.t_data[0][10*COEF_WIDTH - 1:9 *COEF_WIDTH], in_ch.t_data[0][2*COEF_WIDTH - 1:  COEF_WIDTH]};
      out_ch.t_data[0][24*COEF_WIDTH - 1: 16*COEF_WIDTH] = {in_ch.t_data[0][59*COEF_WIDTH - 1:58*COEF_WIDTH], in_ch.t_data[0][51*COEF_WIDTH - 1:50*COEF_WIDTH], in_ch.t_data[0][43*COEF_WIDTH - 1:42*COEF_WIDTH], in_ch.t_data[0][35*COEF_WIDTH - 1:34*COEF_WIDTH], in_ch.t_data[0][27*COEF_WIDTH - 1:26*COEF_WIDTH], in_ch.t_data[0][19*COEF_WIDTH - 1:18*COEF_WIDTH], in_ch.t_data[0][11*COEF_WIDTH - 1:10*COEF_WIDTH], in_ch.t_data[0][3*COEF_WIDTH - 1:2*COEF_WIDTH]};
      out_ch.t_data[0][32*COEF_WIDTH - 1: 24*COEF_WIDTH] = {in_ch.t_data[0][60*COEF_WIDTH - 1:59*COEF_WIDTH], in_ch.t_data[0][52*COEF_WIDTH - 1:51*COEF_WIDTH], in_ch.t_data[0][44*COEF_WIDTH - 1:43*COEF_WIDTH], in_ch.t_data[0][36*COEF_WIDTH - 1:35*COEF_WIDTH], in_ch.t_data[0][28*COEF_WIDTH - 1:27*COEF_WIDTH], in_ch.t_data[0][20*COEF_WIDTH - 1:19*COEF_WIDTH], in_ch.t_data[0][12*COEF_WIDTH - 1:11*COEF_WIDTH], in_ch.t_data[0][4*COEF_WIDTH - 1:3*COEF_WIDTH]};
      out_ch.t_data[0][40*COEF_WIDTH - 1: 32*COEF_WIDTH] = {in_ch.t_data[0][61*COEF_WIDTH - 1:60*COEF_WIDTH], in_ch.t_data[0][53*COEF_WIDTH - 1:52*COEF_WIDTH], in_ch.t_data[0][45*COEF_WIDTH - 1:44*COEF_WIDTH], in_ch.t_data[0][37*COEF_WIDTH - 1:36*COEF_WIDTH], in_ch.t_data[0][29*COEF_WIDTH - 1:28*COEF_WIDTH], in_ch.t_data[0][21*COEF_WIDTH - 1:20*COEF_WIDTH], in_ch.t_data[0][13*COEF_WIDTH - 1:12*COEF_WIDTH], in_ch.t_data[0][5*COEF_WIDTH - 1:4*COEF_WIDTH]};
      out_ch.t_data[0][48*COEF_WIDTH - 1: 40*COEF_WIDTH] = {in_ch.t_data[0][62*COEF_WIDTH - 1:61*COEF_WIDTH], in_ch.t_data[0][54*COEF_WIDTH - 1:53*COEF_WIDTH], in_ch.t_data[0][46*COEF_WIDTH - 1:45*COEF_WIDTH], in_ch.t_data[0][38*COEF_WIDTH - 1:37*COEF_WIDTH], in_ch.t_data[0][30*COEF_WIDTH - 1:29*COEF_WIDTH], in_ch.t_data[0][22*COEF_WIDTH - 1:21*COEF_WIDTH], in_ch.t_data[0][14*COEF_WIDTH - 1:13*COEF_WIDTH], in_ch.t_data[0][6*COEF_WIDTH - 1:5*COEF_WIDTH]};
      out_ch.t_data[0][56*COEF_WIDTH - 1: 48*COEF_WIDTH] = {in_ch.t_data[0][63*COEF_WIDTH - 1:62*COEF_WIDTH], in_ch.t_data[0][55*COEF_WIDTH - 1:54*COEF_WIDTH], in_ch.t_data[0][47*COEF_WIDTH - 1:46*COEF_WIDTH], in_ch.t_data[0][39*COEF_WIDTH - 1:38*COEF_WIDTH], in_ch.t_data[0][31*COEF_WIDTH - 1:30*COEF_WIDTH], in_ch.t_data[0][23*COEF_WIDTH - 1:22*COEF_WIDTH], in_ch.t_data[0][15*COEF_WIDTH - 1:14*COEF_WIDTH], in_ch.t_data[0][7*COEF_WIDTH - 1:6*COEF_WIDTH]};
      out_ch.t_data[0][64*COEF_WIDTH - 1: 56*COEF_WIDTH] = {in_ch.t_data[0][64*COEF_WIDTH - 1:63*COEF_WIDTH], in_ch.t_data[0][56*COEF_WIDTH - 1:55*COEF_WIDTH], in_ch.t_data[0][48*COEF_WIDTH - 1:47*COEF_WIDTH], in_ch.t_data[0][40*COEF_WIDTH - 1:39*COEF_WIDTH], in_ch.t_data[0][32*COEF_WIDTH - 1:31*COEF_WIDTH], in_ch.t_data[0][24*COEF_WIDTH - 1:23*COEF_WIDTH], in_ch.t_data[0][16*COEF_WIDTH - 1:15*COEF_WIDTH], in_ch.t_data[0][8*COEF_WIDTH - 1:7*COEF_WIDTH]};
   end
endmodule

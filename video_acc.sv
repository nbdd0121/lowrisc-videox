module video_acc #(
   parameter ADDR_WIDTH = 64,
   parameter DATA_WIDTH = 64
) (
   input  aclk,
   input  aresetn,
   nasti_channel dma,

   // Instruction Cache Acccess
   input  s_nasti_aclk,
   input  s_nasti_aresetn,
   nasti_channel.slave  s_nasti
);

   // Number of different stream processing units
   localparam NR_FUN_UNITS = 5;
   localparam DEST_WIDTH = 3;
   localparam USER_WIDTH = 8;
   localparam BUF_DEPTH = 7;

   // DMA and routed channels
   nasti_stream_channel # (
      .DATA_WIDTH(DATA_WIDTH),
      .DEST_WIDTH(DEST_WIDTH),
      .USER_WIDTH(USER_WIDTH)
   )
   to_dma_ch(), from_dma_ch(),
   to_buf_ch(), from_buf_ch();

   nasti_channel # (
      .ADDR_WIDTH(64),
      .DATA_WIDTH(DATA_WIDTH)
   ) mover_in_ch(), mover_out_ch();

   // Channels for stream processors
   nasti_stream_channel # (
      .DATA_WIDTH(DATA_WIDTH),
      .DEST_WIDTH(DEST_WIDTH),
      .USER_WIDTH(USER_WIDTH)
   )
   to_yuv422to444_ch(), from_yuv422to444_ch(),
   to_yuv444toRGB_ch(), from_yuv444toRGB_ch(),
   to_rgb32to16_ch  (), from_rgb32to16_ch  (),
   to_dct_ch        (), from_dct_ch        (),
   to_idct_ch       (), from_idct_ch       ();

   nasti_stream_channel # (
      .N_PORT(NR_FUN_UNITS + 1),
      .DEST_WIDTH(DEST_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),
      .USER_WIDTH(USER_WIDTH)
   ) in_vein_ch(), out_vein_ch();

   // Nasti-stream Crossbar
   // The "+ 1" accounts for the data movers
   nasti_stream_crossbar # (
      .N_MASTER(NR_FUN_UNITS + 1),
      .N_SLAVE(NR_FUN_UNITS + 1),
      .DEST_WIDTH(DEST_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),
      .USER_WIDTH(USER_WIDTH)
   ) crossbar (
      .aclk(aclk),
      .aresetn(aresetn),
      .master(out_vein_ch),
      .slave(in_vein_ch)
   );

   // Dummy channel connected to unused ports in splicer and combiner
   nasti_stream_channel # (
      .DEST_WIDTH(DEST_WIDTH),
      .DATA_WIDTH(DATA_WIDTH)
   ) dummy_ch();

   nasti_stream_combiner # (
      .N_PORT(NR_FUN_UNITS + 1)
   ) glue (
      .slave(out_vein_ch),
      .master_0(from_buf_ch),
      .master_1(from_yuv422to444_ch),
      .master_2(from_yuv444toRGB_ch),
      .master_3(from_rgb32to16_ch  ),
      .master_4(from_idct_ch       ),
      .master_5(from_dct_ch        ),
      .master_6(dummy_ch           ),
      .master_7(dummy_ch           )
   );

   nasti_stream_slicer # (
      .N_PORT(NR_FUN_UNITS + 1)
   ) unglue (
      .master(in_vein_ch),
      .slave_0(to_buf_ch),
      .slave_1(to_yuv422to444_ch),
      .slave_2(to_yuv444toRGB_ch),
      .slave_3(to_rgb32to16_ch  ),
      .slave_4(to_idct_ch       ),
      .slave_5(to_dct_ch        ),
      .slave_6(dummy_ch         ),
      .slave_7(dummy_ch         )
   );

   nasti_stream_buf # (
      .DEST_WIDTH (DEST_WIDTH),
      .DATA_WIDTH (DATA_WIDTH),
      .USER_WIDTH (USER_WIDTH),
      .BUF_SIZE   (16        )
   )
   input_buf (
      .aclk    (aclk),
      .aresetn (aresetn),
      .src     (from_dma_ch),
      .dest    (from_buf_ch)
   ),
   output_buf (
      .aclk    (aclk),
      .aresetn (aresetn),
      .src     (to_buf_ch),
      .dest    (to_dma_ch)
   );

   nasti_rw_combiner rw_combiner (
      .read  (mover_in_ch),
      .write (mover_out_ch),
      .slave (dma)
   );

   ////////////////////////
   // Source FIFO and DMA
   typedef struct packed unsigned {
      logic [7:0] user;
      logic last;
      logic [20:6] len;
      logic reserved;
      logic [38:6] addr;
      logic [2:0] reserved2;
      logic [2:0] dest;
   } DataMoverCommand;

   initial assert($bits(DataMoverCommand) == 64) else $error("DataMoverCommand is not 64-bit");

   logic [63:0] src_w_data;
   DataMoverCommand src_r_data;
   logic src_r_en, src_w_en;
   logic src_full, src_empty;
   logic [BUF_DEPTH:0] src_buf_len;

   fifo #(
      .WIDTH (64),
      .DEPTH (BUF_DEPTH)
   ) src_fifo (
      .aclk    (aclk),
      .aresetn (aresetn),
      .w_en    (src_w_en),
      .w_data  (src_w_data),
      .r_en    (src_r_en),
      .r_data  (src_r_data),
      .full    (src_full),
      .empty   (src_empty)
   );

   nasti_stream_mover # (
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),
      .DEST_WIDTH(DEST_WIDTH),
      .USER_WIDTH(USER_WIDTH)
   ) dm_data_to_local (
      .aclk    (aclk),
      .aresetn (aresetn),
      .src     (mover_in_ch),
      .dest    (from_dma_ch),
      .r_addr  ({src_r_data.addr, 6'b0}),
      .r_len   ({src_r_data.len , 6'b0}),
      .r_dest  (src_r_data.dest > NR_FUN_UNITS ? 0 : src_r_data.dest),
      .r_user  (src_r_data.user),
      .r_last  (src_r_data.last),
      .r_valid (!src_empty),
      .r_ready (src_r_en)
   );

   always_ff @(posedge aclk or negedge aresetn) begin
      if (!aresetn) begin
         src_buf_len <= 0;
      end else begin
         if ((src_r_en && !src_empty) ^ (src_w_en && !src_full)) begin
            if (src_r_en && !src_empty)
               src_buf_len <= src_buf_len - 1;
            else
               src_buf_len <= src_buf_len + 1;
         end
      end
   end

   /////////////////////////////
   // Destination FIFO and DMA
   logic [63:0] dest_w_data;
   DataMoverCommand dest_r_data;
   logic dest_r_en, dest_w_en;
   logic dest_full, dest_empty;
   logic [BUF_DEPTH:0] dest_buf_len;

   fifo #(
      .WIDTH (64),
      .DEPTH (BUF_DEPTH)
   ) dest_fifo (
      .aclk    (aclk),
      .aresetn (aresetn),
      .w_en    (dest_w_en),
      .w_data  (dest_w_data),
      .r_en    (dest_r_en),
      .r_data  (dest_r_data),
      .full    (dest_full),
      .empty   (dest_empty)
   );

   stream_nasti_mover# (
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH)
   ) dm_data_from_local (
      .aclk    (aclk),
      .aresetn (aresetn),
      .src     (to_dma_ch),
      .dest    (mover_out_ch),
      .w_addr  ({dest_r_data.addr, 6'b0}),
      .w_len   ({dest_r_data.len , 6'b0}),
      .w_valid (!dest_empty),
      .w_ready (dest_r_en)
   );

   always_ff @(posedge aclk or negedge aresetn) begin
      if (!aresetn) begin
         dest_buf_len <= 0;
      end else begin
         if ((dest_r_en && !dest_empty) ^ (dest_w_en && !dest_full)) begin
            if (dest_r_en && !dest_empty)
               dest_buf_len <= dest_buf_len - 1;
            else
               dest_buf_len <= dest_buf_len + 1;
         end
      end
   end

   /////////////////////////
   // Memory-mapped IO R/W
   logic        inst_clk;
   logic        inst_rst;
   logic        inst_en;
   logic [3:0]  inst_we;
   logic [11:0] inst_addr;
   logic [31:0] inst_write;
   logic [31:0] inst_read;

   // AXI-Lite BRAM controller used to populate the instruction FIFO
   nasti_lite_bram_ctrl # (
      .ADDR_WIDTH (64),
      .DATA_WIDTH (32),
      .BRAM_ADDR_WIDTH (12)
   ) inst_ctrl (
      .s_nasti_aclk    (s_nasti_aclk),
      .s_nasti_aresetn (s_nasti_aresetn),
      .s_nasti         (s_nasti),
      .bram_clk        (inst_clk),
      .bram_rst        (inst_rst),
      .bram_en         (inst_en),
      .bram_we         (inst_we),
      .bram_addr       (inst_addr),
      .bram_wrdata     (inst_write),
      .bram_rddata     (inst_read)
   );

   logic src_low_en, dest_low_en;
   logic [31:0] src_low, dest_low;

   always_ff @(posedge inst_clk or posedge inst_rst)
   begin
      if (inst_rst) begin
         src_w_en    <= 0;
         dest_w_en   <= 0;
         src_low_en  <= 0;
         dest_low_en <= 0;
      end else begin
         // Default to low
         src_w_en  <= 0;
         dest_w_en <= 0;

         if (inst_en) begin
            case (inst_addr)
               12'd0:
                  inst_read <= src_buf_len;
               12'd8:
                  inst_read <= dest_buf_len;
               default:
                  inst_read <= 0;
            endcase

            if (&inst_we) begin
               case (inst_addr)
                  12'd0, 12'd4: begin
                     if (src_low_en) begin
                        src_w_data <= {inst_write, src_low};
                        src_w_en   <= 1;
                        src_low_en <= 0;
                     end else begin
                        src_low <= inst_write;
                        src_low_en <= 1;
                     end
                  end
                  12'd8, 12'd12: begin
                     if (dest_low_en) begin
                        dest_w_data <= {inst_write, dest_low};
                        dest_w_en   <= 1;
                        dest_low_en <= 0;
                     end else begin
                        dest_low <= inst_write;
                        dest_low_en <= 1;
                     end
                  end
               endcase
            end
         end
      end
   end

   yuv422to444_noninterp # (
      .DEST_WIDTH(DEST_WIDTH),
      .USER_WIDTH(USER_WIDTH),
      .CHAIN_ID  (2)
   ) yuv422to444 (
      .aclk(aclk),
      .aresetn(aresetn),
      .src(to_yuv422to444_ch),
      .dst(from_yuv422to444_ch)
   );

   yuv444toRGB # (
      .DEST_WIDTH(DEST_WIDTH),
      .USER_WIDTH(USER_WIDTH),
      .CHAIN_ID  (3)
   ) yuv444toRGB (
      .aclk(aclk),
      .aresetn(aresetn),
      .src(to_yuv444toRGB_ch),
      .dst(from_yuv444toRGB_ch)
   );

   rgb32to16 # (
      .DEST_WIDTH(DEST_WIDTH),
      .USER_WIDTH(USER_WIDTH)
   ) rgb32to16 (
      .aclk    (aclk),
      .aresetn (aresetn),
      .src     (to_rgb32to16_ch),
      .dst     (from_rgb32to16_ch)
   );

   stream_dct dct (
      .in_ch(to_dct_ch),
      .out_ch(from_dct_ch),
      .aclk(aclk),
      .aresetn(aresetn)
   );

   stream_idct idct (
      .in_ch(to_idct_ch),
      .out_ch(from_idct_ch),
      .aclk(aclk),
      .aresetn(aresetn)
   );
endmodule

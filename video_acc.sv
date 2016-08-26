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
   localparam NR_FUN_UNITS = 2;
   localparam DEST_WIDTH = 3;

   // Registers used to control the movement of data
   logic r_valid_to_local, r_ready_to_local;
   logic r_valid_from_local, r_ready_from_local;
   logic [DEST_WIDTH-1:0] routing_dest;

   // DMA and routed channels
   nasti_stream_channel # (
      .DATA_WIDTH(DATA_WIDTH),
      .DEST_WIDTH(DEST_WIDTH)
   )
   to_dma_ch(), from_dma_ch(), routed_ch(),
   to_buf_ch(), from_buf_ch();

   nasti_channel # (
      .ADDR_WIDTH(64),
      .DATA_WIDTH(DATA_WIDTH)
   ) mover_in_ch(), mover_out_ch();

   // Channels for stream processors
   nasti_stream_channel # (
      .DATA_WIDTH(DATA_WIDTH),
      .DEST_WIDTH(DEST_WIDTH)
   )
   to_dct_ch(), from_dct_ch(),
   to_idct_ch(), from_idct_ch(),
   to_yuv422to444_ch(), from_yuv422to444_ch(),
   to_yuv444toRGB_ch(), from_yuv444toRGB_ch();

   nasti_stream_channel # (
      .N_PORT(NR_FUN_UNITS + 1),
      .DEST_WIDTH(DEST_WIDTH),
      .DATA_WIDTH(DATA_WIDTH)
   ) in_vein_ch(), out_vein_ch();

   // Channels for DMA command issuing
   nasti_stream_channel # (
      .DATA_WIDTH (64)
   ) src_command_ch(), src_command_buf_ch();

   nasti_stream_channel # (
      .DATA_WIDTH (64)
   ) dest_command_ch(), dest_command_buf_ch();

   // Nasti-stream router
   nasti_stream_router #(
      .DEST_WIDTH(DEST_WIDTH)
   ) router (
      .aclk(aclk),
      .aresetn(aresetn),
      .dest(routing_dest),
      .master(from_buf_ch),
      .slave(routed_ch)
   );

   // Nasti-stream Crossbar
   // The "+ 1" accounts for the data movers
   nasti_stream_crossbar # (
      .N_MASTER(NR_FUN_UNITS + 1),
      .N_SLAVE(NR_FUN_UNITS + 1),
      .DEST_WIDTH(DEST_WIDTH),
      .DATA_WIDTH(DATA_WIDTH)
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
      .master_0(routed_ch),
      .master_1(from_yuv422to444_ch),
      .master_2(from_yuv444toRGB_ch),
      .master_3(dummy_ch),
      .master_4(dummy_ch),
      .master_5(dummy_ch),
      .master_6(dummy_ch),
      .master_7(dummy_ch)
   );

   nasti_stream_slicer # (
      .N_PORT(NR_FUN_UNITS + 1)
   ) unglue (
      .master(in_vein_ch),
      .slave_0(to_buf_ch),
      .slave_1(to_yuv422to444_ch),
      .slave_2(to_yuv444toRGB_ch),
      .slave_3(dummy_ch),
      .slave_4(dummy_ch),
      .slave_5(dummy_ch),
      .slave_6(dummy_ch),
      .slave_7(dummy_ch)
   );

   nasti_stream_buf # (
      .DEST_WIDTH (DEST_WIDTH),
      .DATA_WIDTH (DATA_WIDTH),
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
   logic src_full, src_empty;

   assign src_command_ch.t_keep = '1;
   assign src_command_ch.t_strb = '1;
   assign src_command_ch.t_last = '0;
   assign src_command_ch.t_user = '0;
   assign src_command_ch.t_dest = '0;
   assign src_command_ch.t_id = '0;

   assign src_full = !src_command_ch.t_ready;
   assign src_empty = !src_command_buf_ch.t_valid;

   nasti_stream_buf #(
      .DATA_WIDTH (64),
      .BUF_SIZE   (128)
   ) src_fifo (
      .aclk    (aclk),
      .aresetn (aresetn),
      .src     (src_command_ch),
      .dest    (src_command_buf_ch)
   );

   nasti_stream_mover # (
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH)
   ) dm_data_to_local (
      .aclk(aclk),
      .aresetn(aresetn),
      .src(mover_in_ch),
      .dest(from_dma_ch),
      .command(src_command_buf_ch),
      .r_valid(r_valid_to_local),
      .r_ready(r_ready_to_local)
   );

   /////////////////////////////
   // Destination FIFO and DMA
   logic dest_full, dest_empty;

   assign dest_command_ch.t_keep = '1;
   assign dest_command_ch.t_strb = '1;
   assign dest_command_ch.t_last = '0;
   assign dest_command_ch.t_user = '0;
   assign dest_command_ch.t_dest = '0;
   assign dest_command_ch.t_id = '0;

   assign dest_full = !dest_command_ch.t_ready;
   assign dest_empty = !dest_command_buf_ch.t_valid;

   nasti_stream_buf #(
      .DATA_WIDTH (64),
      .BUF_SIZE   (128)
   ) dest_fifo (
      .aclk    (aclk),
      .aresetn (aresetn),
      .src     (dest_command_ch),
      .dest    (dest_command_buf_ch)
   );

   stream_nasti_mover# (
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH)
   ) dm_data_from_local (
      .aclk(aclk),
      .aresetn(aresetn),
      .src(to_dma_ch),
      .dest(mover_out_ch),
      .command(dest_command_buf_ch),
      .r_valid(r_valid_from_local),
      .r_ready(r_ready_from_local)
   );

   // Instruction FIFO R/W
   logic        inst_clk;
   logic        inst_rst;
   logic        inst_en;
   logic [3:0]  inst_we;
   logic [11:0] inst_addr;
   logic [31:0] inst_write;
   logic [31:0] inst_read;

   // Instruction FIFO
   logic fifo_w_en, fifo_r_en;
   logic [31:0] fifo_w_data, fifo_r_data;
   logic inst_full, inst_empty;

   fifo #(
      .WIDTH(32),
      .DEPTH(7)
   ) inst_fifo (
      .aclk(aclk),
      .aresetn(aresetn),
      .w_en(fifo_w_en),
      .w_data(fifo_w_data),
      .r_en(fifo_r_en),
      .r_data(fifo_r_data),
      .full(inst_full),
      .empty(inst_empty)
   );

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

   // OPCODES
   // Instructions
   localparam  OP_NOP          = 6'h0;
   localparam  OP_MOV          = 6'h8;
   localparam  OP_DCT          = 6'h9;
   localparam  OP_IDCT         = 6'hA;
   localparam  OP_YUV422TO444  = 6'hB;
   localparam  OP_YUV444TORGB  = 6'hC;

   enum {
      STATE_IDLE,
      STATE_START,
      STATE_WAIT
   } state;

   // Variables used to decode instructions
   logic [5: 0] opcode;
   logic [4: 0] attrib;

   // Peak and split the value at the front of the FIFO
   assign opcode =  fifo_r_data[ 5: 0];
   assign attrib =  fifo_r_data[31:27];

   // Comb logic as we want to update the read enable signal within the same cycle
   always_comb begin
      fifo_r_en = 0;
      if (!inst_empty) begin
         case (state)
            STATE_WAIT:
               if (r_ready_from_local && r_ready_to_local)
                  fifo_r_en = 1;
         endcase
      end
   end

   logic src_low_en, dest_low_en;
   logic [31:0] src_low, dest_low;

   always_ff @(posedge aclk or negedge aresetn)
   begin
      if (!aresetn) begin
         src_command_ch.t_valid <= 0;
         dest_command_ch.t_valid <= 0;
         fifo_w_en <= 0;
         src_low_en <= 0;
         dest_low_en <= 0;
      end else begin
         // Default to low
         src_command_ch.t_valid  <= 0;
         dest_command_ch.t_valid  <= 0;
         fifo_w_en <= 0;

         if (inst_en) begin
            case (inst_addr)
               12'd0:
                  // Read how many instructions are left.
                  // Currently we don't count # of instructions remaining
                  // so we use 32 for full, 0 for empty and 1 otherwise
                  inst_read <= inst_full ? 128 : (inst_empty ? 0 : 1);
               12'd8:
                  inst_read <= src_full ? 128 : (src_empty ? 0 : 1);
               12'd16:
                  inst_read <= dest_full ? 128 : (dest_empty ? 0 : 1);
               default:
                  inst_read <= 0;
            endcase

            if (&inst_we) begin
               case (inst_addr)
                  12'd0: begin
                     fifo_w_data <= inst_write;
                     fifo_w_en   <= 1;
                  end
                  12'd8, 12'd12: begin
                     if (src_low_en) begin
                        src_command_ch.t_data <= {inst_write, src_low};
                        src_command_ch.t_valid  <= 1;
                        src_low_en <= 0;
                     end else begin
                        src_low <= inst_write;
                        src_low_en <= 1;
                     end
                  end
                  12'd16, 12'd20: begin
                     if (dest_low_en) begin
                        dest_command_ch.t_data <= {inst_write, dest_low};
                        dest_command_ch.t_valid <= 1;
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

   // Instruction fetch and instruction decode
   always_ff @(posedge aclk or negedge aresetn)
   begin
      if (!aresetn) begin
         state      <= STATE_IDLE;
         r_valid_to_local   <= 'd0;
         r_valid_from_local <= 'd0;
         routing_dest       <= 'd0;
      end
      else begin
         case (state)
            STATE_IDLE: begin
               if (!inst_empty) begin
                  case (opcode)
                     OP_NOP: begin
                        state <= STATE_IDLE;
                        routing_dest  <= 'd0;
                     end
                     OP_MOV: begin
                        $display("Executing MOV");
                        routing_dest  <= 'd0;
                     end
                     OP_YUV422TO444: begin
                        $display("Execute YUV422TO444");
                        routing_dest  <= 'd1;
                     end
                     OP_YUV444TORGB: begin
                        $display("Execute OP_YUV444TORGB",);
                        routing_dest <= 'd2;
                     end
                     default:
                        state <= STATE_IDLE;
                  endcase
                  if (opcode != OP_NOP) begin
                     r_valid_to_local   <= 1;
                     r_valid_from_local <= 1;
                     state      <= STATE_START;
                  end
               end
            end
            STATE_START: begin
               $display("Waiting for both datamovers to start working.");
               if (r_ready_to_local && r_valid_to_local)
                  r_valid_to_local <= 0;
               if (r_ready_from_local && r_valid_from_local)
                  r_valid_from_local <= 0;
               if (!r_valid_to_local && !r_valid_from_local)
                  state <= STATE_WAIT;
            end
            STATE_WAIT: begin
               if (r_ready_from_local && r_ready_to_local) begin
                  $display("Execution of command finished.");
                  state <= STATE_IDLE;
               end
            end
            default: state <= STATE_IDLE;
         endcase
      end
   end

   yuv422to444_noninterp # (
      .DEST_WIDTH(DEST_WIDTH)
   ) yuv422to444 (
      .aclk(aclk),
      .aresetn(aresetn),
      .src(to_yuv422to444_ch),
      .dst(from_yuv422to444_ch)
   );

   yuv444toRGB # (
      .DEST_WIDTH(DEST_WIDTH)
   ) yuv444toRGB (
      .aclk(aclk),
      .aresetn(aresetn),
      .src(to_yuv444toRGB_ch),
      .dst(from_yuv444toRGB_ch)
   );

endmodule

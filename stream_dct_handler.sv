// This module is used to read data from a 64-bit width NASTI-stream and stage
// the data for the 2D-{I}DCT pipeline. It makes sure to chunck the data into
// 8x8 blocks to avoid data pollution, as well as locking and stalling when
// input and/or output is not ready.
module stream_dct_handler
   (
      nasti_stream_channel.slave  in_ch,
      nasti_stream_channel.master out_ch,

      output reg signed [15:0] row_dct_in     [0:7],
      input signed      [15:0] row_dct_out    [0:7],

      output reg dct_en,
      output reg lock_dct,
      input      busy_dct,
      input      out_en,

      input  aclk,
      input  aresetn
   );

   // Stalling variables.
   logic lock_stream;
   // Control variables used to start the task and determine when the task is finished.
   logic have_seen_last;
   logic [2:0] count_to_8;
   logic [3:0] out_count_to_16;
   logic busy_dct_delay;
   // Misc. variables used to stage input/output.
   logic high, high_latch, out_high, seen_first_valid;

   assign out_ch.t_dest = 'd0;
   assign out_ch.t_strb = out_ch.t_keep;

   always_comb begin
      // Default states
      lock_stream   = 'd0;
      lock_dct      = 'd0;
      high          = high_latch;

      // Check with priority to output if we need to stall.
      if (out_en && !out_ch.t_ready && out_ch.t_valid) begin
         $display("Stalling due to output channel!");
         lock_dct    = 'd1;
         lock_stream = 'd1;
      end else begin
         // Check if we need to do the initial pipeline lock for the load of the first row.
         if (in_ch.t_valid && (&in_ch.t_keep) && in_ch.t_ready && !busy_dct)
            lock_dct = !high;

         // Check if we need to stall due to input not being ready yet.
         if ((!in_ch.t_valid || !(&in_ch.t_keep)) && in_ch.t_ready && !(count_to_8 == 0)) begin
            $display("Stalling due to input channel!");
            lock_dct    = 'd1;
            lock_stream = 'd1;
         end

         // Alternate locking and unlocking the pipeline to load the rows.
         if (!have_seen_last)
            lock_dct = lock_stream || high;

         // Alternate the row half we are loading
         if (in_ch.t_valid && (&in_ch.t_keep) && in_ch.t_ready)
            high = !high;

         // Alternate locking and unlocking the pipeline to have time to output the columns.
         if (busy_dct_delay && !lock_stream && out_en)
            lock_dct = !out_ch.t_ready || out_high;
      end
   end

   always_ff @(posedge aclk or negedge aresetn) begin
      if (!aresetn) begin
         high_latch          <= 'd0;
         out_high            <= 'd1;
         out_ch.t_valid      <= 'd0;
         out_ch.t_last       <= 'd0;
         out_ch.t_keep       <= 'd0;
         in_ch.t_ready       <= 'd0;
         seen_first_valid    <= 'd0;
         have_seen_last      <= 'd0;
         busy_dct_delay      <= 'd0;
         dct_en              <= 'd0;
         count_to_8          <= 3'b0;
         out_count_to_16     <= 4'b0;
      end else begin
         // Debug/Simulation prints for data validation.
         if (dct_en && !lock_dct)
         $display("Loading row with values: %d, %d, %d, %d, %d, %d, %d, %d",
            row_dct_in[0],row_dct_in[1],row_dct_in[2],row_dct_in[3],
            row_dct_in[4],row_dct_in[5],row_dct_in[6],row_dct_in[7]
         );
         if (busy_dct_delay && out_en && !lock_dct)
         $display("Sending row with values: %d, %d, %d, %d, %d, %d, %d, %d",
            row_dct_out[0],row_dct_out[1],row_dct_out[2],row_dct_out[3],
            row_dct_out[4],row_dct_out[5],row_dct_out[6],row_dct_out[7]
         );

         // Handle the input ready signal.
         // We are not ready only when we are processing an 8x8 block.
         // We latch ready high if we lock the stream due to input.
         if (in_ch.t_valid && (&in_ch.t_keep) && !seen_first_valid && !out_en && !busy_dct) begin
            in_ch.t_ready    <= 'd1;
            seen_first_valid <= 'd1;
         end else if (seen_first_valid)
               in_ch.t_ready  <= !(count_to_8 == 0) || !busy_dct_delay;
            else
               in_ch.t_ready <= 'd0;

         // Update latches.
         high_latch     <= high;

         // Delayed signals for corner cases, such as end of data.
         busy_dct_delay <= busy_dct;

         // Logic to maintain the pipeline enabled for an 8x8 block input.
         dct_en <= 'd0;
         if (dct_en && (count_to_8 > 0)) dct_en <= 'd1;
         if (dct_en && lock_stream)      dct_en <= 'd1;
         if (in_ch.t_valid && (&in_ch.t_keep) && in_ch.t_ready && !high)
            dct_en <= 'd1;

         // Row loading logic, 4 integers at a time (16-bit int assumption).
         if (in_ch.t_valid && (&in_ch.t_keep) && in_ch.t_ready) begin
            if (high) begin
               row_dct_in[0] <= in_ch.t_data[0][15: 0];
               row_dct_in[1] <= in_ch.t_data[0][31:16];
               row_dct_in[2] <= in_ch.t_data[0][47:32];
               row_dct_in[3] <= in_ch.t_data[0][63:48];
            end else begin
               row_dct_in[4] <= in_ch.t_data[0][15: 0];
               row_dct_in[5] <= in_ch.t_data[0][31:16];
               row_dct_in[6] <= in_ch.t_data[0][47:32];
               row_dct_in[7] <= in_ch.t_data[0][63:48];
               count_to_8 <= count_to_8 + 1;
            end
         end

         // Handeling the end of the input stream
         if (in_ch.t_last && in_ch.t_valid) begin
            have_seen_last   <= 'd1;
            high_latch       <= 'd0;
            count_to_8       <= 'd0;
            seen_first_valid <= 'd0;
            in_ch.t_ready    <= 'd0;
         end

         // Spliting input stream into 8x8 blocks
         if ((count_to_8 == 0) && dct_en) begin
            high_latch       <= 'd0;
            count_to_8       <= 'd0;
            seen_first_valid <= 'd0;
            in_ch.t_ready    <= 'd0;
         end

         // Output logic. We set valid, keep and strobe only when not locked.
         if (busy_dct_delay && out_en && !lock_stream) begin
            out_ch.t_valid <= 'd1;
            out_ch.t_keep  <= 8'hff;
         end else out_ch.t_valid <= out_en;

         // The handeling of the last data chunck.
         // Including delaying until last is acked.
         if (out_ch.t_valid && (lock_stream || out_ch.t_last))
            out_ch.t_valid <= 'd1;

         if (out_ch.t_last && out_ch.t_valid) out_ch.t_last <= 'd1;
         if (out_count_to_16 == 'hF) out_ch.t_last <= 'd1;

         // We need to react promptly to the ready on the last and reset the state.
         if (out_ch.t_valid && out_ch.t_last && out_ch.t_ready) begin
            $display("Reseting the stream processor's internal state.");
            out_high          <= 'd1;
            have_seen_last    <= 'd0;
            out_ch.t_keep     <= 'd0;
            out_ch.t_valid    <= 'd0;
            out_ch.t_last     <= 'd0;
            count_to_8        <= 'd0;
            seen_first_valid  <= 'd0;
         end
         // End of last packet handle

         // Row output logic
         if (busy_dct_delay && out_en && !lock_stream) begin
            out_high <= !out_high;
         end

         if (busy_dct_delay && out_en && !lock_stream) begin
            if (out_high) begin
               out_ch.t_data[0][15: 0] <= row_dct_out[0];
               out_ch.t_data[0][31:16] <= row_dct_out[1];
               out_ch.t_data[0][47:32] <= row_dct_out[2];
               out_ch.t_data[0][63:48] <= row_dct_out[3];
            end else begin
               out_ch.t_data[0][15: 0] <= row_dct_out[4];
               out_ch.t_data[0][31:16] <= row_dct_out[5];
               out_ch.t_data[0][47:32] <= row_dct_out[6];
               out_ch.t_data[0][63:48] <= row_dct_out[7];
            end

            out_count_to_16 <= out_count_to_16 + 1;
         end
         // End of output logic
      end
   end
endmodule

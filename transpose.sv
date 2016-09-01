module transpose #(
      parameter COEF_WIDTH = 32,
      parameter WITH_STAGING = 0
   )
   (
      input signed      [COEF_WIDTH - 1:0] row    [0:7],
      output reg signed [COEF_WIDTH - 1:0] column [0:7],

      input  en,
      output reg out_en,
      input  aclk,
      input  aresetn,
      input  locked
   );

   logic signed [COEF_WIDTH - 1:0] buffer [0:7] [0:7];
   logic signed [COEF_WIDTH - 1:0] staging [0:7];
   logic [2:0] position;
   logic out_en_internal;

   // Control logic for the transpose buffer
   always_ff @(posedge aclk or negedge aresetn) begin
      if (!aresetn) begin
         out_en_internal   <= 'd0;
         out_en            <= 'd0;
         position          <= 3'b0;
      end else
         if (!locked) begin
            staging <= row;
            out_en <= out_en_internal;
            if (!out_en_internal && en) begin
               buffer[0][position] <= WITH_STAGING == 1 ? staging[0] : row[0];
               buffer[1][position] <= WITH_STAGING == 1 ? staging[1] : row[1];
               buffer[2][position] <= WITH_STAGING == 1 ? staging[2] : row[2];
               buffer[3][position] <= WITH_STAGING == 1 ? staging[3] : row[3];
               buffer[4][position] <= WITH_STAGING == 1 ? staging[4] : row[4];
               buffer[5][position] <= WITH_STAGING == 1 ? staging[5] : row[5];
               buffer[6][position] <= WITH_STAGING == 1 ? staging[6] : row[6];
               buffer[7][position] <= WITH_STAGING == 1 ? staging[7] : row[7];
               position            <= position + 1;
            end else column <= buffer[position];

            if (out_en_internal)
               if (position < 7) begin
                   position <= position + 1;
               end else begin
                  position         <= 3'b0;
                  out_en_internal  <= 'd0;
               end
            else if (en) begin
               if (position == 7) begin
                  out_en_internal  <= en;
               end
            end
      end
   end
endmodule

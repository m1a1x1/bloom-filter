module data_delay_pipeline_ready #(
  parameter DATA_W = 32
)(
  input               clk_i,
  input               srst_i,

  input  [DATA_W-1:0] data_i,
  input               valid_i,
  output              ready_o,

  output [DATA_W-1:0] data_o,
  output              valid_o,
  input               ready_i
);

logic [1:0]             valid_d1;
logic [1:0][DATA_W-1:0] data_d1;
logic                   ready_d1;

logic                   valid_d2;
logic [DATA_W-1:0]      data_d2;

logic                   wr_ptr;
logic                   rd_ptr;

assign ready_o = !(valid_d1[wr_ptr]);

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      rd_ptr <= 1'b0;
    else
      begin
        if( ready_d1 && valid_d1[rd_ptr] )
          rd_ptr <= !rd_ptr;
      end
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      wr_ptr <= 1'b0;
    else
      begin
        if( ready_o && valid_i )
          wr_ptr <= !wr_ptr;
      end
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      valid_d1 <= '0;
    else
      begin
        if( rd_ptr != wr_ptr )
          begin
            if( valid_d1[rd_ptr] && ready_d1 )
              valid_d1[rd_ptr] <= 1'b0;

            if( ready_o )
              valid_d1[wr_ptr] <= valid_i;
          end
       else
         begin
           if( valid_d1[wr_ptr] )
             begin
               if( valid_d1[wr_ptr] && ready_d1 )
                  valid_d1[wr_ptr] <= 1'b0;
             end
           else
             begin
               if( ready_o )
                 valid_d1[wr_ptr] <= valid_i;
             end
         end
      end
  end

always_ff @( posedge clk_i )
  begin
    if( ready_o )
      data_d1[wr_ptr] <= data_i;
  end

assign ready_d1 = ready_i || !(valid_d2);

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      valid_d2 <= 1'b0;
    else
      begin
        if( ready_d1 )
          valid_d2 <= valid_d1[rd_ptr];
      end
  end

always_ff @( posedge clk_i )
  begin
    if( ready_d1 )
      data_d2 <= data_d1[rd_ptr];
  end

assign data_o  = data_d2;
assign valid_o = valid_d2;

endmodule

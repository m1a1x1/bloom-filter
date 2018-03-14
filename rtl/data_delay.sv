module data_delay #(
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

logic              valid_d;
logic [DATA_W-1:0] data_d;

assign ready_o = ready_i || !(valid_d);

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      valid_d <= 1'b0;
    else
      begin
        if( ready_o )
          valid_d <= valid_i;
      end
  end

always_ff @( posedge clk_i )
  begin
    if( ready_o )
      data_d <= data_i;
  end

assign data_o  = data_d;
assign valid_o = valid_d;

endmodule

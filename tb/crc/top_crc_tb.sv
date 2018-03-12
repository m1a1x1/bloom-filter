module top_crc_tb;

import crc_pkg::*;

parameter int BYTE_W   = 8;
parameter int STR_SIZE = 6;
parameter int WIDTH    = 13;
parameter int INIT     = CRC_INITS[0];

logic [STR_SIZE-1:0][BYTE_W-1:0]  data = '{8'd6,8'd5,8'd4,8'd3,8'd2,8'd1};
logic [WIDTH-1:0]                 res;


crc #(
  .BYTE_W   ( BYTE_W   ),
  .WIDTH    ( WIDTH    ),
  .INIT     ( INIT     ),
  .STR_SIZE ( STR_SIZE )
) DUT (
  .data_i ( data  ),
  .res_o  ( res   )
);

initial
  begin
    #20;
    $display(res);
    $stop();
  end

endmodule

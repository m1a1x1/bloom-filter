import crc_pkg::*;

module crc #(
  parameter int BYTE_W   = 8,
  parameter int WIDTH    = 12,
  parameter int INIT     = 1,
  parameter int STR_SIZE = 20
)(
  input  [STR_SIZE-1:0][BYTE_W-1:0] data_i,
  output [WIDTH-1:0]                res_o
);

logic [WIDTH-1:0] res;

initial
  begin
    if( INIT >= 2**WIDTH )
      begin
        $error("Wrong CRC init value. See ./rtl/crc_pkg.sv for more details");
        $stop();
      end
  end

always_comb
  begin
    res = WIDTH'(INIT);
    for( int i = 0; i < STR_SIZE; i++ )
      begin
        res = crc_8d95( data_i[i], res );
      end
  end

assign res_o = res;

endmodule

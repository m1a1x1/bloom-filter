import crc_pkg::*;

module hasher #(
  parameter int BYTE_W     = 8,
  parameter int STR_SIZE   = 6,
  parameter int HASHES_CNT = 12,
  parameter int HASH_W     = 13
)(
  input                               clk_i,
  input                               srst_i,

  input  [STR_SIZE-1:0][BYTE_W-1:0]   data_i,
  input                               valid_i,
  output                              ready_o,

  output [HASHES_CNT-1:0][HASH_W-1:0] hashes_o,
  output [STR_SIZE-1:0][BYTE_W-1:0]   data_o,
  output                              hashes_data_valid_o,
  input                               hashes_data_ready_i
);

logic [HASHES_CNT-1:0][HASH_W-1:0] hashes;
logic [HASHES_CNT-1:0][HASH_W-1:0] hashes_w;
logic [STR_SIZE-1:0][BYTE_W-1:0]   data_in;
logic [STR_SIZE-1:0][BYTE_W-1:0]   data_out;
logic                              valid_in;
logic                              valid_out;
logic                              hashes_data_ready;

initial
  begin
    if( HASHES_W > MAX_HASH_W )
      begin
        $error("Maximum supported hash width is %d", MAX_HASH_W );
        $stop();
      end
    if( HASHES_CNT > CRC_INITS.size() )
      begin
        $error("Maximum supported hashes per string is %d. For more inforamtion see ./rtl/crc_pkg.sv", CRC_INITS.size() );
        $stop();
      end
  end

data_delay #(
  .DATA_W    ( STR_SIZE*BYTE_W        )
) d_in (
  .clk_i     ( clk_i                  ),
  .srst_i    ( srst_i                 ),

  .data_i    ( data_i                 ),
  .valid_i   ( valid_i                ),
  .ready_o   ( ready_o                ),

  .data_o    ( data_in                ),
  .valid_o   ( valid_in               ),
  .ready_i   ( hashes_data_ready      )
);

generate
  for( genvar n = 0; n < HASHES_CNT; n++ )
    begin: hash_f
      crc #(
        .BYTE_W   ( BYTE_W          ),
        .WIDTH    ( HASH_W          ),
        .INIT     ( CRC_INITS[n]    ),
        .STR_SIZE ( STR_SIZE        )
      ) crc (
        .data_i   ( data_in         ),
        .res_o    ( hashes_w[n]     )
      );
    end
endgenerate

data_delay #(
  .DATA_W    ( STR_SIZE*BYTE_W        )
) d_out (
  .clk_i     ( clk_i                  ),
  .srst_i    ( srst_i                 ),

  .data_i    ( data_in                ),
  .valid_i   ( valid_in               ),
  .ready_o   ( hashes_data_ready      ),

  .data_o    ( data_o                 ),
  .valid_o   ( hashes_data_valid_o    ),
  .ready_i   ( hashes_data_ready_i    )
);

assign hashes_o            = hashes;
assign hashes_data_valid_o = valid_out;

endmodule

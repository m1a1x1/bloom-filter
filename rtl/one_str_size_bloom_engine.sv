module one_str_size_bloom_engine #(
  parameter int BYTE_W      = 8,
  parameter int STR_SIZE    = 3,
  parameter int MATCH_CNT_W = 32,
  parameter int HASHES_CNT  = 6,
  parameter int HASH_W      = 12
)(
  input                                 clk_i,
  input                                 srst_i,

  output [MATCH_CNT_W-1:0]              matches_cnt_o,
  input                                 matches_cnt_clean_stb_i,
                            
  input  [STR_SIZE-1:0][BYTE_W-1:0]     data_i,
  input                                 valid_i,
  output                                ready_o,

  output [HASHES_CNT-1:0][HASH_W-1:0]   amm_masters_lut_address_o,
  input  [HASHES_CNT-1:0]               amm_masters_lut_readdata_i,

  output [STR_SIZE-1:0][BYTE_W-1:0]     suspect_string_data_o,
  output                                suspect_string_valid_o,
  input                                 suspect_string_ready_i
);

logic [HASHES_CNT-1:0][HASH_W-1:0] hashes;
logic [STR_SIZE-1:0][BYTE_W-1:0]   data;
logic                              hashes_data_valid;
logic                              hashes_data_ready;

logic [STR_SIZE-1:0][BYTE_W-1:0]   data_d;
logic                              hashes_data_valid_d;
logic                              hashes_data_ready_d;

logic                              amm_masters_lut_readdata_valid;

logic                              suspect_string_ready;
logic                              suspect_string_valid;
logic [STR_SIZE-1:0][BYTE_W-1:0]   suspect_string_data;
logic [HASHES_CNT-1:0]             suspect_string_result_saved;
logic [HASHES_CNT-1:0]             suspect_string_result;

hasher #(
  .BYTE_W               ( BYTE_W            ),
  .STR_SIZE             ( STR_SIZE          ),
  .HASHES_CNT           ( HASHES_CNT        ),
  .HASH_W               ( HASH_W            )
) hs (
  .clk_i                ( clk_i             ),
  .srst_i               ( srst_i            ),
  .data_i               ( data_i            ),
  .valid_i              ( valid_i           ),
  .ready_o              ( ready_o           ),

  .hashes_o             ( hashes            ),
  .data_o               ( data              ),
  .hashes_data_valid_o  ( hashes_data_valid ),
  .hashes_data_ready_i  ( hashes_data_ready )
);

assign amm_masters_lut_address_o = hashes;

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      amm_masters_lut_readdata_valid <= 1'b0;
    else
      amm_masters_lut_readdata_valid <= ( hashes_data_valid ) && 
                                        ( hashes_data_ready );
  end

// Delay 1
data_delay #(
  .DATA_W    ( STR_SIZE*BYTE_W        )
) d1 (
  .clk_i     ( clk_i                  ),
  .srst_i    ( srst_i                 ),

  .data_i    ( data                   ),
  .valid_i   ( hashes_data_valid      ),
  .ready_o   ( hashes_data_ready      ),

  .data_o    ( data_d                 ),
  .valid_o   ( hashes_data_valid_d    ),
  .ready_i   ( hashes_data_ready_d    )
);

// Delay 2
data_delay #(
  .DATA_W    ( STR_SIZE*BYTE_W        )
) d2 (
  .clk_i     ( clk_i                  ),
  .srst_i    ( srst_i                 ),

  .data_i    ( data_d                 ),
  .valid_i   ( hashes_data_valid_d    ),
  .ready_o   ( hashes_data_ready_d    ),

  .data_o    ( suspect_string_data_o  ),
  .valid_o   ( suspect_string_valid   ),
  .ready_i   ( suspect_string_ready_i )
);

// Result from Hash LUT register
always_ff @( posedge clk_i )
  begin
    if( amm_masters_lut_readdata_valid )
      begin
        if( !hashes_data_ready_d )
          suspect_string_result_saved <= amm_masters_lut_readdata_i;
      end
  end

always_ff @( posedge clk_i )
  begin
    if( hashes_data_ready_d && hashes_data_valid_d )
      begin
        if( amm_masters_lut_readdata_valid )
          suspect_string_result <= amm_masters_lut_readdata_i;
        else
          suspect_string_result <= suspect_string_result_saved;
      end
  end

assign suspect_string_valid_o = ( suspect_string_valid   ) &&
                                ( &suspect_string_result );

endmodule

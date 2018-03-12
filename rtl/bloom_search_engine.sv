module bloom_search_engine #(
  parameter int BYTE_W         = 8,
  parameter int AMM_LUT_DATA_W = 32,
  parameter int AMM_LUT_ADDR_W = 32,
  parameter int MATCH_CNT_W    = 32,
  parameter int MAX_STR_SIZE   = 20,
  parameter int MIN_STR_SIZE   = 3,
  parameter int HASHES_CNT     = 6,
  parameter int HASH_W         = 12,
  parameter int MAX_STR_SIZE_W =$clog2(MAX_STR_SIZE_W)+1
)(
  input                                                            clk_i,
  input                                                            srst_i,

  output [MAX_STR_SIZE:MIN_STR_SIZE][MATCH_CNT_W-1:0]              matches_cnt_o,
  input  [MAX_STR_SIZE:MIN_STR_SIZE]                               matches_cnt_clean_stb_i,
                            
  input  [MAX_STR_SIZE-1:0][BYTE_W-1:0]                            window_data_i,
  input  [MAX_STR_SIZE_W-1:0]                                      window_valid_bytes_i,
  output                                                           window_ready_o,
                            
  input  [AMM_LUT_ADDR_W-1:0]                                      amm_slave_lut_address_i,
  input                                                            amm_slave_lut_write_i,
  input  [AMM_LUT_DATA_W-1:0]                                      amm_slave_lut_writedata_i,
                            
  output [MAX_STR_SIZE:MIN_STR_SIZE][MAX_STR_SIZE-1:0][BYTE_W-1:0] suspect_strings_data_o,
  output [MAX_STR_SIZE:MIN_STR_SIZE]                               suspect_strings_valid_o,
  input [MAX_STR_SIZE:MIN_STR_SIZE]                                suspect_strings_ready_i
);

logic [MAX_STR_SIZE:MIN_STR_SIZE]                                  window_ready_per_engine;
logic [MAX_STR_SIZE:MIN_STR_SIZE][HASHES_CNT-1:0][HASH_W-1:0]      amm_masters_lut_address;
logic [MAX_STR_SIZE:MIN_STR_SIZE][HASHES_CNT-1:0]                  amm_masters_lut_readdata;

assign window_ready_o = &( window_ready_per_engine );

hash_lut #(

)(

);

generate
  for( genvar n = MIN_STR_SIZE; n <= MAX_STR_SIZE; n++ )
    begin: one_size_engine
      logic  window_valid;

      assign window_valid = ( window_valid_bytes_i == MAX_STR_SIZE_W'(n) );

      one_str_size_bloom_engine #(
        .BYTE_W                     ( BYTE_W                           ),
        .STR_SIZE                   ( n                                ),
        .MATCH_CNT_W                ( MATCH_CNT_W                      ),
        .HASHES_CNT                 ( HASHES_CNT                       ),
        .HASH_W                     ( HASH_W                           )
      ) ose (
        .clk_i                      ( clk_i                            ),
        .srst_i                     ( srst_i                           ),

        .matches_cnt_o              ( matches_cnt_o[n]                 ),
        .matches_cnt_clean_stb_i    ( matches_cnt_clean_stb_i[n]       ),

        .data_i                     ( window_data_i[n-1:0]             ),
        .valid_i                    ( window_valid                     ),
        .ready_o                    ( window_ready_per_engine[n]       ),

        .amm_masters_lut_address_o  ( amm_masters_lut_address[n]       ), 
        .amm_masters_lut_readdata_i ( amm_masters_lut_readdata[n]      ),

        .suspect_string_data_o      ( suspect_strings_data_o[n][n-1:0] ),
        .suspect_string_valid_o     ( suspect_strings_valid_o[n]       ),
        .suspect_string_ready_i     ( suspect_strings_ready_i          )
      );
    end 
endgenerate


endmodule

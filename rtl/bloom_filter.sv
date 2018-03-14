import bloom_filter_pkg::*;

module bloom_filter #(
//// Changable only in bloom_filter_pkg.sv parameters: ////
// Avalon ST sink paramters:
//   Avalon ST symbols per beat.
//   Must more or eq 1.
  parameter int AST_SINK_SYMBOLS   = AST_SINK_SYMBOLS,
//// Changable with instance parameters: ////
//   Avalon ST symbols order.
//   0 -- for first symbols in low order
//   1 -- for first symbols in hight order
  parameter bit AST_SINK_ORDER     = 1'b1,
// Avalon ST source paramters:
//   Avalon ST symbols per beat.
//   Must more or eq 1.
  parameter int AST_SOURCE_SYMBOLS = 8,
//   0 -- for first symbols in low order
//   1 -- for first symbols in hight order
  parameter bit AST_SOURCE_ORDER   = 1'b1,

//// Derived parameters: ////
// Avalon ST sink paramters:
  parameter int AST_SINK_EMPTY_W   = ( AST_SINK_SYMBOLS  == 1   ) ?
                                     ( 1                        ) :
                                     ( $clog2(AST_SINK_SYMBOLS) ),
// Avalon ST source paramters:
  parameter int AST_SOURCE_EMPTY_W = ( AST_SOURCE_SYMBOLS  == 1   ) ?
                                     ( 1                          ) :
                                     ( $clog2(AST_SOURCE_SYMBOLS) )

//// Both sink and source Avalon ST properties: ////
//  beatsPerCycle                       = 1 (not used)
//  dataBitsPerSymbol                   = BYTE_W
//  emptyWithinPacket                   = false
//  errorDescriptor                     = 0
//  maxChannel                          = 0
//  readyLatency                        = 0

//// Avalon ST sink properties: ////
//  associatedClock                     = main_clk_i
//  associatedReset                     = main_srst_i
//  astSinkFirstSymbolInHighOrderBits   = AST_SINK_ORDER
//  astSinkSymbolsPerBeat               = AST_SINK_SYMBOLS

//// Avalon ST source properties: ////
//  associatedClock                     = ast_source_clk_i
//  associatedReset                     = ast_source_srst_i
//  astSourceFirstSymbolInHighOrderBits = AST_SOURCE_ORDER
//  astSourceSymbolsPerBeat             = AST_SOURCE_SYMBOLS

//// Both Avalon MM slave properties: ////
//  holdTime                            = 0
//  maximumPendingWriteTransactions     = 1
//  setupTime                           = 0
//  timingUnits                         = cycles
//  waitrequestAllowance                = 0
//  associatedClock                     = main_clk_i
//  associatedReset                     = main_srst_i

//// Avalon MM CSR slave properties: ////
//  addressUnits                        = words
//  readLatency                         = 1
//  maximumPendingReadTransactions      = 1
//  ammCsrDataWidth                     = AMM_CSR_DATA_W
//  ammCsrAddrWidth                     = AMM_CSR_ADDR_W

//// Avalon MM hash lut slave properties: ////
//  addressUnits                        = symbols
//  ammLutDataWidth                     = AMM_LUT_DATA_W
//  ammLutAddrWidth                     = AMM_LUT_ADDR_W
)(
  //// Clock interfaces: ////
  // Clock for Avalon ST sink, both Avalon MM and main logic:
  input                                        main_clk_i,
  // Clock for Avalon ST source:
  input                                        ast_source_clk_i,

  //// Reset interfaces: ////
  // Synchronous reset, active hight, for Avalon ST sink, both Avalon MM and
  // main logic:
  input                                        main_srst_i,
  // Synchronous reset, active hight, for Avalon ST source:
  input                                        ast_source_srst_i,

  //// Avalon ST sink -- intreface for getting for searching: ////
  input   [AST_SINK_SYMBOLS-1:0][BYTE_W-1:0]   ast_sink_data_i,
  output                                       ast_sink_ready_o,
  input                                        ast_sink_valid_i,
  input   [AST_SINK_EMPTY_W-1:0]               ast_sink_empty_i,
  input                                        ast_sink_endofpacket_i,
  input                                        ast_sink_startofpacket_i,

  //// Avalon MM CSR slave -- intreface for common configurations: ////
  input   [AMM_CSR_ADDR_W-1:0]                 amm_slave_csr_address_i,
  input                                        amm_slave_csr_read_i,
  output  [AMM_CSR_DATA_W-1:0]                 amm_slave_csr_readdata_o,
  input                                        amm_slave_csr_write_i,
  input   [AMM_CSR_DATA_W-1:0]                 amm_slave_csr_writedata_i,

  //// Avalon MM hash lookup table slave -- intreface for filling up ////
  //// Bloom Filter hash table. Write only.                          ////
  input   [AMM_LUT_ADDR_W-1:0]                 amm_slave_lut_address_i,
  input                                        amm_slave_lut_write_i,
  input   [AMM_LUT_DATA_W-1:0]                 amm_slave_lut_writedata_i,

  //// Avalon ST source -- intreface for string, that could contain patterns: ////
  output  [AST_SOURCE_SYMBOLS-1:0][BYTE_W-1:0] ast_source_data_o,
  input                                        ast_source_ready_i,
  output                                       ast_source_valid_o,
  output  [AST_SOURCE_EMPTY_W-1:0]             ast_source_empty_o,
  output                                       ast_source_endofpacket_o,
  output                                       ast_source_startofpacket_o
);

localparam int MAX_STR_SIZE_W = $clog2(MAX_STR_SIZE) + 1;

logic                                                                                 search_en;

logic [AST_SINK_SYMBOLS-1:0][MAX_STR_SIZE-1:0][BYTE_W-1:0]                            windows_data;
logic [AST_SINK_SYMBOLS-1:0][MAX_STR_SIZE_W-1:0]                                      windows_valid_bytes;
logic [AST_SINK_SYMBOLS-1:0][MAX_STR_SIZE_W-1:0]                                      windows_valid_bytes_masked;
logic [AST_SINK_SYMBOLS-1:0]                                                          windows_ready_per_engine;
logic                                                                                 windows_ready;

logic [AST_SINK_SYMBOLS-1:0][MAX_STR_SIZE:MIN_STR_SIZE][MAX_STR_SIZE-1:0][BYTE_W-1:0] suspect_strings_data;
logic [AST_SINK_SYMBOLS-1:0][MAX_STR_SIZE:MIN_STR_SIZE]                               suspect_strings_valid;
logic [AST_SINK_SYMBOLS-1:0][MAX_STR_SIZE:MIN_STR_SIZE]                               suspect_strings_ready;

logic [AST_SINK_SYMBOLS-1:0][MAX_STR_SIZE:MIN_STR_SIZE][AMM_CSR_DATA_W-1:0]           matches_per_engine_cnt;
logic [AST_SINK_SYMBOLS-1:0][MAX_STR_SIZE:MIN_STR_SIZE]                               matches_per_engine_cnt_clean_stb;

logic                                                                                 hash_lut_clean_stb;
logic                                                                                 hash_lut_clean_done;

logic [AMM_LUT_ADDR_W-1:0]                                                            amm_slave_lut_address;
logic                                                                                 amm_slave_lut_write;
logic [AMM_LUT_DATA_W-1:0]                                                            amm_slave_lut_writedata;

bloom_filter_csr #(
  .AMM_CSR_ADDR_W              ( AMM_CSR_ADDR_W                   ),
  .AMM_CSR_DATA_W              ( AMM_CSR_DATA_W                   ),
  .MATCH_CNT_CNT               ( MATCH_CNT_CNT                    )
) csr (
  .clk_i                       ( main_clk_i                       ),
  .srst_i                      ( main_srst_i                      ),

  .amm_slave_csr_address_i     ( amm_slave_csr_address_i          ),
  .amm_slave_csr_read_i        ( amm_slave_csr_read_i             ),
  .amm_slave_csr_readdata_o    ( amm_slave_csr_readdata_o         ),
  .amm_slave_csr_write_i       ( amm_slave_csr_write_i            ),
  .amm_slave_csr_writedata_i   ( amm_slave_csr_writedata_i        ),

  .en_o                        ( search_en                        ),
  .matches_cnt_i               ( matches_per_engine_cnt           ),
  .matches_cnt_clean_stb_o     ( matches_per_engine_cnt_clean_stb ),
  .hash_lut_clean_stb_o        ( hash_lut_clean_stb               ),
  .hash_lut_clean_done_i       ( hash_lut_clean_done              )
);

ast_shift #(
  .BYTE_W                      ( BYTE_W                     ),
  .AST_SINK_SYMBOLS            ( AST_SINK_SYMBOLS           ),
  .AST_SINK_ORDER              ( AST_SINK_ORDER             ),
  .WINDOW_SIZE                 ( MAX_STR_SIZE               )
) as (
  .clk_i                       ( main_clk_i                 ),
  .srst_i                      ( main_srst_i                ),

  .en_i                        ( search_en                  ),

  .ast_sink_data_i             ( ast_sink_data_i            ),
  .ast_sink_ready_o            ( ast_sink_ready_o           ),
  .ast_sink_valid_i            ( ast_sink_valid_i           ),
  .ast_sink_empty_i            ( ast_sink_empty_i           ),
  .ast_sink_endofpacket_i      ( ast_sink_endofpacket_i     ),
  .ast_sink_startofpacket_i    ( ast_sink_startofpacket_i   ),

  .windows_data_o              ( windows_data               ),
  .windows_valid_bytes_o       ( windows_valid_bytes        ),
  .windows_ready_i             ( windows_ready              )
);

assign windows_ready = &(windows_ready_per_engine);
assign windows_valid_bytes_masked = ( windows_ready       ) ? 
                                    ( windows_valid_bytes ) :
                                    ( '0                  );

amm_writer #(
  .AMM_DATA_W             ( AMM_LUT_DATA_W                      ),
  .AMM_ADDR_W             ( AMM_LUT_ADDR_W                      ),
  .DATA                   ( '1                                  )
) hash_lut_cleaner (
  .clk_i                  ( main_clk_i                          ),
  .srst_i                 ( main_srst_i                         ), 

  .run_stb_i              ( hash_lut_clean_stb                  ), 
  .done_o                 ( hash_lut_clean_done                 ), 

  .amm_slave_address_i    ( amm_slave_lut_address_i             ),
  .amm_slave_write_i      ( amm_slave_lut_write_i               ),
  .amm_slave_writedata_i  ( amm_slave_lut_writedata_i           ),

  .amm_master_address_o   ( amm_slave_lut_address               ),
  .amm_master_write_o     ( amm_slave_lut_write                 ),
  .amm_master_writedata_o ( amm_slave_lut_writedata             )
);

generate
  genvar n;
  for( n = 0; n < AST_SINK_SYMBOLS; n++ )
    begin: bloom_engine_gen
      bloom_search_engine #(
        .BYTE_W                       ( BYTE_W                              ),
        .AMM_LUT_DATA_W               ( AMM_LUT_DATA_W                      ),
        .AMM_LUT_ADDR_W               ( AMM_LUT_ADDR_W                      ),
        .MATCH_CNT_W                  ( AMM_CSR_DATA_W                      ),
        .MAX_STR_SIZE                 ( MAX_STR_SIZE                        ),
        .HASHES_CNT                   ( HASHES_CNT                          ),
        .HASH_W                       ( HASH_W                              ),
        .MIN_STR_SIZE                 ( MIN_STR_SIZE                        ),
        .HASH_LUT_MODE                ( HASH_LUT_MODE                       )
      ) bse (
        .clk_i                        ( main_clk_i                          ),
        .srst_i                       ( main_srst_i                         ),

        .en_i                         ( search_en                           ),

        .matches_cnt_o                ( matches_per_engine_cnt[n]           ),
        .matches_cnt_clean_stb_i      ( matches_per_engine_cnt_clean_stb[n] ),
        
        .window_data_i                ( windows_data[n]                     ),
        .window_valid_bytes_i         ( windows_valid_bytes_masked[n]       ),
        .window_ready_o               ( windows_ready_per_engine[n]         ),

        .amm_slave_lut_address_i      ( amm_slave_lut_address               ),
        .amm_slave_lut_write_i        ( amm_slave_lut_write                 ),
        .amm_slave_lut_writedata_i    ( amm_slave_lut_writedata             ),

        .suspect_strings_data_o       ( suspect_strings_data[n]             ),
        .suspect_strings_valid_o      ( suspect_strings_valid[n]            ),
        .suspect_strings_ready_i      ( suspect_strings_ready[n]            )
      );
    end
endgenerate

strings_mux #(
  .BYTE_W                                 ( BYTE_W                     ),
  .WINDOW_CNT                             ( AST_SINK_SYMBOLS           ),
  .MIN_STR_SIZE                           ( MIN_STR_SIZE               ),
  .MAX_STR_SIZE                           ( MAX_STR_SIZE               ),
  .FIFO_DEPTH                             ( PER_STRING_FIFO_DEPTH      ),
  .AST_SOURCE_SYMBOLS                     ( AST_SOURCE_SYMBOLS         ),
  .AST_SOURCE_ORDER                       ( AST_SOURCE_ORDER           )
) mux (
  .sink_clk_i                             ( main_clk_i                 ),
  .sink_srst_i                            ( main_srst_i                ),

  .source_clk_i                           ( ast_source_clk_i           ),
  .source_srst_i                          ( ast_source_srst_i          ),

  .strings_data_i                         ( suspect_strings_data       ),
  .strings_valid_i                        ( suspect_strings_valid      ),
  .strings_ready_o                        ( suspect_strings_ready      ),

  .ast_source_data_o                      ( ast_source_data_o          ),
  .ast_source_ready_i                     ( ast_source_ready_i         ),
  .ast_source_valid_o                     ( ast_source_valid_o         ),
  .ast_source_empty_o                     ( ast_source_empty_o         ),
  .ast_source_endofpacket_o               ( ast_source_endofpacket_o   ),
  .ast_source_startofpacket_o             ( ast_source_startofpacket_o )
);

endmodule

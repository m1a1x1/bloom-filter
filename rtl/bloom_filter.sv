import bloom_filter_pkg::*;

module bloom_filter #(
//// Changable with instance parameters: ////
// Avalon ST sink paramters:
//   Avalon ST symbols per beat.
//   Must more or eq 1.
  parameter int AST_SINK_SYMBOLS   = 8,
//   Avalon ST symbols order.
//   0 -- for first symbols in low order
//   1 -- for first symbols in hight order
  parameter bit AST_SINK_ORDER     = 1,
// Avalon ST source paramters:
//   Avalon ST symbols per beat.
//   Must more or eq 1.
  parameter int AST_SOURCE_SYMBOLS = 8,
//   0 -- for first symbols in low order
//   1 -- for first symbols in hight order
  parameter bit AST_SOURCE_ORDER   = 1,

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
//  addressUnits                        = symbols
//  holdTime                            = 0
//  maximumPendingWriteTransactions     = 1
//  setupTime                           = 0
//  timingUnits                         = cycles
//  waitrequestAllowance                = 0
//  associatedClock                     = main_clk_i
//  associatedReset                     = main_srst_i

//// Avalon MM CSR slave properties: ////
//  readLatency                         = 1
//  maximumPendingReadTransactions      = 1
//  ammCsrDataWidth                     = AMM_CSR_DATA_W
//  ammCsrAddrWidth                     = AMM_CSR_ADDR_W

//// Avalon MM hash lut slave properties: ////
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

localparam int MAX_STR_SIZE_W = ( MAX_STR_SIZE == 1    ) ?
                                ( 1                    ) :
                                ( $clog2(MAX_STR_SIZE) );

logic                                                      search_en_i;

logic [AST_SINK_SYMBOLS-1:0][MAX_STR_SIZE-1:0][BYTE_W-1:0] windows_data;
logic [AST_SINK_SYMBOLS-1:0][MAX_STR_SIZ_W-1:0]            windows_data_valid_bytes;
logic                                                      windows_data_ready;


ast_shift #(
  .AST_SINK_SYMBOLS            ( AST_SINK_SYMBOLS           ),
  .WINDOW_SIZE                 ( MAX_STR_SIZE               )
) ast_deser_and_slice (
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
  .windows_data_valid_bytes_o  ( windows_data_valid_bytes   ),
  .windows_data_ready_i        ( windows_data_ready         )
);

endmodule

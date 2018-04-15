parameter int AST_SINK_SYMBOLS = 8;
parameter bit AST_SINK_ORDER   = 1;

parameter int AST_SOURCE_SYMBOLS = 1;
parameter bit AST_SOURCE_ORDER   = 1;

parameter int AMM_LUT_DATA_W    = 8;
parameter int AMM_LUT_ADDR_W    = 32;

parameter int MIN_STR_SIZE      = 4;
parameter int MAX_STR_SIZE      = 16;

parameter int HASHES_CNT        = 6;
parameter int HASH_W            = 13;
parameter int HASH_LUT_MODE     = 1;



parameter int OUTPUT_FIFO_DEPTH = 128;
parameter int AMM_CSR_DATA_W    = 16;
parameter int AMM_CSR_ADDR_W    = 12;

parameter int AST_SINK_EMPTY_W = ( AST_SINK_SYMBOLS  == 1   ) ?
                                 ( 1                        ) :
                                 ( $clog2(AST_SINK_SYMBOLS) );

parameter int AST_SOURCE_EMPTY_W = ( AST_SOURCE_SYMBOLS == 1    ) ?
                                   ( 1                          ) :
                                   ( $clog2(AST_SOURCE_SYMBOLS) );
											  
parameter int BYTE_W = 8;

module top(
  input                                        clk_156_25_i,

  input                                        srst_156_25_i,
  input                                        srst_125_i,

  input   [AST_SINK_SYMBOLS-1:0][BYTE_W-1:0]   ast_sink_data_i,
  output                                       ast_sink_ready_o,
  input                                        ast_sink_valid_i,
  input   [AST_SINK_EMPTY_W-1:0]               ast_sink_empty_i,
  input                                        ast_sink_endofpacket_i,
  input                                        ast_sink_startofpacket_i,

  input   [AMM_CSR_ADDR_W-1:0]                 amm_slave_csr_address_i,
  input                                        amm_slave_csr_read_i,
  output  [AMM_CSR_DATA_W-1:0]                 amm_slave_csr_readdata_o,
  input                                        amm_slave_csr_write_i,
  input   [AMM_CSR_DATA_W-1:0]                 amm_slave_csr_writedata_i,

  input   [AMM_LUT_ADDR_W-1:0]                 amm_slave_lut_address_i,
  input                                        amm_slave_lut_write_i,
  input   [AMM_LUT_DATA_W-1:0]                 amm_slave_lut_writedata_i,

  output  [AST_SOURCE_SYMBOLS-1:0][BYTE_W-1:0] ast_source_data_o,
  input                                        ast_source_ready_i,
  output                                       ast_source_valid_o,
  output  [AST_SOURCE_EMPTY_W-1:0]             ast_source_empty_o,
  output                                       ast_source_endofpacket_o,
  output                                       ast_source_startofpacket_o
);

logic                                      clk_125_i;

logic                                      srst_125;
logic                                      srst_156_25;

logic                                      ast_sink_ready;
logic [AST_SINK_SYMBOLS-1:0][BYTE_W-1:0]   ast_sink_data;
logic                                      ast_sink_valid;
logic [AST_SINK_EMPTY_W-1:0]               ast_sink_empty;
logic                                      ast_sink_endofpacket;
logic                                      ast_sink_startofpacket;

logic [AMM_CSR_ADDR_W-1:0]                 amm_slave_csr_address;
logic                                      amm_slave_csr_read;
logic [AMM_CSR_DATA_W-1:0]                 amm_slave_csr_readdata;
logic                                      amm_slave_csr_write;
logic [AMM_CSR_DATA_W-1:0]                 amm_slave_csr_writedata;

logic [AMM_LUT_ADDR_W-1:0]                 amm_slave_lut_address;
logic                                      amm_slave_lut_write;
logic [AMM_LUT_DATA_W-1:0]                 amm_slave_lut_writedata;

logic [AST_SOURCE_SYMBOLS-1:0][BYTE_W-1:0] ast_source_data;
logic                                      ast_source_ready;
logic                                      ast_source_valid;
logic [AST_SOURCE_EMPTY_W-1:0]             ast_source_empty;
logic                                      ast_source_endofpacket;
logic                                      ast_source_startofpacket;

pll pll_156_25_in_125(
  .refclk                                 ( clk_156_25_i      ),
  .rst                                    ( srst_156_25_i     ),
  .outclk_0                               ( clk_125_i         )
);

always_ff @( posedge clk_156_25_i )
  begin
    srst_156_25                <= srst_156_25_i;

    ast_sink_data              <= ast_sink_data_i;
    ast_sink_valid             <= ast_sink_valid_i;
    ast_sink_empty             <= ast_sink_empty_i;
    ast_sink_endofpacket       <= ast_sink_endofpacket_i;
    ast_sink_startofpacket     <= ast_sink_startofpacket_i;

    amm_slave_csr_address      <= amm_slave_csr_address_i;
    amm_slave_csr_read         <= amm_slave_csr_read_i;
    amm_slave_csr_write        <= amm_slave_csr_write_i;
    amm_slave_csr_writedata    <= amm_slave_csr_writedata_i;

    amm_slave_lut_address      <= amm_slave_lut_address_i;
    amm_slave_lut_write        <= amm_slave_lut_write_i;
    amm_slave_lut_writedata    <= amm_slave_lut_writedata_i;

    amm_slave_csr_readdata_o   <= amm_slave_csr_readdata;
    ast_sink_ready_o           <= ast_sink_ready;

   /*
    srst_125                   <= srst_125_i;

    ast_source_data_o          <= ast_source_data;
    ast_source_valid_o         <= ast_source_valid;
    ast_source_empty_o         <= ast_source_empty;
    ast_source_endofpacket_o   <= ast_source_endofpacket;
    ast_source_startofpacket_o <= ast_source_startofpacket;

    ast_source_ready           <= ast_source_ready_i;
    */
  end

always_ff @( posedge clk_125_i )
  begin
    srst_125                   <= srst_125_i;

    ast_source_data_o          <= ast_source_data;
    ast_source_valid_o         <= ast_source_valid;
    ast_source_empty_o         <= ast_source_empty;
    ast_source_endofpacket_o   <= ast_source_endofpacket;
    ast_source_startofpacket_o <= ast_source_startofpacket;

    ast_source_ready           <= ast_source_ready_i;
  end

bloom_filter #(
  .AST_SINK_SYMBOLS           ( AST_SINK_SYMBOLS          ),
  .AST_SINK_ORDER             ( AST_SINK_ORDER            ), 
  .AST_SOURCE_SYMBOLS         ( AST_SOURCE_SYMBOLS        ),
  .AST_SOURCE_ORDER           ( AST_SOURCE_ORDER          ),

  .MIN_STR_SIZE               ( MIN_STR_SIZE              ),
  .MAX_STR_SIZE               ( MAX_STR_SIZE              ),
  .AMM_LUT_ADDR_W             ( AMM_LUT_ADDR_W            ),
  .AMM_LUT_DATA_W             ( AMM_LUT_DATA_W            ),
  .HASHES_CNT                 ( HASHES_CNT                ),
  .HASH_W                     ( HASH_W                    ),
  .HASH_LUT_MODE              ( HASH_LUT_MODE             ),

  .AMM_CSR_DATA_W             ( AMM_CSR_DATA_W            ),
  .AMM_CSR_ADDR_W             ( AMM_CSR_ADDR_W            ),
  .OUTPUT_FIFO_DEPTH          ( OUTPUT_FIFO_DEPTH         )
) dut (
  .main_clk_i                 ( clk_156_25_i              ),
  .ast_source_clk_i           ( clk_125_i                 ),

  .main_srst_i                ( srst_156_25               ),
  .ast_source_srst_i          ( srst_125                  ),

  .ast_sink_data_i            ( ast_sink_data             ),
  .ast_sink_ready_o           ( ast_sink_ready            ),
  .ast_sink_valid_i           ( ast_sink_valid            ),
  .ast_sink_empty_i           ( ast_sink_empty            ),
  .ast_sink_endofpacket_i     ( ast_sink_endofpacket      ),
  .ast_sink_startofpacket_i   ( ast_sink_startofpacket    ),

  .amm_slave_csr_address_i    ( amm_slave_csr_address     ),
  .amm_slave_csr_read_i       ( amm_slave_csr_read        ),
  .amm_slave_csr_readdata_o   ( amm_slave_csr_readdata    ),
  .amm_slave_csr_write_i      ( amm_slave_csr_write       ),
  .amm_slave_csr_writedata_i  ( amm_slave_csr_writedata   ),

  .amm_slave_lut_address_i    ( amm_slave_lut_address     ),
  .amm_slave_lut_write_i      ( amm_slave_lut_write       ),
  .amm_slave_lut_writedata_i  ( amm_slave_lut_writedata   ),

  .ast_source_data_o          ( ast_source_data           ),
  .ast_source_ready_i         ( ast_source_ready          ),
  .ast_source_valid_o         ( ast_source_valid          ),
  .ast_source_empty_o         ( ast_source_empty          ),
  .ast_source_endofpacket_o   ( ast_source_endofpacket    ),
  .ast_source_startofpacket_o ( ast_source_startofpacket  )
);

endmodule

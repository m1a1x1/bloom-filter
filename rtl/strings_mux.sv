module strings_mux #(
  parameter int BYTE_W             = 8,
  parameter int WINDOW_CNT         = 8,
  parameter int MIN_STR_SIZE       = 6,
  parameter int MAX_STR_SIZE       = 20,
  parameter int FIFO_DEPTH         = 5, 
  parameter int AST_SOURCE_SYMBOLS = 1,
  parameter bit AST_SOURCE_ORDER   = 1'b1,
  parameter int AST_SOURCE_EMPTY_W = ( AST_SOURCE_SYMBOLS  == 1   ) ?
                                     ( 1                          ) :
                                     ( $clog2(AST_SOURCE_SYMBOLS) )
)(
  input                                                                            sink_clk_i,
  input                                                                            sink_srst_i,

  input                                                                            source_clk_i,
  input                                                                            source_srst_i,

  input  [WINDOW_CNT-1:0][MAX_STR_SIZE:MIN_STR_SIZE][MAX_STR_SIZE-1:0][BYTE_W-1:0] strings_data_i,
  input  [WINDOW_CNT-1:0][MAX_STR_SIZE:MIN_STR_SIZE]                               strings_valid_i,
  output [WINDOW_CNT-1:0][MAX_STR_SIZE:MIN_STR_SIZE]                               strings_ready_o,

  output  [AST_SOURCE_SYMBOLS-1:0][BYTE_W-1:0]                                     ast_source_data_o,
  input                                                                            ast_source_ready_i,
  output                                                                           ast_source_valid_o,
  output  [AST_SOURCE_EMPTY_W-1:0]                                                 ast_source_empty_o,
  output                                                                           ast_source_endofpacket_o,
  output                                                                           ast_source_startofpacket_o
);

localparam STR_SIZES_CNT = MAX_STR_SIZE - MIN_STR_SIZE + 1;

logic  [WINDOW_CNT-1:0][MAX_STR_SIZE:MIN_STR_SIZE][AST_SOURCE_SYMBOLS-1:0][BYTE_W-1:0] ast_source_data;
logic  [WINDOW_CNT-1:0][MAX_STR_SIZE:MIN_STR_SIZE]                                     ast_source_ready;
logic  [WINDOW_CNT-1:0][MAX_STR_SIZE:MIN_STR_SIZE]                                     ast_source_valid;
logic  [WINDOW_CNT-1:0][MAX_STR_SIZE:MIN_STR_SIZE][AST_SOURCE_EMPTY_W-1:0]             ast_source_empty;
logic  [WINDOW_CNT-1:0][MAX_STR_SIZE:MIN_STR_SIZE]                                     ast_source_endofpacket;
logic  [WINDOW_CNT-1:0][MAX_STR_SIZE:MIN_STR_SIZE]                                     ast_source_startofpacket;

logic  [(WINDOW_CNT*STR_SIZES_CNT)-1:0][AST_SOURCE_SYMBOLS-1:0][BYTE_W-1:0]            flat_ast_source_data;
logic  [(WINDOW_CNT*STR_SIZES_CNT)-1:0]                                                flat_ast_source_ready;
logic  [(WINDOW_CNT*STR_SIZES_CNT)-1:0]                                                flat_ast_source_valid;
logic  [(WINDOW_CNT*STR_SIZES_CNT)-1:0][AST_SOURCE_EMPTY_W-1:0]                        flat_ast_source_empty;
logic  [(WINDOW_CNT*STR_SIZES_CNT)-1:0]                                                flat_ast_source_endofpacket;
logic  [(WINDOW_CNT*STR_SIZES_CNT)-1:0]                                                flat_ast_source_startofpacket;

initial
  begin
    if( MAX_STR_SIZE > 32 )
      begin
        $error( "MAX_STR_SIZE must be less, then 32" );
        $stop();
      end
  end

generate
  genvar w;
  for( w = 0; w < WINDOW_CNT; w++ )
    begin: per_window
      genvar n;
      for( n = MIN_STR_SIZE; n <= MAX_STR_SIZE; n++ )
        begin: per_data_len
          logic                     data_fifo_wr_full;
          logic                     data_fifo_rd_empty;
          logic [n-1:0][BYTE_W-1:0] data;
          logic                     data_valid;
          logic                     data_to_ast_done;

          data_dc_fifo #(
            .DATA_W        ( n*BYTE_W                                       ),
            .DEPTH         ( FIFO_DEPTH                                     )
          ) dc_fifo (
            .data          ( strings_data_i[w][n][n-1:0]                    ),
            .rdclk         ( source_clk_i                                   ),
            .rdreq         ( data_to_ast_done                               ),
            .wrclk         ( sink_clk_i                                     ),
            .wrreq         ( strings_valid_i[w][n] && strings_ready_o[w][n] ),
            .q             ( data                                           ),
            .rdempty       ( data_fifo_rd_empty                             ),
            .wrfull        ( data_fifo_wr_full                              )
          );

          assign data_valid            = !data_fifo_rd_empty;
          assign strings_ready_o[w][n] = !data_fifo_wr_full;

          data_to_ast #(
            .BYTE_W                     ( BYTE_W                         ),
            .DATA_SYMBOLS               ( n                              ),
            .AST_SOURCE_ORDER           ( AST_SOURCE_ORDER               ),
            .AST_SOURCE_SYMBOLS         ( AST_SOURCE_SYMBOLS             )
          ) dta (
            .clk_i                      ( source_clk_i                   ),
            .srst_i                     ( source_srst_i                  ),

            .data_i                     ( data                           ),
            .data_valid_i               ( data_valid                     ),
            .done_o                     ( data_to_ast_done               ),

            .ast_source_data_o          ( ast_source_data[w][n]          ),
            .ast_source_ready_i         ( ast_source_ready[w][n]         ),
            .ast_source_valid_o         ( ast_source_valid[w][n]         ),
            .ast_source_empty_o         ( ast_source_empty[w][n]         ),
            .ast_source_endofpacket_o   ( ast_source_endofpacket[w][n]   ),
            .ast_source_startofpacket_o ( ast_source_startofpacket[w][n] )
          );
        end
    end
endgenerate

assign flat_ast_source_data          = ast_source_data;
assign flat_ast_source_valid         = ast_source_valid;
assign flat_ast_source_empty         = ast_source_empty;
assign flat_ast_source_endofpacket   = ast_source_endofpacket;
assign flat_ast_source_startofpacket = ast_source_startofpacket;
assign ast_source_ready              = flat_ast_source_ready;

one_hot_ast_mux #(
  .BYTE_W                                 ( BYTE_W                        ),
  .IN_DIRS_CNT                            ( (WINDOW_CNT*STR_SIZES_CNT)    ),
  .AST_SYMBOLS                            ( AST_SOURCE_SYMBOLS            )
) oh_mux (
  .clk_i                                  ( source_clk_i                  ),
  .srst_i                                 ( source_srst_i                 ),

  .ast_sink_data_i                        ( flat_ast_source_data          ),
  .ast_sink_ready_o                       ( flat_ast_source_ready         ),
  .ast_sink_valid_i                       ( flat_ast_source_valid         ),
  .ast_sink_empty_i                       ( flat_ast_source_empty         ),
  .ast_sink_endofpacket_i                 ( flat_ast_source_endofpacket   ),
  .ast_sink_startofpacket_i               ( flat_ast_source_startofpacket ),

  .ast_source_data_o                      ( ast_source_data_o             ),
  .ast_source_ready_i                     ( ast_source_ready_i            ),
  .ast_source_valid_o                     ( ast_source_valid_o            ),
  .ast_source_empty_o                     ( ast_source_empty_o            ),
  .ast_source_endofpacket_o               ( ast_source_endofpacket_o      ),
  .ast_source_startofpacket_o             ( ast_source_startofpacket_o    )
);

endmodule

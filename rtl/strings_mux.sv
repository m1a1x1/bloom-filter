module strings_mux #(
  parameter int BYTE_W             = 8,
  parameter int WINDOW_CNT         = 8,
  parameter int MIN_STR_SIZE       = 6,
  parameter int MAX_STR_SIZE       = 20,
  parameter int OUTPUT_FIFO_DEPTH  = 128,
  parameter int AST_SOURCE_SYMBOLS = 1,
  parameter bit AST_SOURCE_ORDER   = 1'b1,
  parameter int AST_SOURCE_EMPTY_W = ( AST_SOURCE_SYMBOLS  == 1   ) ?
                                     ( 1                          ) :
                                     ( $clog2(AST_SOURCE_SYMBOLS) )
)(
  input                                                                            main_clk_i,
  input                                                                            main_srst_i, 

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

logic  [MAX_STR_SIZE:MIN_STR_SIZE][WINDOW_CNT-1:0][AST_SOURCE_SYMBOLS-1:0][BYTE_W-1:0] ast_source_data;
logic  [MAX_STR_SIZE:MIN_STR_SIZE][WINDOW_CNT-1:0]                                     ast_source_ready;
logic  [MAX_STR_SIZE:MIN_STR_SIZE][WINDOW_CNT-1:0]                                     ast_source_valid;
logic  [MAX_STR_SIZE:MIN_STR_SIZE][WINDOW_CNT-1:0][AST_SOURCE_EMPTY_W-1:0]             ast_source_empty;
logic  [MAX_STR_SIZE:MIN_STR_SIZE][WINDOW_CNT-1:0]                                     ast_source_endofpacket;
logic  [MAX_STR_SIZE:MIN_STR_SIZE][WINDOW_CNT-1:0]                                     ast_source_startofpacket;

logic [WINDOW_CNT-1:0][MAX_STR_SIZE:MIN_STR_SIZE][MAX_STR_SIZE-1:0][BYTE_W-1:0]        strings_data_d;
logic [WINDOW_CNT-1:0][MAX_STR_SIZE:MIN_STR_SIZE]                                      strings_valid_d;
logic [WINDOW_CNT-1:0][MAX_STR_SIZE:MIN_STR_SIZE]                                      strings_ready_d;


logic  [MAX_STR_SIZE:MIN_STR_SIZE][AST_SOURCE_SYMBOLS-1:0][BYTE_W-1:0]                 ast_source_sizes_muxed_data;
logic  [MAX_STR_SIZE:MIN_STR_SIZE]                                                     ast_source_sizes_muxed_ready;
logic  [MAX_STR_SIZE:MIN_STR_SIZE]                                                     ast_source_sizes_muxed_valid;
logic  [MAX_STR_SIZE:MIN_STR_SIZE][AST_SOURCE_EMPTY_W-1:0]                             ast_source_sizes_muxed_empty;
logic  [MAX_STR_SIZE:MIN_STR_SIZE]                                                     ast_source_sizes_muxed_endofpacket;
logic  [MAX_STR_SIZE:MIN_STR_SIZE]                                                     ast_source_sizes_muxed_startofpacket;

generate
  genvar n;
  for( n = MIN_STR_SIZE; n <= MAX_STR_SIZE; n++ )
    begin: per_sizes
      logic                                        out_fifo_full;
      logic                                        out_fifo_empty;
      logic  [AST_SOURCE_SYMBOLS-1:0][BYTE_W-1:0]  ast_source_tmp_data;
      logic                                        ast_source_tmp_ready;
      logic                                        ast_source_tmp_valid;
      logic  [AST_SOURCE_EMPTY_W-1:0]              ast_source_tmp_empty;
      logic                                        ast_source_tmp_endofpacket;
      logic                                        ast_source_tmp_startofpacket;
      genvar   w;

      for( w = 0; w < WINDOW_CNT; w++ )
        begin: per_data_len
          logic [n-1:0][BYTE_W-1:0]        strings_data_d;
          logic                            strings_valid_d;
          logic                            strings_ready_d;
          
          always_comb
            begin
              strings_data_d  = strings_data_i[w][n][n-1:0];
              strings_valid_d = strings_valid_i[w][n];
              strings_ready_o[w][n] = strings_ready_d;
            end
/*
          data_delay_pipeline_ready #(
            .DATA_W                     ( n*BYTE_W                    )
          ) d_in (
            .clk_i                      ( main_clk_i                  ),
            .srst_i                     ( main_srst_i                 ),

            .data_i                     ( strings_data_i[w][n][n-1:0] ),
            .valid_i                    ( strings_valid_i[w][n]       ),
            .ready_o                    ( strings_ready_o[w][n]       ),

            .data_o                     ( strings_data_d              ),
            .valid_o                    ( strings_valid_d             ),
            .ready_i                    ( strings_ready_d             )
          );
*/
          data_to_ast #(
            .BYTE_W                     ( BYTE_W                         ),
            .DATA_SYMBOLS               ( n                              ),
            .AST_SOURCE_ORDER           ( AST_SOURCE_ORDER               ),
            .AST_SOURCE_SYMBOLS         ( AST_SOURCE_SYMBOLS             )
          ) dta (
            .clk_i                      ( main_clk_i                     ),
            .srst_i                     ( main_srst_i                    ),

            .data_i                     ( strings_data_d                 ),
            .data_valid_i               ( strings_valid_d                ),
            .ready_o                    ( strings_ready_d                ),

            .ast_source_data_o          ( ast_source_data[n][w]          ),
            .ast_source_ready_i         ( ast_source_ready[n][w]         ),
            .ast_source_valid_o         ( ast_source_valid[n][w]         ),
            .ast_source_empty_o         ( ast_source_empty[n][w]         ),
            .ast_source_endofpacket_o   ( ast_source_endofpacket[n][w]   ),
            .ast_source_startofpacket_o ( ast_source_startofpacket[n][w] )
          );
        end

      one_hot_ast_mux #(
        .BYTE_W                                 ( BYTE_W                         ),
        .IN_DIRS_CNT                            ( WINDOW_CNT                     ),
        .AST_SYMBOLS                            ( AST_SOURCE_SYMBOLS             )
      ) sizes_mux (
        .clk_i                                  ( main_clk_i                     ),
        .srst_i                                 ( main_srst_i                    ),

        .ast_sink_data_i                        ( ast_source_data[n]             ),
        .ast_sink_ready_o                       ( ast_source_ready[n]            ),
        .ast_sink_valid_i                       ( ast_source_valid[n]            ),
        .ast_sink_empty_i                       ( ast_source_empty[n]            ),
        .ast_sink_endofpacket_i                 ( ast_source_endofpacket[n]      ),
        .ast_sink_startofpacket_i               ( ast_source_startofpacket[n]    ),

        .ast_source_data_o                      ( ast_source_tmp_data            ),
        .ast_source_ready_i                     ( ast_source_tmp_ready           ),
        .ast_source_valid_o                     ( ast_source_tmp_valid           ),
        .ast_source_empty_o                     ( ast_source_tmp_empty           ),
        .ast_source_endofpacket_o               ( ast_source_tmp_endofpacket     ),
        .ast_source_startofpacket_o             ( ast_source_tmp_startofpacket   )
      );

      /*
      always_comb 
        begin
          ast_source_tmp_ready = ast_source_sizes_muxed_ready[n];

          ast_source_sizes_muxed_data[n]          = ast_source_tmp_data;
          ast_source_sizes_muxed_valid[n]         = ast_source_tmp_valid;        
          ast_source_sizes_muxed_empty[n]         = ast_source_tmp_empty;        
          ast_source_sizes_muxed_endofpacket[n]   = ast_source_tmp_endofpacket;  
          ast_source_sizes_muxed_startofpacket[n] = ast_source_tmp_startofpacket;
        end
      */
      assign ast_source_tmp_ready            = !out_fifo_full;
      assign ast_source_sizes_muxed_valid[n] = !out_fifo_empty;

      data_dc_fifo #(
        .DATA_W  ( AST_SOURCE_SYMBOLS*BYTE_W + 1 + 1 + AST_SOURCE_EMPTY_W             ),
        .DEPTH   ( OUTPUT_FIFO_DEPTH                                                  )
      ) out_fifo (
        .wrclk   ( main_clk_i                                                         ),
        .wrreq   ( ast_source_tmp_valid && ast_source_tmp_ready                       ),
        .data    ( {ast_source_tmp_data, ast_source_tmp_endofpacket, ast_source_tmp_startofpacket, ast_source_tmp_empty} ),
        .wrfull  ( out_fifo_full                                                      ),
        .rdclk   ( source_clk_i                                                       ),
        .rdreq   ( ast_source_sizes_muxed_valid[n] && ast_source_sizes_muxed_ready[n] ),
        .rdempty ( out_fifo_empty                                                     ),
        .q       ( {ast_source_sizes_muxed_data[n], ast_source_sizes_muxed_endofpacket[n], ast_source_sizes_muxed_startofpacket[n], ast_source_sizes_muxed_empty[n]} )
      );
    end
endgenerate

one_hot_ast_mux #(
  .BYTE_W                                 ( BYTE_W                               ),
  .IN_DIRS_CNT                            ( STR_SIZES_CNT                        ),
  .AST_SYMBOLS                            ( AST_SOURCE_SYMBOLS                   )
) windows_mux (
  .clk_i                                  ( source_clk_i                         ),
  .srst_i                                 ( source_srst_i                        ),
  /*
  .clk_i                                  ( main_clk_i                         ),
  .srst_i                                 ( main_srst_i                        ),
  */

  .ast_sink_data_i                        ( ast_source_sizes_muxed_data          ),
  .ast_sink_ready_o                       ( ast_source_sizes_muxed_ready         ),
  .ast_sink_valid_i                       ( ast_source_sizes_muxed_valid         ),
  .ast_sink_empty_i                       ( ast_source_sizes_muxed_empty         ),
  .ast_sink_endofpacket_i                 ( ast_source_sizes_muxed_endofpacket   ),
  .ast_sink_startofpacket_i               ( ast_source_sizes_muxed_startofpacket ),

  .ast_source_data_o                      ( ast_source_data_o                    ),
  .ast_source_ready_i                     ( ast_source_ready_i                   ),
  .ast_source_valid_o                     ( ast_source_valid_o                   ),
  .ast_source_empty_o                     ( ast_source_empty_o                   ),
  .ast_source_endofpacket_o               ( ast_source_endofpacket_o             ),
  .ast_source_startofpacket_o             ( ast_source_startofpacket_o           )
);

endmodule

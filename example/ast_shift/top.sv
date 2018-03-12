parameter int AST_SINK_SYMBOLS = 8;
parameter bit AST_SINK_ORDER   = 1;
parameter int WINDOW_SIZE      = 20;

parameter int AST_SINK_EMPTY_W = ( AST_SINK_SYMBOLS  == 1   ) ?
                                 ( 1                        ) :
                                 ( $clog2(AST_SINK_SYMBOLS) );

parameter int WINDOW_SIZE_W    = ( WINDOW_SIZE == 1    ) ?
                                 ( 1                   ) :
                                 ( $clog2(WINDOW_SIZE) );

module top(
  input                                                       clk_i,
  input                                                       srst_i,

  input   [AST_SINK_SYMBOLS-1:0][BYTE_W-1:0]                  ast_sink_data_i,
  output                                                      ast_sink_ready_o,
  input                                                       ast_sink_valid_i,
  input   [AST_SINK_EMPTY_W-1:0]                              ast_sink_empty_i,
  input                                                       ast_sink_endofpacket_i,
  input                                                       ast_sink_startofpacket_i,
  output  [AST_SINK_SYMBOLS*WINDOW_SIZE-1:0][BYTE_W-1:0]      windows_data_o,
  output  [AST_SINK_SYMBOLS-1:0][WINDOW_SIZE_W-1:0]           windows_data_valid_bytes_o,
  input                                                       windows_data_ready_i
);

logic                                                     srst;
logic                                                     ast_sink_ready;
logic [AST_SINK_SYMBOLS-1:0][BYTE_W-1:0]                  ast_sink_data;
logic                                                     ast_sink_valid;
logic [AST_SINK_EMPTY_W-1:0]                              ast_sink_empty;
logic                                                     ast_sink_endofpacket;
logic                                                     ast_sink_startofpacket;
logic [AST_SINK_SYMBOLS-1:0][WINDOW_SIZE-1:0][BYTE_W-1:0] windows_data;
logic [AST_SINK_SYMBOLS-1:0][WINDOW_SIZE_W-1:0]           windows_data_valid_bytes;
logic                                                     windows_data_ready;

always_ff @( posedge clk_i )
  begin
    srst                       <= srst_i;
    ast_sink_ready_o           <= ast_sink_ready;
    windows_data_o             <= windows_data;
    windows_data_valid_bytes_o <= windows_data_valid_bytes;

    ast_sink_data              <= ast_sink_data_i;
    ast_sink_valid             <= ast_sink_valid_i;
    ast_sink_empty             <= ast_sink_empty_i;
    ast_sink_endofpacket       <= ast_sink_endofpacket_i;
    ast_sink_startofpacket     <= ast_sink_startofpacket_i;
    windows_data_ready         <= windows_data_ready_i;
  end

ast_shift #(
  .AST_SINK_SYMBOLS            ( AST_SINK_SYMBOLS         ),
  .AST_SINK_ORDER              ( AST_SINK_ORDER           ),
  .WINDOW_SIZE                 ( WINDOW_SIZE              )
) sh (
  .clk_i                       ( clk_i                    ),
  .srst_i                      ( srst                     ),
  .en_i                        ( 1'b1                     ),

  .ast_sink_data_i             ( ast_sink_data            ),
  .ast_sink_ready_o            ( ast_sink_ready           ),
  .ast_sink_valid_i            ( ast_sink_valid           ),
  .ast_sink_empty_i            ( ast_sink_empty           ),
  .ast_sink_endofpacket_i      ( ast_sink_endofpacket     ),
  .ast_sink_startofpacket_i    ( ast_sink_startofpacket   ),
  .windows_data_o              ( windows_data             ),
  .windows_data_valid_bytes_o  ( windows_data_valid_bytes ),
  .windows_data_ready_i        ( windows_data_ready       )
);


endmodule

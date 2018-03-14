module one_hot_ast_mux #(
  parameter int BYTE_W      = 8,
  parameter int IN_DIRS_CNT = 8,

  parameter int AST_SYMBOLS = 1,
  parameter int AST_EMPTY_W = ( AST_SYMBOLS  == 1   ) ?
                              ( 1                   ) :
                              ( $clog2(AST_SYMBOLS) )
)(
  input                                                 clk_i,
  input                                                 srst_i,

  input  [IN_DIRS_CNT-1:0][AST_SYMBOLS-1:0][BYTE_W-1:0] ast_sink_data_i,
  output [IN_DIRS_CNT-1:0]                              ast_sink_ready_o,
  input  [IN_DIRS_CNT-1:0]                              ast_sink_valid_i,
  input  [IN_DIRS_CNT-1:0][AST_EMPTY_W-1:0]             ast_sink_empty_i,
  input  [IN_DIRS_CNT-1:0]                              ast_sink_endofpacket_i,
  input  [IN_DIRS_CNT-1:0]                              ast_sink_startofpacket_i,

  output [AST_SYMBOLS-1:0][BYTE_W-1:0]                  ast_source_data_o,
  input                                                 ast_source_ready_i,
  output                                                ast_source_valid_o,
  output [AST_EMPTY_W-1:0]                              ast_source_empty_o,
  output                                                ast_source_endofpacket_o,
  output                                                ast_source_startofpacket_o
);

localparam IN_DIRS_LOG2 = ( IN_DIRS_CNT == 1      ) ? 
                          ( 1                     ) : 
                          ( $clog2( IN_DIRS_CNT ) );

logic [IN_DIRS_CNT-1:0]  in_ready_w;

logic [IN_DIRS_LOG2-1:0] next_select_num;
logic [IN_DIRS_LOG2-1:0] select_num;
logic                    packet_in_progress;

assign ast_sink_ready_o = in_ready_w;

one_hot_arb #( 
  .REQ_NUM  ( IN_DIRS_CNT         )
) oh_arb (
  .req_i    ( ast_sink_valid_i    ),
  .num_o    ( next_select_num     )
);

always_ff @( posedge clk_i ) 
  begin
    if( srst_i ) 
      begin
        select_num         <= 0;
        packet_in_progress <= 0;
      end 
    else 
      begin
        if( !ast_source_valid_o && !packet_in_progress ) 
          begin
             select_num <= next_select_num;
          end 
        else 
          begin
             packet_in_progress <= 1;
          end

        if( ast_source_endofpacket_o && ast_source_valid_o && ast_source_ready_i ) 
          begin
             select_num         <= next_select_num;
             packet_in_progress <= 0;
          end
      end
  end

assign ast_source_data_o          = ast_sink_data_i[ select_num ];
assign ast_source_valid_o         = ast_sink_valid_i[ select_num ];
assign ast_source_empty_o         = ast_sink_empty_i[ select_num ];
assign ast_source_endofpacket_o   = ast_sink_endofpacket_i[ select_num ];
assign ast_source_startofpacket_o = ast_sink_startofpacket_i[ select_num ];

always_comb
  begin
    in_ready_w               = '0;
    in_ready_w[ select_num ] = ast_source_ready_i;
  end

endmodule

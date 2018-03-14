/*
  Simple data sender via Avalon-ST interface.
  Give a word to it and when ready became "1" - it will send data to
  output.
*/

module data_to_ast #(
  parameter int BYTE_W             = 8,
  parameter int DATA_SYMBOLS       = 6,

  parameter int AST_SOURCE_SYMBOLS = 1,
  parameter bit AST_SOURCE_ORDER   = 1'b1,
  parameter int AST_SOURCE_EMPTY_W = ( AST_SOURCE_SYMBOLS  == 1   ) ?
                                     ( 1                          ) :
                                     ( $clog2(AST_SOURCE_SYMBOLS) )
) (
  input                                              clk_i,
  input                                              srst_i,

  // Data which will be streamed
  input   [DATA_SYMBOLS-1:0][BYTE_W-1:0]             data_i,
  input                                              data_valid_i,
  output                                             done_o,

  output  [AST_SOURCE_SYMBOLS-1:0][BYTE_W-1:0]       ast_source_data_o,
  input                                              ast_source_ready_i,
  output                                             ast_source_valid_o,
  output  [AST_SOURCE_EMPTY_W-1:0]                   ast_source_empty_o,
  output                                             ast_source_endofpacket_o,
  output                                             ast_source_startofpacket_o
);

localparam DATA_MOD = ( DATA_SYMBOLS % AST_SOURCE_SYMBOLS == 0 ) ?
                      ( AST_SOURCE_SYMBOLS                     ) :
                      ( DATA_SYMBOLS % AST_SOURCE_SYMBOLS      ); 

logic [DATA_SYMBOLS*BYTE_W-1:0]             data;
logic [$clog2(DATA_SYMBOLS):0]              data_ptr;

logic [AST_SOURCE_SYMBOLS-1:0][BYTE_W-1:0]  ast_data;
logic [AST_SOURCE_SYMBOLS-1:0][BYTE_W-1:0]  ast_data_rev;

logic                                       run_flag;

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      data <= '0;
    else
      if( data_valid_i )
        data <= data_i;
  end


always_ff @( posedge clk_i )
  begin
    if( srst_i )
      run_flag <= '0;
    else
      begin
        if( ast_source_endofpacket_o && ast_source_valid_o && ast_source_ready_i )
          run_flag <= 1'b0;
        else
          if( data_valid_i )
            run_flag <= 1'b1;
      end
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      data_ptr <= '0;
    else
      begin
        if( ast_source_ready_i && ast_source_valid_o )
          if( ast_source_endofpacket_o )
            data_ptr <= '0;
          else
            if( ( DATA_SYMBOLS - data_ptr ) > AST_SOURCE_SYMBOLS )
              data_ptr <= data_ptr + AST_SOURCE_SYMBOLS;
      end
  end

always_comb
  begin
    ast_data = '0;
    if( data_ptr == ( DATA_SYMBOLS - DATA_MOD ) )
      ast_data = data[DATA_SYMBOLS*BYTE_W-1 -:DATA_MOD*BYTE_W];
    else
      ast_data = data[data_ptr*BYTE_W +: (AST_SOURCE_SYMBOLS*BYTE_W)]; 
  end

always_comb
  begin
    for( int i=0; i<AST_SOURCE_SYMBOLS; i++ )
      ast_data_rev[i] = ast_data[AST_SOURCE_SYMBOLS-i-1];
  end

generate
  if( AST_SOURCE_ORDER )
    begin: be
      assign ast_source_data_o = ast_data_rev;
    end
  else
    begin: le
      assign ast_source_data_o = ast_data;
    end
endgenerate

assign ast_source_startofpacket_o = ( ( data_ptr == '0 ) && run_flag );
assign ast_source_endofpacket_o   = ( ( data_ptr == ( DATA_SYMBOLS - DATA_MOD  ) ) && run_flag );
assign ast_source_valid_o         = run_flag;
assign ast_source_empty_o         = ( AST_SOURCE_SYMBOLS - DATA_MOD );

assign done_o = ast_source_endofpacket_o && ast_source_valid_o && ast_source_ready_i;

endmodule

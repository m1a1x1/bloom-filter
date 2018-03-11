import bloom_filter_pkg::*;

module ast_shift #(
  parameter int AST_SINK_SYMBOLS = 8,
  parameter bit AST_SINK_ORDER   = 1,
  parameter int AST_SINK_EMPTY_W = ( AST_SINK_SYMBOLS  == 1   ) ?
                                   ( 1                        ) :
                                   ( $clog2(AST_SINK_SYMBOLS) ),

  parameter int WINDOW_SIZE      = 20,
  parameter int WINDOW_SIZE_W    = ( WINDOW_SIZE == 1    ) ?
                                   ( 1                   ) :
                                   ( $clog2(WINDOW_SIZE) )
)(
  input                                                       clk_i,
  input                                                       srst_i,

  input                                                       en_i,

  input   [AST_SINK_SYMBOLS-1:0][BYTE_W-1:0]                  ast_sink_data_i,
  output                                                      ast_sink_ready_o,
  input                                                       ast_sink_valid_i,
  input   [AST_SINK_EMPTY_W-1:0]                              ast_sink_empty_i,
  input                                                       ast_sink_endofpacket_i,
  input                                                       ast_sink_startofpacket_i,

  output  [AST_SINK_SYMBOLS-1:0][WINDOW_SIZE-1:0][BYTE_W-1:0] windows_data_o,
  output  [AST_SINK_SYMBOLS-1:0][WINDOW_SIZE_W-1:0]           windows_data_valid_bytes_o,
  input                                                       windows_data_ready_i
);

localparam SHIFT_BUFF_SIZE = AST_SINK_SYMBOLS+WINDOW_SIZE-1;

logic [SHIFT_BUFF_SIZE-1:0][BYTE_W-1:0]                   shift_buff;
logic [$clog2(SHIFT_BUFF_SIZE):0]                         shift_buff_head;
logic [$clog2(SHIFT_BUFF_SIZE):0]                         shift_buff_tail;
logic                                                     last_clear_shift;

logic [AST_SINK_SYMBOLS-1:0][BYTE_W-1:0]                  ast_sink_data;

logic [AST_SINK_SYMBOLS-1:0][WINDOW_SIZE-1:0][BYTE_W-1:0] windows_data;
logic                                                     head_in_windows;
logic [AST_SINK_SYMBOLS-1:0][WINDOW_SIZE_W-1:0]           windows_data_valid_bytes;
logic                                                     saved_windows_ready;

enum logic [0:0] { SHIFT_INPUT_S,
                   CLEAR_SHIFT_S } state, next_state;


always_ff @( posedge clk_i )
  begin
    if( srst_i )
      state <= SHIFT_INPUT_S;
    else
      state <= next_state;
  end

always_comb
  begin
    next_state = state;
    case( state )
      SHIFT_INPUT_S:
        begin
          if( ast_sink_endofpacket_i && ast_sink_ready_o && ast_sink_endofpacket_i )
            next_state = CLEAR_SHIFT_S;
        end

      CLEAR_SHIFT_S:
        begin
          if( last_clear_shift && windows_data_ready_i )
            begin
              next_state = SHIFT_INPUT_S;
            end
        end

    default:
      begin
        next_state = SHIFT_INPUT_S;
      end
    endcase
  end

assign head_in_windows = shift_buff_head < AST_SINK_SYMBOLS;
/*
assign last_clear_shift = ( head_in_windows                                         ) && 
                          ( ( shift_buff_tail - shift_buff_head) < AST_SINK_SYMBOLS );
*/
assign last_clear_shift = shift_buff_tail < AST_SINK_SYMBOLS;

generate
  begin
    if( AST_SINK_ORDER )
      begin: swap
        always_comb
          begin
            for( int i = 0; i < AST_SINK_SYMBOLS; i++ )
              begin
                ast_sink_data[i] = ast_sink_data_i[AST_SINK_SYMBOLS-i-1];
              end
          end
      end
    else
      begin: no_swap
        assign ast_sink_data = ast_sink_data_i;
      end
  end
endgenerate

assign ast_sink_ready_o = ( state == SHIFT_INPUT_S                          ) ?
                          ( ( head_in_windows                             ) ?
                            ( saved_windows_ready || windows_data_ready_i ) :
                            ( 1'b1                                        ) ) :
                          ( 1'b0                                            );

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      saved_windows_ready <= 1'b0;
    else
      begin
        if( state == CLEAR_SHIFT_S )
          saved_windows_ready <= 1'b0;
        else
          begin
            if( saved_windows_ready )
              begin
                if( ast_sink_valid_i && ast_sink_ready_o )
                  saved_windows_ready <= 1'b0;
              end
            else
              begin
                if( windows_data_ready_i && ! ( ast_sink_valid_i && ast_sink_ready_o ) )
                  saved_windows_ready <= 1'b1;
              end
          end
      end
  end

always_ff @( posedge clk_i )
  begin
    if( ( ast_sink_ready_o && ast_sink_valid_i && en_i       ) || 
        ( ( state == CLEAR_SHIFT_S ) && windows_data_ready_i )    )
      shift_buff <= { ast_sink_data, shift_buff[SHIFT_BUFF_SIZE-1:AST_SINK_SYMBOLS]}; 
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      shift_buff_head <= SHIFT_BUFF_SIZE-1;
    else
      begin
        if( state == SHIFT_INPUT_S )
          begin
            if( ast_sink_valid_i && ast_sink_ready_o )
              begin
                if( ast_sink_startofpacket_i )
                  shift_buff_head <= SHIFT_BUFF_SIZE - AST_SINK_SYMBOLS;
                else
                  begin
                    if( head_in_windows ) 
                      shift_buff_head <= '0;
                    else
                      shift_buff_head <= shift_buff_head - AST_SINK_SYMBOLS;
                  end
              end
          end
        else
          begin
            if( windows_data_ready_i )
              begin
                if( last_clear_shift )
                  shift_buff_head <= SHIFT_BUFF_SIZE-1;
                else
                  begin
                    if( head_in_windows ) 
                      shift_buff_head <= '0;
                    else
                      shift_buff_head <= shift_buff_head - AST_SINK_SYMBOLS;
                  end
              end
          end
      end
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      shift_buff_tail <= SHIFT_BUFF_SIZE-1;
    else
      begin
        if( state == SHIFT_INPUT_S )
          begin
            if( ast_sink_valid_i && ast_sink_ready_o )
              begin
                if( ast_sink_endofpacket_i )
                  shift_buff_tail <= SHIFT_BUFF_SIZE - 1 - ast_sink_empty_i;
                else
                  shift_buff_tail <= SHIFT_BUFF_SIZE - 1;
              end
          end
        else
          begin
            if( windows_data_ready_i )
              begin
                if( last_clear_shift )
                  shift_buff_tail <= SHIFT_BUFF_SIZE-1;
                else
                  shift_buff_tail <= shift_buff_tail - AST_SINK_SYMBOLS;
              end
          end
      end
  end

always_comb
  begin
    for( int i = 0; i < AST_SINK_SYMBOLS; i++ )
      windows_data[i] = shift_buff[WINDOW_SIZE+i-1 -: WINDOW_SIZE];
  end

always_comb
  begin
    if( saved_windows_ready || !head_in_windows )
      windows_data_valid_bytes = '0;
    else
      begin
        for( int i = 0; i < AST_SINK_SYMBOLS; i++ )
          begin
            if( ( i < shift_buff_head ) || ( i > shift_buff_tail ) )
              windows_data_valid_bytes[i] = '0;
            else
              begin
                if( (shift_buff_tail-i) >= WINDOW_SIZE )
                  windows_data_valid_bytes[i] = WINDOW_SIZE;
                else
                  windows_data_valid_bytes[i] = shift_buff_tail-i+1;
              end
          end
      end
  end  

assign windows_data_o             = windows_data;
assign windows_data_valid_bytes_o = windows_data_valid_bytes;

endmodule

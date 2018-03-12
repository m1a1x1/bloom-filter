`timescale 1ns / 1ns

import ast_port_pkg::*;

let max(a,b) = (a > b) ? a : b;
let min(a,b) = (a < b) ? a : b;

module top_ast_shift_tb;

// Gap (in clock ticks) between packets
parameter GAP                  = 0;

// Enable random break inside packet (source valid signal will be random)
parameter bit IN_PACKET_BREAK  = 1;

// As we use random ready - we may want to send send same packet many times,
// to try to check different ready cases.
parameter ONE_TASK_REPEAT_CNT  = 100;

// Packet size limitations:
//   MIN_PKT_SIZE >= 1
//   MIN_PKT_SIZE <= MAX_PKT_SIZE <= (2**MAX_PKT_SIZE_W)-1
parameter MIN_PKT_SIZE         = 1;
parameter MAX_PKT_SIZE         = 200;

// NOTE: Tesbench will send in total:
//   (MAX_PKT_SIZE_W - MIN_PKT_SIZE + 1) * ONE_TASK_REPEAT_CNT
//
// For example:
//   With settings as:
//     Packet from 1 to 3 bytes,
//     One task per packet,
//   3*1=3 packets will be sent to DUT 

parameter WINDOW_SIZE = 20; 

parameter int WINDOW_SIZE_W    = ( WINDOW_SIZE == 1    ) ?
                                 ( 1                   ) :
                                 ( $clog2(WINDOW_SIZE) );

// Enable random ready (sink ready will be random)
parameter bit RANDOM_READY     = 1'b1;

localparam AST_DATA_W          = 64;
localparam AST_EMPTY_W         = 3;
localparam AST_ERROR_W         = 1;
localparam AST_CHANNEL_W       = 1;
localparam BYTE_W              = 8;

localparam BYTES_IN_WORD       = AST_DATA_W/BYTE_W;

logic                        clk;
logic                        rst;
bit                          rst_done=0;

logic [BYTES_IN_WORD-1:0][WINDOW_SIZE-1:0][BYTE_W-1:0] windows_data;
logic [BYTES_IN_WORD-1:0][WINDOW_SIZE_W:0]             windows_valid_bytes;
logic                                                  windows_ready;


// One packet queue
typedef bit[BYTE_W-1:0]      packet_t[$];


// All packets to send
packet_t                     one_task;
packet_t                     tasks[$];

// SystemVerilog interface with Avalon-ST signals. 
// It have assertion for more then one start or end of packet inside one packet
// sending. 
avalon_st_if #( 
  .DATA_W    ( AST_DATA_W     ),
  .EMPTY_W   ( AST_EMPTY_W    ),
  .ERROR_W   ( AST_ERROR_W    ),
  .CHANNEL_W ( AST_CHANNEL_W  ),
  .TUSER_W   ( 1              )
) ast_src_if (
  .clk       ( clk            )
);

// Class for sending and reciving packets with given avalon_st_if.
//   * REVERT_BYTES is same as Avalon-ST "firstSymbolInHighOrderBits" parameter.
//   * tuser is custom information which can be send with packet and do not
//     specified in Avalon-ST. We use it as a way to send max_packet_size
//   * GAP_WORDS gap in ticks between packets.
//   * BREAK_EN - enable random break inside one packet (when even if we have "ready",
//     we do not send data. In this brake data is "X" and valid is "0")
ast_port #(
  .REVERT_BYTES ( 0               ), 
  .CHANNEL_EN   ( 0               ),
  .ERROR_EN     ( 0               ),
  .RX_TUSER_EN  ( 0               ),
  .DATA_W       ( AST_DATA_W      ),
  .EMPTY_W      ( AST_EMPTY_W     ),
  .ERROR_W      ( AST_ERROR_W     ),
  .CHANNEL_W    ( AST_CHANNEL_W   ),
  .TUSER_W      ( 1               ),
  .BREAK_EN     ( IN_PACKET_BREAK ),
  .GAP_WORDS    ( GAP             )
) ast_src_p;

initial
  begin
    clk = 1'b0;
    forever
      begin
        #10
        clk = ~clk;
      end
  end

initial
  begin
    rst = 1'b0;
    #19
    @( posedge clk )
    rst = 1'b1;
    #39
    @( posedge clk )
    rst = 1'b0;
    @( posedge clk )
    rst_done = 1'b1;
  end

//********************************************************************
//****************************** DUT *********************************
ast_shift #(
  .AST_SINK_SYMBOLS            ( BYTES_IN_WORD            ),
  .AST_SINK_ORDER              ( 0                        ),
  .WINDOW_SIZE                 ( WINDOW_SIZE              )
) dut (
  .clk_i                       ( clk                      ),
  .srst_i                      ( rst                      ),

  .en_i                        ( 1'b1                     ),

  .ast_sink_valid_i            ( ast_src_if.val           ),
  .ast_sink_ready_o            ( ast_src_if.ready         ),
  .ast_sink_data_i             ( ast_src_if.data          ),
  .ast_sink_empty_i            ( ast_src_if.empty         ),
  .ast_sink_startofpacket_i    ( ast_src_if.sop           ),
  .ast_sink_endofpacket_i      ( ast_src_if.eop           ),

  .windows_data_o              ( windows_data             ),
  .windows_valid_bytes_o       ( windows_valid_bytes      ),
  .windows_ready_i             ( windows_ready            )
);


initial
  begin
    ast_src_p = new( ast_src_if );
    wait( rst_done );
    ast_src_p.run( );
  end

initial
  begin
    bit rand_bit;

    windows_ready <= 1'b0;
    wait( rst_done )
    windows_ready <= 1'b1;
    if( RANDOM_READY )
      begin
        forever
          begin
            @( posedge clk )
            rand_bit = $urandom();
            windows_ready <= rand_bit;
          end
      end
  end

//********************************************************************
//************************* TASKS and FUNCTIONS **********************


// Generates one packet.
function automatic packet_t gen_one_packet ( input int  pkt_size ); 
  packet_t               pkt;
  static int             byte_cnt = 1;

  for( int i = 0; i < pkt_size; i++ )
    begin
      pkt.push_back(byte_cnt[BYTE_W-1:0]);
      byte_cnt++;
    end
  return pkt;
endfunction

// Sending of Avalon-ST is done in ast_port.
// To send packet you need to put all needed data to corresponding fifo.
task send_tasks( input packet_t tasks [$] );
  foreach( tasks[i] )
    ast_src_p.rx_fifo.put( tasks[i] );
endtask

// Compare packet data from reference splitter and from DUT.
function bit compare_data( input bit   [BYTE_W-1:0] ref_windows[][][],
                                 bit   [BYTE_W-1:0] res_windows[$][] 
                         );

  
  
  bit res;

  bit   [BYTE_W-1:0] res_for_check_windows[][];
  bit   [BYTE_W-1:0] ref_for_check_windows[][];
  bit   [BYTE_W-1:0] res_find[][];

  res = 0;
  /*
  $display( "Dut Windows" );
  for( int i=0; i < res_windows.size() ; i++ )
    begin
      $display("----- Window %d -----", i );
      for( int j = 0; j < res_windows[i].size(); j++ )
        $display( "%02d " , res_windows[i][j] );
    end
  */
  for( int i = 0; i < ref_windows.size(); i++ )
    begin
      ref_for_check_windows = ref_windows[i];
      if( res_windows.size() < ref_for_check_windows.size() )
        begin
          $error( "Some windows are mising!" );
          $display( "\tFound in %d packet", i );
          $display( "\tWant %d windows, have %d windows", ref_for_check_windows.size(),res_windows.size());
          $stop();
          res = 1;
        end
      res_for_check_windows = new[ ref_for_check_windows.size() ];
      for( int j = 0; j < ref_for_check_windows.size(); j++ )
        res_for_check_windows[j] = res_windows.pop_front();

      foreach( ref_for_check_windows[i] )
        begin
          res_find = res_for_check_windows.find_first with ( item == ref_for_check_windows[i] );
          if( res_find.size() == 0 )
            begin
              $error( "No needed window in the output!" );
              $display( "\tPacket #%d", i );
              $display( "\tMissing window: " );
              for( int k = 0; k < ref_for_check_windows[i].size(); k++ )
                begin
                  $display( "\t\t %d", ref_for_check_windows[i][k] );
                end
              $stop();
              res = 1;
            end
          else
            begin
              //$display("Found match" );
              //$display( res_find );
              ;
            end
        end

      if( i == ( ref_windows.size() - 1 ) )
        begin
          if( res_windows.size() != 0 )
            begin
              $error( "To many windows in final packet!" );
            end
        end
    end
  return res;
 
endfunction

// Check data from DUT
task automatic check_results( input packet_t input_pkts [$] );

  int                       watchdog = 0;
  bit   [BYTE_W-1:0]        ref_windows[$][$][];
  bit   [BYTE_W-1:0]        res_windows[$][];
  bit   [BYTE_W-1:0]        window_bytes[];

  packet_t                  dut_data;
  bit                       data_ok;
  bit                       all_done;

  foreach( input_pkts[i] )
    begin
      bit [BYTE_W-1:0] ref_windows_one_pkt[$][];
      int              head = 0;
      int              tail;

      while( head < input_pkts[i].size() )
        begin
          if( (input_pkts[i].size()-head) < WINDOW_SIZE )
              tail = input_pkts[i].size();
          else
              tail = WINDOW_SIZE-1+head;
          ref_windows_one_pkt.push_back( input_pkts[i][head:tail] );
          head += 1;
        end
      ref_windows.push_back( ref_windows_one_pkt );
    end

  while( watchdog < 100 )
    begin
      @( posedge clk )
      if( windows_valid_bytes == '0 )
        watchdog += 1;
      else
        begin
          if( windows_ready )
            begin
              for( int i = 0; i < BYTES_IN_WORD; i++ )
                begin
                  if( windows_valid_bytes[i] != '0 )
                    begin
                      watchdog = 0;
                      window_bytes = new[ windows_valid_bytes[i] ];
                      for( int j = 0; j < windows_valid_bytes[i]; j++ )
                        window_bytes[j] = windows_data[i][j];
                      res_windows.push_back( window_bytes );
                    end
                end
            end
        end
    end

  data_ok  = compare_data( ref_windows, res_windows) == 0;

  if( !data_ok )
    begin
      $error( "Error in DUT!");
      $finish();
    end  

endtask

//********************************************************************
//************************* MAIN FLOW ********************************

initial
  begin
    wait( rst_done )

    for( int s=MIN_PKT_SIZE; s<=MAX_PKT_SIZE; s++ )
      begin
        for( int r=0; r<ONE_TASK_REPEAT_CNT; r++)
          tasks.push_back( gen_one_packet( s ) );
      end
 
    send_tasks( tasks );
    check_results( tasks );
    
    $display( "Test done, No errors" );
    $stop();
  end

endmodule

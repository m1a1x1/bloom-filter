`timescale 1ns / 1ns

import ast_port_pkg::*;
import bloom_filter_pkg::*;

module top_tb;

// Gap (in clock ticks) between input packets
parameter GAP                  = 0;

// Enable random break inside packet (source valid signal will be random)
parameter bit IN_PACKET_BREAK  = 0;

// Enable random ready (sink ready will be random)
parameter bit RANDOM_READY     = 1'b0;

parameter string PACKETS_TO_SEND_FNAME = "packets_to_send";
parameter string REF_PACKETS_FNAME     = "ref_packets";
parameter string HASH_LUT_DUMP_FNAME   = "hash_lut_dump";

logic                        clk;
logic                        rst;
bit                          rst_done=0;
typedef bit[BYTE_W-1:0]      packet_t[$];

parameter bit AST_SINK_ORDER     = 1;
parameter int AST_SOURCE_SYMBOLS = 1;
parameter bit AST_SOURCE_ORDER   = 1;

logic  [AMM_CSR_ADDR_W-1:0] csr_address;
logic                       csr_read;
logic  [AMM_CSR_DATA_W-1:0] csr_readdata;
logic                       csr_write;
logic  [AMM_CSR_DATA_W-1:0] csr_writedata;

logic  [AMM_LUT_ADDR_W-1:0] lut_address;
logic                       lut_write;
logic  [AMM_LUT_DATA_W-1:0] lut_writedata;


localparam AST_SINK_EMPTY_W = ( AST_SINK_SYMBOLS == 1    ) ?
                              ( 1                        ) :
                              ( $clog2(AST_SINK_SYMBOLS) );

localparam AST_SOURCE_EMPTY_W = ( AST_SOURCE_SYMBOLS == 1    ) ?
                                ( 1                        ) :
                                ( $clog2(AST_SOURCE_SYMBOLS) );

// SystemVerilog interface with Avalon-ST signals. 
// It have assertion for more then one start or end of packet inside one packet
// sending. 
avalon_st_if #( 
  .DATA_W    ( AST_SINK_SYMBOLS*BYTE_W ),
  .EMPTY_W   ( AST_SINK_EMPTY_W        ),
  .ERROR_W   ( 1                       ),
  .CHANNEL_W ( 1                       ),
  .TUSER_W   ( 1                       )
) ast_src_if (
  .clk       ( clk                     )
);

avalon_st_if #( 
  .DATA_W    ( AST_SOURCE_SYMBOLS*BYTE_W ),
  .EMPTY_W   ( AST_SOURCE_EMPTY_W        ),
  .ERROR_W   ( 1                         ),
  .CHANNEL_W ( 1                         ),
  .TUSER_W   ( 1                         )
) ast_snk_if (
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
  .REVERT_BYTES ( AST_SINK_ORDER          ), 
  .CHANNEL_EN   ( 0                       ),
  .ERROR_EN     ( 0                       ),
  .RX_TUSER_EN  ( 0                       ),
  .DATA_W       ( AST_SINK_SYMBOLS*BYTE_W ),
  .EMPTY_W      ( AST_SINK_EMPTY_W        ),
  .ERROR_W      ( 1                       ),
  .CHANNEL_W    ( 1                       ),
  .TUSER_W      ( 1                       ),
  .BREAK_EN     ( IN_PACKET_BREAK         ),
  .GAP_WORDS    ( GAP                     )
) ast_src_p;

ast_port #(
  .REVERT_BYTES ( AST_SOURCE_ORDER          ), 
  .CHANNEL_EN   ( 0                         ),
  .ERROR_EN     ( 0                         ),
  .RX_TUSER_EN  ( 0                         ),
  .DATA_W       ( AST_SOURCE_SYMBOLS*BYTE_W ),
  .EMPTY_W      ( AST_SOURCE_EMPTY_W        ),
  .ERROR_W      ( 1                         ),
  .CHANNEL_W    ( 1                         ),
  .TUSER_W      ( 1                         ),
  .BREAK_EN     ( 0                         ),
  .GAP_WORDS    ( 0                         )
) ast_snk_p;

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
bloom_filter #(
  .AST_SINK_ORDER             ( AST_SINK_ORDER     ), 
  .AST_SOURCE_SYMBOLS         ( AST_SOURCE_SYMBOLS ),
  .AST_SOURCE_ORDER           ( AST_SOURCE_ORDER   )
) dut (
  .main_clk_i                 ( clk                ),
  .ast_source_clk_i           ( clk                ),

  .main_srst_i                ( rst                ),
  .ast_source_srst_i          ( rst                ),

  .ast_sink_valid_i           ( ast_src_if.val     ),
  .ast_sink_ready_o           ( ast_src_if.ready   ),
  .ast_sink_data_i            ( ast_src_if.data    ),
  .ast_sink_empty_i           ( ast_src_if.empty   ),
  .ast_sink_startofpacket_i   ( ast_src_if.sop     ),
  .ast_sink_endofpacket_i     ( ast_src_if.eop     ),

  .amm_slave_csr_address_i    ( csr_address        ),
  .amm_slave_csr_read_i       ( csr_read           ),
  .amm_slave_csr_readdata_o   ( csr_readdata       ),
  .amm_slave_csr_write_i      ( csr_write          ),
  .amm_slave_csr_writedata_i  ( csr_writedata      ),

  .amm_slave_lut_address_i    ( lut_address        ),
  .amm_slave_lut_write_i      ( lut_write          ),
  .amm_slave_lut_writedata_i  ( lut_writedata      ),

  .ast_source_valid_o         ( ast_snk_if.val     ),
  .ast_source_ready_i         ( ast_snk_if.ready   ),
  .ast_source_data_o          ( ast_snk_if.data    ),
  .ast_source_empty_o         ( ast_snk_if.empty   ),
  .ast_source_startofpacket_o ( ast_snk_if.sop     ),
  .ast_source_endofpacket_o   ( ast_snk_if.eop     )
);

initial
  begin
    ast_src_p = new( ast_src_if, PACKETS_TO_SEND_FNAME );
    wait( rst_done );
    ast_src_p.run( );
  end

initial
  begin
    ast_snk_p = new( ast_snk_if );
    wait( rst_done );
    ast_snk_p.run( );
  end

initial
  begin
    bit rand_bit;

    ast_snk_if.ready <= 1'b0;
    wait( rst_done )
    ast_snk_if.ready <= 1'b1;
    if( RANDOM_READY )
      begin
        forever
          begin
            @( posedge clk )
            rand_bit = $urandom();
            ast_snk_if.ready <= rand_bit;
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

task csr_read_t( input  bit [AMM_CSR_ADDR_W-1:0] addr, 
                 output bit [AMM_CSR_DATA_W-1:0] value
              );
  csr_address   <= '0;        
  csr_writedata <= '0;
  csr_write     <= '0;
  csr_read      <= '0;
  @( posedge clk );
  csr_address   <= addr;        
  csr_read      <= 1'b1;
  @( posedge clk );
  csr_read      <= 1'b0;
  @( posedge clk );
  value         = csr_readdata;
endtask

task csr_write_t( input bit [AMM_CSR_ADDR_W-1:0] addr, 
                      bit [AMM_CSR_DATA_W-1:0] value
                );
  csr_address   <= '0;        
  csr_writedata <= '0;
  csr_write     <= '0;
  csr_read      <= '0;
  @( posedge clk );
  csr_address   <= addr;        
  csr_writedata <= value;
  csr_write     <= 1'b1;
  @( posedge clk );
  csr_write     <= 1'b0;
endtask

task csr_wait_t( input bit [AMM_CSR_ADDR_W-1:0] addr, 
                     bit [AMM_CSR_DATA_W-1:0] value
              );
  bit [AMM_CSR_DATA_W-1:0] reg_value;

  do
    begin
      repeat (50) @( posedge clk );
      csr_read_t( addr, reg_value );
    end
  while( reg_value != value );
endtask

// Config Bloom Filter:
// Clean hash lut and write hash lut memory dump from file:
task config_bf( );
  //csr_write_t( HASH_LUT_CLEAN, AMM_CSR_DATA_W'(1) );
  //csr_wait_t( HASH_LUT_CLEAN, '0 );
  csr_write_t( EN, AMM_CSR_DATA_W'(1) );
endtask

task check( input string fname );
  packet_t all_ref_data [$];
  packet_t dut_packet;
  int res [];
  static int watchdog = 0;

  forever
    begin
      packet_t rd_pkt;

      if( ast_snk_p.next_frame( fname, rd_pkt ) == 0 )
        begin
          all_ref_data.push_back( rd_pkt );
        end
      else
        begin
          break;
        end
    end

  while( all_ref_data.size() > 0 )
    begin
      ast_snk_p.tx_fifo.get( dut_packet );
      res = all_ref_data.find_first_index with ( item == dut_packet );
      if( res.size() == 0 )
        begin
          $error( "Unexpeced search result from DUT. String:\n\t", dut_packet );
          $display( "was not in reference results");
          $stop();
        end
      else
        begin
          $display( "String ", all_ref_data[res[0]], "was found!" );
          all_ref_data.delete( res[0] ); 
        end
    end

 while( watchdog < 100 )
   begin
     @( posedge clk );
     watchdog += 1;
   end

 if( ast_snk_p.tx_fifo.num() > 0 )
   begin
     static int cnt = 0;
     $error( "Unexpeced %d search results from DUT. Strings:\n\t", ast_snk_p.tx_fifo.num() );
     while( ast_snk_p.tx_fifo.num() > 0 )
       begin
         ast_snk_p.tx_fifo.get( dut_packet );
         $display( "\n\tRes # %d", cnt, dut_packet );
         cnt += 1;
       end
     $stop();
   end

endtask

task write_dump( input string fname );
  integer fd;
  integer code;
  bit [AMM_LUT_ADDR_W-1:0] addr;
  bit [AMM_CSR_DATA_W-1:0] data;

  fd = $fopen( fname, "r" );
  $display( "Start reading hash table dump from %s", fname);
  while( 1 )
    begin
      code = $fscanf( fd, "%d %d", addr, data);
      code = $feof( fd );

      if( code != 0 )
        begin
         @( posedge clk );
          lut_write <= 1'b0;
          break;
        end

      @( posedge clk );
      lut_write     <= 1'b1;
      lut_address   <= addr;;
      lut_writedata <= data;;
    end
  $fclose( fd );
  $display( "Hash table dump loaded!");
endtask

//********************************************************************
//************************* MAIN FLOW ********************************

packet_t tasks[$];

initial
  begin
    wait( rst_done )
    write_dump( HASH_LUT_DUMP_FNAME );
    config_bf( );
    check( REF_PACKETS_FNAME );
    $display( "Test done, No errors" );
    $stop();
  end

endmodule

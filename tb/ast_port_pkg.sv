package ast_port_pkg;

typedef bit[7:0] packet_data_t[$];

class ast_port #( 
  parameter REVERT_BYTES = 0, 
  parameter CHANNEL_EN   = 0,
  parameter ERROR_EN     = 0,
  parameter RX_TUSER_EN  = 0,
  parameter DATA_W       = 64,
  parameter EMPTY_W      = 3,
  parameter ERROR_W      = 8,
  parameter CHANNEL_W    = 8,
  parameter TUSER_W      = 1,
  parameter BREAK_EN     = 0,
  parameter GAP_WORDS    = 0
);

  localparam BYTES_IN_WORD = DATA_W / 8;

  typedef struct packed {
    logic [CHANNEL_W-1:0] data;
  } channel_data_t;

  typedef bit[ERROR_W-1:0] errors_data_t [$];

  typedef struct packed {
    logic [TUSER_W-1:0] tuser;
  } tuser_data_t;

  virtual avalon_st_if #( 
    .DATA_W    ( DATA_W    ),
    .EMPTY_W   ( EMPTY_W   ),
    .ERROR_W   ( ERROR_W   ),
    .TUSER_W   ( TUSER_W   ),
    .CHANNEL_W ( CHANNEL_W )
  ) ast_if;
  
  mailbox #( packet_data_t  ) rx_fifo;
  mailbox #( channel_data_t ) rx_channel_fifo;
  mailbox #( errors_data_t  ) rx_errors_fifo;
  mailbox #( tuser_data_t   ) rx_tuser_fifo;

  mailbox #( packet_data_t  ) tx_fifo;
  mailbox #( channel_data_t ) tx_channel_fifo;
  mailbox #( errors_data_t  ) tx_errors_fifo;

  string                      rx_fname;

  function new( virtual avalon_st_if #( .DATA_W    ( DATA_W    ),
                                        .EMPTY_W   ( EMPTY_W   ),
                                        .ERROR_W   ( ERROR_W   ),
                                        .TUSER_W   ( TUSER_W   ),
                                        .CHANNEL_W ( CHANNEL_W ) ) ast_if,
                                     string rx_fname = " ");
    this.ast_if          = ast_if;
    this.rx_fifo         = new ();
    this.rx_channel_fifo = new ();
    this.rx_errors_fifo  = new ();
    this.rx_tuser_fifo   = new ();

    this.tx_fifo         = new ();
    this.tx_channel_fifo = new ();
    this.tx_errors_fifo  = new ();

    this.rx_fname        = rx_fname;


    this.init_interface();
  endfunction

  function static int next_frame( input string fname, output packet_data_t read_pkt );
    int         fpos;
    int         real_len;
    logic [7:0] _byte;
    string      line;
    int         next_space;
   
    integer fd;
    integer code;
    
    fd   = $fopen( fname, "r" );
    code = $fseek( fd, fpos, 0 );
    code = $fgets( line, fd);
    code = $feof( fd );
    read_pkt = {};

    if( code != 0 ) 
      begin
        return -1;
      end
  
    while( 1 )
      begin
        code = $sscanf( line, "%d", _byte);

        for( int i=0; i < line.len(); i++)
          if( line.getc(i) == " " )
            begin
              next_space = i;
              break;
            end
           
        line = line.substr(next_space+1,line.len()-1);
        read_pkt.push_back( _byte );

        if( line.len() == 1 )
          break;
      end

    fpos = $ftell( fd );
    
    $fclose( fd );
    return 0;
  endfunction
  
  `define CB @( posedge ast_if.clk );

  task file_to_rx_fifo();
    if( this.rx_fname != " " )
      begin
        //$display("Reading packets from %s", this.pkt_rx_fname );
        forever
          begin
            packet_data_t rd_pkt;

            if( next_frame( this.rx_fname, rd_pkt ) == 0 )
              begin
                this.rx_fifo.put( rd_pkt );
              end
            else
              begin
                return;
              end
          end
      end
  endtask


  task rx_monitor();
    packet_data_t  rx_pkt;
    channel_data_t channel = '0;
    errors_data_t  errors;
    tuser_data_t   tuser = '0;

    forever
      begin

        if( is_rx_packet( ) )
          begin
            if( CHANNEL_EN )
              this.rx_channel_fifo.get( channel );

            if( ERROR_EN )
              this.rx_errors_fifo.get( errors );

            if( RX_TUSER_EN )
              this.rx_tuser_fifo.get( tuser );

            this.rx_fifo.get( rx_pkt );
            
            this.send( rx_pkt, channel, errors, tuser, GAP_WORDS );
          end
        else
          begin
            `CB
          end
      end
  endtask

  function bit is_rx_packet( );
    bit res = 1'b0;

    res = ( this.rx_fifo.num() > 0 );

    if( CHANNEL_EN ) 
      res = res && ( this.rx_channel_fifo.num() > 0 );

    if( ERROR_EN )
      res = res && ( this.rx_errors_fifo.num() > 0 );

    if( RX_TUSER_EN )
      res = res && ( this.rx_tuser_fifo.num() > 0 );

    return res;
  endfunction
  
  task tx_monitor();
    forever
      begin
        packet_data_t  tx_pkt;
        channel_data_t channel;
        errors_data_t  errors;

        this.receive( tx_pkt, channel, errors );
        this.tx_fifo.put( tx_pkt );

        if( CHANNEL_EN )
          this.tx_channel_fifo.put( channel );

        if( ERROR_EN )
          this.tx_errors_fifo.put( errors );

      end
  endtask
  
  task run();

    file_to_rx_fifo();

    fork
      rx_monitor();
      tx_monitor();
    join_any
  endtask
  
  function init_interface();
    ast_if.data    = '0;
    ast_if.sop     = '0;
    ast_if.eop     = '0;
    ast_if.val     = '0;
    ast_if.empty   = '0;
    ast_if.channel = '0;
    ast_if.error   = '0;
  endfunction

  task send( input packet_data_t  rx_pkt,
                   channel_data_t channel='0,
                   errors_data_t  errors,
                   tuser_data_t   tuser='0,
                   int            gap_words );
    begin

      int                           data_byte_num;       
      int                           word_byte_num;       
      int                           packet_len;          
      int                           cur_word_byte_num;
      int                           pkt_empty;
      int                           pkt_words_cnt;
      bit  [BYTES_IN_WORD-1:0][7:0] pkt_data;
      bit                           load_new_word;
      int                           word_num;
      logic           [ERROR_W-1:0] error;

      bit                           pause;

      data_byte_num = 0;      
      word_byte_num = 0;      
      packet_len    = 0;    
      
      packet_len    = rx_pkt.size(); 

      pkt_empty     = ( packet_len % BYTES_IN_WORD == 0 ) ? ( '0 ) : ( BYTES_IN_WORD - packet_len % BYTES_IN_WORD );

      pkt_words_cnt = packet_len / BYTES_IN_WORD;

      if( pkt_empty != 0 )
        pkt_words_cnt++;

      ast_if.data    <= '0;
      load_new_word  = 1'b0;

      word_num = 0;
      while( word_num < pkt_words_cnt )
        begin
          if( word_num == 0 )
            begin
              ast_if.sop     <= 1'b1;
              ast_if.eop     <= 1'b0;
              ast_if.val     <= 1'b1;
              ast_if.channel <= channel;
              ast_if.error   <= '0;
              ast_if.tuser   <= tuser;
              ast_if.empty   <= 3'd0;
            end
          else
            if( word_num > 0 && ast_if.ready )
              ast_if.sop <= 1'b0;
          
          if( ast_if.ready || ( word_num == 0 ) )
            load_new_word = 1'b1;
          else
            load_new_word = 1'b0;

          
          if( load_new_word )
            begin
              pause = (BREAK_EN) ? ( $urandom() ) : ( 1'b0 );
              if( pause )
                begin
                  ast_if.val  <= 1'b0;
                  ast_if.data <= 'x;
                end
              else
                begin
                  error = errors.pop_front();
                  ast_if.val     <= 1'b1;
                  for( int i = 0; i < BYTES_IN_WORD; i++ )
                    begin
                      cur_word_byte_num = ( REVERT_BYTES ) ? ( BYTES_IN_WORD - 1 - i ) : ( i );
                      pkt_data[cur_word_byte_num] = rx_pkt[ data_byte_num ];
                      data_byte_num++;

                      if( data_byte_num == packet_len )
                        begin
                          break;
                        end
                    end


                  ast_if.data  <= pkt_data;
                  ast_if.error <= error;

                  if( data_byte_num == packet_len )
                    begin
                      ast_if.eop   <= 1'b1;
                      ast_if.empty <= pkt_empty;
                    end

                  word_num++;
                end
            end
          `CB
        end
     
      while( 1 )
        begin
          if( ast_if.ready )
            begin
              ast_if.sop     <= 1'b0;
              ast_if.val     <= 1'b0;
              ast_if.eop     <= 1'b0;
              ast_if.empty   <= '0;
              ast_if.channel <= '0;
              ast_if.error   <= '0;
              break;
            end 
          `CB
        end

      for( int i = 0; ( i < gap_words ); i++ )
        begin
          `CB
        end

    end
  endtask

  task receive( output packet_data_t  tx_pkt,
                       channel_data_t channel,
                       errors_data_t  errors );

    bit                          eop_flag;
    bit [BYTES_IN_WORD-1:0][7:0] pkt_data; 
    bit            [ERROR_W-1:0] error; 
    bit [EMPTY_W:0]              valid_bytes;
    packet_data_t                _tx_pkt;
    channel_data_t               _channel='0;
    errors_data_t                _errors;

    eop_flag = 1'd0;
    do
      begin
        `CB
        
        pkt_data = ast_if.data;
        error    = ast_if.error;

        if( ast_if.val && ast_if.ready )
          begin
            _errors.push_back(error);
            if( ast_if.sop )
              _channel = ast_if.channel;
            
            if( ast_if.eop )
              begin
                eop_flag = 1'b1;

                if( ast_if.empty == 'b0 )
                  valid_bytes = BYTES_IN_WORD;
                else
                  valid_bytes = ( BYTES_IN_WORD - ast_if.empty );
              end
            else
              valid_bytes = BYTES_IN_WORD;

            for( int i = 0; i < valid_bytes; i++ )
              begin
                if( REVERT_BYTES )
                  begin
                    _tx_pkt.push_back( pkt_data[BYTES_IN_WORD-1-i] );
                  end
                else
                  begin
                    _tx_pkt.push_back( pkt_data[i] );
                  end
              end

          end
      end
    while(!eop_flag);

    tx_pkt  = _tx_pkt;
    channel = _channel;
    errors   = _errors;

  endtask


endclass

endpackage

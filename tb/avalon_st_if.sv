interface avalon_st_if
#(
  parameter DATA_W    = 64,
  parameter EMPTY_W   = 3,
  parameter ERROR_W   = 1,
  parameter CHANNEL_W = 8,
  parameter TUSER_W   = 1
)( 
  input clk
);

logic [DATA_W-1:0]     data;
logic                  sop;
logic                  eop;
logic                  val;
logic [EMPTY_W-1:0]    empty;
logic [ERROR_W-1:0]    error;
logic [CHANNEL_W-1:0]  channel;
logic [TUSER_W-1:0]    tuser;
logic                  ready;

modport snk(
  input  clk,
         data,
         sop,
         eop,
         val,
         empty,
         error,
         channel,
         tuser,
  output ready
);


modport src(
  output data,
         sop,
         eop,
         val,
         empty,
         error,
         channel,
         tuser,
  input  clk,
         ready
);

// synthesis translate_off
int                  sop_eop_cnt;

initial
  begin
    sop_eop_cnt = 0;

    forever
      begin
        if( val && ready )
          begin
            if( sop )
              sop_eop_cnt = sop_eop_cnt + 1'd1;
            
            if( eop )
              sop_eop_cnt = sop_eop_cnt - 1'd1;
          end

        @( posedge clk );
      end
  end

initial
  begin
    forever
      begin
        @( posedge clk );
        if( (sop_eop_cnt < 0) || (sop_eop_cnt > 2) )
          $error( "Assertion error in avalon_st_if" );
      end
  end
// synthesis translate_on

endinterface

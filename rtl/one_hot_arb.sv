module one_hot_arb #(
  parameter int REQ_NUM   = 2, 
  parameter int REQ_NUM_W = ( REQ_NUM == 1      ) ? 
                            ( 1                 ) : 
                            ( $clog2( REQ_NUM ) )
)(
  input        [REQ_NUM-1:0]   req_i,
  output logic [REQ_NUM_W-1:0] num_o
);

always_comb
 begin
   num_o = '0;
   for( int i = 0; i < REQ_NUM; i++ )
     begin
       if( req_i[i] == 1'b1 )
         begin
           num_o = i[REQ_NUM_W-1:0];
           break;
         end
     end
 end

endmodule

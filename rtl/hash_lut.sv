function automatic int calc_mem_blocks ( input int str_size_cnt, hash_cnt,
                                               hash_w, mode, mem_w
                                       );
  int mem_block_cnt = 0;


  case( mode )
    0:
      begin
        if( hash_w < mem_w )
          begin
            if( (hash_cnt % 2) == 0 ) 
              mem_block_cnt = str_size_cnt * (hash_cnt/2);
            else
              mem_block_cnt = str_size_cnt * ((hash_cnt/2) + 1);
          end
        else
          begin
            mem_block_cnt =  str_size_cnt * hash_cnt;
          end
      end
    1:
      begin
        mem_block_cnt = str_size_cnt * (hash_cnt/2);
      end
    default:
      begin
        $error("Unsupported mode %d. See ./rtl/bloom_filter_pkg.sv for list supported modes", mode);
        $stop();
      end
  endcase

  return mem_block_cnt;
endfunction

module hash_lut #(
  parameter int AMM_LUT_ADDR_W = 32,
  parameter int AMM_LUT_DATA_W = 32,
  parameter int MAX_STR_SIZE   = 20,
  parameter int MIN_STR_SIZE   = 8,
  parameter int HASHES_CNT     = 6,
  parameter int HASH_W         = 12,
  parameter int MODE           = 0
)(
  input                                                                clk_i,
  input                                                                srst_i,

  input                                                                config_i,

  input        [AMM_LUT_ADDR_W-1:0]                                    amm_slave_lut_address_i,
  input                                                                amm_slave_lut_write_i,
  input        [AMM_LUT_DATA_W-1:0]                                    amm_slave_lut_writedata_i,

  input        [MAX_STR_SIZE:MIN_STR_SIZE][HASHES_CNT-1:0][HASH_W-1:0] amm_slaves_lut_rd_address_i,
  output logic [MAX_STR_SIZE:MIN_STR_SIZE][HASHES_CNT-1:0]             amm_slaves_lut_rd_readdata_o
);

localparam int STR_SIZE_CNT    = MAX_STR_SIZE - MIN_STR_SIZE + 1;
localparam int M10K_W          = 13;
localparam int MEM_BLOCKS_CNT  = calc_mem_blocks(STR_SIZE_CNT, HASHES_CNT, HASH_W, MODE, M10K_W);
localparam int MEM_BLOCKS_W    = ( ( MODE == 0 ) && ( HASH_W < M10K_W ) ) ?
                                 ( M10K_W                               ) :
                                 ( HASH_W                               );

logic [MEM_BLOCKS_CNT-1:0][MEM_BLOCKS_W-1:0] addr_p0;
logic [MEM_BLOCKS_CNT-1:0][MEM_BLOCKS_W-1:0] addr_p1;
logic [MEM_BLOCKS_CNT-1:0][MEM_BLOCKS_W-1:0] addr_p0_wr;
logic [MEM_BLOCKS_CNT-1:0][MEM_BLOCKS_W-1:0] addr_p0_rd;
logic [MEM_BLOCKS_CNT-1:0][MEM_BLOCKS_W-1:0] addr_p1_rd;
logic [MEM_BLOCKS_CNT-1:0]                   rd_data_p0;
logic [MEM_BLOCKS_CNT-1:0]                   rd_data_p1;

logic [$clog2(MEM_BLOCKS_CNT)-1:0]           cur_wr_block;

initial
  begin
    if( MODE == 1 )
      begin
        if( ( HASHES_CNT % 2 ) != 0 )
          begin
            $error("In hashes lut memory mode 1 HASHES_CNT must be even" );
            $stop();
          end
      end
  end

assign cur_wr_block = amm_slave_lut_address_i[AMM_LUT_ADDR_W-1:MEM_BLOCKS_W];

always_comb
  begin
    for( int i = 0; i < MEM_BLOCKS_CNT; i++ )
      addr_p0_wr[i] = amm_slave_lut_address_i[MEM_BLOCKS_W-1:0];
  end

assign addr_p0 = ( config_i   ) ? 
                 ( addr_p0_wr ) :
                 ( addr_p0_rd );

assign addr_p1 =  addr_p1_rd;

generate 
  genvar k;
  if( (MODE == 0) && ( HASH_W >= M10K_W ) )
    begin: m0_block_per_hash
      assign addr_p1 = '0; 
      for( k = 0; k < MEM_BLOCKS_CNT; k++ )
        begin: rd_addr
          localparam int K_P = (k/HASHES_CNT);

          assign addr_p0_rd[k] = amm_slaves_lut_rd_address_i[MIN_STR_SIZE+(k/HASHES_CNT)][k%HASHES_CNT];
          assign amm_slaves_lut_rd_readdata_o[MIN_STR_SIZE+K_P][k%HASHES_CNT] = rd_data_p0[k];
        end
    end
  else
    begin
      if( MODE == 0 )
        begin: m0_block_per_two_hashes
          for( k = 0; k < MEM_BLOCKS_CNT; k++ )
            begin: rd_addr
              localparam int K_P0 = ( k * 2 );
              localparam bit LAST_NOT_USED = ( HASHES_CNT % 2 ) != 0;
              localparam int K_P1 = ( ( LAST_NOT_USED ) && ( k == ( MEM_BLOCKS_CNT - 1 ) ) ) ?
                                    ( k * 2                                                ) :
                                    ( ( k * 2 ) + 1                                        );

              always_comb
                begin
                  addr_p0_rd[k] = MEM_BLOCKS_W'({1'b0,amm_slaves_lut_rd_address_i[MIN_STR_SIZE+(K_P0/HASHES_CNT)][K_P0%HASHES_CNT]});
                  addr_p1_rd[k] = MEM_BLOCKS_W'({1'b1,amm_slaves_lut_rd_address_i[MIN_STR_SIZE+(K_P1/HASHES_CNT)][K_P1%HASHES_CNT]}); 
                end

              always_comb
                begin
                  amm_slaves_lut_rd_readdata_o[MIN_STR_SIZE+(K_P0/HASHES_CNT)][K_P0%HASHES_CNT] = rd_data_p0[k];
                  if( !LAST_NOT_USED || ( k != ( MEM_BLOCKS_CNT - 1 ) ) )
                    amm_slaves_lut_rd_readdata_o[MIN_STR_SIZE+(K_P1/HASHES_CNT)][K_P1%HASHES_CNT] = rd_data_p1[k]; 
                end
            end
        end
      else
        begin: m1_block_per_two_hashes
          for( k = 0; k < MEM_BLOCKS_CNT; k++ )
            begin: rd_addr
              localparam int K_P0 = k * 2;
              localparam int K_P1 = ( k * 2 ) + 1;

              always_comb
                begin
                  addr_p0_rd[k] = amm_slaves_lut_rd_address_i[MIN_STR_SIZE+(K_P0/HASHES_CNT)][K_P0%HASHES_CNT];
                  addr_p1_rd[k] = amm_slaves_lut_rd_address_i[MIN_STR_SIZE+(K_P1/HASHES_CNT)][K_P1%HASHES_CNT]; 
                end

              always_comb
                begin
                  amm_slaves_lut_rd_readdata_o[MIN_STR_SIZE+(K_P0/HASHES_CNT)][K_P0%HASHES_CNT] = rd_data_p0[k];
                  amm_slaves_lut_rd_readdata_o[MIN_STR_SIZE+(K_P1/HASHES_CNT)][K_P1%HASHES_CNT] = rd_data_p1[k]; 
                end
            end
        end
    end
endgenerate

generate
  genvar n;
  for( n = 0; n < MEM_BLOCKS_CNT; n++ )
    begin: mem_blk
      logic                              wr_en;
      logic                              q_0;
      logic                              q_1;

      assign wr_en = ( config_i              ) && 
                     ( amm_slave_lut_write_i ) &&
                     ( cur_wr_block == n     );

      true_dp_ram #(
        .ADDR_W     ( MEM_BLOCKS_W                 ),
        .DATA_W     ( 1                            )
      ) mem (
        .address_a  ( addr_p0[n]                   ),
        .address_b  ( addr_p1[n]                   ),
        .clock      ( clk_i                        ),
        .data_a     ( amm_slave_lut_writedata_i[0] ),
        .data_b     ( '0                           ),
        .wren_a     ( wr_en                        ),
        .wren_b     ( 1'b0                         ),
        .q_a        ( q_0                          ),
        .q_b        ( q_1                          )
      );

      assign rd_data_p0[n] = ( config_i ) ?
                             ( 1'b0     ) :
                             ( q_0      );

      assign rd_data_p1[n] = ( config_i ) ?
                             ( 1'b0     ) :
                             ( q_1      );
      /*
      assign rd_data_p0[n] = 1'b1;
      assign rd_data_p1[n] = 1'b1;
      */
    end
endgenerate


endmodule

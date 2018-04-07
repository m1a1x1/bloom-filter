import bloom_filter_regs_pkg::*;

module bloom_filter_csr #(
  parameter AMM_CSR_ADDR_W = 8,
  parameter AMM_CSR_DATA_W = 8,
  parameter MAX_STR_SIZE   = 1,
  parameter MIN_STR_SIZE   = 1,
  parameter ENGINES_CNT    = 1,

  parameter MATCH_CNT_CNT  = (MAX_STR_SIZE-MIN_STR_SIZE+1)*ENGINES_CNT
)(
  input                                                clk_i,
  input                                                srst_i,

  input        [AMM_CSR_ADDR_W-1:0]                    amm_slave_csr_address_i,
  input                                                amm_slave_csr_read_i,
  output logic [AMM_CSR_DATA_W-1:0]                    amm_slave_csr_readdata_o,
  input                                                amm_slave_csr_write_i,
  input        [AMM_CSR_DATA_W-1:0]                    amm_slave_csr_writedata_i,

  output                                               en_o,
  /*
  input        [MATCH_CNT_CNT-1:0][AMM_CSR_DATA_W-1:0] matches_cnt_i,
  output       [MATCH_CNT_CNT-1:0]                     matches_cnt_clean_stb_o,
  */
  output                                               hash_lut_clean_stb_o,
  input                                                hash_lut_clean_done_i
);

//localparam REGS_CNT = MATCH_CNT_CNT+BASIC_REGS_CNT;
localparam REGS_CNT = BASIC_REGS_CNT;

logic [REGS_CNT-1:0][AMM_CSR_DATA_W-1:0] all_regs;

logic                                         en;

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      amm_slave_csr_readdata_o <= '0;
    else
      begin
        if( amm_slave_csr_read_i )
          amm_slave_csr_readdata_o <= all_regs[ amm_slave_csr_address_i ]; 
      end
  end

always_comb
  begin
    all_regs[ EN ]    = '0;
    all_regs[ EN ][0] = en;

    all_regs[ HASH_LUT_CLEAN ]    = '0;
    all_regs[ HASH_LUT_CLEAN ][0] = !hash_lut_clean_done_i;
    /*
    for( int i = 0; i < MATCH_CNT_CNT; i++ )
      all_regs[MATCH_CNT_BASE+i] = matches_cnt_i[i];
    */
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      en <= 1'b0;
    else
      begin
        if( ( amm_slave_csr_write_i         ) && 
            ( amm_slave_csr_address_i == EN ) )
          en <= amm_slave_csr_writedata_i[0];
      end
  end
/*
generate
  genvar n;
  for( n = 0; n < MATCH_CNT_CNT; n++ )
    begin: clean_match_stat_stb
      assign matches_cnt_clean_stb_o[n] = ( amm_slave_csr_address_i == (MATCH_CNT_BASE+n) ) &&
                                          ( amm_slave_csr_read_i                          );
    end
endgenerate
*/
assign hash_lut_clean_stb_o = ( amm_slave_csr_address_i == HASH_LUT_CLEAN ) &&
                              ( amm_slave_csr_write_i                     ) &&
                              ( amm_slave_csr_writedata_i[0]              );

assign en_o = en;

endmodule

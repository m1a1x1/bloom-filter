module amm_writer #(
  parameter int AMM_DATA_W = 5,
  parameter int AMM_ADDR_W = 5,
  parameter     DATA       = '0
)(
  input                         clk_i,
  input                         srst_i,

  input                         run_stb_i,
  output                        done_o, 

  input        [AMM_ADDR_W-1:0] amm_slave_address_i,
  input                         amm_slave_write_i,
  input        [AMM_DATA_W-1:0] amm_slave_writedata_i,

  output logic [AMM_ADDR_W-1:0] amm_master_address_o,
  output logic                  amm_master_write_o,
  output logic [AMM_DATA_W-1:0] amm_master_writedata_o
);

logic                  done;
logic [AMM_ADDR_W-1:0] cnt;

always_comb
  begin
    if( done )
      begin
        amm_master_address_o   = amm_slave_address_i;
        amm_master_write_o     = amm_slave_write_i;
        amm_master_writedata_o = amm_slave_writedata_i;
      end
    else
      begin
        amm_master_address_o   = cnt;
        amm_master_write_o     = 1'b1;
        amm_master_writedata_o = DATA;
      end
  end

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      begin
        done <= 1'b1;
      end
    else
      begin
        if( run_stb_i )
          done <= 1'b0;
        else
          begin
            if( &(cnt) )
              done <= 1'b1;
          end
      end
  end

always_ff @( posedge clk_i )
  begin
    if( run_stb_i )
      cnt <= '0;
    else
      begin
        if( !done )
          cnt <= cnt + AMM_ADDR_W'(1);
      end
  end

assign done_o = done;

endmodule

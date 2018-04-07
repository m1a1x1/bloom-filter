vlib work

vlog /home/mt/Altera/16.1/quartus/eda/sim_lib/altera_mf.v
vlog -sv ../rtl/bloom_filter_regs_pkg.sv
vlog -sv ../rtl/crc_pkg.sv
vlog -sv ../rtl/true_dp_ram.sv
vlog -sv ../rtl/amm_writer.sv
vlog -sv ../rtl/ast_shift.sv
vlog -sv ../rtl/bloom_filter_csr.sv
vlog -sv ../rtl/crc.sv
vlog -sv ../rtl/data_dc_fifo.sv
vlog -sv ../rtl/data_delay.sv
vlog -sv ../rtl/data_delay_pipeline_ready.sv
vlog -sv ../rtl/data_to_ast.sv
vlog -sv ../rtl/hash_lut.sv
vlog -sv ../rtl/one_hot_arb.sv
vlog -sv ../rtl/one_hot_ast_mux.sv
vlog -sv ../rtl/strings_mux.sv
vlog -sv ../rtl/hasher.sv
vlog -sv ../rtl/one_str_size_bloom_engine.sv
vlog -sv ../rtl/bloom_search_engine.sv
vlog -sv ../rtl/bloom_filter.sv

vlog -sv ast_port_pkg.sv
vlog -sv avalon_st_if.sv
vlog -sv top_tb.sv

vsim -novopt top_tb

add wave -hex -r top_tb/*

run -all

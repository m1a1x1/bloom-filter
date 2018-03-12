vlib work

vlog -sv ../../rtl/bloom_filter_pkg.sv
vlog -sv ../../rtl/ast_shift.sv
vlog -sv ../ast_port_pkg.sv
vlog -sv ../avalon_st_if.sv

vlog top_ast_shift_tb.sv

vsim -novopt top_ast_shift_tb

add wave -hex -r top_ast_shift_tb/*

run -all

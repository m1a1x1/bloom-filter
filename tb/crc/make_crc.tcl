vlib work

vlog -sv ../../rtl/crc_pkg.sv
vlog -sv ../../rtl/crc.sv
vlog -sv top_crc_tb.sv

vsim -novopt top_crc_tb

add wave -hex -r top_crc_tb/*

run -all

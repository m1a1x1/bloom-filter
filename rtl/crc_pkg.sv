package crc_pkg;

parameter MAX_HASH_W                = 16;
parameter bit [15:0] CRC_INITS [20] = '{ 16'd1,
                                         16'd2,
                                         16'd3,
                                         16'd4,
                                         16'd5,
                                         16'd6,
                                         16'd7,
                                         16'd8,
                                         16'd9,
                                         16'd10,
                                         16'd11,
                                         16'd12,
                                         16'd13,
                                         16'd14,
                                         16'd15,
                                         16'd16,
                                         16'd17,
                                         16'd18,
                                         16'd19,
                                         16'd20
                                       };

// CRC 16 0x8d95
//-----------------------------------------------------------------------------
// Copyright (C) 2009 OutputLogic.com 
// This source file may be used and distributed without restriction 
// provided that this copyright statement is not removed from the file 
// and that any derivative work contains the original copyright notice 
// and the associated disclaimer. 
// 
// THIS SOURCE FILE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS 
// OR IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED  
// WARRANTIES OF MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE. 
//-----------------------------------------------------------------------------
// CRC module for data[7:0],   crc[15:0]=1+x^2+x^4+x^7+x^8+x^10+x^11+x^15+x^16;
//-----------------------------------------------------------------------------

function logic [15:0] crc_8d95 (
  input [7:0]   byte_in,
  input [15:0]  prev_res
);
  logic [15:0] lfsr_q,lfsr_c;

  lfsr_q = prev_res;

	lfsr_c[0] = lfsr_q[8] ^ lfsr_q[9] ^ lfsr_q[10] ^ lfsr_q[11] ^ lfsr_q[12] ^ byte_in[0] ^ byte_in[1] ^ byte_in[2] ^ byte_in[3] ^ byte_in[4];
	lfsr_c[1] = lfsr_q[9] ^ lfsr_q[10] ^ lfsr_q[11] ^ lfsr_q[12] ^ lfsr_q[13] ^ byte_in[1] ^ byte_in[2] ^ byte_in[3] ^ byte_in[4] ^ byte_in[5];
	lfsr_c[2] = lfsr_q[8] ^ lfsr_q[9] ^ lfsr_q[13] ^ lfsr_q[14] ^ byte_in[0] ^ byte_in[1] ^ byte_in[5] ^ byte_in[6];
	lfsr_c[3] = lfsr_q[9] ^ lfsr_q[10] ^ lfsr_q[14] ^ lfsr_q[15] ^ byte_in[1] ^ byte_in[2] ^ byte_in[6] ^ byte_in[7];
	lfsr_c[4] = lfsr_q[8] ^ lfsr_q[9] ^ lfsr_q[12] ^ lfsr_q[15] ^ byte_in[0] ^ byte_in[1] ^ byte_in[4] ^ byte_in[7];
	lfsr_c[5] = lfsr_q[9] ^ lfsr_q[10] ^ lfsr_q[13] ^ byte_in[1] ^ byte_in[2] ^ byte_in[5];
	lfsr_c[6] = lfsr_q[10] ^ lfsr_q[11] ^ lfsr_q[14] ^ byte_in[2] ^ byte_in[3] ^ byte_in[6];
	lfsr_c[7] = lfsr_q[8] ^ lfsr_q[9] ^ lfsr_q[10] ^ lfsr_q[15] ^ byte_in[0] ^ byte_in[1] ^ byte_in[2] ^ byte_in[7];
	lfsr_c[8] = lfsr_q[0] ^ lfsr_q[8] ^ lfsr_q[12] ^ byte_in[0] ^ byte_in[4];
	lfsr_c[9] = lfsr_q[1] ^ lfsr_q[9] ^ lfsr_q[13] ^ byte_in[1] ^ byte_in[5];
	lfsr_c[10] = lfsr_q[2] ^ lfsr_q[8] ^ lfsr_q[9] ^ lfsr_q[11] ^ lfsr_q[12] ^ lfsr_q[14] ^ byte_in[0] ^ byte_in[1] ^ byte_in[3] ^ byte_in[4] ^ byte_in[6];
	lfsr_c[11] = lfsr_q[3] ^ lfsr_q[8] ^ lfsr_q[11] ^ lfsr_q[13] ^ lfsr_q[15] ^ byte_in[0] ^ byte_in[3] ^ byte_in[5] ^ byte_in[7];
	lfsr_c[12] = lfsr_q[4] ^ lfsr_q[9] ^ lfsr_q[12] ^ lfsr_q[14] ^ byte_in[1] ^ byte_in[4] ^ byte_in[6];
	lfsr_c[13] = lfsr_q[5] ^ lfsr_q[10] ^ lfsr_q[13] ^ lfsr_q[15] ^ byte_in[2] ^ byte_in[5] ^ byte_in[7];
	lfsr_c[14] = lfsr_q[6] ^ lfsr_q[11] ^ lfsr_q[14] ^ byte_in[3] ^ byte_in[6];
	lfsr_c[15] = lfsr_q[7] ^ lfsr_q[8] ^ lfsr_q[9] ^ lfsr_q[10] ^ lfsr_q[11] ^ lfsr_q[15] ^ byte_in[0] ^ byte_in[1] ^ byte_in[2] ^ byte_in[3] ^ byte_in[7];

  return lfsr_c;
endfunction

endpackage

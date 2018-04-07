package bloom_filter_pkg;

parameter int BYTE_W           = 8;
parameter int AST_SINK_SYMBOLS = 8;

parameter int AMM_CSR_DATA_W   = 16;
parameter int AMM_CSR_ADDR_W   = 12;

// Only 1 lowest bit is used
parameter int AMM_LUT_DATA_W   = 8;

// Addres forming in the next way:
//   Lowes bits are for hash values. In mode 0 and with HASH_W less the 13
//   bits (M10 memory width) it is 13 lowes bits. In other cases it is HASH_W
//   bits.
//   Next whole address is number of memory block. See README.md to find out,
//   how to calculate block number based on hash function number, string
//   length and current mode.
parameter int AMM_LUT_ADDR_W = 18;

parameter int MIN_STR_SIZE = 3;

// Maximum string length for search.
// Must be more or eq 1 and more or eq MIN_STR_SIZE and less then 32.
parameter int MAX_STR_SIZE = 5;

parameter int HASHES_CNT = 6;

parameter int HASH_W     = 10;

// Mode for storing hash functions:
//   0 -- each hash function is in seporate memory space
//   1 -- each 2 hash functions of the same string size engine storing in
//        one memory space
parameter int HASH_LUT_MODE = 1;

parameter int OUTPUT_FIFO_DEPTH = 128;

// Registers:
parameter EN             = 0;
parameter HASH_LUT_CLEAN = 1;
parameter MATCH_CNT_BASE = 2;
parameter MATCH_CNT_CNT  = (MAX_STR_SIZE-MIN_STR_SIZE+1)*AST_SINK_SYMBOLS;

parameter REGS_CNT = MATCH_CNT_CNT+2;

endpackage

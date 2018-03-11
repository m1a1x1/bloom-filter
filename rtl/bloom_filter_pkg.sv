package bloom_filter_pkg;

parameter int BYTE_W         = 8;

parameter int AMM_CSR_DATA_W = 32;
parameter int AMM_CSR_ADDR_W = 32;

parameter int AMM_LUT_DATA_W = 32;
parameter int AMM_LUT_ADDR_W = 32;

parameter int MIN_STR_SIZE   = 3;
// Maximum string length for search.
// Must be more or eq 1 and more or eq MIN_STR_SIZE.
parameter int MAX_STR_SIZE   = 20;

endpackage

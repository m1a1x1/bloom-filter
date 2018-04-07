import mem

BLOOM_OFFSET       = 0
BLOOM_DEV          = './mem.txt'
HASH_LUT_DUMP_FILE = '../hash_lut_dump'

bloom = mem.Memory( BLOOM_DEV )
with open(HASH_LUT_DUMP_FILE, 'r') as f:
  lines = f.readlines()
  lines = [_.split() for _ in lines]
  for l in lines:
    addr = int(l[0])
    data = int(l[1])
    bloom.write8( addr, data )

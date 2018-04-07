#!/usr/bin/python3

import crc_algorithms as ca
import functools
import argparse
from argparse import RawTextHelpFormatter
import random
import sys
import math as m

MAX_STRING_LEN = 5
MIN_STRING_LEN = 3
STRING_TO_ADD_CNT = 1
M10K_ADDR_W = 13

OUTPUT_DIR = '../'

class BloomOneLen( ):
  def __init__( self, length, rom, hashes_keys, hash_f ):
    self.length = length
    self.rom = rom
    self.hashes_cnt = len(hashes_keys)
    self.hashes_keys = hashes_keys
    self.hash_f = hash_f
  
  def calc_hashes( self, string ):
    hashes_res = [None for _ in range(self.hashes_cnt)]
    for i in range(self.hashes_cnt):
        hashes_res[i] = self.hash_f( self.hashes_keys[i], string )

    return( hashes_res )
  
  def check_match( self, string ):
    hashes_results = self.calc_hashes( string )
    for i in range( self.hashes_cnt ):
      if ( self.rom[i][ hashes_results[i] ] == 0 ):
        return False

    for i in string:
        print( i )
    print( hashes_results )
    return True

  def check_long_string ( self, long_string ):
    for i in range( len( long_string ) - self.length + 1):
      send_to_check = long_string[ i : ( self.length + i ) ]

      if self.check_match( send_to_check ):
        return True

    return False

  def check_string ( self, string ):
    if self.check_match( string ):
      print( string )
      return True
    return False

def write_data_file( data, fname ):
  f = open( fname, 'w' )
  for d in data:
    for i in d:
      f.write( str(i) + " " )
    f.write("\n")
  f.close()

def write_rom_dump( rom, mode, hashes_cnt, hash_w, fname ):

    block_offset = hash_w
    if( mode == 0 ):
        if( hash_w < M10K_ADDR_W ):
          blocks_cnt =  m.ceil((MAX_STRING_LEN-MIN_STRING_LEN+1)*hashes_cnt/2)
          block_offset = M10K_ADDR_W
        else:
          blocks_cnt = (MAX_STRING_LEN-MIN_STRING_LEN+1) * hashes_cnt
    elif( mode == 1 ):
        blocks_cnt = (MAX_STRING_LEN-MIN_STRING_LEN+1) * (hashes_cnt/2)

    blocks_cnt = int(blocks_cnt)

    f = open( fname, 'w' )
    for i in range(blocks_cnt):
        print( i )
        if( mode == 0 ):
          if( hash_w >= M10K_ADDR_W ):
            addr_base = i << hash_w
            for j in range(2**hash_w):
              addr = addr_base | ( j & ((2**hash_w) - 1) )
              if( rom[MIN_STRING_LEN+int(i/hashes_cnt)][i%hashes_cnt][j] == 0 ):
                  data = 0
              else:
                  data = 1
              f.write(str(addr)+' '+str(data)+ '\n')
          else:
            addr_base = i << M10K_ADDR_W
            for j in range(2**hash_w):
              addr_h1 = addr_base | ( j & ((2**hash_w) - 1) )
              addr_h2 = addr_h1 | (1 << hash_w)

              if( rom[MIN_STRING_LEN+int((i*2)/hashes_cnt)][(i*2)%hashes_cnt][j] == 0 ):
                  data_h1 = 0
              else:
                  data_h1 = 1

              f.write(str(addr_h1)+' '+str(data_h1)+'\n')
              
              try:
                  if( rom[MIN_STRING_LEN+int((i*2+1)/hashes_cnt)][(i*2+1)%hashes_cnt][j] == 0 ):
                      data_h2 = 0
                  else:
                      data_h2 = 1
                  f.write(str(addr_h2)+' '+str(data_h2)+'\n')
              except IndexError:
                  continue
        elif( mode == 1 ):
            addr_base = i << hash_w 
            for j in range(2**hash_w):
              addr = addr_base | ( j & ((2**hash_w) - 1) )

              if( rom[MIN_STRING_LEN+int((i*2)/hashes_cnt)][(i*2)%hashes_cnt][j] == 0 ):
                  data_h1 = 0
              else:
                  data_h1 = 1

              if( rom[MIN_STRING_LEN+int((i*2+1)/hashes_cnt)][(i*2+1)%hashes_cnt][j] == 0 ):
                  data_h2 = 0
              else:
                  data_h2 = 1
              
              data = data_h1 | data_h2
              f.write(str(addr)+' '+str(data)+'\n')

def crc_wrap( init, data, hash_width ):

  data_int = 0
  for i in range(len(data)):
      data_int |= (data[i]) << (i)*8
  data = int.to_bytes(data_int,len(data),byteorder='little')

  crc = ca.Crc(width = 16, poly = 0x8d95,
            reflect_in = False, xor_in = init,
            reflect_out = False, xor_out = 0x0)
  return (crc.bit_by_bit(data) % (2**hash_width))

def gen_crc_inits(hashes_cnt):
  crc_inits_per_len = [ i for i in range(1,hashes_cnt+1) ]
  inits = [ crc_inits_per_len for _ in range(MAX_STRING_LEN+1)]
  return inits

def gen_unic_strings( cnt ):
    strings = [None for _ in range(MAX_STRING_LEN+1)]
    for i in range(MIN_STRING_LEN, MAX_STRING_LEN+1):
      strings[i] = gen_unic_strings_len(cnt, i)
    return (strings)

def gen_unic_strings_len( cnt, length ):
    strings_one_len = set()
    if( 2**(8*length) <= cnt ):
      for i in range( 2**(8*length) ):
        strings_one_len.add(int.to_bytes(i,length,byteorder='big'))
    else:    
      while(len(strings_one_len)<cnt):
        strings_one_len.add(bytes(random.getrandbits(8) for _ in range(length)))
    return list(strings_one_len)

def count_m10k( string_sizes_cnt, hash_w, hashes_cnt ):
    M10K_SIZE = 10240
          
    if( mode == 0 ):
      memory_used = string_sizes_cnt*hashes_cnt*(2**hash_w)

      if( hash_w <= M10K_ADDR_W ):
        coef = 2**(M10K_ADDR_W - hash_w)
        if( coef > 2 ):
          coef = 2.0
        m10k_cnt_2_ports = m.ceil(string_sizes_cnt*hashes_cnt/coef)
      else:
        coef = 2**(hash_w-M10K_ADDR_W)
        m10k_cnt_2_ports = m.ceil(string_sizes_cnt*hashes_cnt*coef)

    elif( mode == 1 ):
      memory_used = string_sizes_cnt*hashes_cnt/2*(2**hash_w)

      if( hash_w <= M10K_ADDR_W ):
        coef = 2**(M10K_ADDR_W - hash_w)
        if( coef > 2 ):
          coef = 2.0
        m10k_cnt_2_ports = m.ceil(string_sizes_cnt*hashes_cnt/2)
      else:
        coef = 2**(hash_w-M10K_ADDR_W)
        m10k_cnt_2_ports = m.ceil(string_sizes_cnt*(hashes_cnt/2)*coef)

    return m10k_cnt_2_ports

def init_rom( hashes_cnt, hash_w ):
    rom = [None for _ in range(MAX_STRING_LEN+1)]

    for i in range(len(rom)):
      rom[i] = [None for _ in range(hashes_cnt)]
      for j in range(hashes_cnt):
          rom[i][j] = [0 for _ in range(2**hash_w)]

    return(rom)


def fill_rom( cur_rom, strings_to_search, hashes_cnt, hashes_keys, hash_f, mode, hash_w ):
    rom = cur_rom
    if( mode == 0 ):
      # Every hash function in it's seporate memory
      # Fill memory:
      for s in strings_to_search:
        for i in range(hashes_cnt):
          rom[len(s)][i][hash_f(hashes_keys[len(s)][i],s)] += 1

    elif( mode == 1 ):
      # Every two hashes from the same word lengths putted to same memory. 
      if( hashes_cnt % 2 != 0 ):
          print( "In mode 1 --hashes must be devided by 2" )
          sys.exit(0)

      for s in strings_to_search:
        for i in range(int(hashes_cnt/2)):
          rom[len(s)][i*2][hash_f(hashes_keys[len(s)][i*2],s)] += 1
          rom[len(s)][i*2][hash_f(hashes_keys[len(s)][i*2+1],s)] += 1

          rom[len(s)][i*2+1][hash_f(hashes_keys[len(s)][i*2],s)] += 1
          rom[len(s)][i*2+1][hash_f(hashes_keys[len(s)][i*2+1],s)] += 1

    return(rom)

def gen_data_with_strings( strings, data ):
  strings = random.sample(strings,k=len(strings) )
  data_with_strings = list()
  for i in range(len(strings)):
      new_data = random.sample(data, k=1)[0]
      new_data = b"".join([new_data, strings[i]])
      new_data = b"".join([new_data, random.sample(data, k=1)[0]])
      data_with_strings.append(new_data)
  return ( data_with_strings )

if __name__ == "__main__":

  parser = argparse.ArgumentParser( description='Reference model of Bloom pattern search.', prefix_chars='--', formatter_class=RawTextHelpFormatter)

  parser.add_argument('--mode', metavar='memb_arrange_mode', type=int,
                       help='Number of memory arrangment mode:\n \
* 0 - each hash function for each string length is seporated;\n \
* 1 - each 2 hashes for same strings length shares the same memory;')

  parser.add_argument('--hashes', metavar='hashes_cnt', type=int,
                      help='Hashes amount for each string length.\n \
Otional.\n \
Posible values:\n \
* > 0 for mode 0\n \
* devided by 2 for mode 1')

  parser.add_argument('--hashw', metavar='hash_w', type=int,
                      help='Hash width = maximum amount of string in memory.\n \
Posible values:\n \
* 0 < hashw <= 16\n')

  args = parser.parse_args()
  parsed_args = vars(args)

  if( parsed_args[ 'mode' ] is not None ):
    mode = parsed_args[ 'mode' ] 
    if( ( mode < 0 ) or ( mode > 1 ) ):
        print( "Wrong mode!" )
        print( "Use -h for help" )
        sys.exit( 0 ) 
    print( "Mode set:", mode )
  else:
    print( "No mode was set!" )
    print( "Use -h for help" )
    sys.exit( 0 ) 

  if( parsed_args[ 'hashes' ] is not None ):
    hashes_cnt = parsed_args[ 'hashes' ]
    if( hashes_cnt <= 0 ):
        print( "Wrong hashes!" )
        print( "Use -h for help" )
        sys.exit( 0 ) 
    print( "Hashes set:", hashes_cnt )
  else:
    print( "No hashes was set!" )
    print( "Use -h for help" )
    sys.exit( 0 ) 
   
  if( parsed_args[ 'hashw' ] is not None ):
    hash_w = parsed_args[ 'hashw' ]
    if( (hash_w <= 0) or (hash_w > 16) ):
        print( "Wrong hashw!" )
        print( "Use -h for help" )
        sys.exit( 0 ) 
    print( "Hashw set:", hash_w )
  else:
    print( "No hashw was set!" )
    print( "Use -h for help" )
    sys.exit( 0 ) 

  crc_cut   = functools.partial(crc_wrap, hash_width=hash_w)
  crc_inits = gen_crc_inits(hashes_cnt)

  m10k_cnt_2p = count_m10k( MAX_STRING_LEN-MIN_STRING_LEN+1, hash_w, hashes_cnt )

  rom = init_rom( hashes_cnt, hash_w )
  unic_strings = gen_unic_strings(STRING_TO_ADD_CNT*2)
  strings_in_rom = list()
  strings_not_in_rom = list()

  for _len in range(MIN_STRING_LEN,MAX_STRING_LEN+1):
    unic_strings_len = unic_strings[_len]
    strings_to_add   = unic_strings_len[:STRING_TO_ADD_CNT]
    rom = fill_rom( rom, strings_to_add, hashes_cnt, crc_inits, crc_cut, mode, hash_w )
    for i in strings_to_add:
        strings_in_rom.append(i)

    strings_not_to_add = unic_strings_len[STRING_TO_ADD_CNT:]

    for i in strings_not_to_add:
        strings_not_in_rom.append(i)

  data_with_strings    = gen_data_with_strings( strings_in_rom, strings_not_in_rom )
  data_without_strings = strings_not_in_rom

  data_to_check = data_with_strings + data_without_strings
  data_to_check = random.sample(data_to_check,k=len(data_to_check) )

  ref_results = list()

  all_blooms = [None for _ in range(MAX_STRING_LEN+1)]

  for i in range(MIN_STRING_LEN,MAX_STRING_LEN+1):
    bloom = BloomOneLen(i, rom[i], crc_inits[i], crc_cut)
    all_blooms[i] = bloom

  for s in data_to_check:
    for i in range(MIN_STRING_LEN,MAX_STRING_LEN+1): 
      bloom = all_blooms[i]
      all_subs_cnt = (len(s) - i + 1)
      if( all_subs_cnt > 0 ):
        for j in range( all_subs_cnt ):
          res = bloom.check_string( s[j:i+j] )
          if( res ):
            ref_results.append(s[j:i+j])

  write_data_file( data_to_check, OUTPUT_DIR+'packets_to_send' )
  write_data_file( ref_results, OUTPUT_DIR+'ref_packets' )
  write_rom_dump( rom, mode, hashes_cnt, hash_w, OUTPUT_DIR+'hash_lut_dump' )

  #with open(result_fname, 'w') as f:
  #  f.write('M10K2p %d\n' % m10k_cnt_2p)
  #  f.write('M10K4p %d\n' % m10k_cnt_4p)

  #  for i in range(MIN_STRING_LEN,MAX_STRING_LEN+1):
  #    f.write('Len %d\n' % i)
  #    for j in range(STRING_TO_ADD_CNT):
  #      line  = '%d ' % (j+1)
  #      for k in range(EXPEREMENTS_CNT):
  #        line +='%0.6f ' % (results[k][i][j]/STRING_TO_CHECK_CNT)
  #      line += '\n'
  #      f.write(line)

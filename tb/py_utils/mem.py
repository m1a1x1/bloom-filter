#!/usr/bin/python3

import threading
import os
import mmap
import time as t


class Memory():
  def __init__(self, dev):
    self.lock  = threading.Lock()
    self.dev = dev

  def read(self, addr, bytes_cnt):
    with self.lock:
      fd = os.open( self.dev, os.O_RDWR )
      offset = addr & ~(4096-1)
      mem=mmap.mmap( fd, length=4096, offset=offset ) 
      mem.seek(addr-offset)
      data_bytestring = mem.read(bytes_cnt)
      mem.close()
      os.close( fd )
      return int.from_bytes( data_bytestring, byteorder='little', signed=False )

  def write(self, addr, value, bytes_cnt ):
    with self.lock:
      fd = os.open( self.dev, os.O_RDWR )
      offset = addr & ~(4096-1)
      mem=mmap.mmap( fd, length=4096, offset=offset ) 
      mem.seek(addr-offset)
      value_b = value.to_bytes(bytes_cnt, byteorder='little' )
      mem.write( value_b )
      mem.close()
      os.close( fd )

  def read32(self, addr):
    return self.read(addr, 4)

  def write32(self, addr, value ):
    self.write(addr, value, 4)

  def write64(self, addr, value ):
    self.write(addr, value, 8)

  def read64(self, addr ):
    return self.read(addr, 8)

  def write16(self, addr, value ):
    self.write(addr, value, 2)

  def read16(self, addr ):
    return self.read(addr, 2)

  def write8(self, addr, value ):
    self.write(addr, value, 1)

  def read8(self, addr ):
    return self.read(addr, 1)

  def waitNot0(self, addr ):
    res = self.read32(addr)
    while res == 0 :
      t.sleep(0.5)
      res = self.read32(addr)
    return True

if __name__ == "__main__":
  mem = Memory( "./tst" )
  a = mem.read32(0)


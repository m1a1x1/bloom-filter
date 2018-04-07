Bloom-filter on FPGA
====================

Synopsis
--------

This is IP-core of highly parametrized Bloom-filter implementation on internal 
memory.

All interfaces are compatible with Avalon specifications:

  * Avalon ST sink - interface for input packets. Strings will be searched in data comming from this interface.
  * Avalon ST source - output packet interface with only suspicious strings (as Bloom filter can gave false-positive result). 
  * Avalon MM CSR - interface for configuring filter.
  * Avalon MM lut hash - interface for writing strings in memory for search.

Build
-----

  * Add qsys/bloom_filter_hw.tcl into your Qsys project.
  * Configure parameters (with Qsys).
  * Build firmware.

Structure
---------

  * ./example/: project example for testing Fmax and resource utilization.
  * ./qsys/: Qsys *hw.tcl IP-core description.
  * ./rtl/: SystemVerilog source code.
  * ./tb/: Testbench
  * ./tb/py_utils/: Utils for both testbench input data generating and checking and configuring Bloom-filter in real hardware.

Testbench
---------

Author
------

  * Maksim Tolkachev

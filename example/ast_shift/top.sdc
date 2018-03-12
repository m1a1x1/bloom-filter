#**************************************************************                 
# Time Information                                                              
#**************************************************************                 
                                                                                
set_time_format -unit ns -decimal_places 3                                      
                                                                                
create_clock -name {clk} -period 6.400 -waveform { 0.000 3.200 } [get_ports {clk_i}]

derive_clock_uncertainty

#**************************************************************                 
# Time Information                                                              
#**************************************************************                 
                                                                                
set_time_format -unit ns -decimal_places 3                                      
                                                                                
create_clock -name {clk_156_25} -period 6.400 -waveform { 0.000 3.200 } [get_ports {clk_156_25_i}]
create_clock -name {clk_125} -period 8.000 -waveform { 0.000 4.000 } [get_ports {clk_125_i}]

derive_clock_uncertainty

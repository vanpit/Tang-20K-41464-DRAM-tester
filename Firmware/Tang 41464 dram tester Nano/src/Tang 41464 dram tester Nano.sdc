//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.11.03 Education 
//Created Time: 2026-03-24 17:58:50
create_clock -name clk -period 30.303 -waveform {0 15.152} [get_ports {clk}]
create_clock -name clk_dramroutines -period 6.061 -waveform {0 3.03} [get_nets {clk_dramroutines}]
set_clock_groups -asynchronous -group [get_clocks {clk}] -group [get_clocks {clk_dramroutines}]

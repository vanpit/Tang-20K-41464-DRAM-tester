//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.11.03 Education 
//Created Time: 2026-03-14 23:34:25
create_clock -name clk -period 37.037 -waveform {0 18.518} [get_ports {clk}]
create_clock -name clk_dramroutines -period 5.291 -waveform {0 2.646} [get_nets {clk_dramroutines}]
set_clock_groups -asynchronous -group [get_clocks {clk}] -group [get_clocks {clk_dramroutines}]

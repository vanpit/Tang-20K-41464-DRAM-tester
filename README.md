Tang Primer 20K & Tang Nano 20K 41464 DRAM Tester

Timing resolution is 5.29ns for Primer 20K version and 6.06ns for Nano 20K version

- 8 different patterns WRITE/READ
- MATS+
- 4ms (datasheet) data retention 

BOM:

- Tang Primer 20K + Lite dock + PMOD LEDx8 module + Sipeed RV Debugger Plus
  OR
- Tang Nano 20K
  
- U1, U2: SN74AHCT245PWR
- U3: SN74LVC8T245PW
- U4: MIC94090YC6-TR
- LED SMD 0805 ex. IN-S85CS5R
- R1, R2: 5K Ohm Resistor SMD 0805
- R3..R10: 33 Ohm Resistor SMD 0805
- R11..R14, R16: 10K Ohm Resistor SMD 0805
- R15: 1K Ohm Resistor SMD 0805
- R17..R24: 0 Ohm OR 33 Ohm Resistor SMD 0805
- C1..C7: 100nF 0805 Capacitor
- ZIF Socket 18 pin
- 40 pin (2x20) 90 deg female connector (ZL263-40DG) (Tang Primer only)
- 2x 20 male/female pin headers (Tang Nano only)
- 18 pin (1x18) 90 deg male connector (optional, for debug)

How to use:

- Assembly guide - Pictures
- Synthetize and program Tang with Gowin IDE.
  - For Primer 20K version use "Tang 41464 tester-1.1.zip" gerber files and "Tang 41464 dram tester" firmware project
  - For Nano 20K version use  "Tang 41464 tester Nano 1.1.zip" gerber files and "Tang 41464 dram tester Nano" firmware project
  - IMPORTANT! For Nano 20K version set "pll_clk O0=33M" in BL616 config as project use 10 PIN FPGA clock 
- Connect to uart module serial port with 115200 baud rate

Terminal keys
- "1", "2", "3", "4": select dram class speed test 80ns, 100ns, 120ns, 150ns
- "q", "Q": increase/decrease test repetition count (0x03FF reps takes about 10 minutes)
- "w": enable/disable 4ms delay/data retention test between write and read operations
- "c": show current test config
- "r" / lite dock T2 button / Nano 20K S1 button: start test

Tang Primer r20K 41464 DRAM Tester

- 8 different patterns WRITE/READ
- MATS+
- 4ms (datasheet) data retention 

BOM:

- Tang Primer 20K + Lite dock + PMOD LEDx8 module + Sipeed RV Debugger Plus
- U1: SN74LVC8T245PW
- U2, U3: SN74AHCT245PWR
- U4: MIC94090YC6-TR
- LED SMD 0805 ex. IN-S85CS5R
- R1, R2: 5K Ohm Resistor SMD 0805
- R3..R10: 33 Ohm Resistor SMD 0805
- R11..R14, R16: 10K Ohm Resistor SMD 0805
- R15: 1K Ohm Resistor SMD 0805
- R17..R24: O Ohm Resistor SMD 0805
- C1..C7: 100nF 0805 Capacitor
- ZIF Socket 18 pin
- 40 pin (2x20) 90 deg female connector (ZL263-40DG)
- 18 pin (1x18) 90 deg male connector (optional, for debug)

How to use:

- Assembly guide - Pictures
- Synthetize and program Tang with Gowin IDE.
- Connect to uart module serial port with 115200 baud rate

Terminal keys
- "1", "2", "3", "4": select dram class speed test 80ns, 100ns, 120ns, 150ns
- "q", "Q": increase/decrease test repetitions numbers (0x03FF reps takes about 10 minutes)
- "w": enable/disable 4ms delay/data retention test between write and read operations
- "c": show current test config
- "r" / lite dock T2 button: start test

this project is part of a question I posted on evvblog.com
https://www.eevblog.com/forum/fpga/gowin-vs-yosys/msg5404313/#msg5404313
Gowin (1) Yosys (0)

I have been trying to figure out why this design works in simulation but not on my device
I have been tracking down an off by one error "on-chip", that does not match simulations. 
If I build and load the verilog with yosys and nextpnr, the error is present and the design broken.
If I build this with GOWIN's toolchain, the design works as expected.

Dev board tang nano 9k.

UART.fs - Yosys/nextpnr

GOWIN_UART.fs - Gowin toolchain

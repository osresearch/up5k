
all: pulse.bin

pulse.blif: pulse.v
serial.blif: serial.v uart.v pll_32.v

include Makefile.icestorm

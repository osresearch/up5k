
all: pulse.bin

pulse.blif: pulse.v
serial.blif: serial.v uart.v util.v

include Makefile.icestorm

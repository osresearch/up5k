
all: pulse.bin

pulse.blif: pulse.v
serial.blif: serial.v


include Makefile.icestorm

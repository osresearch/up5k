
all: pulse.bin

pulse.blif: pulse.v
serial.blif: serial.v uart.v pll_96.v

pll_96.v:
	icepll \
		-i 48 \
		-o 96 \
		-m \
		-n pll_96 \
		-f pll_96.v \


include Makefile.icestorm

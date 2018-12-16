
all: pulse.bin

blink.blif: blink.v
pulse.blif: pulse.v util.v
serial.blif: serial.v uart.v util.v
serial-echo.blif: serial-echo.v uart.v util.v
spram-demo.blif: spram-demo.v spram.v uart.v util.v

include Makefile.icestorm

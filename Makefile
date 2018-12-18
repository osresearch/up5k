
all: pulse.bin blink.bin serial.bin serial-echo.bin spram-demo.bin lighthouse.bin

blink.blif: blink.v
pulse.blif: pulse.v util.v
serial.blif: serial.v uart.v util.v
serial-echo.blif: serial-echo.v uart.v util.v
spram-demo.blif: spram-demo.v spram.v uart.v util.v

lighthouse.blif: lighthouse.v

include Makefile.icestorm

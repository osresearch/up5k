
all: pulse.bin blink.bin serial.bin serial-echo.bin spram-demo.bin lighthouse.bin

blink.json: blink.v
pulse.json: pulse.v util.v
serial.json: serial.v uart.v util.v
serial-echo.json: serial-echo.v uart.v util.v
serial-hexdump.json: serial-hexdump.v
spram-demo.json: spram-demo.v spram.v uart.v util.v
spispy.json: spispy.v spi_device.v spram.v uart.v util.v


lighthouse.json: lighthouse-demo.v

include Makefile.icestorm

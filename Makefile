
all: PAINT.PRG


PAINT.PRG: paint.p8
	p8compile -target cx16 -sourcelines paint.p8
	mv paint.prg PAINT.PRG

emu: PAINT.PRG
	PULSE_LATENCY_MSEC=20 x16emu -scale 2 -quality best -run -prg $<

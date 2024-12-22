.PHONY:  all clean zip emu

all: PAINT.PRG

emu: all
	PULSE_LATENCY_MSEC=20 x16emu -scale 2 -quality best -run -prg PAINT.PRG

clean:
	rm -f *.prg *.PRG *.asm *.vice-* *.zip *.7z

PAINT.PRG: src/paint.p8 src/drawing.p8 src/colors.p8
	prog8c -target cx16 -sourcelines src/paint.p8
	mv paint.prg PAINT.PRG

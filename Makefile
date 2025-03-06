.PHONY:  all clean zip run

PROG8C ?= prog8c       # if that fails, try this alternative (point to the correct jar file location): java -jar prog8c.jar


all: PAINT.PRG

run: all
	PULSE_LATENCY_MSEC=20 x16emu -scale 2 -quality best -run -prg PAINT.PRG

clean:
	rm -f *.prg *.PRG *.asm *.vice-* *.zip *.7z

PAINT.PRG: src/paint.p8 src/drawing.p8 src/colors.p8
	$(PROG8C) -target cx16 src/paint.p8
	mv paint.prg PAINT.PRG

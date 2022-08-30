always: test.prg test.pgx test.pgz

test.prg: test.asm
test.pgx: test.asm
test.pgz: test.asm

%.prg:
	64tass	-b prg.asm $^ -o $@

%.pgx:
	64tass	-b pgx.asm $^ -o $@

%.pgz:
	64tass	-b pgz.asm $^ -o $@

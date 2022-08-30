always: test.prg test.pgx

test.prg: test.asm
test.pgx: test.asm

%.prg:
	64tass	-b prg.asm $^ -o $@

%.pgx:
	64tass	-b pgx.asm $^ -o $@


.PHONY: c asm

c: bf.c
	gcc -Wall -o bf $^

asm: bf.S
	as -o /tmp/bf.o $^
	ld -nostdlib /tmp/bf.o -o bf

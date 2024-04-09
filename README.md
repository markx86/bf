# bf
## a simple brainfuck interpreter

[!NOTE]
> This is a project I made in an afternoon, while at home with a fever.  
> If you see obvious bugs, now you know why.

**bf** is a simple brainfuck interpreter that can read a program from either stdin
or a file. It supports programs up to 32KB in size.  

The source code comes in two languages:
- **C**: this is the first version I made and it was a prototype for the second one
- **x86-64 assembly**: this is the second version, and it limits itself to using only
the original x86 registers (\*ax, \*bx, \*cx, \*dx, \*di, \*si), which *should* make
it easier to port to 32-bit, if I ever want to :^)

## usage

```bash
$ bf [INPUT-FILE]
```

where `INPUT-FILE` is an optional arguments, and is a valid path to a file containing
a valid brainfuck program. If no argument is provided or if INPUT-FILE is `-`, **bf**
will read the program from standard input.

[!NOTE]
> The program must under 32KB in size.

## building

To build the **C** version run:
```bash
$ make c
```

To build the **x86-64 assembly** version run:
```bash
$ make asm
```

[!WARNING]
> Both build targets will produce an executable called `bf` and will overwrite any
> existing file with that name in the same directory as the `makefile`.

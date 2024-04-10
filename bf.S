/**
 * Copyright (C) 2024 markx86
 * License GPLv3+: GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>
 *
 * Usage: bf [INPUT-FILE]
 *  Where INPUT-FILE is the path to a file containing a brainfuck program.
 *  If no argument is provided or if INPUT-FILE is -, the program is read
 *  from standard input.
 *  The maximum size of the program is 32KB.
 */

.section .text, "ax"

.equ MAX_PROG , (32 << 9)
.equ MAX_CELLS, (32 << 9)

.equ SYS_read , 0
.equ SYS_write, 1
.equ SYS_open , 2
.equ SYS_close, 3
.equ SYS_exit , 60

.global _start
_start:
  /* check if a file was provided */
  pop %rcx /* argc */
  /* if (argc >= 2) */
  cmp $2, %rcx
  jl 2f
  pop %rdi /* argv[0] */
  pop %rdi /* argv[1] */
  /* check if argv[1] == "-" */
  mov (%rdi), %rdx
  cmp $'-', %dl
  jne 1f
  cmp $0, %dh
  jne 1f
  xor %edi, %edi
  jmp 2f
1:
  /* rsi is already at 0 == O_RDONLY */
  mov $SYS_open, %al
  syscall
  cmp $0, %eax
  jl do_exit
  mov %eax, %edi
2:

  /* read in the program */
  mov $SYS_read, %rax
  /* rdi already holds the fd from which we should read the program */
  mov $prog, %rsi
  mov $MAX_PROG, %rdx
  syscall
  add %rsi, %rax
  push %rsi
  push %rax
  /* 8(%rsp) is the start of the program */
  /* 0(%rsp) is the end of the program */

  /* if we read the program from a file, it's about time we close that fd */
  test %rdi, %rdi
  jz 1f
  mov $SYS_close, %eax
  syscall
1:

  /* init vm */
  /* %rsi already points to `prog` so no need to mov it in there again */
  mov $cells, %rdi
  /* zero out cells */
  mov %rdi, %rdx
  mov $MAX_CELLS, %ecx
  shr $3, %ecx
  xor %eax, %eax
  rep stosq
  mov %rdx, %rdi

exec_loop:
  /* compute index in jump table */
  /* switch(*ip) */
  xor %edx, %edx
  mov $jump_table, %rbx
  xor %eax, %eax
  mov (%rsi), %al
  shl $4, %ax
  shr $4, %al
  xor %ah, %al
  test $1, %ah
  jnz 1f
  and $7, %al
1:
  xor %ah, %ah
  lea (%rbx,%rax,), %rbx
  mov (%rbx), %al
  add $switch_begin, %rax
  jmp *%rax

switch_begin:

/* case ',' */
io_inp:
  mov $SYS_read, %rax
  jmp do_io

/* case '.' */
io_out:
  mov $SYS_write, %rax
  inc %dl
  jmp do_io

/* case '>' */
incr_ptr:
  inc %rdi
  jmp clamp_ptr

/* case '<' */
decr_ptr:
  dec %rdi
  jmp clamp_ptr

/* case '+' */
incr_val:
  incb (%rdi)
  jmp switch_done

/* case '-' */
decr_val:
  decb (%rdi)
  jmp switch_done

/* case '[' */
skip_fwd:
  mov (%rdi), %cl
  test %cl, %cl
  jnz switch_done
  /* level = 0 */
skip_fwd_loop:
  /* while (++ip < &prog[prog_size]) */
  inc %rsi
  cmp 0(%rsp), %rsi
  jge switch_done
  mov (%rsi), %al
  /* if (*ip == '[') */
  cmp $'[', %al
  jne 1f
  inc %edx
  jmp 2f
1:
  /* else if (*ip == ']') */
  cmp $']', %al
  jne 2f
  /* if (level == 0) */
  test %edx, %edx
  jz switch_done
  /* else */
  dec %edx
2:
  jmp skip_fwd_loop

/* case ']' */
skip_bwd:
  mov (%rdi), %cl
  test %cl, %cl
  jz switch_done
  /* level = 0 */
skip_bwd_loop:
  /* while (--ip >= &prog[0]) */
  dec %rsi
  cmp 8(%rsp), %rsi
  jl switch_done
  mov (%rsi), %al
  /* if (*ip == ']') */
  cmp $']', %al
  jne 1f
  inc %edx
  jmp 2f
1:
  /* else if (*ip == '[') */
  cmp $'[', %al
  jne 2f
  /* if (level == 0) */
  test %edx, %edx
  jz switch_done
  /* else */
  dec %edx
2:
  jmp skip_bwd_loop

do_io:
  push %rsi
  mov %rdi, %rsi
  mov %edx, %edi
  xor %edx, %edx
  inc %dl
  syscall
  mov %rsi, %rdi
  pop %rsi
  jmp switch_done

def_case:
  mov (%rsi), %al
  movzx %al, %rax
  jmp do_exit

clamp_ptr:
  /* check that the pointer to the cells is within bounds
     and if not, adjust it */
  mov %rdi, %rax
  sub $cells, %rax
  jl 1f
  cmp $MAX_CELLS, %rax
  jl switch_done
  sub $MAX_CELLS, %rdi
  jmp switch_done
1:
  add $MAX_CELLS, %rdi

switch_done:
  /* increment the program counter %rsi and check
     if we just executed the last instruction of the program */
  inc %rsi
  mov %rsi, %rax
  cmp 0(%rsp), %rax
  jl exec_loop

  mov $0, %rdi
do_exit:
  mov $SYS_exit, %rax
  syscall



.section .rodata, "a"

jump_table:
  .byte (def_case    - switch_begin) /* 0 -> \0 */
  .byte (incr_val    - switch_begin) /* 1 -> +  */
  .byte (switch_done - switch_begin) /* 2 -> SP */
  .byte (def_case    - switch_begin) /* 3 ->    */
  .byte (io_out      - switch_begin) /* 4 -> .  */
  .byte (def_case    - switch_begin) /* 5 ->    */
  .byte (io_inp      - switch_begin) /* 6 -> ,  */
  .byte (decr_val    - switch_begin) /* 7 -> -  */
  .byte (skip_bwd    - switch_begin) /* 8 -> ]  */
  .byte (def_case    - switch_begin) /* 9 ->    */
  .byte (switch_done - switch_begin) /* a -> \n */
  .byte (def_case    - switch_begin) /* b ->    */
  .byte (def_case    - switch_begin) /* c ->    */
  .byte (incr_ptr    - switch_begin) /* d -> >  */
  .byte (skip_fwd    - switch_begin) /* e -> [  */
  .byte (decr_ptr    - switch_begin) /* f -> <  */

.section .bss, "aw"

prog:
  .skip MAX_PROG

cells:
  .skip MAX_CELLS

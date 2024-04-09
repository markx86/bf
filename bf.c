#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>

#define MAX_PROG (32 << 9)
#define MAX_CELLS (32 << 9)

static char prog[MAX_PROG];
static char cells[MAX_CELLS];

int main(int argc, char** argv) {
  int prog_fd;
  size_t prog_size, level;
  char *dp, *ip;

  if (argc > 2) {
    fprintf(stderr, "USAGE: %s [INPUT-FILE]", argv[0]);
    return -1;
  }

  prog_fd = argc < 2 || strcmp(argv[1], "-") == 0 ? 0 : open(argv[1], O_RDONLY);

  prog_size = read(prog_fd, prog, MAX_PROG);
  memset(cells, 0, MAX_CELLS);

  dp = cells;
  ip = prog;

  while (ip < &prog[prog_size]) {
    switch (*ip) {
      case '>':
        if (++dp >= &cells[MAX_CELLS])
          dp = &cells[0];
        break;
      case '<':
        if (--dp < &cells[0])
          dp = &cells[MAX_CELLS];
        break;
      case '+':
        ++(*dp);
        break;
      case '-':
        --(*dp);
        break;
      case '.':
        if (write(1, dp, 1) < 0) {
          perror("write");
          return -1;
        }
        break;
      case ',':
        if (read(0, dp, 1) < 0) {
          perror("read");
          return -1;
        }
        break;
      case '[':
        if (*dp)
          break;
        level = 0;
        while (++ip < &prog[prog_size]) {
          if (*ip == '[')
            ++level;
          else if (*ip == ']') {
            if (level > 0)
              --level;
            else
              break;
          }
        }
        if (*ip != ']' || level)
          return -1;
        break;
      case ']':
        if (!*dp)
          break;
        level = 0;
        while (--ip >= &prog[0]) {
          if (*ip == ']')
            ++level;
          else if (*ip == '[') {
            if (level > 0)
              --level;
            else
              break;
          }
        }
        if (*ip != '[' || level)
          return -1;
        break;
      case '\n':
      case '\t':
      case ' ':
        break;
      default:
        return *ip;
    }
    ++ip;
  }

  close(prog_fd);

  return 0;
}

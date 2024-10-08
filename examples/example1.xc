#include <stdio.h>
#include <stdlib.h>
#include <string.h>

allocate_using heap;

int f(closure<(int) -> int> fun, int a) {
  return fun(a);
}

int main (int argc, char **argv) {
  int y = 2;
  int *z = allocate(sizeof(int));
  *z = 0;

  closure<(int) -> int> fun = lambda (int x) -> (*z = x * y + *z);

  int a = f(fun, 1);
  int b = f(fun, 2);
  int c = f(fun, 3);

  printf("%d %d %d\n", a, b, c);
  return 0;
}

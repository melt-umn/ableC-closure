#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int f(closure<(int) -> int> fun, int a) {
  return fun(a);
}

int main (int argc, char **argv) {
  allocate_using heap;
  int y = 2;
  int z = 0;
  int *zp = &z;

  closure<(int) -> int> fun = lambda (int x) -> (*zp = x * y + *zp);

  int a = f(fun, 1);
  int b = f(fun, 2);
  int c = f(fun, 3);

  printf("%d %d %d\n", a, b, c);

  fun.free(free);
  
  if (a != 2)
    return 1;
  if (b != 6)
    return 2;
  if (c != 12)
    return 3;
  return 0;
}

#include <stdio.h>
#include <stdlib.h>

int f(closure<(int) -> int> fun, int a) {
  return fun(a);
}

int main (int argc, char **argv) {
  int y = 2;
  int z = 0;
  int *zp = &z;

  closure<(int) -> int> fun = lambda allocate(malloc) (int x) -> (*zp = x * y + *zp);

  int a = f(fun, 1);
  int b = f(fun, 2);
  int c = f(fun, 3);

  printf("%d %d %d\n", a, b, c);

  fun.free(free);
  
  return 0;
}

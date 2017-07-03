#include <gc.h>
#include <stdio.h>
#include <stdlib.h>

int f(closure<(int) -> int> fun, int a) {
  return fun(a);
}

int main(int argc, char **argv) {
  int y = 1;
  int z = 0;

  closure<(int) -> int> fun = lambda (int x) -> (z = x * y + z); // Mutating const z

  int a = f(fun, 1);
  int b = f(fun, 2);
  int c = f(fun, 3);

  printf("%d %d %d\n", a, b, c);
  return 0;
}

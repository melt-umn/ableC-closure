#include <gc.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int f(int a) {
  return a + 1;
}

int main (int argc, char **argv) {
  closure<(int) -> int> fun = lambda (int x) -> (int) {
    printf("%d\n", x);
    return f(x);
  };

  int a = fun(1);

  printf("%d\n", a);
  return a != 2;
}

#include <gc.h>
#include <string.h>
#include <stdio.h>

int x = 1;

int main() {
  int x = 2;
  closure<(void) -> int> foo = lambda (void) -> x;
  int res = foo();

  printf("%d\n", res);

  return res != 2;
}

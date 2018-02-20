#include <gc.h>
#include <string.h>
#include <stdio.h>

int main() {
  closure<(int) -> int> fn[1];
  *fn = lambda (int x) -> (x == 0? 0 : x + (*fn)(x - 1));

  printf("%d\n", (*fn)(5));
}

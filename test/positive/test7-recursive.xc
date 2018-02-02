#include <gc.h>
#include <stdio.h>

int main() {
  closure<(int) -> int> fn[1];
  *fn = lambda (int x) -> (x == 0? 0 : x + (*fn)(x - 1));

  int result = (*fn)(5);
  printf("%d\n", result);

  return result != 15;
}

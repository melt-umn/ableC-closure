#include <string.h>
#include <alloca.h>
#include <stdio.h>

allocate_using stack;

int main() {
  int x = 1;
  int y = 2;
  int z = 3;
  
  closure<(int) -> int> foo = lambda [y, z, ...](int i) -> i + x + y;

  int res = foo(7);

  return res != 10;
}

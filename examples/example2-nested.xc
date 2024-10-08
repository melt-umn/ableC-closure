#include <stdio.h>
#include <arena.h>
#include <string.h>

int main (int argc, char **argv) {
  int a, b;
  with_arena ar {
    closure<((int) -> int) -> (int) -> int> repeat = 
      lambda [ar](closure<(int) -> int> f) -> ({
        allocate_using arena ar;
        lambda [f](int x) -> f(f(x));
      });

    closure<(int) -> int> inc = lambda [](int x) -> (x + 1);

    closure<(int) -> int> addtwo = repeat(inc);
    
    a = inc(1);
    b = addtwo(1);
  }

  printf("%d %d\n", a, b);
  if (a != 2)
    return 1;
  if (b != 3)
    return 2;
  else
    return 0;
}

#include <gc.h>
#include <string.h>

int main (int argc, char **argv) {
  const int x = 42;

  closure<(void) -> int> fun = lambda (void) -> (x);
  
  return fun() != 42;
}

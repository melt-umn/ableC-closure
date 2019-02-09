#include <gc.h>
#include <string.h>

int main() {
  closure<(const int x) -> int> foo = lambda (const int x) -> x + 2;
  int result = foo(2);
  if (result != 4)
    return 1;
  else
    return 0;
}

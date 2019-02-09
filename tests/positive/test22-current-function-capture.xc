#include <string.h>
#include <gc.h>

int foo() {
  lambda (int x) -> (foo());
  return 7;
}

int main() {
  foo();
}

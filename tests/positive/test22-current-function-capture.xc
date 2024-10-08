#include <string.h>
#include <alloca.h>

allocate_using stack;

int foo() {
  lambda (int x) -> (foo());
  return 7;
}

int main() {
  foo();
}

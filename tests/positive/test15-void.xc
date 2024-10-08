#include <stdio.h>

int x = 0;

void foo(int i) {
  x += i;
}

int main() {
  closure<(int) -> void> bar = lambda (int i) -> foo(i);

  printf("x: %d\n", x);
  bar(1);
  printf("x: %d\n", x);
  bar(2);
  printf("x: %d\n", x);

  return x != 3;
}

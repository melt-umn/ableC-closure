#include <string.h>
#include <alloca.h>
#include <stdio.h>

allocate_using stack;

struct data {
  int arr[5];
};

int main() {
  struct data data;
  for (int i = 0; i < 5; i++) {
    data.arr[i] = i * 2;
  }
  closure<(int) -> int> foo = lambda (int i) -> data.arr[i % 5];

  for (int i = 0; i < 10; i++) {
    unsigned result = foo(i);
    printf("foo(%d) = %d\n", i, result);
    if (result != (i % 5) * 2) {
      return 1;
    }
  }
}

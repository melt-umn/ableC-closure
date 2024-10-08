#include <alloca.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

allocate_using stack;

int main (int argc, char **argv) {
  int data[2] = {0, 1};
  
  closure<() -> int> fib = lambda () -> int {
    int temp = data[1];
    data[1] += data[0];
    data[0] = temp;
    return data[0];
  };
  
  printf("%d\n", fib());
  printf("%d\n", fib());
  printf("%d\n", fib());
  printf("%d\n", fib());
  printf("%d\n", fib());
  printf("%d\n", fib());
  printf("%d\n", fib());
  printf("%d\n", fib());
}

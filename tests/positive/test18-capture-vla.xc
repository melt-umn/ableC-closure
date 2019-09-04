#include <string.h>
#include <gc.h>
#include <stdio.h>

int main() {
  int x = 3, y = 4, z = 5;
  int data[x][y][z];
  for (int i = 0; i < x; i++) {
    for (int j = 0; j < y; j++) {
      for (int k = 0; k < z; k++) {
        data[i][j][k] = i * j * k;
      }
    }
  }
  closure<(int) -> int> foo = lambda (int i) -> data[i % 3][i % y][i % 5];

  for (int i = 0; i < x * y * z; i++) {
    unsigned result = foo(i);
    printf("foo(%d) = %d\n", i, result);
    if (result != (i % 3) * (i % y) * (i % 5)) {
      return 1;
    }
  }
}

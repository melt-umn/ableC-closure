#include <gc.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

int main (int argc, char **argv) {
  int x = 0;
  int *xp = &x;
  
  closure<() -> void> fn = lambda () -> void {
    (*xp)++;
  };

  fn();
  fn();
  fn();
  fn();
  fn();
  
  if (x != 5)
    return 1;
  return 0;
}

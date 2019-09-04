#include <string.h>
#include <gc.h>

struct foo {
  int x;
};

int main() {
  // Test parsing of struct foo {
  lambda () -> struct foo {
    return (struct foo){42};
  };
}

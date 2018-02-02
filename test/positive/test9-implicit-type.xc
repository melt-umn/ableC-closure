#include <gc.h>

int main (int argc, char **argv) {
  lambda []() -> (lambda [](int i) -> (i));
}

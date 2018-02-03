#include <gc.h>

int main (int argc, char **argv) {
  lambda [](closure<(int) -> int> f) -> (f);
}

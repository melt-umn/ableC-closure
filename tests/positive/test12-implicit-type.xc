#include <gc.h>
#include <string.h>

int main (int argc, char **argv) {
  lambda [](closure<(int) -> int> f) -> f;
}

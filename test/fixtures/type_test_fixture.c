typedef int MyInt;

struct Pair {
    int first;
    const int second;
};

typedef struct Pair PairAlias;

int add(int a, int b) {
    return a + b;
}

int *global_ptr;
const int const_value;
volatile int volatile_value;
int array_values[3];
int variadic_sum(int count, ...) {
    return count;
}

struct Pair make_pair(int first, int second) {
    struct Pair pair = {first, second};
    return pair;
}

PairAlias alias_value;
MyInt my_int_value;

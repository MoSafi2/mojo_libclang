typedef int MyInt;

struct Pair {
    int first;
    const int second;
};

typedef struct Pair PairAlias;

int add(int a, int b) {
    return a + b;
}

int use_add() {
    return add(1, 2);
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

void restrict_func(int *restrict p) { (void)p; }

_Atomic int atomic_value;

typedef int v4si __attribute__((__vector_size__(16)));
v4si vector_value;

#define SIMPLE_MACRO 17
#define ADD_ONE(x) ((x) + 1)

int initialized_global = 7;
extern int extern_decl;
static int static_counter = 3;

/// Documented helper for comment range tests.
int documented_helper(void) {
    return ADD_ONE(SIMPLE_MACRO);
}

// C++ test fixture for CXX-specific cursor features
class Base {
public:
    virtual ~Base() = default;
    virtual int virtual_method() const = 0;
    virtual int overridden_method() const { return 1; }
    static int static_method() { return 0; }
};

class Derived : public Base {
public:
    int virtual_method() const override { return 2; }
    int overridden_method() const override { return 3; }
    Derived() = default;
    Derived(int) : Derived() {}
    Derived(const Derived&) = default;
    Derived(Derived&&) = default;
    Derived& operator=(const Derived&) = default;
    Derived& operator=(Derived&&) = default;
    explicit Derived(double) {}
};

enum class ScopedEnum { A, B, C };
enum OldEnum { X, Y, Z };

inline int inlined_func() { return 42; }

class Copyable {
public:
    Copyable() = default;
    Copyable(const Copyable&) = default;
    Copyable(Copyable&&) = default;
};

class Addable {
public:
    int operator+(const Addable&) const { return 0; }
};

template <typename T>
struct Wrapper {
    T value;
};

Wrapper<int> int_wrapper;

template <int N>
struct NTTP {
    static const int value = N;
};

NTTP<42> nttp_instance;

void overloaded_fn(int) {}
void overloaded_fn(double) {}

void use_overload() { overloaded_fn(1); }

struct MutableStruct {
    mutable int m;
};

bool unary_test(bool x) { return !x; }

class ConcreteBase {
public:
    int base_field;
};

class ConcreteDerived : public ConcreteBase {
public:
    int derived_field;
};

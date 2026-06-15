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

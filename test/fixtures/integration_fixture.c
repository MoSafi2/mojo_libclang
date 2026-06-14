int add(int a, int b) { return a + b; }
double divide(double x, double y) { return x / y; }
struct Point { int x; int y; };
struct Point make_origin(void) { struct Point p = {0, 0}; return p; }
int global_counter;
const char *message = "hello";

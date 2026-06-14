"""Composite runner that executes all test modules."""
from test import (
    api_test,
    type_test,
    token_test,
    cursor_test,
    diagnostic_test,
    integration_test,
)
from std.testing import TestSuite


def main() raises:
    print("=== api_test ===")
    api_test.main()
    print("=== type_test ===")
    type_test.main()
    print("=== token_test ===")
    token_test.main()
    print("=== cursor_test ===")
    cursor_test.main()
    print("=== diagnostic_test ===")
    diagnostic_test.main()
    print("=== integration_test ===")
    integration_test.main()

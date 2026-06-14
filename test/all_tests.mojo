"""Composite runner that executes all test modules."""
from test import (
    test_type,
    test_token,
    test_cursor,
    test_diagnostic,
    test_integration,
)
from std.testing import TestSuite


def main() raises:
    print("=== type_test ===")
    test_type.main()
    print("=== token_test ===")
    test_token.main()
    print("=== cursor_test ===")
    test_cursor.main()
    print("=== diagnostic_test ===")
    test_diagnostic.main()
    print("=== integration_test ===")
    test_integration.main()

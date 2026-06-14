"""Composite runner that executes all test modules."""
from test import (
    test_type,
    test_token,
    test_cursor,
    test_diagnostic,
    test_source_location,
    test_source_range,
    test_index,
    test_translation_unit,
    test_cursor_children,
    test_file,
    test_support,
    test_common,
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
    print("=== source_location_test ===")
    test_source_location.main()
    print("=== source_range_test ===")
    test_source_range.main()
    print("=== index_test ===")
    test_index.main()
    print("=== translation_unit_test ===")
    test_translation_unit.main()
    print("=== cursor_children_test ===")
    test_cursor_children.main()
    print("=== file_test ===")
    test_file.main()
    print("=== support_test ===")
    test_support.main()
    print("=== common_test ===")
    test_common.main()
    print("=== integration_test ===")
    test_integration.main()

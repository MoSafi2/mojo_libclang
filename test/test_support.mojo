"""Unit tests for common public support values."""
from clang.cindex import UnsavedFile
from std.testing import assert_equal, TestSuite


# -- UnsavedFile -----------------------------------------------------------


def test_unsaved_file_fields() raises:
    var f = UnsavedFile(
        filename=String("test.c"),
        contents=String("int x;"),
    )
    assert_equal(f.filename, String("test.c"))
    assert_equal(f.contents, String("int x;"))


def test_unsaved_file_copy() raises:
    var f1 = UnsavedFile(
        filename=String("a.c"),
        contents=String("int y;"),
    )
    var f2 = f1.copy()
    assert_equal(f2.filename, String("a.c"))
    assert_equal(f2.contents, String("int y;"))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

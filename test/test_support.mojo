"""Unit tests for `clang/support.mojo`."""
from clang.cindex import UnsavedFile, SourcePosition, SourceExtentInput
from std.ffi import c_uint
from std.testing import (
    assert_equal,
    assert_true,
    assert_false,
    assert_raises,
    TestSuite,
)


def _check(cond: Bool, msg: String) raises:
    if not cond:
        raise Error(msg)


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


# -- SourcePosition --------------------------------------------------------


def test_source_position_from_line_column() raises:
    var pos = SourcePosition.from_line_column(1, 1)
    _check(pos.is_line_column(), "should be line-column")
    _check(not pos.is_offset_only(), "should not be offset-only")


def test_source_position_from_offset() raises:
    var pos = SourcePosition.from_offset(42)
    _check(pos.is_offset_only(), "should be offset-only")
    _check(not pos.is_line_column(), "should not be line-column")


def test_source_position_validate_line_column() raises:
    var pos = SourcePosition.from_line_column(10, 5)
    pos.validate()


def test_source_position_validate_offset() raises:
    var pos = SourcePosition.from_offset(99)
    pos.validate()


def test_source_position_validate_all_none_raises() raises:
    var pos = SourcePosition(
        line=Optional[c_uint](),
        column=Optional[c_uint](),
        offset=Optional[c_uint](),
    )
    with assert_raises():
        pos.validate()


def test_source_position_validate_mixed_raises() raises:
    var pos = SourcePosition(
        line=Optional[c_uint](1),
        column=Optional[c_uint](),
        offset=Optional[c_uint](5),
    )
    with assert_raises():
        pos.validate()


# -- SourceExtentInput -----------------------------------------------------


def test_source_extent_from_positions() raises:
    var start = SourcePosition.from_line_column(1, 1)
    var end = SourcePosition.from_line_column(10, 5)
    var ext = SourceExtentInput.from_positions(start, end)
    _check(ext.start.is_line_column(), "start should be line-column")
    _check(ext.end.is_line_column(), "end should be line-column")


def test_source_extent_from_offsets() raises:
    var ext = SourceExtentInput.from_offsets(0, 100)
    _check(ext.start.is_offset_only(), "start should be offset-only")
    _check(ext.end.is_offset_only(), "end should be offset-only")


def test_source_extent_from_line_columns() raises:
    var ext = SourceExtentInput.from_line_columns(1, 1, 10, 5)
    _check(ext.start.is_line_column(), "start should be line-column")
    _check(ext.end.is_line_column(), "end should be line-column")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

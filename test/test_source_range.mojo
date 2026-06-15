"""Unit tests for `src/libclang/source_range.mojo`."""
from src.libclang import (
    Index,
    TranslationUnit,
    SourceLocation,
    SourceRange,
    SourcePosition,
    SourceExtentInput,
)
from std.ffi import c_uint
from std.testing import assert_equal, assert_true, assert_false, TestSuite


comptime FIXTURE_PATH: String = "test/fixtures/type_test_fixture.c"


def _check(cond: Bool, msg: String) raises:
    if not cond:
        raise Error(msg)


def _parse_fixture() raises -> TranslationUnit:
    var index = Index.create()
    return index.parse(FIXTURE_PATH)


def test_null_range() raises:
    var tu = _parse_fixture()
    var rng = SourceRange.null(tu._raw)
    _check(rng.is_null(), "null range should report is_null")


def test_null_range_start_not_from_main_file() raises:
    var tu = _parse_fixture()
    var rng = SourceRange.null(tu._raw)
    var start = rng.start()
    _check(
        not start.is_from_main_file(),
        "null range start should not be from main file",
    )


def test_null_range_end_not_from_main_file() raises:
    var tu = _parse_fixture()
    var rng = SourceRange.null(tu._raw)
    var end = rng.end()
    _check(
        not end.is_from_main_file(),
        "null range end should not be from main file",
    )


# def test_range_from_locations_not_null() raises:
#     var tu = _parse_fixture()
#     var start = tu.get_location(
#         FIXTURE_PATH,
#         SourcePosition.from_line_column(1, 1),
#     )
#     var end = tu.get_location(
#         FIXTURE_PATH,
#         SourcePosition.from_line_column(1, 8),
#     )
#     var rng = SourceRange.from_locations(start, end)
#     _check(not rng.is_null(), "non-null range should not be null")


# def test_range_start_matches_input() raises:
#     var tu = _parse_fixture()
#     var start = tu.get_location(
#         FIXTURE_PATH,
#         SourcePosition.from_line_column(1, 1),
#     )
#     var end = tu.get_location(
#         FIXTURE_PATH,
#         SourcePosition.from_line_column(1, 8),
#     )
#     var rng = SourceRange.from_locations(start, end)
#     var got_start = rng.start()
#     _check(got_start == start, "range start should match input")


# def test_range_end_matches_input() raises:
#     var tu = _parse_fixture()
#     var start = tu.get_location(
#         FIXTURE_PATH,
#         SourcePosition.from_line_column(1, 1),
#     )
#     var end = tu.get_location(
#         FIXTURE_PATH,
#         SourcePosition.from_line_column(1, 8),
#     )
#     var rng = SourceRange.from_locations(start, end)
#     var got_end = rng.end()
#     _check(got_end == end, "range end should match input")


# def test_range_start_end_line_column() raises:
#     var tu = _parse_fixture()
#     var start = tu.get_location(
#         FIXTURE_PATH,
#         SourcePosition.from_line_column(10, 1),
#     )
#     var end = tu.get_location(
#         FIXTURE_PATH,
#         SourcePosition.from_line_column(10, 11),
#     )
#     var rng = SourceRange.from_locations(start, end)
#     var s = rng.start()
#     var e = rng.end()
#     assert_equal(Int(s.line()), 10)
#     assert_equal(Int(e.line()), 10)
#     assert_equal(Int(s.column()), 1)
#     assert_equal(Int(e.column()), 11)


def test_range_via_tu_extent() raises:
    var tu = _parse_fixture()
    var rng = tu.get_extent(
        FIXTURE_PATH,
        SourceExtentInput.from_line_columns(1, 1, 1, 8),
    )
    _check(not rng.is_null(), "get_extent should return non-null range")


def test_range_equality_same() raises:
    var tu = _parse_fixture()
    var start = tu.get_location(
        FIXTURE_PATH,
        SourcePosition.from_line_column(1, 1),
    )
    var end = tu.get_location(
        FIXTURE_PATH,
        SourcePosition.from_line_column(1, 8),
    )
    var rng1 = SourceRange.from_locations(start, end)
    var rng2 = SourceRange.from_locations(start, end)
    _check(rng1 == rng2, "identical ranges should be equal")


def test_range_equality_different() raises:
    var tu = _parse_fixture()
    var start = tu.get_location(
        FIXTURE_PATH,
        SourcePosition.from_line_column(1, 1),
    )
    var end = tu.get_location(
        FIXTURE_PATH,
        SourcePosition.from_line_column(1, 8),
    )
    var rng = SourceRange.from_locations(start, end)
    var null_rng = SourceRange.null(tu._raw)
    _check(not (rng == null_rng), "non-null range should not equal null range")


def test_range_null_equality() raises:
    var tu = _parse_fixture()
    var null1 = SourceRange.null(tu._raw)
    var null2 = SourceRange.null(tu._raw)
    _check(null1 == null2, "two null ranges should be equal")


def test_range_extent_consistency() raises:
    var tu = _parse_fixture()
    var start = tu.get_location(
        FIXTURE_PATH,
        SourcePosition.from_line_column(10, 1),
    )
    var end = tu.get_location(
        FIXTURE_PATH,
        SourcePosition.from_line_column(10, 11),
    )
    var rng1 = SourceRange.from_locations(start, end)
    var rng2 = tu.get_extent(
        FIXTURE_PATH,
        SourceExtentInput.from_line_columns(10, 1, 10, 11),
    )
    _check(rng1 == rng2, "from_locations and get_extent should match")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

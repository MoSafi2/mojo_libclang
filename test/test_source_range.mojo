"""Unit tests for `clang/source_range.mojo`."""
from clang.cindex import (
    Index,
    TranslationUnit,
    SourceLocation,
    SourceRange,
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
    var rng = SourceRange.null(tu)
    _check(rng.is_null(), "null range should report is_null")


def test_null_range_start_not_from_main_file() raises:
    var tu = _parse_fixture()
    var rng = SourceRange.null(tu)
    var start = rng.start()
    _check(
        not start.is_from_main_file(),
        "null range start should not be from main file",
    )


def test_null_range_end_not_from_main_file() raises:
    var tu = _parse_fixture()
    var rng = SourceRange.null(tu)
    var end = rng.end()
    _check(
        not end.is_from_main_file(),
        "null range end should not be from main file",
    )


def test_range_from_locations_not_null() raises:
    var tu = _parse_fixture()
    var start = tu.location(
        FIXTURE_PATH,
        1,
        1,
    )
    var end = tu.location(
        FIXTURE_PATH,
        1,
        8,
    )
    var rng = SourceRange.from_locations(start, end)
    _check(not rng.is_null(), "non-null range should not be null")


def test_range_start_matches_input() raises:
    var tu = _parse_fixture()
    var start = tu.location(
        FIXTURE_PATH,
        1,
        1,
    )
    var end = tu.location(
        FIXTURE_PATH,
        1,
        8,
    )
    var rng = SourceRange.from_locations(start, end)
    var got_start = rng.start()
    _check(got_start == start, "range start should match input")


def test_range_end_matches_input() raises:
    var tu = _parse_fixture()
    var start = tu.location(
        FIXTURE_PATH,
        1,
        1,
    )
    var end = tu.location(
        FIXTURE_PATH,
        1,
        8,
    )
    var rng = SourceRange.from_locations(start, end)
    var got_end = rng.end()
    _check(got_end == end, "range end should match input")


def test_range_start_end_line_column() raises:
    var tu = _parse_fixture()
    var start = tu.location(
        FIXTURE_PATH,
        10,
        1,
    )
    var end = tu.location(
        FIXTURE_PATH,
        10,
        11,
    )
    var rng = SourceRange.from_locations(start, end)
    var s = rng.start()
    var e = rng.end()
    assert_equal(Int(s.line()), 10)
    assert_equal(Int(e.line()), 10)
    assert_equal(Int(s.column()), 1)
    assert_equal(Int(e.column()), 11)


def test_range_via_tu_extent() raises:
    var tu = _parse_fixture()
    var rng = tu.extent(
        FIXTURE_PATH,
        1, 1, 1, 8,
    )
    _check(not rng.is_null(), "extent should return non-null range")


def test_range_via_tu_extent_from_offsets() raises:
    var tu = _parse_fixture()
    var rng = tu.extent_from_offsets(FIXTURE_PATH, 0, 7)
    _check(
        not rng.is_null(),
        "extent_from_offsets should return non-null range",
    )
    assert_equal(Int(rng.start().line()), 1)
    assert_equal(Int(rng.start().column()), 1)
    assert_equal(Int(rng.end().line()), 1)
    assert_equal(Int(rng.end().column()), 8)


def test_range_equality_same() raises:
    var tu = _parse_fixture()
    var start = tu.location(
        FIXTURE_PATH,
        1,
        1,
    )
    var end = tu.location(
        FIXTURE_PATH,
        1,
        8,
    )
    var rng1 = SourceRange.from_locations(start, end)
    var rng2 = SourceRange.from_locations(start, end)
    _check(rng1 == rng2, "identical ranges should be equal")


def test_range_equality_different() raises:
    var tu = _parse_fixture()
    var start = tu.location(
        FIXTURE_PATH,
        1,
        1,
    )
    var end = tu.location(
        FIXTURE_PATH,
        1,
        8,
    )
    var rng = SourceRange.from_locations(start, end)
    var null_rng = SourceRange.null(tu)
    _check(not (rng == null_rng), "non-null range should not equal null range")


def test_range_null_equality() raises:
    var tu = _parse_fixture()
    var null1 = SourceRange.null(tu)
    var null2 = SourceRange.null(tu)
    _check(null1 == null2, "two null ranges should be equal")


def test_range_extent_consistency() raises:
    var tu = _parse_fixture()
    var start = tu.location(
        FIXTURE_PATH,
        10,
        1,
    )
    var end = tu.location(
        FIXTURE_PATH,
        10,
        11,
    )
    var rng1 = SourceRange.from_locations(start, end)
    var rng2 = tu.extent(
        FIXTURE_PATH,
        10, 1, 10, 11,
    )
    _check(rng1 == rng2, "from_locations and extent should match")


def test_range_contains() raises:
    var tu = _parse_fixture()
    var start = tu.location(
        FIXTURE_PATH,
        10,
        1,
    )
    var end = tu.location(
        FIXTURE_PATH,
        10,
        11,
    )
    var extent = SourceRange.from_locations(start, end)
    var mid = tu.location(
        FIXTURE_PATH,
        10,
        5,
    )
    _check(mid in extent, "mid location should be inside range")
    _check(start in extent, "start location should be inside range")
    _check(end in extent, "end location should be inside range")

    var before = tu.location(
        FIXTURE_PATH,
        9,
        1,
    )
    _check(before not in extent, "before location should not be inside range")


def test_source_range_null_arc_pointer() raises:
    var tu = _parse_fixture()
    var rng1 = SourceRange.null(tu)
    var rng2 = SourceRange.null(tu._shared_state())
    _check(rng1 == rng2, "null ranges should be equal")


def test_source_range_ne() raises:
    var tu = _parse_fixture()
    var start = tu.location(
        FIXTURE_PATH,
        1,
        1,
    )
    var end = tu.location(
        FIXTURE_PATH,
        1,
        8,
    )
    var rng = SourceRange.from_locations(start, end)
    var null_rng = SourceRange.null(tu)
    _check(rng != null_rng, "non-null range should != null range")


def test_source_range_write_to() raises:
    var tu = _parse_fixture()
    var rng = SourceRange.null(tu)
    var s = String(rng)
    _check(s.byte_length() > 0, "write_to should produce non-empty string")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

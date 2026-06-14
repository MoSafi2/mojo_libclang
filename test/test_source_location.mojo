"""Unit tests for `src/libclang/source_location.mojo`."""
from src.libclang import (
    Index,
    TranslationUnit,
    SourceLocation,
    SourcePosition,
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


def test_null_location() raises:
    var tu = _parse_fixture()
    var loc = SourceLocation.null(tu._raw)
    _check(loc == loc, "null location should equal itself")


def test_null_location_properties() raises:
    var tu = _parse_fixture()
    var loc = SourceLocation.null(tu._raw)
    _check(
        not loc.is_from_main_file(),
        "null location should not be from main file",
    )
    _check(
        not loc.is_in_system_header(),
        "null location should not be in system header",
    )


# def test_location_from_line_column() raises:
#     var tu = _parse_fixture()
#     var loc = tu.get_location(
#         FIXTURE_PATH,
#         SourcePosition.from_line_column(1, 1),
#     )
#     assert_equal(Int(loc.line()), 1)
#     assert_equal(Int(loc.column()), 1)


# def test_location_from_offset() raises:
#     var tu = _parse_fixture()
#     var loc = tu.get_location_for_offset(FIXTURE_PATH, c_uint(0))
#     assert_equal(Int(loc.line()), 1)
#     assert_equal(Int(loc.column()), 1)


# def test_location_line_column_mid_file() raises:
#     var tu = _parse_fixture()
#     var loc = tu.get_location(
#         FIXTURE_PATH,
#         SourcePosition.from_line_column(10, 1),
#     )
#     assert_equal(Int(loc.line()), 10)
#     assert_equal(Int(loc.column()), 1)


# def test_location_offset_zero() raises:
#     var tu = _parse_fixture()
#     var loc = tu.get_location(
#         FIXTURE_PATH,
#         SourcePosition.from_line_column(1, 1),
#     )
#     _check(Int(loc.offset()) == 0,
#            "offset at line 1 col 1 should be 0")


# def test_location_file_not_null() raises:
#     var tu = _parse_fixture()
#     var loc = tu.get_location(
#         FIXTURE_PATH,
#         SourcePosition.from_line_column(1, 1),
#     )
#     var f = loc.file()
#     _check(f is not None, "file should not be None")


def test_location_is_in_system_header() raises:
    var tu = _parse_fixture()
    var loc = tu.get_location(
        FIXTURE_PATH,
        SourcePosition.from_line_column(1, 1),
    )
    _check(
        not loc.is_in_system_header(), "fixture should not be in system header"
    )


def test_location_is_from_main_file() raises:
    var tu = _parse_fixture()
    var loc = tu.get_location(
        FIXTURE_PATH,
        SourcePosition.from_line_column(1, 1),
    )
    _check(loc.is_from_main_file(), "fixture should be from main file")


def test_location_equality_same() raises:
    var tu = _parse_fixture()
    var loc1 = tu.get_location(
        FIXTURE_PATH,
        SourcePosition.from_line_column(1, 1),
    )
    var loc2 = tu.get_location(
        FIXTURE_PATH,
        SourcePosition.from_line_column(1, 1),
    )
    _check(loc1 == loc2, "same position should be equal")


def test_location_equality_different() raises:
    var tu = _parse_fixture()
    var loc1 = tu.get_location(
        FIXTURE_PATH,
        SourcePosition.from_line_column(1, 1),
    )
    var loc2 = tu.get_location(
        FIXTURE_PATH,
        SourcePosition.from_line_column(10, 1),
    )
    _check(not (loc1 == loc2), "different positions should not be equal")


def test_location_equality_null() raises:
    var tu = _parse_fixture()
    var null1 = SourceLocation.null(tu._raw)
    var null2 = SourceLocation.null(tu._raw)
    _check(null1 == null2, "two null locations should be equal")


def test_location_line_column_vs_offset_consistency() raises:
    var tu = _parse_fixture()
    var loc1 = tu.get_location(
        FIXTURE_PATH,
        SourcePosition.from_line_column(1, 1),
    )
    var loc2 = tu.get_location_for_offset(FIXTURE_PATH, c_uint(0))
    _check(loc1 == loc2, "line 1 col 1 should equal offset 0")


# def test_location_line_column_non_zero_offset() raises:
#     var tu = _parse_fixture()
#     var loc = tu.get_location(
#         FIXTURE_PATH,
#         SourcePosition.from_line_column(1, 8),
#     )
#     _check(Int(loc.offset()) >= 7,
#            "offset at line 1 col 8 should be >= 7")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

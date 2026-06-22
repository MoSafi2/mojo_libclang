"""Unit tests for `clang/source_location.mojo`."""
from clang.cindex import (
    Index,
    TranslationUnit,
    SourceLocation,
    File,
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
    var loc = SourceLocation.null(tu)
    _check(loc == loc, "null location should equal itself")


def test_null_location_properties() raises:
    var tu = _parse_fixture()
    var loc = SourceLocation.null(tu)
    _check(
        not loc.is_from_main_file(),
        "null location should not be from main file",
    )
    _check(
        not loc.is_in_system_header(),
        "null location should not be in system header",
    )


def test_location_from_line_column() raises:
    var tu = _parse_fixture()
    var loc = tu.location(
        FIXTURE_PATH,
        1,
        1,
    )
    assert_equal(Int(loc.line()), 1)
    assert_equal(Int(loc.column()), 1)


def test_location_from_offset() raises:
    var tu = _parse_fixture()
    var loc = tu.location_for_offset(FIXTURE_PATH, 0)
    assert_equal(Int(loc.line()), 1)
    assert_equal(Int(loc.column()), 1)


def test_location_line_column_mid_file() raises:
    var tu = _parse_fixture()
    var loc = tu.location(
        FIXTURE_PATH,
        10,
        1,
    )
    assert_equal(Int(loc.line()), 10)
    assert_equal(Int(loc.column()), 1)


def test_location_offset_zero() raises:
    var tu = _parse_fixture()
    var loc = tu.location(
        FIXTURE_PATH,
        1,
        1,
    )
    _check(Int(loc.offset()) == 0,
           "offset at line 1 col 1 should be 0")


def test_location_file_not_null() raises:
    var tu = _parse_fixture()
    var loc = tu.location(
        FIXTURE_PATH,
        1,
        1,
    )
    var f = loc.file()
    _check(f is not None, "file should not be None")


def test_location_is_in_system_header() raises:
    var tu = _parse_fixture()
    var loc = tu.location(
        FIXTURE_PATH,
        1,
        1,
    )
    _check(
        not loc.is_in_system_header(), "fixture should not be in system header"
    )


def test_location_is_from_main_file() raises:
    var tu = _parse_fixture()
    var loc = tu.location(
        FIXTURE_PATH,
        1,
        1,
    )
    _check(loc.is_from_main_file(), "fixture should be from main file")


def test_location_equality_same() raises:
    var tu = _parse_fixture()
    var loc1 = tu.location(
        FIXTURE_PATH,
        1,
        1,
    )
    var loc2 = tu.location(
        FIXTURE_PATH,
        1,
        1,
    )
    _check(loc1 == loc2, "same position should be equal")


def test_location_equality_different() raises:
    var tu = _parse_fixture()
    var loc1 = tu.location(
        FIXTURE_PATH,
        1,
        1,
    )
    var loc2 = tu.location(
        FIXTURE_PATH,
        10,
        1,
    )
    _check(not (loc1 == loc2), "different positions should not be equal")


def test_location_equality_null() raises:
    var tu = _parse_fixture()
    var null1 = SourceLocation.null(tu)
    var null2 = SourceLocation.null(tu)
    _check(null1 == null2, "two null locations should be equal")


def test_location_line_column_vs_offset_consistency() raises:
    var tu = _parse_fixture()
    var loc1 = tu.location(
        FIXTURE_PATH,
        1,
        1,
    )
    var loc2 = tu.location_for_offset(FIXTURE_PATH, 0)
    _check(loc1 == loc2, "line 1 col 1 should equal offset 0")


def test_location_line_column_non_zero_offset() raises:
    var tu = _parse_fixture()
    var loc = tu.location_for_offset(
        FIXTURE_PATH,
        7,
    )
    _check(Int(loc.line()) == 1, "offset 7 should map to line 1")
    _check(Int(loc.column()) == 8, "offset 7 should map to column 8")


def test_location_ordering() raises:
    var tu = _parse_fixture()
    var a = tu.location(
        FIXTURE_PATH,
        1,
        1,
    )
    var b = tu.location(
        FIXTURE_PATH,
        2,
        1,
    )
    _check(a < b, "earlier location should be less than later location")
    _check(a <= b, "earlier location should be less than or equal")
    _check(b > a, "later location should be greater")
    _check(b >= a, "later location should be greater or equal")
    _check(a != b, "different locations should not be equal")


def test_source_location_null_arc_pointer() raises:
    var tu = _parse_fixture()
    var loc1 = SourceLocation.null(tu)
    var loc2 = SourceLocation.null(tu._shared_state())
    _check(loc1 == loc2, "null locations should be equal")


def test_source_location_from_position_arc_pointer() raises:
    var tu = _parse_fixture()
    var file_handle = tu.file(FIXTURE_PATH).value()._raw_value()
    var loc = SourceLocation.from_position(
        tu._shared_state(), file_handle, 1, 1
    )
    _check(loc.line() == 1, "line should be 1")


def test_source_location_from_offset_arc_pointer() raises:
    var tu = _parse_fixture()
    var file_handle = tu.file(FIXTURE_PATH).value()._raw_value()
    var loc = SourceLocation.from_offset(tu._shared_state(), file_handle, 0)
    _check(loc.offset() == 0, "offset should be 0")


def test_source_location_from_raw() raises:
    var tu = _parse_fixture()
    var loc = SourceLocation.null(tu)
    var raw = loc._raw_value()
    var loc2 = SourceLocation.from_raw(tu._shared_state(), raw)
    _check(loc == loc2, "from_raw should reconstruct equal location")


def test_source_location_raw_file() raises:
    var tu = _parse_fixture()
    var loc = tu.location(
        FIXTURE_PATH,
        1,
        1,
    )
    var f = File(tu=tu._shared_state(), raw=loc._raw_file())
    _check(f.name().byte_length() > 0, "_raw_file should yield a valid file")


def test_source_location_file_name() raises:
    var tu = _parse_fixture()
    var loc = tu.location(
        FIXTURE_PATH,
        1,
        1,
    )
    _check(loc.file_name().byte_length() > 0, "file_name should not be empty")


def test_source_location_spelling_tuple() raises:
    var tu = _parse_fixture()
    var loc = tu.location(
        FIXTURE_PATH,
        1,
        1,
    )
    var (_, line, col, _) = loc.spelling_tuple()
    _check(line == 1, "line should be 1")
    _check(col == 1, "column should be 1")


def test_source_location_refresh() raises:
    var tu = _parse_fixture()
    var loc = tu.location(
        FIXTURE_PATH,
        1,
        1,
    )
    loc.refresh()
    _check(loc.line() == 1, "refresh should keep line 1")


def test_source_location_write_to() raises:
    var tu = _parse_fixture()
    var loc = SourceLocation.null(tu)
    var s = String(loc)
    _check(s.byte_length() > 0, "write_to should produce non-empty string")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

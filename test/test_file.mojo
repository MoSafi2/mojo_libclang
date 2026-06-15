"""Unit tests for `src/libclang/file.mojo`."""
from src.libclang import Index, TranslationUnit, File
from std.testing import assert_equal, assert_true, assert_false, TestSuite


comptime FIXTURE_PATH: String = "test/fixtures/type_test_fixture.c"
comptime MISSING_PATH: String = "test/fixtures/__nonexistent__._"


def _check(cond: Bool, msg: String) raises:
    if not cond:
        raise Error(msg)


def _parse_fixture() raises -> TranslationUnit:
    var index = Index.create()
    return index.parse(FIXTURE_PATH)


# -- Null file -------------------------------------------------------------


def test_null_file_creation() raises:
    var tu = _parse_fixture()
    var f = File.null(tu.state())
    _check(True, "null file creation should succeed")


# -- from_name -------------------------------------------------------------


def test_from_name_exists() raises:
    var tu = _parse_fixture()
    var f_opt = tu.get_file(FIXTURE_PATH)
    _check(f_opt is not None, "existing file should be found")


def test_from_name_not_found() raises:
    var tu = _parse_fixture()
    var f_opt = tu.get_file(MISSING_PATH)
    _check(f_opt is None, "missing file should return None")


# -- name / real_path / time -----------------------------------------------


def test_name_nonempty() raises:
    var tu = _parse_fixture()
    var f = tu.get_file(FIXTURE_PATH).copy()
    _check(f.value().name().byte_length() > 0, "file name should not be empty")


def test_real_path_nonempty() raises:
    var tu = _parse_fixture()
    var f = tu.get_file(FIXTURE_PATH)
    var path = f.value().real_path()
    _check(path.byte_length() > 0, "real_path should not be empty")


def test_time_succeeds() raises:
    var tu = _parse_fixture()
    var f = tu.get_file(FIXTURE_PATH)
    _ = f.value().time()


# -- is_multiple_include_guarded -------------------------------------------


def test_not_include_guarded() raises:
    var tu = _parse_fixture()
    var f = tu.get_file(FIXTURE_PATH)
    _check(
        not f.value().is_multiple_include_guarded(),
        "fixture should not be include-guarded",
    )


# -- Equality --------------------------------------------------------------


def test_equality_same_file() raises:
    var tu = _parse_fixture()
    var f1 = tu.get_file(FIXTURE_PATH)
    var f2 = tu.get_file(FIXTURE_PATH)
    _check(f1.value() == f2.value(), "same file should be equal")


def test_equality_null_vs_nonnull() raises:
    var tu = _parse_fixture()
    var f = tu.get_file(FIXTURE_PATH)
    var null_f = File.null(tu.state())
    _check(
        not (f.value() == null_f), "non-null file should not equal null file"
    )


def test_equality_two_null() raises:
    var tu = _parse_fixture()
    var null1 = File.null(tu.state())
    var null2 = File.null(tu.state())
    _check(null1 == null2, "two null files should be equal")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

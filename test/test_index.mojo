"""Unit tests for `clang/index.mojo`."""
from clang.index import Index
from clang.translation_unit import TranslationUnit
from clang.enums import TranslationUnitFlags
from std.os import getenv
from std.testing import (
    assert_equal,
    assert_true,
    assert_false,
    assert_raises,
    TestSuite,
)


comptime FIXTURE_PATH: String = "test/fixtures/type_test_fixture.c"
comptime MISSING_PATH: String = "test/fixtures/__nonexistent__._"


def _save_path() -> String:
    var directory = getenv("TMPDIR")
    if not directory:
        directory = "/tmp"
    return directory + "/libclang_test_index_save.ast"


def _check(cond: Bool, msg: String) raises:
    if not cond:
        raise Error(msg)


# -- Index creation --------------------------------------------------------


def test_create_default() raises:
    var index = Index.create()
    _check(True, "Index.create() should succeed")


def test_create_exclude_decls() raises:
    var index = Index.create(exclude_decls=True)
    _check(True, "Index.create(exclude_decls=True) should succeed")


def test_create_display_diagnostics() raises:
    var index = Index.create(display_diagnostics=True)
    _check(True, "Index.create(display_diagnostics=True) should succeed")


def test_create_both_flags() raises:
    var index = Index.create(exclude_decls=True, display_diagnostics=True)
    _check(True, "Index.create with both flags should succeed")


def test_constructor_default() raises:
    var index = Index()
    _check(True, "Index() constructor should succeed")


def test_constructor_with_flags() raises:
    var index = Index(exclude_decls=True)
    var index2 = Index(display_diagnostics=True)
    var index3 = Index(exclude_decls=True, display_diagnostics=True)
    _check(True, "Index() constructor with flags should succeed")


# -- Parse valid files -----------------------------------------------------


def test_parse_valid_file() raises:
    var index = Index.create()
    var tu = index.parse(FIXTURE_PATH)
    _check(tu.spelling().byte_length() > 0, "TU should have non-empty spelling")


def test_parse_with_args() raises:
    var index = Index.create()
    var args = List[String]()
    args.append("-std=c99")
    var tu = index.parse(FIXTURE_PATH, args=args)
    _check(tu.spelling().byte_length() > 0, "TU with args should have spelling")


def test_parse_with_multiple_args() raises:
    var index = Index.create()
    var args = List[String]()
    args.append("-std=c99")
    args.append("-pedantic")
    args.append("-Wall")
    var tu = index.parse(FIXTURE_PATH, args=args)
    _check(
        tu.spelling().byte_length() > 0,
        "TU with multiple args should have spelling",
    )


def test_parse_with_options() raises:
    var index = Index.create()
    var tu = index.parse(
        FIXTURE_PATH,
        options=TranslationUnitFlags.DETAILED_PREPROCESSING_RECORD,
    )
    _check(
        tu.spelling().byte_length() > 0, "TU with options should have spelling"
    )


def test_parse_reuse_index() raises:
    var index = Index.create()
    var tu1 = index.parse(FIXTURE_PATH)
    _check(tu1.spelling().byte_length() > 0, "first parse should succeed")
    var tu2 = index.parse(FIXTURE_PATH)
    _check(tu2.spelling().byte_length() > 0, "second parse should succeed")


# -- Error handling --------------------------------------------------------


def test_parse_nonexistent_path_raises() raises:
    var index = Index.create()
    with assert_raises():
        _ = index.parse(MISSING_PATH)


def test_read_nonexistent_path_raises() raises:
    var index = Index.create()
    with assert_raises():
        _ = index.read(MISSING_PATH)


# -- Index lifecycle -------------------------------------------------------


def test_index_drop_and_recreate() raises:
    for _ in range(5):
        var index = Index.create()
        var tu = index.parse(FIXTURE_PATH)
        _ = tu.spelling()


def test_index_state_and_raw() raises:
    var index = Index.create()
    var state = index._shared_state()
    _check(state[].alive, "state should be alive")
    var raw = index._raw_handle()
    _check(Bool(raw), "raw CXIndex should not be null")


def test_index_write_to() raises:
    var index = Index.create()
    var s = String(index)
    _check(s.byte_length() > 0, "write_to should produce non-empty string")


def test_index_default_editing_options() raises:
    var index = Index.create()
    var opts = index.default_editing_options()
    _check(
        Int(opts.as_c_uint()) >= 0,
        "default editing options should be non-negative",
    )


def test_index_read_success() raises:
    var index = Index.create()
    var tu = index.parse(FIXTURE_PATH)
    tu.save(_save_path())
    var tu2 = index.read(_save_path())
    _check(tu2.spelling().byte_length() > 0, "read should load saved AST")


def test_index_copy() raises:
    var index = Index.create()
    var index2 = index.copy()
    var tu = index2.parse(FIXTURE_PATH)
    _check(tu.spelling().byte_length() > 0, "copied index should parse")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

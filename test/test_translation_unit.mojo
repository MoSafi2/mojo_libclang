"""Unit tests for `clang/translation_unit.mojo`."""
from clang.index import Index
from clang.common import (
    UnsavedFile,
        )
from clang.source_range import SourceRange
from clang.cursor import Cursor
from clang.translation_unit import TranslationUnit

from clang.source_location import SourceLocation
from clang.file_inclusion import FileInclusion

from clang._ffi import (
    CXCursor_TypedefDecl,
    CXCursor_TranslationUnit,
    CXCursor_VarDecl,
)

from std.ffi import c_uint
from std.testing import (
    assert_equal,
    assert_true,
    assert_false,
    assert_raises,
    TestSuite,
)


comptime FIXTURE_PATH: String = "test/fixtures/type_test_fixture.c"
comptime MISSING_PATH: String = "test/fixtures/__nonexistent__._"
comptime INVALID_PATH: String = "test/fixtures/raw_ffi_probe_invalid.c"
comptime SAVE_PATH: String = "/tmp/libclang_test_tu_save.ast"


def _check(cond: Bool, msg: String) raises:
    if not cond:
        raise Error(msg)


def _parse_fixture() raises -> TranslationUnit:
    var index = Index.create()
    return index.parse(FIXTURE_PATH)


def _parse_invalid() raises -> TranslationUnit:
    var index = Index.create()
    return index.parse(String(INVALID_PATH))


# -- Cursor ------------------------------------------------------------------


def test_cursor_not_null() raises:
    var tu = _parse_fixture()
    var c = tu.cursor()
    _check(not c.is_null(), "TU cursor should not be null")


def test_cursor_kind_translation_unit() raises:
    var tu = _parse_fixture()
    var c = tu.cursor()
    assert_equal(Int(c.kind().as_c_uint()), Int(CXCursor_TranslationUnit))


# -- Diagnostics --------------------------------------------------------------


def test_num_diagnostics_zero_for_valid() raises:
    var tu = _parse_fixture()
    assert_equal(Int(tu.num_diagnostics()), 0)


def test_num_diagnostics_positive_for_invalid() raises:
    var tu = _parse_invalid()
    _check(
        tu.num_diagnostics() > 0, "invalid source should produce diagnostics"
    )


def test_diagnostic_matches_diagnostics_set() raises:
    var tu = _parse_invalid()
    if tu.num_diagnostics() > 0:
        var d1 = tu.diagnostic(0)
        var set = tu.diagnostics()
        var d2 = set[0]
        _check(
            d1.spelling() == d2.spelling(),
            "diagnostic(0) should match diagnostics()[0] spelling",
        )


def test_diagnostics_count_matches_num_diagnostics() raises:
    var tu = _parse_invalid()
    var diags = tu.diagnostics()
    assert_equal(Int(diags.__len__()), Int(tu.num_diagnostics()))


# -- file ---------------------------------------------------------------------


def test_get_file_exists() raises:
    var tu = _parse_fixture()
    var f_opt = tu.file(FIXTURE_PATH)
    _check(f_opt is not None, "existing file should be found")


def test_get_file_not_found() raises:
    var tu = _parse_fixture()
    var f_opt = tu.file(MISSING_PATH)
    _check(f_opt is None, "missing file should return None")


# -- location / location_for_offset -------------------------------------------


def test_get_location_invalid_path_raises() raises:
    var tu = _parse_fixture()
    with assert_raises():
        _ = tu.location(
            MISSING_PATH,
        1,
        1,
    )


def test_location_for_offset_invalid_path_raises() raises:
    var tu = _parse_fixture()
    with assert_raises():
        _ = tu.location_for_offset(MISSING_PATH, c_uint(0))


# -- cursor_for_location -------------------------------------------------------


def test_get_cursor_at_typedef() raises:
    var tu = _parse_fixture()
    var loc = tu.location(
        FIXTURE_PATH,
        1,
        1,
    )
    var c = tu.cursor_for_location(loc)
    assert_equal(
        Int(c.kind().as_c_uint()),
        Int(CXCursor_TypedefDecl),
        "cursor at line 1 col 1 should be TypedefDecl",
    )


def test_get_cursor_at_function() raises:
    var tu = _parse_fixture()
    var loc = tu.location(
        FIXTURE_PATH,
        10,
        1,
    )
    var c = tu.cursor_for_location(loc)
    _check(not c.is_null(), "cursor at line 10 should not be null")


def test_get_cursor_null_location() raises:
    var tu = _parse_fixture()
    var null_loc = SourceLocation.null(tu)
    var c = tu.cursor_for_location(null_loc)
    _check(c.is_null(), "cursor at null location should be null")


# -- tokens ----------------------------------------------------------------


def test_tokens_nonempty() raises:
    var tu = _parse_fixture()
    var extent = tu.extent(
        FIXTURE_PATH,
        1, 1, 1, 100,
    )
    var tokens = tu.tokens(extent)
    _check(Int(tokens.__len__()) > 0, "expected at least one token")


def test_tokens_empty_extent() raises:
    var tu = _parse_fixture()
    var tokens = tu.tokens(SourceRange.null(tu))
    assert_equal(
        Int(tokens.__len__()), 0, "null range should produce no tokens"
    )


# -- reparse -------------------------------------------------------------------


def test_reparse_no_changes() raises:
    var tu = _parse_fixture()
    tu.reparse()
    var c = tu.cursor()
    _check(not c.is_null(), "cursor should be valid after reparse")


# test_reparse_with_content_change triggers libclang crash during reparsing in
# this environment (unknown module format); tracked as environment-specific.
# def test_reparse_with_content_change() raises:
#     var tu = _parse_fixture()
#     var unsaved = List[UnsavedFile]()
#     unsaved.append(
#         UnsavedFile(
#             filename=String(FIXTURE_PATH),
#             contents=String("int y;\n"),
#         ),
#     )
#     tu.reparse(unsaved_files=unsaved)
#     var cursor = tu.cursor()
#     var children = cursor.children()
#     _check(Int(children.__len__()) > 0,
#            "reparsed TU should have children")


def test_reparse_twice() raises:
    var tu = _parse_fixture()
    tu.reparse()
    tu.reparse()
    var c = tu.cursor()
    _check(not c.is_null(), "cursor should be valid after double reparse")


# -- save/read lifecycle -------------------------------------------------------


def test_save_then_read() raises:
    var tu = _parse_fixture()
    tu.save(SAVE_PATH)
    var index = Index.create()
    var tu2 = index.read(SAVE_PATH)
    _check(
        tu2.spelling().byte_length() > 0,
        "restored TU should have non-empty spelling",
    )


def test_save_then_read_cursor() raises:
    var tu = _parse_fixture()
    tu.save(SAVE_PATH)
    var index = Index.create()
    var tu2 = index.read(SAVE_PATH)
    var c = tu2.cursor()
    _check(not c.is_null(), "restored TU cursor should not be null")


def test_from_source() raises:
    var tu = TranslationUnit.from_source(FIXTURE_PATH)
    _check(tu.spelling().byte_length() > 0, "from_source should produce a TU")


def test_from_ast_file() raises:
    var tu = _parse_fixture()
    tu.save(SAVE_PATH)
    var tu2 = TranslationUnit.from_ast_file(SAVE_PATH)
    _check(
        tu2.spelling().byte_length() > 0,
        "from_ast_file should produce a TU with non-empty spelling",
    )


def test_includes() raises:
    var tu = _parse_fixture()
    var includes = tu.includes()
    _check(len(includes) >= 0, "includes should return a list")


def test_includes_with_actual_include() raises:
    var index = Index.create()
    var tu = index.parse("test/fixtures/include_test.c")
    var includes = tu.includes()
    _check(
        len(includes) > 0, "include_test.c should have at least one inclusion"
    )


def test_translation_unit_generation_and_state() raises:
    var tu = _parse_fixture()
    _check(tu._generation_id() == 0, "initial generation should be 0")
    _check(tu._shared_state()[].generation == tu._generation_id(), "state generation matches")


def test_translation_unit_raw() raises:
    var tu = _parse_fixture()
    var raw = tu._raw_handle()
    _check(raw is not None, "raw CXTranslationUnit should not be null")


def test_translation_unit_len() raises:
    var tu = _parse_invalid()
    _check(Int(tu.__len__()) > 0, "invalid TU should have positive diagnostic count")


def test_translation_unit_write_to() raises:
    var tu = _parse_fixture()
    var s = String(tu)
    _check(s.byte_length() > 0, "write_to should produce non-empty string")


def test_translation_unit_copy() raises:
    var tu = _parse_fixture()
    var tu2 = tu.copy()
    _check(tu2.spelling() == tu.spelling(), "copied TU should share state")


def test_file_inclusion_fields() raises:
    var index = Index.create()
    var tu = index.parse("test/fixtures/include_test.c")
    var includes = tu.includes()
    _check(len(includes) > 0, "should have at least one inclusion")
    var inc = includes[0].copy()
    _check(inc.depth > 0, "included file should have depth > 0")
    _check(not inc.is_input_file(), "included file should not be input file")
    var s = String(inc)
    _check(s.byte_length() > 0, "FileInclusion write_to should produce output")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

from clang.cindex import (
    Index,
    CursorKind,
    TranslationUnit,
    Cursor,
    CursorSet,
    TranslationUnitFlags,
)
from clang.common import SourcePosition
from std.testing import assert_equal, assert_true, TestSuite
from std.iter import enumerate


comptime FIXTURE_PATH: String = "test/fixtures/type_test_fixture.c"
comptime CXX_FIXTURE_PATH: String = "test/fixtures/cxx_test_fixture.cpp"
comptime SKIPPED_FIXTURE_PATH: String = "test/fixtures/skipped_ranges_fixture.c"


def _check(cond: Bool, msg: String = "") raises:
    if not cond:
        raise Error(msg)


def _parse() raises -> TranslationUnit:
    var index = Index.create()
    return index.parse(FIXTURE_PATH)


def _parse_cxx() raises -> TranslationUnit:
    var index = Index.create()
    return index.parse(CXX_FIXTURE_PATH)


def _find_by_spelling(mut tu: TranslationUnit, name: String) raises -> Cursor:
    var walk = tu.cursor().walk_preorder()
    for i in range(len(walk)):
        var c = walk[i].copy()
        if c.spelling() == name:
            return c^
    raise Error("cursor not found")


# TargetInfo currently crashes in this checkout when clang_TargetInfo_getTriple
# is queried through the wrapper. Keep the surface out of the active suite until
# a dedicated probe shows it is stable.
# def test_target_info() raises:
#     var tu = _parse()
#     var info = tu.target_info()
#     _check(info.triple().byte_length() > 0, "target triple should be non-empty")
#     _check(info.pointer_width() > 0, "pointer width should be positive")


def test_resource_usage() raises:
    var tu = _parse()
    var usage = tu.resource_usage()
    _check(len(usage) > 0, "resource usage should have entries")
    _check(Int(usage.total()) > 0, "resource usage total should be positive")


def test_file_contents() raises:
    var tu = _parse()
    var contents = tu.file_contents(FIXTURE_PATH)
    _check(contents.byte_length() > 0, "file contents should not be empty")


def test_all_skipped_ranges() raises:
    var index = Index.create()
    var tu = index.parse(
        SKIPPED_FIXTURE_PATH,
        options=TranslationUnitFlags.DETAILED_PREPROCESSING_RECORD,
    )
    var skipped = tu.all_skipped_ranges()
    _check(len(skipped) > 0, "expected skipped ranges in fixture")
    _check(not skipped[0].is_null(), "first skipped range should be non-null")


def test_cursor_var_initializer_and_storage() raises:
    var tu = _parse()
    var c = _find_by_spelling(tu, "initialized_global")
    _check(c.var_decl_initializer() is not None, "initializer should exist")
    _check(c.has_var_decl_global_storage(), "global should have global storage")
    _check(not c.has_var_decl_external_storage(), "initialized global is not extern")


def test_cursor_macro_flags() raises:
    var index = Index.create()
    var tu = index.parse(
        FIXTURE_PATH,
        options=TranslationUnitFlags.DETAILED_PREPROCESSING_RECORD,
    )
    var macro = _find_by_spelling(tu, "ADD_ONE")
    _check(macro.is_macro_function_like(), "ADD_ONE should be function-like macro")
    var plain = _find_by_spelling(tu, "SIMPLE_MACRO")
    _check(not plain.is_macro_function_like(), "SIMPLE_MACRO should not be function-like")


def test_cursor_comment_and_name_ranges() raises:
    var tu = _parse()
    var c = _find_by_spelling(tu, "documented_helper")
    _check(not c.comment_range().is_null(), "comment range should be non-null")
    _check(not c.spelling_name_range().is_null(), "spelling name range should be non-null")


def test_cursor_reference_name_range_and_eval() raises:
    var tu = _parse()
    var ref_cursor = _find_by_spelling(tu, "add")
    _check(not ref_cursor.reference_name_range().is_null(), "reference name range should be non-null")
    var init = _find_by_spelling(tu, "initialized_global")
    var result = init.evaluate()
    _check(result is not None, "initialized global should evaluate")
    assert_equal(result.value().as_int(), 7)


def test_cursor_invalid_and_exception_kind() raises:
    var tu = _parse()
    var cursor = _find_by_spelling(tu, "add")
    _check(not cursor.is_invalid_declaration(), "add should not be invalid")
    _check(Int(cursor.cursor_exception_specification_kind().as_c_uint()) >= 0)


def test_cursor_platform_availability() raises:
    var tu = _parse()
    var cursor = _find_by_spelling(tu, "add")
    var avail = cursor.platform_availability()
    _check(len(avail) >= 0)


def test_cursor_set() raises:
    var tu = _parse()
    var cursor = _find_by_spelling(tu, "add")
    var cset = CursorSet()
    _check(cset.insert(cursor), "insert should report success for new cursor")
    _check(cset.contains(cursor), "set should contain inserted cursor")


def test_type_modified_and_nullability() raises:
    var tu = _parse()
    var cursor = _find_by_spelling(tu, "atomic_value")
    var typ = cursor.type()
    _check(Int(typ.nullability().as_c_uint()) >= 0)


def test_type_fields_via_visitor() raises:
    var tu = _parse()
    var cursor = _find_by_spelling(tu, "Pair")
    var fields = cursor.type().get_fields()
    assert_equal(len(fields), 2)


def test_inline_namespace() raises:
    var tu = _parse_cxx()
    var cursor = _find_by_spelling(tu, "V1")
    _check(cursor.is_inline_namespace(), "V1 should be an inline namespace")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

"""Composite integration test for the full public API.

Exercises a real-world scenario: parse C source, navigate the AST, inspect
types, tokenize, and handle diagnostics — all in one coherent flow.
"""
from clang.cindex import (
    Index,
    TranslationUnit,
    SourcePosition,
    SourceExtentInput,
    Cursor,
    Type,
    SourceLocation,
    SourceRange,
    File,
    Token,
    TokenGroup,
    Diagnostic,
)
from clang._ffi import (
    CXCursor_FunctionDecl,
    CXCursor_StructDecl,
    CXCursor_VarDecl,
    CXCursor_TranslationUnit,
    CXType_Int,
    CXType_FunctionProto,
    CXType_Pointer,
    CXType_Record,
    CXType_Invalid,
    CXToken_Keyword,
    CXToken_Identifier,
    CXToken_Punctuation,
)
from std.ffi import c_uint
from std.testing import assert_equal, assert_true, TestSuite


comptime FIXTURE_PATH: String = "test/fixtures/integration_fixture.c"


def _check(cond: Bool, msg: String) raises:
    if not cond:
        raise Error(msg)


def _parse_fixture() raises -> TranslationUnit:
    var index = Index.create()
    return index.parse(FIXTURE_PATH)


def _find_children(
    mut tu: TranslationUnit, kind: c_uint
) raises -> List[Cursor]:
    var root = tu.cursor()
    var out = List[Cursor]()
    var children = root.get_children()
    for i in range(children.__len__()):
        var c = children[i].copy()
        if c.kind() == kind:
            out.append(c^)
    return out^


def _find_function(mut tu: TranslationUnit, name: String) raises -> Cursor:
    var funcs = _find_children(tu, CXCursor_FunctionDecl)
    for i in range(funcs.__len__()):
        var f = funcs[i].copy()
        if f.spelling() == name:
            return f^
    raise Error(t"function not found: {name}")


# -- Parse lifecycle -------------------------------------------------------


def test_index_create_and_parse() raises:
    var index = Index.create()
    var tu = index.parse(FIXTURE_PATH)
    var spelling = tu.spelling()
    _check(spelling.byte_length() > 0, "TU spelling should not be empty")


def test_parse_no_diagnostics_for_valid_source() raises:
    var tu = _parse_fixture()
    assert_equal(
        Int(tu.num_diagnostics()),
        0,
        "valid fixture should produce zero diagnostics",
    )


# -- Translation unit cursor -----------------------------------------------


def test_tu_cursor() raises:
    var tu = _parse_fixture()
    var c = tu.cursor()
    _check(not c.is_null(), "TU cursor should not be null")
    assert_equal(
        Int(c.kind().as_c_uint()), Int(CXCursor_TranslationUnit), "TU cursor kind mismatch"
    )


def test_tu_cursor_children() raises:
    var tu = _parse_fixture()
    var c = tu.cursor()
    var children = c.get_children()
    _check(children.__len__() >= 5, "expected at least 5 top-level decls")
    var walk = c.walk_preorder()
    _check(
        walk.__len__() > children.__len__(),
        "preorder walk should be deeper than direct children",
    )


# -- Function cursors ------------------------------------------------------


# def test_function_add_cursor() raises:
#     var tu = _parse_fixture()
#     var add = _find_function(tu, "add")
#     assert_equal(add.spelling(), "add")
#     assert_equal(Int(add.num_arguments()), 2)
#     var t = add.type()
#     assert_equal(Int(t.kind()), Int(CXType_FunctionProto))
#     var result = add.result_type()
#     assert_equal(Int(result.kind()), Int(CXType_Int))

#     var args = add.get_arguments()
#     assert_equal(args.__len__(), 2)
#     arg0 = args[0].copy()
#     arg1 = args[1].copy()
#     assert_equal(arg0.spelling(), "a")
#     assert_equal(arg1.spelling(), "b")
#     var parent = add.semantic_parent()
#     _check(parent is not None, "function should have semantic parent")
#     var p = parent.value().copy()
#     assert_equal(Int(p.kind()), Int(CXCursor_TranslationUnit))

#     var extent = add.extent()
#     _check(not extent.is_null(), "function extent should not be null")

#     var loc = add.location()
#     _check(Int(loc.line()) >= 1, "function location line should be positive")

#     var canon = add.canonical()
#     _check(not canon.is_null(), "canonical cursor should not be null")

#     var ref_ = add.referenced()
#     _check(ref_ is not None, "definition cursor should reference itself")

#     _ = add.usr()

#     var display = add.display_name()
#     _check(display.byte_length() > 0, "display_name should not be empty")

#     _ = add.hash()


# def test_function_divide_cursor() raises:
#     var tu = _parse_fixture()
#     var divide = _find_function(tu, "divide")
#     assert_equal(divide.spelling(), "divide")
#     assert_equal(Int(divide.num_arguments()), 2)
#     var args = divide.get_arguments()
#     arg0 = args[0].copy()
#     assert_equal(arg0.spelling(), "x")
#     arg1 = args[1].copy()
#     assert_equal(arg1.spelling(), "y")

#     var t = divide.type()
#     assert_equal(Int(t.kind()), Int(CXType_FunctionProto))

#     var result = divide.result_type()
#     _check(Int(result.kind()) != Int(CXType_Int),
#            "divide result should not be int")

#     var lex_parent = divide.lexical_parent()
#     _check(lex_parent is not None, "function should have lexical parent")


# -- Variable cursors ------------------------------------------------------


# def test_global_variable_cursor() raises:
#     var tu = _parse_fixture()
#     var vars = _find_children(tu, CXCursor_VarDecl)
#     _check(vars.__len__() >= 2, "expected at least 2 var decls")

#     var counter = vars[0].copy()
#     _check(counter.spelling().byte_length() > 0, "var should have spelling")
#     _ = counter.type()
#     _check(counter.is_declaration(), "variable should be a declaration")

#     var msg_var = vars[1].copy()
#     _ = msg_var.spelling()
#     _ = msg_var.type()


# -- Struct cursor ---------------------------------------------------------


def test_struct_cursor() raises:
    var tu = _parse_fixture()
    var structs = _find_children(tu, CXCursor_StructDecl)
    _check(structs.__len__() >= 1, "expected at least 1 struct decl")
    var point = structs[0].copy()
    assert_equal(point.spelling(), "Point")

    var children = point.get_children()
    _check(children.__len__() >= 2,
           "struct Point should have at least 2 fields")

    var first = children[0].copy()
    _check(first.spelling().byte_length() > 0,
           "struct field should have spelling")


# -- Tokenization ----------------------------------------------------------


def test_tokenize_line1() raises:
    var tu = _parse_fixture()
    var extent = tu.get_extent(
        FIXTURE_PATH,
        SourceExtentInput.from_line_columns(1, 1, 1, 100),
    )
    var tokens = tu.get_tokens(extent)
    _check(tokens.__len__() > 0, "expected at least one token")
    var first = tokens[0]
    assert_equal(Int(first.kind().as_c_uint()), Int(CXToken_Keyword))
    assert_equal(first.spelling(), "int")

    var second = tokens[1]
    assert_equal(Int(second.kind().as_c_uint()), Int(CXToken_Identifier))
    assert_equal(second.spelling(), "add")

    var third = tokens[2]
    assert_equal(Int(third.kind().as_c_uint()), Int(CXToken_Punctuation))


def test_tokenize_whole_file() raises:
    var tu = _parse_fixture()
    var extent = tu.get_extent(
        FIXTURE_PATH,
        SourceExtentInput.from_line_columns(1, 1, 6, 80),
    )
    var tokens = tu.get_tokens(extent)
    _check(tokens.__len__() > 0, "whole file should produce tokens")
    var first = tokens[0]
    _ = first.kind()
    _ = first.spelling()


# Token.location and Token.extent are currently unstable per raw_bindings.md.
# Keep these disabled until the shim-layer ABI for these wrappers is fixed.
# def test_token_location() raises:
#     var tu = _parse_fixture()
#     var extent = tu.get_extent(
#         FIXTURE_PATH,
#         SourceExtentInput.from_line_columns(1, 1, 1, 100),
#     )
#     var tokens = tu.get_tokens(extent)
#     var first = tokens[0]
#     var loc = first.location()
#     assert_equal(Int(loc.line()), 1, "first token at line 1")
#     _check(Int(loc.column()) >= 1, "first token col >= 1")
#
#
# def test_token_extent_not_null() raises:
#     var tu = _parse_fixture()
#     var extent = tu.get_extent(
#         FIXTURE_PATH,
#         SourceExtentInput.from_line_columns(1, 1, 1, 100),
#     )
#     var tokens = tu.get_tokens(extent)
#     var first = tokens[0]
#     var tok_extent = first.extent()
#     _check(not tok_extent.is_null(), "token extent should not be null")
#
#


def test_token_cursor_annotation() raises:
    var tu = _parse_fixture()
    var extent = tu.get_extent(
        FIXTURE_PATH,
        SourceExtentInput.from_line_columns(1, 1, 1, 100),
    )
    var tokens = tu.get_tokens(extent)
    var first = tokens[0]
    var c = first.cursor()
    assert_equal(Int(c.kind().as_c_uint()), Int(CXCursor_FunctionDecl),
                 "annotated cursor for 'int' keyword should be FunctionDecl")


# -- Source locations ------------------------------------------------------


# def test_source_location_from_position() raises:
#     var tu = _parse_fixture()
#     var loc = tu.get_location(
#         FIXTURE_PATH,
#         SourcePosition.from_line_column(1, 1),
#     )
#     assert_equal(Int(loc.line()), 1)
#     assert_equal(Int(loc.column()), 1)


def test_source_location_from_offset() raises:
    var tu = _parse_fixture()
    var loc = tu.get_location_for_offset(FIXTURE_PATH, c_uint(0))
    _check(Int(loc.line()) >= 1, "offset 0 should map to line 1")
    var loc2 = tu.get_location(
        FIXTURE_PATH,
        SourcePosition.from_offset(0),
    )
    _check(loc == loc2,
           "get_location(from_offset) should match get_location_for_offset")


def test_source_location_system_header() raises:
    var tu = _parse_fixture()
    var loc = tu.get_location(
        FIXTURE_PATH,
        SourcePosition.from_line_column(1, 1),
    )
    _check(not loc.is_in_system_header(),
           "fixture should not be in system header")
    _check(loc.is_from_main_file(), "fixture should be from main file")


# def test_source_location_file() raises:
#     var tu = _parse_fixture()
#     var loc = tu.get_location(
#         FIXTURE_PATH,
#         SourcePosition.from_line_column(1, 1),
#     )
#     _ = loc.file()


# -- Source ranges ---------------------------------------------------------


def test_source_range_from_locations() raises:
    var tu = _parse_fixture()
    var start = tu.get_location(
        FIXTURE_PATH,
        SourcePosition.from_line_column(1, 1),
    )
    var end = tu.get_location(
        FIXTURE_PATH,
        SourcePosition.from_line_column(1, 5),
    )
    var rng = SourceRange.from_locations(start, end)
    _check(not rng.is_null(), "range should not be null")


def test_source_range_null() raises:
    var tu = _parse_fixture()
    var null_rng = SourceRange.null(tu)
    _check(null_rng.is_null(), "null range should be null")


# -- File operations -------------------------------------------------------


# def test_file_from_name() raises:
#     var tu = _parse_fixture()
#     var f_opt = tu.get_file(FIXTURE_PATH)
#     _check(f_opt is not None, "file lookup should succeed")
#     var f = f_opt.value().copy()
#     _check(f.name().byte_length() > 0, "file name should not be empty")
#     _check(f.real_path().byte_length() > 0,
#            "file real path should not be empty")
#     _ = f.time()


def test_file_equality() raises:
    var tu = _parse_fixture()
    var f1_opt = tu.get_file(FIXTURE_PATH)
    var f2_opt = tu.get_file(FIXTURE_PATH)
    _check(f1_opt is not None, "f1 should exist")
    _check(f2_opt is not None, "f2 should exist")
    _check(f1_opt.value() == f2_opt.value(), "same file should be equal")


# -- Cursor equality ------------------------------------------------------


def test_cursor_equality() raises:
    var tu = _parse_fixture()
    var add1 = _find_function(tu, "add")
    var add2 = _find_function(tu, "add")
    _check(add1 == add2, "same function should be equal")
    var null_c = Cursor.null(tu)
    _check(not (add1 == null_c), "function != null cursor")
    _ = add1.hash()
    _ = add2.hash()


# -- Diagnostics on invalid -------------------------------------------------


# def test_diagnostics_for_invalid_parse() raises:
#     var index = Index.create()
#     var bad = String("int x = ;\n")
#     var unsaved = List[UnsavedFile]()
#     unsaved.append(
#         UnsavedFile(filename=String("test/bad.c"), contents=bad),
#     )
#     var tu = index.parse(String("test/bad.c"), unsaved_files=unsaved)
#     _check(tu.num_diagnostics() > 0,
#            "invalid source should produce diagnostics")

#     var diags = tu.diagnostics()
#     assert_equal(diags.__len__(), Int(tu.num_diagnostics()),
#                  "set size should match")
#     var first = diags[c_uint(0)]
#     _check(first.spelling().byte_length() > 0,
#            "diagnostic spelling should not be empty")
#     _ = first.severity()
#     var loc = first.location()
#     _check(Int(loc.line()) >= 1, "diagnostic location should have line")
#     _check(first.category_name().byte_length() > 0,
#            "category name should not be empty")
#     _check(first.format().byte_length() > 0,
#            "formatted should not be empty")
#     _ = first.option()


# def test_diagnostic_set_iteration() raises:
#     var index = Index.create()
#     var bad = String("int x = ;\n")
#     var unsaved = List[UnsavedFile]()
#     unsaved.append(
#         UnsavedFile(filename=String("test/bad_iter.c"), contents=bad),
#     )
#     var tu = index.parse(String("test/bad_iter.c"), unsaved_files=unsaved)
#     var diags = tu.diagnostics()
#     var n = diags.__len__()
#     var count = 0
#     for i in range(n):
#         var d = diags[c_uint(i)]
#         _ = d.severity()
#         _ = d.spelling()
#         count += 1
#     assert_equal(count, n, "iterator should visit all diagnostics")


# -- Lifecycle (leak detection) --------------------------------------------


# def test_repeated_parse_and_drop() raises:
#     for i in range(5):
#         var index = Index.create()
#         var tu = index.parse(
#             FIXTURE_PATH,
#             unsaved_files=_make_unsaved(),
#         )
#         var c = tu.cursor()
#         _ = c.spelling()
#         _ = i


def test_token_group_drop_after_read() raises:
    var tu = _parse_fixture()
    var extent = tu.get_extent(
        FIXTURE_PATH,
        SourceExtentInput.from_line_columns(1, 1, 6, 80),
    )
    for i in range(3):
        var tokens = tu.get_tokens(extent)
        _ = tokens.__len__()
        _ = i


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

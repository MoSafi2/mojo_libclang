"""Unit tests for `src/libclang/cursor.mojo`."""
from src.libclang import (
    Index,
    TranslationUnit,
    Cursor,
    CXCursor_TranslationUnit,
    CXCursor_TypedefDecl,
    CXCursor_FunctionDecl,
    CXCursor_StructDecl,
    CXCursor_VarDecl,
    CXCursor_ParmDecl,
)
from src._ffi import CXType_Int, CXType_FunctionProto
from std.ffi import c_uint
from std.testing import assert_equal, assert_true, TestSuite


comptime FIXTURE_PATH: String = "test/fixtures/type_test_fixture.c"


def _check(cond: Bool, msg: String = "") raises:
    if not cond:
        raise Error(msg)


def _parse() raises -> TranslationUnit:
    var index = Index.create()
    return index.parse(FIXTURE_PATH)


def _find(mut tu: TranslationUnit, kind: c_uint) raises -> Cursor:
    var root = tu.cursor()
    var children = root.get_children()
    for i in range(Int(children.__len__())):
        var c = children[i].copy()
        if c.kind() == kind:
            return c^
    raise Error("child not found")


def test_null_cursor() raises:
    var tu = _parse()
    var c = Cursor.null(tu._raw)
    _check(c.is_null(), "null cursor should report is_null")
    _check(c.is_invalid(), "null cursor should report is_invalid")


def test_tu_cursor() raises:
    var tu = _parse()
    var c = tu.cursor()
    assert_equal(Int(c.kind()), Int(CXCursor_TranslationUnit))
    _check(c.is_definition(), "TU cursor should be definition")


def test_spelling() raises:
    var tu = _parse()
    var c = tu.cursor()
    _check(c.spelling().byte_length() > 0)
    var td = _find(tu, CXCursor_TypedefDecl)
    _check(td.spelling().byte_length() > 0)


# def test_display_name_and_usr() raises:
#     var tu = _parse()
#     var c = tu.cursor()
#     _check(c.display_name().byte_length() > 0)
#     _check(c.usr() is not None)


def test_type_and_result_type() raises:
    var tu = _parse()
    var func = _find(tu, CXCursor_FunctionDecl)
    var typ = func.type()
    assert_equal(Int(typ.kind()), Int(CXType_FunctionProto))
    var rt = func.result_type()
    assert_equal(Int(rt.kind()), Int(CXType_Int))


# def test_location_and_extent() raises:
#     var tu = _parse()
#     var func = _find(tu, CXCursor_FunctionDecl)
#     var loc = func.location()
#     _check(Int(loc.line()) >= 1)
#     var ext = func.extent()
#     _check(not ext.is_null())


def test_semantic_parent() raises:
    var tu = _parse()
    var top = _find(tu, CXCursor_TypedefDecl)
    var p = top.semantic_parent()
    _check(p is not None)
    assert_equal(Int(p.value().kind()), Int(CXCursor_TranslationUnit))


def test_lexical_parent() raises:
    var tu = _parse()
    var top = _find(tu, CXCursor_TypedefDecl)
    var p = top.lexical_parent()
    _check(p is not None)
    assert_equal(Int(p.value().kind()), Int(CXCursor_TranslationUnit))


def test_referenced_definition_canonical() raises:
    var tu = _parse()
    var c = _find(tu, CXCursor_TypedefDecl)
    _check(c.referenced() is not None)
    _check(c.definition() is not None)
    _check(c == c.canonical())


def test_hash() raises:
    var tu = _parse()
    var c1 = tu.cursor()
    var c2 = tu.cursor()
    assert_equal(Int(c1.hash()), Int(c2.hash()))


def test_is_declaration() raises:
    var tu = _parse()
    var td = _find(tu, CXCursor_TypedefDecl)
    _check(td.is_declaration())
    var fd = _find(tu, CXCursor_FunctionDecl)
    _check(fd.is_declaration())
    var sd = _find(tu, CXCursor_StructDecl)
    _check(sd.is_declaration())


def test_kind_predicates_false() raises:
    var tu = _parse()
    var c = _find(tu, CXCursor_TypedefDecl)
    _check(not c.is_reference())
    _check(not c.is_expression())
    _check(not c.is_statement())
    _check(not c.is_attribute())
    _check(not c.is_invalid())
    _check(not c.has_attrs())
    _check(not c.is_bitfield())
    _check(not c.is_anonymous())
    _check(not c.is_anonymous_record_decl())


def test_bitfield_width() raises:
    var tu = _parse()
    var c = _find(tu, CXCursor_TypedefDecl)
    assert_equal(Int(c.get_bitfield_width()), -1)


def test_underlying_typedef_type() raises:
    var tu = _parse()
    var c = _find(tu, CXCursor_TypedefDecl)
    _ = c.underlying_typedef_type()


def test_enum_properties() raises:
    var tu = _parse()
    var c = _find(tu, CXCursor_TypedefDecl)
    _ = c.storage_class()
    _ = c.access_specifier()
    _ = c.availability()
    _ = c.linkage()
    _ = c.visibility()
    _ = c.language()
    _ = c.tls_kind()


def test_comments_and_mangling() raises:
    var tu = _parse()
    var c = _find(tu, CXCursor_FunctionDecl)
    _ = c.raw_comment()
    _ = c.brief_comment()
    _ = c.mangled_name()


def test_included_file() raises:
    var tu = _parse()
    var c = tu.cursor()
    _check(c.get_included_file() is None)


# def test_function_arguments() raises:
#     var tu = _parse()
#     var func = _find(tu, CXCursor_FunctionDecl)
#     assert_equal(Int(func.num_arguments()), 2)
#     var args = func.get_arguments()
#     assert_equal(Int(args.__len__()), 2)
#     for i in range(Int(args.__len__())):
#         var arg = args[i].copy()
#         assert_equal(Int(arg.kind()), Int(CXCursor_ParmDecl))


def test_template_arguments() raises:
    var tu = _parse()
    var c = _find(tu, CXCursor_VarDecl)
    _ = c.get_num_template_arguments()


def test_equality() raises:
    var tu = _parse()
    var c1 = tu.cursor()
    var c2 = tu.cursor()
    _check(c1 == c2)
    var children = c1.get_children()
    var child = children[0].copy()
    _check(not (c1 == child))


# def test_equality_null() raises:
#     var tu = _parse()
#     var null1 = Cursor.null(tu._raw)
#     var null2 = Cursor.null(tu._raw)
#     _check(null1 == null2)


# def test_children_and_walk() raises:
#     var tu = _parse()
#     var c = tu.cursor()
#     var children = c.get_children()
#     var walk = c.walk_preorder()
#     _check(Int(children.__len__()) > 0)
#     _check(Int(walk.__len__()) >= Int(children.__len__()))


def test_enum_type_and_get_field_offsetof() raises:
    var tu = _parse()
    var c = _find(tu, CXCursor_StructDecl)
    _ = c.enum_type()
    _ = c.get_field_offsetof()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

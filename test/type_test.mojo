"""Unit tests for `src/libclang/type_.mojo`."""
from src.libclang import (
    Index,
    TranslationUnit,
    Cursor,
    Type,
)
from src.libclang_raw import (
    CXCursorKind,
    CXCursor_FunctionDecl,
    CXCursor_StructDecl,
    CXCursor_TypedefDecl,
    CXCursor_VarDecl,
    CXCallingConv_C,
    CXCursor_ExceptionSpecificationKind_None,
    CXRefQualifier_None,
    CXType_ConstantArray,
    CXType_FunctionProto,
    CXType_Int,
    CXType_Invalid,
    CXType_Pointer,
    CXType_Record,
    CXType_Typedef,
)
from std.ffi import c_uint
from std.testing import assert_equal, assert_false, assert_true, TestSuite


comptime FIXTURE_PATH: String = "test/type_test_fixture.c"


def _parse_fixture() raises -> TranslationUnit:
    var index = Index.create()
    return index.parse(FIXTURE_PATH)


def _check(cond: Bool, message: String) raises:
    if not cond:
        raise Error(message)


def _find_cursor(mut tu: TranslationUnit, name: String, kind: CXCursorKind) raises -> Cursor:
    var root = tu.cursor()
    var cursors = root.walk_preorder()
    for i in range(Int(cursors.__len__())):
        var cursor = cursors[i].copy()
        if cursor.kind() == kind and cursor.spelling() == name:
            return cursor^
    raise Error("cursor not found: " + name)


def _cursor_type(mut tu: TranslationUnit, name: String, kind: CXCursorKind) raises -> Type:
    var cursor = _find_cursor(tu, name, kind)
    return cursor.type()


def _function_type(mut tu: TranslationUnit, name: String) raises -> Type:
    return _cursor_type(tu, name, CXCursor_FunctionDecl)


def _var_type(mut tu: TranslationUnit, name: String) raises -> Type:
    return _cursor_type(tu, name, CXCursor_VarDecl)


def _struct_type(mut tu: TranslationUnit, name: String) raises -> Type:
    return _cursor_type(tu, name, CXCursor_StructDecl)


def test_type_default_kind_is_invalid() raises:
    var tu = _parse_fixture()
    var t = Type(tu=tu._raw)
    assert_equal(Int(t.kind()), Int(CXType_Invalid))


def test_type_spelling_and_kind_from_cursor() raises:
    var tu = _parse_fixture()
    var t = _function_type(tu, String("add"))
    assert_equal(Int(t.kind()), Int(CXType_FunctionProto))
    assert_equal(t.spelling(), String("int (int, int)"))


def test_type_get_canonical_for_typedef() raises:
    var tu = _parse_fixture()
    var elaborated = _var_type(tu, String("my_int_value"))
    var t = elaborated.get_named_type()
    var canonical = t.get_canonical()
    assert_equal(Int(t.kind()), Int(CXType_Typedef))
    assert_equal(Int(canonical.kind()), Int(CXType_Int))
    assert_equal(canonical.spelling(), String("int"))


def test_type_get_pointee() raises:
    var tu = _parse_fixture()
    var t = _var_type(tu, String("global_ptr"))
    var pointee = t.get_pointee()
    assert_equal(Int(t.kind()), Int(CXType_Pointer))
    assert_equal(Int(pointee.kind()), Int(CXType_Int))
    assert_equal(pointee.spelling(), String("int"))


def test_type_get_result() raises:
    var tu = _parse_fixture()
    var t = _function_type(tu, String("add"))
    var result = t.get_result()
    assert_equal(Int(result.kind()), Int(CXType_Int))
    assert_equal(result.spelling(), String("int"))


def test_type_get_array_element_type() raises:
    var tu = _parse_fixture()
    var t = _var_type(tu, String("array_values"))
    var element = t.get_array_element_type()
    assert_equal(Int(t.kind()), Int(CXType_ConstantArray))
    assert_equal(Int(element.kind()), Int(CXType_Int))
    assert_equal(element.spelling(), String("int"))


def test_type_element_type_matches_array_element_type() raises:
    var tu = _parse_fixture()
    var t = _var_type(tu, String("array_values"))
    var element = t.element_type()
    var array_element = t.get_array_element_type()
    assert_true(element == array_element)


def test_type_get_arg_type() raises:
    var tu = _parse_fixture()
    var t = _function_type(tu, String("add"))
    var first = t.get_arg_type(c_uint(0))
    var second = t.get_arg_type(c_uint(1))
    assert_equal(Int(first.kind()), Int(CXType_Int))
    assert_equal(Int(second.kind()), Int(CXType_Int))
    assert_true(first == second)


def test_type_argument_types() raises:
    var tu = _parse_fixture()
    var t = _function_type(tu, String("add"))
    var args = t.argument_types()
    assert_equal(Int(args.__len__()), 2)
    assert_equal(Int(args[0].kind()), Int(CXType_Int))
    assert_equal(Int(args[1].kind()), Int(CXType_Int))


def test_type_get_template_argument_type_for_non_template_is_invalid() raises:
    var tu = _parse_fixture()
    var t = _function_type(tu, String("add"))
    var arg = t.get_template_argument_type(c_uint(0))
    assert_equal(Int(arg.kind()), Int(CXType_Invalid))


def test_type_get_named_type_for_elaborated_record() raises:
    var tu = _parse_fixture()
    var t = _function_type(tu, String("make_pair"))
    var result = t.get_result()
    var named = result.get_named_type()
    assert_equal(Int(named.kind()), Int(CXType_Record))
    assert_equal(named.spelling(), String("struct Pair"))


def test_type_get_class_type_for_non_objc_is_invalid() raises:
    var tu = _parse_fixture()
    var t = _function_type(tu, String("add"))
    var class_type = t.get_class_type()
    assert_equal(Int(class_type.kind()), Int(CXType_Invalid))


def test_type_get_unqualified() raises:
    var tu = _parse_fixture()
    var t = _var_type(tu, String("const_value"))
    assert_true(t.is_const_qualified())
    var unqualified = t.get_unqualified()
    assert_false(unqualified.is_const_qualified())
    assert_equal(Int(unqualified.kind()), Int(CXType_Int))


def test_type_get_non_reference_keeps_non_reference_type() raises:
    var tu = _parse_fixture()
    var t = _var_type(tu, String("const_value"))
    var non_reference = t.get_non_reference()
    assert_true(t == non_reference)


def test_type_get_size_and_align() raises:
    var tu = _parse_fixture()
    var t = _var_type(tu, String("const_value"))
    assert_equal(Int(t.get_size()), 4)
    assert_equal(Int(t.get_align()), 4)


def test_type_get_offset() raises:
    var tu = _parse_fixture()
    var t = _struct_type(tu, String("Pair"))
    assert_equal(Int(t.get_offset(String("first"))), 0)
    assert_equal(Int(t.get_offset(String("second"))), 32)


def test_type_address_space() raises:
    var tu = _parse_fixture()
    var t = _var_type(tu, String("const_value"))
    assert_equal(Int(t.address_space()), 0)


def test_type_get_ref_qualifier() raises:
    var tu = _parse_fixture()
    var t = _function_type(tu, String("add"))
    assert_equal(Int(t.get_ref_qualifier()), Int(CXRefQualifier_None))


def test_type_get_exception_specification_kind() raises:
    var tu = _parse_fixture()
    var t = _function_type(tu, String("add"))
    assert_equal(
        Int(t.get_exception_specification_kind()),
        Int(CXCursor_ExceptionSpecificationKind_None),
    )


def test_type_get_calling_conv() raises:
    var tu = _parse_fixture()
    var t = _function_type(tu, String("add"))
    assert_equal(Int(t.get_calling_conv()), Int(CXCallingConv_C))


def test_type_qualifiers() raises:
    var tu = _parse_fixture()
    var const_t = _var_type(tu, String("const_value"))
    var volatile_t = _var_type(tu, String("volatile_value"))
    var array_t = _var_type(tu, String("array_values"))
    var plain_t = array_t.get_array_element_type()
    assert_true(const_t.is_const_qualified())
    assert_false(const_t.is_volatile_qualified())
    assert_true(volatile_t.is_volatile_qualified())
    assert_false(plain_t.is_const_qualified())
    assert_false(plain_t.is_volatile_qualified())
    assert_false(plain_t.is_restrict_qualified())


def test_type_is_function_variadic() raises:
    var tu = _parse_fixture()
    var fixed = _function_type(tu, String("add"))
    var variadic = _function_type(tu, String("variadic_sum"))
    assert_false(fixed.is_function_variadic())
    assert_true(variadic.is_function_variadic())


def test_type_is_pod() raises:
    var tu = _parse_fixture()
    var t = _struct_type(tu, String("Pair"))
    assert_true(t.is_pod())


def test_type_get_array_size_and_element_count() raises:
    var tu = _parse_fixture()
    var t = _var_type(tu, String("array_values"))
    assert_equal(Int(t.get_array_size()), 3)
    assert_equal(Int(t.element_count()), 3)


def test_type_num_arg_types() raises:
    var tu = _parse_fixture()
    var t = _function_type(tu, String("add"))
    assert_equal(Int(t.num_arg_types()), 2)


def test_type_num_template_args_for_non_template() raises:
    var tu = _parse_fixture()
    var t = _function_type(tu, String("add"))
    assert_equal(Int(t.num_template_args()), -1)


def test_type_typedef_name() raises:
    var tu = _parse_fixture()
    var elaborated = _var_type(tu, String("my_int_value"))
    var t = elaborated.get_named_type()
    assert_equal(Int(t.kind()), Int(CXType_Typedef))
    assert_equal(t.typedef_name(), String("MyInt"))


def test_type_get_declaration() raises:
    var tu = _parse_fixture()
    var t = _struct_type(tu, String("Pair"))
    var decl = t.get_declaration()
    _check(decl != None, "record type did not return a declaration cursor")
    var cursor = decl.value().copy()
    assert_equal(cursor.spelling(), String("Pair"))
    assert_equal(Int(cursor.kind()), Int(CXCursor_StructDecl))


def test_type_eq() raises:
    var tu = _parse_fixture()
    var add_type = _function_type(tu, String("add"))
    var add_type_again = _function_type(tu, String("add"))
    var ptr_type = _var_type(tu, String("global_ptr"))
    assert_true(add_type == add_type_again)
    assert_false(add_type == ptr_type)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

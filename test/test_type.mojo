"""Unit tests for `clang/type_.mojo`."""
from clang.cindex import (
    Index,
    TranslationUnit,
    Cursor,
    Type,
    CallingConv,
    TypeKind,
    TypeNullabilityKind,
    PrintingPolicy,
)
from clang._ffi import (
    CXCursorKind,
    CXCursor_FunctionDecl,
    CXCursor_StructDecl,
    CXCursor_ClassDecl,
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
    CXType_Atomic,
    CXType_Vector,
)
from std.ffi import c_uint
from std.testing import assert_equal, assert_false, assert_true, TestSuite


comptime FIXTURE_PATH: String = "test/fixtures/type_test_fixture.c"
comptime CXX_FIXTURE_PATH: String = "test/fixtures/cxx_test_fixture.cpp"


def _parse_fixture() raises -> TranslationUnit:
    var index = Index.create()
    return index.parse(FIXTURE_PATH)


def _check(cond: Bool, message: String) raises:
    if not cond:
        raise Error(message)


def _find_cursor(
    mut tu: TranslationUnit, name: String, kind: CXCursorKind
) raises -> Cursor:
    var root = tu.cursor()
    var cursors = root.walk_preorder()
    for i in range(Int(cursors.__len__())):
        var cursor = cursors[i].copy()
        if cursor.kind() == kind and cursor.spelling() == name:
            return cursor^
    raise Error("cursor not found: " + name)


def _cursor_type(
    mut tu: TranslationUnit, name: String, kind: CXCursorKind
) raises -> Type:
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
    var t = Type(tu)
    assert_equal(Int(t.kind().as_c_uint()), Int(CXType_Invalid))


def test_type_spelling_and_kind_from_cursor() raises:
    var tu = _parse_fixture()
    var t = _function_type(tu, String("add"))
    assert_equal(Int(t.kind().as_c_uint()), Int(CXType_FunctionProto))
    assert_equal(t.spelling(), String("int (int, int)"))


def test_type_get_canonical_for_typedef() raises:
    var tu = _parse_fixture()
    var elaborated = _var_type(tu, String("my_int_value"))
    var t = elaborated.get_named_type()
    var canonical = t.get_canonical()
    assert_equal(Int(t.kind().as_c_uint()), Int(CXType_Typedef))
    assert_equal(Int(canonical.kind().as_c_uint()), Int(CXType_Int))
    assert_equal(canonical.spelling(), String("int"))


def test_type_get_pointee() raises:
    var tu = _parse_fixture()
    var t = _var_type(tu, String("global_ptr"))
    var pointee = t.get_pointee()
    assert_equal(Int(t.kind().as_c_uint()), Int(CXType_Pointer))
    assert_equal(Int(pointee.kind().as_c_uint()), Int(CXType_Int))
    assert_equal(pointee.spelling(), String("int"))


def test_type_get_result() raises:
    var tu = _parse_fixture()
    var t = _function_type(tu, String("add"))
    var result = t.get_result()
    assert_equal(Int(result.kind().as_c_uint()), Int(CXType_Int))
    assert_equal(result.spelling(), String("int"))


def test_type_get_array_element_type() raises:
    var tu = _parse_fixture()
    var t = _var_type(tu, String("array_values"))
    var element = t.get_array_element_type()
    assert_equal(Int(t.kind().as_c_uint()), Int(CXType_ConstantArray))
    assert_equal(Int(element.kind().as_c_uint()), Int(CXType_Int))
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
    assert_equal(Int(first.kind().as_c_uint()), Int(CXType_Int))
    assert_equal(Int(second.kind().as_c_uint()), Int(CXType_Int))
    assert_true(first == second)


def test_type_argument_types() raises:
    var tu = _parse_fixture()
    var t = _function_type(tu, String("add"))
    var args = t.argument_types()
    assert_equal(Int(args.__len__()), 2)
    assert_equal(Int(args[0].kind().as_c_uint()), Int(CXType_Int))
    assert_equal(Int(args[1].kind().as_c_uint()), Int(CXType_Int))


def test_type_get_template_argument_type_for_non_template_is_invalid() raises:
    var tu = _parse_fixture()
    var t = _function_type(tu, String("add"))
    var arg = t.get_template_argument_type(c_uint(0))
    assert_equal(Int(arg.kind().as_c_uint()), Int(CXType_Invalid))


def test_type_get_named_type_for_elaborated_record() raises:
    var tu = _parse_fixture()
    var t = _function_type(tu, String("make_pair"))
    var result = t.get_result()
    var named = result.get_named_type()
    assert_equal(Int(named.kind().as_c_uint()), Int(CXType_Record))
    assert_equal(named.spelling(), String("struct Pair"))


def test_type_get_class_type_for_non_objc_is_invalid() raises:
    var tu = _parse_fixture()
    var t = _function_type(tu, String("add"))
    var class_type = t.get_class_type()
    assert_equal(Int(class_type.kind().as_c_uint()), Int(CXType_Invalid))


def test_type_get_unqualified() raises:
    var tu = _parse_fixture()
    var t = _var_type(tu, String("const_value"))
    assert_true(t.is_const_qualified())
    var unqualified = t.get_unqualified()
    assert_false(unqualified.is_const_qualified())
    assert_equal(Int(unqualified.kind().as_c_uint()), Int(CXType_Int))


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
    assert_equal(
        Int(t.get_ref_qualifier().as_c_uint()), Int(CXRefQualifier_None)
    )


def test_type_get_exception_specification_kind() raises:
    var tu = _parse_fixture()
    var t = _function_type(tu, String("add"))
    assert_equal(
        Int(t.get_exception_specification_kind().as_c_uint()),
        Int(CXCursor_ExceptionSpecificationKind_None),
    )


def test_type_get_calling_conv() raises:
    var tu = _parse_fixture()
    var t = _function_type(tu, String("add"))
    assert_equal(Int(t.get_calling_conv().as_c_uint()), Int(CXCallingConv_C))


def test_type_get_calling_conv_name() raises:
    var tu = _parse_fixture()
    var t = _function_type(tu, String("add"))
    assert_equal(t.get_calling_conv().name(), String("C"))
    assert_equal(CallingConv.INVALID.name(), String("INVALID"))
    assert_equal(CallingConv.UNEXPOSED.name(), String("UNEXPOSED"))



def test_type_get_value_type() raises:
    var tu = _parse_fixture()
    var t = _var_type(tu, String("atomic_value"))
    assert_equal(Int(t.kind().as_c_uint()), Int(CXType_Atomic))

    var value_type = t.get_value_type()
    assert_true(value_type is not None)
    assert_equal(Int(value_type.value().kind().as_c_uint()), Int(CXType_Int))
    assert_equal(value_type.value().spelling(), String("int"))


def test_type_vector_element_type_and_count() raises:
    var tu = _parse_fixture()
    var t = _var_type(tu, String("vector_value")).get_canonical()
    assert_equal(Int(t.kind().as_c_uint()), Int(CXType_Vector))

    var element = t.element_type()
    assert_equal(Int(element.kind().as_c_uint()), Int(CXType_Int))


def test_type_nullability_kind() raises:
    var tu = _parse_fixture()
    var t = _var_type(tu, String("global_ptr"))
    var nullability = t.nullability()
    _check(
        nullability == TypeNullabilityKind.INVALID
        or nullability == TypeNullabilityKind.UNSPECIFIED
        or nullability == TypeNullabilityKind.NON_NULL
        or nullability == TypeNullabilityKind.NULLABLE
        or nullability == TypeNullabilityKind.NULLABLE_RESULT,
        "nullability should return a typed enum value",
    )
    assert_equal(Int(t.element_count()), -1)


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
    assert_equal(Int(t.kind().as_c_uint()), Int(CXType_Typedef))
    assert_equal(t.typedef_name(), String("MyInt"))


def test_type_get_declaration() raises:
    var tu = _parse_fixture()
    var t = _struct_type(tu, String("Pair"))
    var decl = t.get_declaration()
    _check(decl != None, "record type did not return a declaration cursor")
    var cursor = decl.value().copy()
    assert_equal(cursor.spelling(), String("Pair"))
    assert_equal(Int(cursor.kind().as_c_uint()), Int(CXCursor_StructDecl))


def test_type_eq() raises:
    var tu = _parse_fixture()
    var add_type = _function_type(tu, String("add"))
    var add_type_again = _function_type(tu, String("add"))
    var ptr_type = _var_type(tu, String("global_ptr"))
    assert_true(add_type == add_type_again)
    assert_false(add_type == ptr_type)


# -----------------------------------------------------------------------
# Phase 2.1: Type.get_fields, get_bases, get_methods
# -----------------------------------------------------------------------


def _parse_cxx() raises -> TranslationUnit:
    var index = Index.create()
    return index.parse(CXX_FIXTURE_PATH)


def test_type_get_fields_on_struct() raises:
    var tu = _parse_fixture()
    var t = _struct_type(tu, "Pair")
    var fields = t.get_fields()
    var first = fields[0].copy()
    assert_equal(Int(fields.__len__()), 2, "Pair should have 2 fields")
    assert_equal(first.spelling(), "first", "first field should be 'first'")


def test_type_get_fields_empty_for_non_record() raises:
    var tu = _parse_fixture()
    var t = _function_type(tu, "add")
    var fields = t.get_fields()
    assert_equal(
        Int(fields.__len__()), 0, "function type should have no fields"
    )



def test_type_raw_value() raises:
    var tu = _parse_fixture()
    var t = _function_type(tu, "add")
    var raw = t.raw_value()
    assert_equal(Int(raw.kind), Int(CXType_FunctionProto))


def test_type_translation_unit() raises:
    var tu = _parse_fixture()
    var t = _function_type(tu, "add")
    var got_tu = t.translation_unit()
    _check(
        got_tu.spelling() == tu.spelling(), "translation unit spelling matches"
    )


def test_type_write_to() raises:
    var tu = _parse_fixture()
    var t = _function_type(tu, "add")
    var s = String(t)
    _check(s.byte_length() > 0, "write_to should produce non-empty string")


def test_type_ne() raises:
    var tu = _parse_fixture()
    var add_type = _function_type(tu, "add")
    var ptr_type = _var_type(tu, "global_ptr")
    _check(add_type != ptr_type, "different types should be !=")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

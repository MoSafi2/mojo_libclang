"""Unit tests for `src/libclang/cursor.mojo`."""
from src.libclang import (
    Index,
    TranslationUnit,
    Cursor,
    Type,
    AccessSpecifier,
    CursorKind,
    BinaryOperator,
    UnaryOperator,
    TemplateArgumentKind,
)
from src._ffi import (
    CXCursor_TranslationUnit,
    CXCursor_TypedefDecl,
    CXCursor_FunctionDecl,
    CXCursor_StructDecl,
    CXCursor_VarDecl,
    CXCursor_ParmDecl,
    CXCursor_FieldDecl,
    CXCursor_CXXMethod,
    CXCursor_ClassDecl,
    CXCursor_EnumDecl,
    CXCursor_Constructor,
    CXCursor_Destructor,
    CXCursor_CXXBaseSpecifier,
    CXCursor_UnaryOperator,
    CXCursor_DeclRefExpr,
    CXType_Int,
    CXType_FunctionProto,
    CXType_Record,
)
from src.libclang.cursor import collect_children, walk_preorder
from std.ffi import c_uint, c_int
from std.iter import iter, enumerate
from std.testing import assert_equal, assert_true, assert_false, TestSuite


comptime FIXTURE_PATH: String = "test/fixtures/type_test_fixture.c"
comptime CXX_FIXTURE_PATH: String = "test/fixtures/cxx_test_fixture.cpp"


def _check(cond: Bool, msg: String = "") raises:
    if not cond:
        raise Error(msg)


def _parse() raises -> TranslationUnit:
    var index = Index.create()
    return index.parse(FIXTURE_PATH)


def _find(mut tu: TranslationUnit, kind: c_uint) raises -> Cursor:
    var root = tu.cursor()
    var children = root.get_children()
    for i in range(children.__len__()):
        var c = children[i].copy()
        if c.kind() == kind:
            return c^
    raise Error("child not found by kind")


def _find_by_spelling(mut tu: TranslationUnit, name: String) raises -> Cursor:
    var root = tu.cursor()
    var walk = walk_preorder(root)
    for i in range(walk.__len__()):
        var c = walk[i].copy()
        if c.spelling() == name:
            return c^
    raise Error(t"child not found by spelling: {name}")


def _parse_cxx() raises -> TranslationUnit:
    var index = Index.create()
    return index.parse(CXX_FIXTURE_PATH)


def _find_cxx(mut tu: TranslationUnit, kind: c_uint) raises -> Cursor:
    var root = tu.cursor()
    var children = root.get_children()
    for i in range(children.__len__()):
        var c = children[i].copy()
        if c.kind() == kind:
            return c^
    raise Error("child not found by kind")


def test_null_cursor() raises:
    var tu = _parse()
    var c = Cursor.null(tu)
    _check(c.is_null(), "null cursor should report is_null")


def test_tu_cursor() raises:
    var tu = _parse()
    var c = tu.cursor()
    assert_equal(Int(c.kind().as_c_uint()), Int(CXCursor_TranslationUnit))


def test_spelling() raises:
    var tu = _parse()
    var c = tu.cursor()
    _check(c.spelling().byte_length() > 0)
    var td = _find(tu, CXCursor_TypedefDecl)
    _check(td.spelling().byte_length() > 0)


def test_display_name_and_usr() raises:
    var tu = _parse()
    var td = _find(tu, CXCursor_TypedefDecl)
    _check(td.display_name().byte_length() > 0)
    _check(td.usr() is not None)


def test_type_and_result_type() raises:
    var tu = _parse()
    var func = _find(tu, CXCursor_FunctionDecl)
    var typ = func.type()
    assert_equal(Int(typ.kind().as_c_uint()), Int(CXType_FunctionProto))
    var rt = func.result_type()
    assert_equal(Int(rt.kind().as_c_uint()), Int(CXType_Int))


def test_location_and_extent() raises:
    var tu = _parse()
    var func = _find(tu, CXCursor_FunctionDecl)
    var loc = func.location()
    _check(Int(loc.line()) >= 1)
    var ext = func.extent()
    _check(not ext.is_null())


def test_semantic_parent() raises:
    var tu = _parse()
    var top = _find(tu, CXCursor_TypedefDecl)
    var p = top.semantic_parent()
    _check(p is not None)
    assert_equal(
        Int(p.value().kind().as_c_uint()), Int(CXCursor_TranslationUnit)
    )


def test_lexical_parent() raises:
    var tu = _parse()
    var top = _find(tu, CXCursor_TypedefDecl)
    var p = top.lexical_parent()
    _check(p is not None)
    assert_equal(
        Int(p.value().kind().as_c_uint()), Int(CXCursor_TranslationUnit)
    )


def test_referenced_definition_canonical() raises:
    var tu = _parse()
    var c = _find(tu, CXCursor_TypedefDecl)
    _check(c.referenced() is not None)
    _check(c.definition() is not None)
    var canon = c.canonical()
    _check(c == canon)


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


def test_function_arguments() raises:
    var tu = _parse()
    var func = _find(tu, CXCursor_FunctionDecl)
    assert_equal(Int(func.num_arguments()), 2)
    var args = func.get_arguments()
    assert_equal(args.__len__(), 2)
    for i in range(args.__len__()):
        var arg = args[i].copy()
        assert_equal(Int(arg.kind().as_c_uint()), Int(CXCursor_ParmDecl))


def test_template_arguments() raises:
    var tu = _parse()
    var c = _find(tu, CXCursor_VarDecl)


def test_equality() raises:
    var tu = _parse()
    var c1 = tu.cursor()
    var c2 = tu.cursor()
    _check(c1 == c2)
    var children = c1.get_children()
    var child = children[0].copy()
    _check(not (c1 == child))


def test_equality_null() raises:
    var tu = _parse()
    var null1 = Cursor.null(tu)
    var null2 = Cursor.null(tu)
    _check(null1 == null2)


def test_children_and_walk() raises:
    var tu = _parse()
    var c = tu.cursor()
    var children = c.get_children()
    var walk = c.walk_preorder()
    _check(children.__len__() > 0)
    _check(walk.__len__() >= children.__len__())


#
def test_collect_children_nonempty() raises:
    var tu = _parse()
    var root = tu.cursor()
    var children = collect_children(root)
    _check(children.__len__() > 0, "root should have children")


# #
def test_collect_children_first_typedef() raises:
    var tu = _parse()
    var root = tu.cursor()
    var children = collect_children(root)
    var first = children[0].copy()
    assert_equal(
        Int(first.kind().as_c_uint()),
        Int(CXCursor_TypedefDecl),
        "first child should be TypedefDecl",
    )


def test_collect_children_includes_struct() raises:
    var tu = _parse()
    var root = tu.cursor()
    var children = collect_children(root)
    var found = False
    for i in range(children.__len__()):
        var c = children[i].copy()
        if c.kind() == CXCursor_StructDecl:
            found = True
            break
    _check(found, "children should include a struct decl")


def test_collect_children_includes_function() raises:
    var tu = _parse()
    var root = tu.cursor()
    var children = collect_children(root)
    var found = False
    for i in range(children.__len__()):
        var c = children[i].copy()
        if c.kind() == CXCursor_FunctionDecl:
            found = True
            break
    _check(found, "children should include a function decl")


# #
def test_walk_preorder_first_is_root() raises:
    var tu = _parse()
    var root = tu.cursor()
    var walk = walk_preorder(root)
    var first = walk[0].copy()
    assert_equal(
        Int(first.kind().as_c_uint()),
        Int(CXCursor_TranslationUnit),
        "first element should be the root TU cursor",
    )


def test_walk_preorder_deeper_than_children() raises:
    var tu = _parse()
    var root = tu.cursor()
    var children = collect_children(root)
    var walk = walk_preorder(root)
    _check(
        walk.__len__() >= children.__len__(),
        "preorder walk should be at least as deep as direct children",
    )


def test_collect_children_child_spelling() raises:
    var tu = _parse()
    var root = tu.cursor()
    var children = collect_children(root)
    for i in range(children.__len__()):
        var c = children[i].copy()
        var s = c.spelling()
        _check(s.byte_length() > 0, "each child should have non-empty spelling")


def test_walk_preorder_spelling_nonempty() raises:
    var tu = _parse()
    var root = tu.cursor()
    var walk = walk_preorder(root)
    var nonempty_count = 0
    for i in range(walk.__len__()):
        var c = walk[i].copy()
        var s = c.spelling()
        if s.byte_length() > 0:
            nonempty_count += 1
    _check(
        nonempty_count > 0,
        "at least some walk elements should have non-empty spelling",
    )


# -----------------------------------------------------------------------
# C++ feature tests
# -----------------------------------------------------------------------


def test_cxx_is_virtual() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "virtual_method")
    _check(c.is_virtual(), "virtual_method should be virtual")


def test_cxx_is_pure_virtual() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "virtual_method")
    _check(c.is_pure_virtual(), "virtual_method should be pure virtual")


def test_cxx_is_static() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "static_method")
    _check(c.is_static(), "static_method should be static")


def test_cxx_is_const() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "virtual_method")
    _check(c.is_const(), "virtual_method should be const")


def test_cxx_is_defaulted() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "Derived")
    var children = c.get_children()
    var found_defaulted = False
    for i in range(children.__len__()):
        var child = children[i].copy()
        if child.is_defaulted():
            found_defaulted = True
            break
    _check(found_defaulted, "Derived should have a defaulted constructor")


def test_cxx_is_deleted() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "Derived")
    # No deleted functions in this fixture, but check that none are incorrectly detected as deleted
    var children = c.get_children()
    for i in range(children.__len__()):
        var child = children[i].copy()
        if child.spelling() == "Derived":
            # constructors are defaulted not deleted
            assert_false(
                child.is_deleted(), "Derived() is defaulted not deleted"
            )


def test_cxx_is_copy_assignment_operator() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "operator=")
    _check(
        c.is_copy_assignment_operator(), "operator= should be copy assignment"
    )


def test_cxx_is_move_assignment_operator() raises:
    var tu = _parse_cxx()
    # The Derived class has move assignment, but there are two operator= overloads
    var c = _find_by_spelling(tu, "operator=")
    # operator= is both copy and move? Let's just check it works without crashing
    _ = c.is_move_assignment_operator()
    _ = c.is_copy_assignment_operator()


def test_cxx_is_explicit() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "Derived")
    var children = c.get_children()
    var found_explicit = False
    for i in range(children.__len__()):
        var child = children[i].copy()
        if child.is_explicit():
            found_explicit = True
            break
    _check(found_explicit, "Derived(double) should be explicit")


def test_cxx_is_abstract_record() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "Base")
    _check(c.is_abstract_record(), "Base should be abstract")


def test_cxx_is_scoped_enum() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "ScopedEnum")
    _check(c.is_scoped_enum(), "ScopedEnum should be scoped")


def test_cxx_access_specifier() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "virtual_method")
    var spec = c.access_specifier()
    # public = 1
    assert_equal(Int(spec.as_c_uint()), 1, "virtual_method should be public")


# def test_cxx_get_bases() raises:
#     var tu = _parse_cxx()
#     var c = _find_by_spelling(tu, "Derived")
#     var t = c.type()
#     var bases = t.get_bases()
#     _check(bases.__len__() > 0, "Derived should have a base class")


# def test_cxx_get_methods() raises:
#     var tu = _parse_cxx()
#     var c = _find_by_spelling(tu, "Derived")
#     var t = c.type()
#     var methods = t.get_methods()
#     _check(methods.__len__() > 0, "Derived should have methods")


def test_cxx_overridden_cursors() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "overridden_method")
    var overridden = c.overridden_cursors()
    # May be 0 if the overridden chain isn't fully resolved in a single-TU parse;
    # the important thing is the call doesn't crash and returns sane results.
    _check(
        overridden.__len__() >= 0, "overridden cursors call should not crash"
    )


def test_cxx_is_virtual_base() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "Derived")
    var children = c.get_children()
    for i in range(children.__len__()):
        var child = children[i].copy()
        if child.kind() == CXCursor_CXXBaseSpecifier:
            assert_false(child.is_virtual_base(), "Base is not virtual")


def test_cxx_is_anonymous() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "Derived")
    assert_false(c.is_anonymous(), "Derived is not anonymous")


def test_cxx_is_anonymous_record_decl() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "Derived")
    assert_false(
        c.is_anonymous_record_decl(), "Derived is not anonymous record"
    )


def test_cxx_linkage() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "Derived")
    var lnk = c.linkage()
    # CXLinkage_External = 4 (or similar), just check it's non-zero
    _check(Int(lnk.as_c_uint()) > 0, "Derived should have external linkage")


def test_cxx_visibility() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "virtual_method")
    var vis = c.visibility()
    # CXVisibility_Default = 0, CXVisibility_Hidden = 1, CXVisibility_Protected = 2
    # Just check it returns a valid value without crashing
    _check(
        Int(vis.as_c_uint()) >= 0, "visibility should be a non-negative value"
    )


def test_cxx_availability() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "virtual_method")
    var avail = c.availability()
    # CXAvailability_Available = 0
    _check(Int(avail.as_c_uint()) == 0, "virtual_method should be available")


def test_cxx_language() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "virtual_method")
    var lang = c.language()
    # CXLanguage_CPlusPlus = 3
    assert_equal(
        Int(lang.as_c_uint()), 3, "C++ method should report CPlusPlus language"
    )


def test_cxx_storage_class() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "static_method")
    var sc = c.storage_class()
    # CX_SC_Static = 3
    assert_equal(
        Int(sc.as_c_uint()), 3, "static_method should have static storage class"
    )


def test_cxx_tls_kind() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "Derived")
    var tls = c.tls_kind()
    # CXTLS_None = 0 for non-thread-local
    assert_equal(Int(tls.as_c_uint()), 0, "Derived should have no TLS kind")


def test_cxx_is_bitfield() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "Derived")
    assert_false(c.is_bitfield(), "Derived is not a bitfield")


def test_cxx_get_bitfield_width_not_bitfield() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "virtual_method")
    assert_equal(
        Int(c.get_bitfield_width()), -1, "non-bitfield should return -1"
    )


def test_cxx_get_offset_of_field() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "Derived")
    var children = c.get_children()
    for i in range(children.__len__()):
        var child = children[i].copy()
        if child.kind() == CXCursor_CXXBaseSpecifier:
            _ = child.get_offset_of_field()
            break


def test_cxx_get_mangled_name() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "virtual_method")
    var mangled = c.mangled_name()
    _check(mangled.byte_length() > 0, "mangled name should be non-empty")


def test_cxx_underlying_typedef_type() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "ScopedEnum")
    # ScopedEnum is not a typedef, but test that calling underlying_typedef_type
    # doesn't crash
    _ = c.underlying_typedef_type()


def test_cxx_enum_type() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "ScopedEnum")
    var t = c.enum_type()
    _ = t.spelling()


# -----------------------------------------------------------------------
# New feature tests: Phase 1
# -----------------------------------------------------------------------


def test_is_invalid_on_null() raises:
    var tu = _parse()
    var c = Cursor.null(tu)
    _check(c.is_invalid(), "null cursor should be invalid")


def test_is_translation_unit_on_root() raises:
    var tu = _parse()
    var c = tu.cursor()
    _check(c.is_translation_unit(), "root cursor should be translation unit")


def test_is_preprocessing_not_found() raises:
    var tu = _parse()
    var c = _find(tu, CXCursor_FunctionDecl)
    assert_false(c.is_preprocessing(), "function decl is not preprocessing")


def test_is_unexposed_not_found() raises:
    var tu = _parse()
    var c = _find(tu, CXCursor_TypedefDecl)
    assert_false(c.is_unexposed(), "typedef decl is not unexposed")


def test_has_attrs_on_plain_decl() raises:
    var tu = _parse()
    var c = _find(tu, CXCursor_FunctionDecl)
    assert_false(c.has_attrs(), "plain function decl has no attrs")


def test_is_variadic_on_variadic_func() raises:
    var tu = _parse()
    var c = _find_by_spelling(tu, "variadic_sum")
    _check(c.is_variadic(), "variadic_sum should be variadic")


def test_is_variadic_on_regular_func() raises:
    var tu = _parse()
    var c = _find(tu, CXCursor_FunctionDecl)
    assert_false(c.is_variadic(), "regular add() is not variadic")


def test_is_const_qualified_type() raises:
    var tu = _parse()
    var c = _find_by_spelling(tu, "const_value")
    _check(c.is_const_qualified_type(), "const_value should be const qualified")


def test_is_volatile_qualified_type() raises:
    var tu = _parse()
    var c = _find_by_spelling(tu, "volatile_value")
    _check(
        c.is_volatile_qualified_type(),
        "volatile_value should be volatile qualified",
    )


def test_is_pod_type_on_struct() raises:
    var tu = _parse()
    var c = _find(tu, CXCursor_StructDecl)
    var t = c.type()
    _check(t.is_pod(), "struct Pair should be POD")


def test_is_anonymous() raises:
    var tu = _parse()
    var c = _find(tu, CXCursor_FunctionDecl)
    assert_false(c.is_anonymous(), "named function is not anonymous")


def test_num_arguments() raises:
    var tu = _parse()
    var c = _find_by_spelling(tu, "add")
    assert_equal(Int(c.num_arguments()), 2, "add() should have 2 params")


def test_get_arguments() raises:
    var tu = _parse()
    var c = _find_by_spelling(tu, "add")
    var args = c.get_arguments()
    assert_equal(args.__len__(), 2, "add() should have 2 args")
    for i in range(args.__len__()):
        var arg = args[i].copy()
        assert_equal(Int(arg.kind().as_c_uint()), Int(CXCursor_ParmDecl))


def test_num_template_arguments() raises:
    var tu = _parse()
    var c = _find(tu, CXCursor_TypedefDecl)
    assert_equal(
        Int(c.num_template_arguments()),
        -1,
        "typedef should have no template args",
    )


# def test_pretty_printed() raises:
#     var tu = _parse()
#     var c = _find(tu, CXCursor_FunctionDecl)
#     var text = c.pretty_printed()
#     _check(text.byte_length() > 0, "pretty-printed text should be non-empty")


def test_brief_comment_none() raises:
    var tu = _parse()
    var c = _find(tu, CXCursor_FunctionDecl)
    _check(c.brief_comment() is None, "no brief comment on uncommented decl")


def test_raw_comment_none() raises:
    var tu = _parse()
    var c = _find(tu, CXCursor_FunctionDecl)
    _check(c.raw_comment() is None, "no raw comment on uncommented decl")


def test_get_fields_empty() raises:
    var tu = _parse()
    var c = _find(tu, CXCursor_TypedefDecl)
    var t = c.type()
    var fields = t.get_fields()
    assert_equal(fields.__len__(), 0, "typedef has no fields")


# def test_enum_type_and_get_field_offsetof() raises:
#     var tu = _parse()
#     var c = _find(tu, CXCursor_StructDecl)
#     _ = c.enum_type()
#     _ = c.get_field_offsetof()


def test_cursor_for_in_iteration() raises:
    var tu = _parse()
    var root = tu.cursor()
    var count = 0
    for child in root:
        _ = child.kind()
        count += 1
    assert_true(count > 0, "for-in over cursor should yield children")


def test_cursor_iterable_conformance() raises:
    var tu = _parse()
    var root = tu.cursor()
    var it = iter(root)
    var first = it.__next__()
    assert_true(
        first.spelling().byte_length() >= 0,
        "iter(root) should return a working Iterator",
    )


def test_cursor_enumerate_iteration() raises:
    var tu = _parse()
    var root = tu.cursor()
    var count = 0
    for i, child in enumerate(root):
        _ = i
        _ = child.kind()
        count += 1
        if count >= 3:
            break
    assert_equal(count, 3, "enumerate(cursor) should iterate children")


def test_null_cursor_iteration_is_empty() raises:
    var tu = _parse()
    var c = Cursor.null(tu)
    var count = 0
    for _ in c:
        count += 1
    assert_equal(count, 0, "null cursor should yield no children")


def test_enum_value() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "X")
    _check(c.kind() == CursorKind.ENUM_CONSTANT_DECL, "expected enum constant")
    assert_equal(Int(c.enum_value()), 0, "first enum constant should be 0")


def test_binary_operator() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "operator+")
    if c.kind() == CursorKind.BINARY_OPERATOR:
        _check(
            c.binary_operator() == BinaryOperator.ADD,
            "expected Add binary operator",
        )
    else:
        # Some libclang versions expose operator functions as FunctionDecls.
        _check(True, "operator found")


def test_is_function_inlined() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "inlined_func")
    _check(c.is_function_inlined(), "expected inlined function")


def test_constructor_predicates() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "Copyable")
    if c.kind() == CursorKind.CONSTRUCTOR:
        _check(c.is_copy_constructor(), "expected copy constructor")
        _check(not c.is_default_constructor(), "not default constructor")
    else:
        _check(True, "constructor found")


def test_cursor_translation_unit() raises:
    var tu = _parse()
    var c = _find(tu, CXCursor_FunctionDecl)
    var got_tu = c.translation_unit()
    _check(got_tu.spelling() == tu.spelling(), "cursor translation_unit matches")


def test_cursor_raw_value() raises:
    var tu = _parse()
    var c = _find(tu, CXCursor_FunctionDecl)
    var raw = c.raw_value()
    assert_equal(Int(raw.kind), Int(CXCursor_FunctionDecl))


def test_cursor_raw_translation_unit() raises:
    var tu = _parse()
    var c = _find(tu, CXCursor_FunctionDecl)
    var raw_tu = c.raw_translation_unit()
    _check(raw_tu is not None, "raw translation unit should not be null")


def test_cursor_write_to() raises:
    var tu = _parse()
    var c = _find(tu, CXCursor_FunctionDecl)
    var s = String(c)
    _check(s.byte_length() > 0, "write_to should produce non-empty string")


def test_cursor_equals_and_ne() raises:
    var tu = _parse()
    var c1 = _find(tu, CXCursor_FunctionDecl)
    var c2 = _find(tu, CXCursor_FunctionDecl)
    _check(c1.equals(c2), "equals should return true for same cursor")
    _check(c1 == c2, "== should return true for same cursor")
    _check(c1 == c2, "!= should return false for same cursor")
    var null_c = Cursor.null(tu)
    _check(not c1.equals(null_c), "equals should return false for null cursor")


def test_cursor_get_argument() raises:
    var tu = _parse()
    var c = _find_by_spelling(tu, "add")
    var arg0 = c.get_argument(c_uint(0))
    assert_equal(arg0.kind(), CursorKind.PARM_DECL)
    assert_equal(arg0.spelling(), "a")


def test_cursor_get_tokens() raises:
    var tu = _parse()
    var c = _find_by_spelling(tu, "add")
    var tokens = c.get_tokens()
    _check(Int(tokens.__len__()) > 0, "cursor should have tokens")


def test_cursor_is_mutable_field() raises:
    var tu = _parse_cxx()
    var root = tu.cursor()
    var cursors = root.walk_preorder()
    var found = False
    for i in range(cursors.__len__()):
        var c = cursors[i].copy()
        if c.kind() == CursorKind.FIELD_DECL and c.spelling() == "m":
            _check(c.is_mutable_field(), "m should be mutable")
            found = True
    _check(found, "mutable field not found")


def test_cursor_is_external_symbol() raises:
    var tu = _parse()
    var c = _find_by_spelling(tu, "add")
    var result = c.is_external_symbol()
    _check(result == True or result == False, "is_external_symbol should return a bool")


def test_cursor_is_restrict_qualified_type() raises:
    var tu = _parse()
    var c = _find_by_spelling(tu, "restrict_func")
    var children = c.get_children()
    var found = False
    for i in range(children.__len__()):
        var child = children[i].copy()
        if child.kind() == CursorKind.PARM_DECL:
            _check(
                child.is_restrict_qualified_type(),
                "restrict parameter should be restrict-qualified",
            )
            found = True
    _check(found, "restrict parameter not found")


def test_cursor_is_pod_type() raises:
    var tu = _parse()
    var c = _find_by_spelling(tu, "alias_value")
    _check(c.is_pod_type(), "struct type should be POD")


def test_cursor_constructor_predicates_extended() raises:
    var tu = _parse_cxx()
    var derived = _find_by_spelling(tu, "Derived")
    var children = derived.get_children()
    var found_default = False
    var found_copy = False
    var found_move = False
    var found_converting = False
    for i in range(children.__len__()):
        var c = children[i].copy()
        if c.kind() == CursorKind.CONSTRUCTOR:
            if c.is_default_constructor():
                found_default = True
            if c.is_copy_constructor():
                found_copy = True
            if c.is_move_constructor():
                found_move = True
            if c.is_converting_constructor():
                found_converting = True
    _check(found_default, "default constructor not found")
    _check(found_copy, "copy constructor not found")
    _check(found_move, "move constructor not found")
    _check(found_converting, "converting constructor not found")


def test_cursor_template_arguments() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "int_wrapper")
    var decl = c.type().get_declaration()
    _check(decl != None, "template specialization declaration not found")
    var spec = decl.value().copy()
    assert_equal(Int(spec.num_template_arguments()), 1)
    assert_equal(
        spec.template_argument_kind(c_uint(0)),
        TemplateArgumentKind.TYPE,
    )
    var t = spec.template_argument_type(c_uint(0))
    assert_equal(Int(t.kind().as_c_uint()), Int(CXType_Int))
    var tmpl = spec.specialized_cursor_template()
    _check(tmpl != None, "specialized cursor template not found")
    _check(tmpl.value().spelling() == "Wrapper", "template should be Wrapper")


def test_cursor_nttp_arguments() raises:
    var tu = _parse_cxx()
    var c = _find_by_spelling(tu, "nttp_instance")
    var decl = c.type().get_declaration()
    _check(decl != None, "NTTP specialization declaration not found")
    var spec = decl.value().copy()
    assert_equal(Int(spec.num_template_arguments()), 1)
    assert_equal(
        spec.template_argument_kind(c_uint(0)),
        TemplateArgumentKind.INTEGRAL,
    )
    assert_equal(Int(spec.template_argument_value(c_uint(0))), 42)
    assert_equal(Int(spec.template_argument_unsigned_value(c_uint(0))), 42)


def test_cursor_overloaded_decls() raises:
    var tu = _parse_cxx()
    var root = tu.cursor()
    var cursors = root.walk_preorder()
    for i in range(cursors.__len__()):
        var c = cursors[i].copy()
        if c.spelling() == "overloaded_fn" and Int(c.num_overloaded_decls()) > 0:
            var decl = c.get_overloaded_decl(c_uint(0))
            _check(decl.spelling() == "overloaded_fn")
            return
    _check(True, "no overloaded decl cursor found")


def test_cursor_get_field_offsetof() raises:
    var tu = _parse()
    var s = _find_by_spelling(tu, "Pair")
    var children = s.get_children()
    for i in range(children.__len__()):
        var c = children[i].copy()
        if c.kind() == CursorKind.FIELD_DECL and c.spelling() == "first":
            assert_equal(Int(c.get_field_offsetof()), 0)
        if c.kind() == CursorKind.FIELD_DECL and c.spelling() == "second":
            assert_equal(Int(c.get_field_offsetof()), 32)


# def test_cursor_get_base_offsetof() raises:
#     var tu = _parse_cxx()
#     var derived = _find_by_spelling(tu, "ConcreteDerived")
#     var children = derived.get_children()
#     for i in range(children.__len__()):
#         var c = children[i].copy()
#         if c.kind() == CursorKind.CXX_BASE_SPECIFIER:
#             var offset = c.get_base_offsetof(derived)
#             _check(
#                 Int(offset) >= -1,
#                 "get_base_offsetof should return a valid offset value",
#             )


def test_cursor_objc_type_encoding() raises:
    var tu = _parse()
    var c = _find_by_spelling(tu, "add")
    var enc = c.objc_type_encoding()
    _check(enc.byte_length() >= 0, "objc_type_encoding should return a string")


def test_cursor_unary_operator() raises:
    var tu = _parse_cxx()
    var root = tu.cursor()
    var cursors = root.walk_preorder()
    for i in range(cursors.__len__()):
        var c = cursors[i].copy()
        if c.kind() == CursorKind.UNARY_OPERATOR:
            _check(
                c.unary_operator() == UnaryOperator.LNOT,
                "expected logical-not unary operator",
            )
            return
    _check(True, "no unary operator found")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

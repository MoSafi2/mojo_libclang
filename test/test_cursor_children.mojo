"""Unit tests for `src/libclang/cursor_children.mojo`."""
from src.libclang import (
    Index,
    TranslationUnit,
    Cursor,
    CXCursor_TranslationUnit,
    CXCursor_FunctionDecl,
    CXCursor_TypedefDecl,
    CXCursor_StructDecl,
    CXCursor_VarDecl,
)
from src.libclang.cursor_children import collect_children, walk_preorder
from std.testing import assert_equal, assert_true, assert_false, TestSuite


comptime FIXTURE_PATH: String = "test/fixtures/type_test_fixture.c"


def _check(cond: Bool, msg: String) raises:
    if not cond:
        raise Error(msg)


def _parse_fixture() raises -> TranslationUnit:
    var index = Index.create()
    return index.parse(FIXTURE_PATH)


def test_collect_children_nonempty() raises:
    var tu = _parse_fixture()
    var root = tu.cursor()
    var children = collect_children(root)
    _check(Int(children.__len__()) > 0, "root should have children")


def test_collect_children_first_typedef() raises:
    var tu = _parse_fixture()
    var root = tu.cursor()
    var children = collect_children(root)
    var first = children[0].copy()
    assert_equal(Int(first.kind()), Int(CXCursor_TypedefDecl),
                 "first child should be TypedefDecl")


def test_collect_children_includes_struct() raises:
    var tu = _parse_fixture()
    var root = tu.cursor()
    var children = collect_children(root)
    var found = False
    for i in range(Int(children.__len__())):
        if children[i].copy().kind() == CXCursor_StructDecl:
            found = True
            break
    _check(found, "children should include a struct decl")


def test_collect_children_includes_function() raises:
    var tu = _parse_fixture()
    var root = tu.cursor()
    var children = collect_children(root)
    var found = False
    for i in range(Int(children.__len__())):
        if children[i].copy().kind() == CXCursor_FunctionDecl:
            found = True
            break
    _check(found, "children should include a function decl")


def test_walk_preorder_first_is_root() raises:
    var tu = _parse_fixture()
    var root = tu.cursor()
    var walk = walk_preorder(root)
    var first = walk[0].copy()
    assert_equal(Int(first.kind()), Int(CXCursor_TranslationUnit),
                 "first element should be the root TU cursor")


def test_walk_preorder_deeper_than_children() raises:
    var tu = _parse_fixture()
    var root = tu.cursor()
    var children = collect_children(root)
    var walk = walk_preorder(root)
    _check(Int(walk.__len__()) >= Int(children.__len__()),
           "preorder walk should be at least as deep as direct children")


def test_collect_children_child_spelling() raises:
    var tu = _parse_fixture()
    var root = tu.cursor()
    var children = collect_children(root)
    for i in range(Int(children.__len__())):
        var c = children[i].copy()
        var s = c.spelling()
        _check(s.byte_length() > 0,
               "each child should have non-empty spelling")


def test_walk_preorder_spelling_nonempty() raises:
    var tu = _parse_fixture()
    var root = tu.cursor()
    var walk = walk_preorder(root)
    for i in range(Int(walk.__len__())):
        var c = walk[i].copy()
        var s = c.spelling()
        _check(s.byte_length() > 0,
               "each element should have non-empty spelling")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

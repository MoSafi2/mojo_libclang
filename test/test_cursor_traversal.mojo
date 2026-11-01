"""Cursor traversal grows with AST size without a fixed sibling limit."""
from clang.cindex import Cursor, CursorKind, Index, TranslationUnit
from clang.cursor import collect_children
from std.os import getenv
from std.testing import assert_equal, assert_raises, TestSuite


def _parse_fixture(filename: String) raises -> TranslationUnit:
    var index = Index.create()
    var tu = index.parse(getenv("LIBCLANG_TRAVERSAL_FIXTURES") + "/" + filename)
    assert_equal(Int(tu.num_diagnostics()), 0)
    return tu^


def _parse_children(count: Int) raises -> TranslationUnit:
    return _parse_fixture("children_" + String(count) + ".c")


def _assert_children(children: List[Cursor], count: Int) raises:
    assert_equal(len(children), count)
    for i in range(count):
        assert_equal(children[i].spelling(), "child_" + String(i))


def test_children_boundary_counts() raises:
    for count in [0, 4095, 4096, 4097, 10000]:
        var tu = _parse_children(count)
        var root = tu.cursor()
        var children = root.children()
        _assert_children(children, count)
        var collected = collect_children(root)
        _assert_children(collected, count)
        var seen = 0
        for child in root:
            assert_equal(child.spelling(), "child_" + String(seen))
            seen += 1
        assert_equal(seen, count)
        var preorder = root.walk_preorder()
        assert_equal(len(preorder), count + 1)
        assert_equal(preorder[0].kind(), CursorKind.TRANSLATION_UNIT)
        for i in range(count):
            assert_equal(preorder[i + 1].spelling(), "child_" + String(i))


def test_iteration_with_10000_children() raises:
    var tu = _parse_children(10000)
    var root = tu.cursor()
    var seen = 0
    for child in root:
        assert_equal(child.spelling(), "child_" + String(seen))
        seen += 1
    assert_equal(seen, 10000)


def test_nested_parent_with_5000_fields() raises:
    var tu = _parse_fixture("nested.c")
    var root = tu.cursor()
    var parents = root.children()
    assert_equal(len(parents), 1)
    var parent = parents[0].copy()
    var children = parent.children()
    _assert_children(children, 5000)
    var seen = 0
    for child in parent:
        assert_equal(child.spelling(), "child_" + String(seen))
        seen += 1
    assert_equal(seen, 5000)
    var preorder = root.walk_preorder()
    assert_equal(len(preorder), 5002)
    assert_equal(preorder[5001].spelling(), "child_4999")


def test_total_tree_exceeds_4096_nodes() raises:
    var tu = _parse_fixture("tree.c")
    var root = tu.cursor()
    var preorder = root.walk_preorder()
    assert_equal(len(preorder), 6041)
    for parent in range(40):
        var offset = 1 + parent * 151
        assert_equal(preorder[offset].spelling(), "Parent_" + String(parent))
        for child in range(150):
            assert_equal(
                preorder[offset + child + 1].spelling(),
                "child_" + String(child),
            )


def _children_from_local_tu() raises -> List[Cursor]:
    var tu = _parse_children(5000)
    var root = tu.cursor()
    return root.children()


def test_collected_children_keep_tu_alive() raises:
    var children = _children_from_local_tu()
    _assert_children(children, 5000)


def test_reparse_preserves_invalidation() raises:
    var tu = _parse_children(3)
    var root = tu.cursor()
    tu.reparse()
    with assert_raises():
        _ = root.children()
    var seen = 0
    for child in root:
        _ = child
        seen += 1
    assert_equal(seen, 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

"""Minimal cursor test to isolate memory corruption."""
from src.libclang import (
    Index,
    Cursor,
    CXCursor_TranslationUnit,
)
from std.testing import assert_equal, assert_true, TestSuite


comptime FIXTURE_PATH: String = "test/type_test_fixture.c"


def test_null_cursor() raises:
    var index = Index.create()
    var tu = index.parse(FIXTURE_PATH)
    var c = Cursor.null(tu._raw)
    assert_true(c.is_null(), "null cursor should report is_null")


def test_tu_cursor() raises:
    var index = Index.create()
    var tu = index.parse(FIXTURE_PATH)
    var c = tu.cursor()
    assert_equal(Int(c.kind()), Int(CXCursor_TranslationUnit))
    assert_true(not c.is_null())
    assert_true(c.is_definition())


def test_tu_spelling() raises:
    var index = Index.create()
    var tu = index.parse(FIXTURE_PATH)
    var c = tu.cursor()
    var s = c.spelling()
    assert_true(s.byte_length() > 0)


def test_children_count() raises:
    var index = Index.create()
    var tu = index.parse(FIXTURE_PATH)
    var c = tu.cursor()
    var children = c.get_children()
    assert_true(Int(children.__len__()) > 0)


def test_function_spelling_via_children() raises:
    var index = Index.create()
    var tu = index.parse(FIXTURE_PATH)
    var c = tu.cursor()
    var children = c.get_children()
    if Int(children.__len__()) > 0:
        var child = children[0].copy()
        var s = child.spelling()
        assert_true(s.byte_length() > 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

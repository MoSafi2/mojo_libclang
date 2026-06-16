"""Tests for the PrintingPolicy wrapper."""
from clang.cindex import (
    Index,
    TranslationUnit,
    Cursor,
    PrintingPolicy,
    PrintingPolicyProperty,
)
from clang._ffi import CXCursor, CXCursor_FunctionDecl
from std.memory import UnsafePointer
from std.testing import assert_true, TestSuite


comptime FIXTURE_PATH: String = "test/fixtures/type_test_fixture.c"


def _parse() raises -> TranslationUnit:
    var index = Index.create()
    return index.parse(FIXTURE_PATH)


def _find_function(mut tu: TranslationUnit, name: String) raises -> Cursor:
    var root = tu.cursor()
    var cursors = root.walk_preorder()
    for i in range(cursors.__len__()):
        var c = cursors[i].copy()
        if c.kind().as_c_uint() == CXCursor_FunctionDecl and c.spelling() == name:
            return c^
    raise Error("function not found: " + name)


def test_printing_policy_create() raises:
    var tu = _parse()
    var c = _find_function(tu, "add")
    var raw = c.raw_value()
    var ptr = UnsafePointer[CXCursor, MutAnyOrigin](to=raw)
    var policy = PrintingPolicy(
        rebind[UnsafePointer[CXCursor, MutExternalOrigin]](ptr),
    )
    _ = policy


def test_printing_policy_get_and_set_property() raises:
    var tu = _parse()
    var c = _find_function(tu, "add")
    var raw = c.raw_value()
    var ptr = UnsafePointer[CXCursor, MutAnyOrigin](to=raw)
    var policy = PrintingPolicy(
        rebind[UnsafePointer[CXCursor, MutExternalOrigin]](ptr),
    )
    var original = policy.get_property(PrintingPolicyProperty.SUPPRESS_SCOPE)
    policy.set_property(PrintingPolicyProperty.SUPPRESS_SCOPE, original + 1)
    var updated = policy.get_property(PrintingPolicyProperty.SUPPRESS_SCOPE)
    assert_true(
        updated == original + 1,
        "set_property should update the property value",
    )


def test_printing_policy_write_to() raises:
    var tu = _parse()
    var c = _find_function(tu, "add")
    var raw = c.raw_value()
    var ptr = UnsafePointer[CXCursor, MutAnyOrigin](to=raw)
    var policy = PrintingPolicy(
        rebind[UnsafePointer[CXCursor, MutExternalOrigin]](ptr),
    )
    var s = String(policy)
    assert_true(s.byte_length() > 0, "write_to should produce output")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

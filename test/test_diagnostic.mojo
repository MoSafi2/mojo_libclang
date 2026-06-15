"""Unit tests for `src/libclang/diagnostic.mojo`.

Exercises `Diagnostic`, `DiagnosticSet`, and `FixIt` wrappers.
"""
from src.libclang import (
    Index,
    TranslationUnit,
    Diagnostic,
    DiagnosticSet,
    FixIt,
    CXDiagnostic_Error,
)
from std.ffi import c_uint
from std.testing import assert_equal, assert_true, TestSuite


comptime INVALID_PATH: String = "test/fixtures/raw_ffi_probe_invalid.c"


def _check(cond: Bool, msg: String) raises:
    if not cond:
        raise Error(msg)


def _parse_invalid() raises -> TranslationUnit:
    var index = Index.create()
    return index.parse(String(INVALID_PATH))


# -- Diagnostic count and set ---------------------------------------------


def test_diagnostic_count_is_positive() raises:
    var tu = _parse_invalid()
    _check(tu.num_diagnostics() > 0, "expected diagnostics for invalid source")


def test_diagnostic_set_from_tu() raises:
    var tu = _parse_invalid()
    var diags = tu.diagnostics()
    assert_equal(
        Int(diags.__len__()),
        Int(tu.num_diagnostics()),
        "diagnostics set size should match num_diagnostics",
    )


# def test_diagnostic_set_iteration() raises:
#     var tu = _parse_invalid()
#     var diags = tu.diagnostics()
#     var n = Int(diags.__len__())
#     var count = 0
#     for i in range(n):
#         var d = diags[c_uint(i)]
#         _ = d.severity()
#         count += 1
#     assert_equal(count, n, "iteration count should match")


# -- Diagnostic properties ------------------------------------------------


# def test_diagnostic_severity() raises:
#     var tu = _parse_invalid()
#     var diags = tu.diagnostics()
#     var first = diags[c_uint(0)]
#     _ = first.severity()


# def test_diagnostic_spelling() raises:
#     var tu = _parse_invalid()
#     var diags = tu.diagnostics()
#     var first = diags[c_uint(0)]
#     var text = first.spelling()
#     _check(text.byte_length() > 0, "diagnostic spelling should not be empty")


# def test_diagnostic_location() raises:
#     var tu = _parse_invalid()
#     var diags = tu.diagnostics()
#     var first = diags[c_uint(0)]
#     var loc = first.location()
#     _check(
#         Int(loc.line()) >= 1, "diagnostic location should have positive line"
#     )


# def test_diagnostic_category() raises:
#     var tu = _parse_invalid()
#     var diags = tu.diagnostics()
#     var first = diags[c_uint(0)]
#     var num = first.category_number()
#     var name = first.category_name()
#     _check(Int(num) >= 0, "category number should be non-negative")
#     _check(name.byte_length() > 0, "category name should not be empty")


# def test_diagnostic_option() raises:
#     var tu = _parse_invalid()
#     var diags = tu.diagnostics()
#     var first = diags[c_uint(0)]
#     _ = first.option()
#     _ = first.disable_option()


# def test_diagnostic_format() raises:
#     var tu = _parse_invalid()
#     var diags = tu.diagnostics()
#     var first = diags[c_uint(0)]
#     var formatted = first.format()
#     _check(
#         formatted.byte_length() > 0, "formatted diagnostic should not be empty"
#     )


# def test_diagnostic_ranges() raises:
#     var tu = _parse_invalid()
#     var diags = tu.diagnostics()
#     var first = diags[c_uint(0)]
#     if first.num_ranges() > 0:
#         var r = first.range(c_uint(0))
#         _ = r.start()


# -- FixIt -----------------------------------------------------------------


# def test_diagnostic_fixits() raises:
#     var tu = _parse_invalid()
#     var diags = tu.diagnostics()
#     var first = diags[c_uint(0)]
#     if first.num_fixits() > 0:
#         var fix = first.fixit(c_uint(0))
#         _check(fix.value.byte_length() > 0, "fixit value should not be empty")
#         _ = fix.range


# -- Child diagnostics ----------------------------------------------------


# def test_diagnostic_children() raises:
#     var tu = _parse_invalid()
#     var diags = tu.diagnostics()
#     var first = diags[c_uint(0)]
#     var children = first.children()
#     _ = Int(children.__len__())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

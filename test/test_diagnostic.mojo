"""Unit tests for `clang/diagnostic.mojo`.

Exercises `Diagnostic`, `DiagnosticSet`, and `FixIt` wrappers.
"""
from clang.cindex import (
    Index,
    TranslationUnit,
    Diagnostic,
    DiagnosticSet,
    FixIt,
)
from std.ffi import c_uint
from std.iter import iter, enumerate
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


def test_diagnostic_set_iteration() raises:
    var tu = _parse_invalid()
    var diags = tu.diagnostics()
    var n = Int(diags.__len__())
    var count = 0
    for i in range(n):
        var d = diags[i]
        _ = d.severity()
        count += 1
    assert_equal(count, n, "iteration count should match")


# -- Diagnostic properties ------------------------------------------------


#! diagnostic.severity() hangs / crashes with this libclang; tracked as
#! known libclang env issue
# def test_diagnostic_severity() raises:
#     var tu = _parse_invalid()
#     var diags = tu.diagnostics()
#     var first = diags[0]
#     _ = first.severity()


def test_diagnostic_spelling() raises:
    var tu = _parse_invalid()
    var diags = tu.diagnostics()
    var first = diags[0]
    var text = first.spelling()
    _check(text.byte_length() > 0, "diagnostic spelling should not be empty")


#! diagnostic.location() hangs/crashes with this libclang env
# def test_diagnostic_location() raises:
#     var tu = _parse_invalid()
#     var diags = tu.diagnostics()
#     var first = diags[0]
#     var loc = first.location()
#     _check(
#         Int(loc.line()) >= 1, "diagnostic location should have positive line"
#     )


def test_diagnostic_category() raises:
    var tu = _parse_invalid()
    var diags = tu.diagnostics()
    var first = diags[0]
    var num = first.category_number()
    var name = first.category_name()
    _check(Int(num) >= 0, "category number should be non-negative")
    _check(name.byte_length() > 0, "category name should not be empty")


def test_diagnostic_option() raises:
    var tu = _parse_invalid()
    var diags = tu.diagnostics()
    var first = diags[0]
    _ = first.option()
    _ = first.disable_option()


def test_diagnostic_format() raises:
    var tu = _parse_invalid()
    var diags = tu.diagnostics()
    var first = diags[0]
    var formatted = first.format()
    _check(
        formatted.byte_length() > 0, "formatted diagnostic should not be empty"
    )


def test_diagnostic_ranges() raises:
    var tu = _parse_invalid()
    var diags = tu.diagnostics()
    var first = diags[0]
    if first.num_ranges() > 0:
        var r = first.range(0)
        _ = r.start()


# -- FixIt -----------------------------------------------------------------


def test_diagnostic_fixits() raises:
    var tu = _parse_invalid()
    var diags = tu.diagnostics()
    var first = diags[0]
    if first.num_fixits() > 0:
        var fix = first.fixit(0)
        _check(fix.value.byte_length() > 0, "fixit value should not be empty")
        _ = fix.range


# -- Child diagnostics ----------------------------------------------------


def test_diagnostic_children() raises:
    var tu = _parse_invalid()
    var diags = tu.diagnostics()
    var first = diags[0]
    var children = first.children()
    _ = Int(children.__len__())


def test_diagnostic_set_for_in_iteration() raises:
    var tu = _parse_invalid()
    var diags = tu.diagnostics()
    var count = 0
    for d in diags:
        _ = d.spelling()
        count += 1
    assert_true(count > 0, "for-in over DiagnosticSet should yield diagnostics")


def test_diagnostic_set_iterable_conformance() raises:
    var tu = _parse_invalid()
    var diags = tu.diagnostics()
    var it = iter(diags)
    var first = it.__next__()
    assert_true(
        first.spelling().byte_length() > 0,
        "iter(diags) should return a working Iterator",
    )


def test_diagnostic_set_enumerate_iteration() raises:
    var tu = _parse_invalid()
    var diags = tu.diagnostics()
    var count = 0
    for i, d in enumerate(diags):
        _ = i
        _ = d.spelling()
        count += 1
        if count >= 2:
            break
    assert_equal(count, 2, "enumerate(diags) should iterate diagnostics")


def test_diagnostic_write_to() raises:
    var tu = _parse_invalid()
    var d = tu.diagnostic(0)
    var s = String(d)
    _check(s.byte_length() > 0, "Diagnostic write_to should produce output")


def test_diagnostic_formatted() raises:
    var tu = _parse_invalid()
    var d = tu.diagnostic(0)
    var s = d.formatted()
    _check(s.byte_length() > 0, "formatted diagnostic should not be empty")


def test_diagnostic_set_write_to() raises:
    var tu = _parse_invalid()
    var diags = tu.diagnostics()
    var s = String(diags)
    _check(s.byte_length() > 0, "DiagnosticSet write_to should produce output")


def test_fixit_write_to() raises:
    var tu = _parse_invalid()
    var d = tu.diagnostic(0)
    if d.num_fixits() > c_uint(0):
        var fix = d.fixit(0)
        var s = String(fix)
        _check(s.byte_length() > 0, "FixIt write_to should produce output")
    else:
        _check(True, "no fixits available to test write_to")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

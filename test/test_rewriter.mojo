"""Tests for the Rewriter wrapper."""
from clang.cindex import Index, TranslationUnit, Rewriter, SourcePosition
from clang.source_range import SourceRange
from std.testing import assert_true, TestSuite


comptime FIXTURE_PATH: String = "test/fixtures/type_test_fixture.c"


def _parse() raises -> TranslationUnit:
    var index = Index.create()
    return index.parse(FIXTURE_PATH)


def test_rewriter_create() raises:
    var tu = _parse()
    var rewriter = Rewriter(tu)
    _ = rewriter


def test_rewriter_insert_text() raises:
    var tu = _parse()
    var rewriter = Rewriter(tu)
    var loc = tu.get_location(
        FIXTURE_PATH,
        SourcePosition.from_line_column(1, 1),
    )
    rewriter.insert_text_before(loc, "// inserted\n")


def test_rewriter_replace_text() raises:
    var tu = _parse()
    var rewriter = Rewriter(tu)
    var start = tu.get_location(
        FIXTURE_PATH,
        SourcePosition.from_line_column(1, 1),
    )
    var end = tu.get_location(
        FIXTURE_PATH,
        SourcePosition.from_line_column(1, 9),
    )
    var extent = SourceRange.from_locations(start, end)
    rewriter.replace_text(extent, "/* replaced */")


def test_rewriter_arc_pointer_constructor() raises:
    var tu = _parse()
    var rewriter = Rewriter(tu.state())
    _ = rewriter


def test_rewriter_remove_text() raises:
    var tu = _parse()
    var rewriter = Rewriter(tu)
    var start = tu.get_location(
        FIXTURE_PATH,
        SourcePosition.from_line_column(1, 1),
    )
    var end = tu.get_location(
        FIXTURE_PATH,
        SourcePosition.from_line_column(1, 9),
    )
    var extent = SourceRange.from_locations(start, end)
    rewriter.remove_text(extent)


def test_rewriter_overwrite_changed_files() raises:
    var tu = _parse()
    var rewriter = Rewriter(tu)
    var result = rewriter.overwrite_changed_files()
    assert_true(result >= 0, "overwrite_changed_files should return non-negative")


def test_rewriter_write_to() raises:
    var tu = _parse()
    var rewriter = Rewriter(tu)
    var s = String(rewriter)
    assert_true(s.byte_length() > 0, "write_to should produce output")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

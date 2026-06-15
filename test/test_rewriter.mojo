"""Tests for the Rewriter wrapper."""
from src.libclang import Index, TranslationUnit, Rewriter, SourcePosition
from src.libclang.source_range import SourceRange
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


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

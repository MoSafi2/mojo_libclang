"""Tests for typed error helpers."""
from src.libclang import (
    Index,
    TranslationUnit,
    TranslationUnitLoadError,
    TranslationUnitSaveError,
    CompilationDatabaseError,
    SaveError,
)
from std.ffi import c_uint
from std.testing import assert_raises, TestSuite


def test_translation_unit_load_error_message() raises:
    var index = Index.create()
    with assert_raises():
        _ = index.parse("test/fixtures/__nonexistent__._")


def test_translation_unit_save_error_code() raises:
    var err = SaveError.INVALID_TU
    var msg = "test"
    with assert_raises():
        raise TranslationUnitSaveError(err, msg)


def test_compilation_database_error() raises:
    with assert_raises():
        raise CompilationDatabaseError(c_uint(1), "cannot load")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

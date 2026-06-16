"""Tests for compilation database wrappers."""
from clang.cindex import CompilationDatabase, CompileCommands, CompileCommand
from std.testing import assert_equal, assert_true, TestSuite


comptime DB_PATH: String = "test/fixtures/build"


def test_from_directory() raises:
    var db = CompilationDatabase.from_directory(DB_PATH)
    _ = db


def test_get_compile_commands() raises:
    var db = CompilationDatabase.from_directory(DB_PATH)
    var cmds = db.get_compile_commands("test/fixtures/type_test_fixture.c")
    assert_true(len(cmds) > 0, "should have at least one command")

    var cmd = cmds[0]
    assert_true(cmd.directory().byte_length() > 0, "directory should be non-empty")
    assert_true(cmd.filename().byte_length() > 0, "filename should be non-empty")
    assert_true(cmd.num_args() > 0, "should have args")


def test_get_all_compile_commands() raises:
    var db = CompilationDatabase.from_directory(DB_PATH)
    var cmds = db.get_all_compile_commands()
    assert_true(len(cmds) > 0, "should have all commands")


def test_compile_commands_iteration() raises:
    var db = CompilationDatabase.from_directory(DB_PATH)
    var cmds = db.get_all_compile_commands()
    var count = 0
    for cmd in cmds:
        count += 1
        _ = cmd.directory()
    assert_equal(count, len(cmds), "iteration should visit all commands")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

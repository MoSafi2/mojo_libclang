"""Unsaved buffers retain their owner through parse and reparse calls."""
from clang.cindex import Index, TranslationUnit, UnsavedFile
from std.testing import assert_equal, assert_raises, TestSuite

comptime FIXTURE = "test/fixtures/raw_ffi_probe_fixture.c"


def _files(filename: String, var contents: String) -> List[UnsavedFile]:
    var files = List[UnsavedFile]()
    files.append(UnsavedFile(filename=filename, contents=contents^))
    return files^


def _parse(
    var filename: String, var contents: String
) raises -> TranslationUnit:
    var index = Index.create()
    var files = _files(filename, contents^)
    return index.parse(filename, unsaved_files=files)


def test_parse_empty_unsaved_buffer() raises:
    var tu = _parse(FIXTURE, "")
    assert_equal(Int(tu.num_diagnostics()), 0)
    var root = tu.cursor()
    var children = root.children()
    assert_equal(len(children), 0)
    assert_equal(tu.file_contents(FIXTURE), "")


def test_parse_unsaved_replaces_disk_contents() raises:
    var tu = _parse(FIXTURE, "int from_unsaved = 42;\n")
    assert_equal(Int(tu.num_diagnostics()), 0)
    var root = tu.cursor()
    var children = root.children()
    assert_equal(len(children), 1)
    assert_equal(children[0].spelling(), "from_unsaved")
    assert_equal(tu.file_contents(FIXTURE), "int from_unsaved = 42;\n")


def test_parse_large_unsaved_buffer() raises:
    var source = String()
    for i in range(5000):
        source += "int child_" + String(i) + ";\n"
    var tu = _parse(FIXTURE, source)
    assert_equal(Int(tu.num_diagnostics()), 0)
    var root = tu.cursor()
    var children = root.children()
    assert_equal(len(children), 5000)
    assert_equal(children[4999].spelling(), "child_4999")
    assert_equal(tu.file_contents(FIXTURE), source)


def test_virtual_unicode_unsaved_file() raises:
    var path = String("virtual_é.c")
    var source = String("int café = 7;\n")
    var tu = _parse(path, source)
    assert_equal(Int(tu.num_diagnostics()), 0)
    var root = tu.cursor()
    var children = root.children()
    assert_equal(len(children), 1)
    assert_equal(children[0].spelling(), "café")
    assert_equal(tu.file_contents(path), source)


def test_multiple_unsaved_files() raises:
    var main_path = String("test/fixtures/include_test.c")
    var main_source = String(
        '#include "included_header.h"\nint use(void) { return'
        " from_unsaved_header(); }\n"
    )
    var files = _files(main_path, main_source)
    files.append(
        UnsavedFile(
            filename="test/fixtures/included_header.h",
            contents="int from_unsaved_header(void);\n",
        )
    )
    var index = Index.create()
    var tu = index.parse(main_path, unsaved_files=files)
    assert_equal(Int(tu.num_diagnostics()), 0)
    assert_equal(tu.file_contents(main_path), main_source)
    assert_equal(
        tu.file_contents("test/fixtures/included_header.h"),
        "int from_unsaved_header(void);\n",
    )
    var root = tu.cursor()
    var children = root.children()
    assert_equal(len(children), 2)
    assert_equal(children[0].spelling(), "from_unsaved_header")
    assert_equal(children[1].spelling(), "use")


def test_reparse_unsaved_changes_and_clear() raises:
    var tu = _parse(FIXTURE, "int before;")
    var stale = tu.cursor()
    var files = _files(FIXTURE, "int after;")
    tu.reparse(unsaved_files=files)
    assert_equal(Int(tu.num_diagnostics()), 0)
    var root = tu.cursor()
    var children = root.children()
    assert_equal(len(children), 1)
    assert_equal(children[0].spelling(), "after")
    assert_equal(tu.file_contents(FIXTURE), "int after;")
    with assert_raises():
        _ = stale.children()
    var empty_files = _files(FIXTURE, "")
    tu.reparse(unsaved_files=empty_files)
    var empty_root = tu.cursor()
    var empty_children = empty_root.children()
    assert_equal(len(empty_children), 0)
    assert_equal(tu.file_contents(FIXTURE), "")


def test_unsaved_parse_failure_then_success() raises:
    var index = Index.create()
    var files = _files(FIXTURE, "int recovery;")
    for _ in range(3):
        with assert_raises():
            _ = index.parse("missing_unsaved_main.c", unsaved_files=files)
    var tu = index.parse(FIXTURE, unsaved_files=files)
    var root = tu.cursor()
    var children = root.children()
    assert_equal(len(children), 1)
    assert_equal(children[0].spelling(), "recovery")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

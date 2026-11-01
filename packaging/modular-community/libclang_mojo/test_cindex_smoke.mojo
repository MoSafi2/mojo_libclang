from clang.cindex import CursorKind, Index, UnsavedFile, version_info
from std.testing import assert_equal, assert_true


def main() raises:
    var index = Index.create()
    for filename in ["api.c", "api.cpp"]:
        var tu = index.parse(String(filename))
        assert_equal(Int(tu.num_diagnostics()), 0)
        var root = tu.cursor()
        var found = False
        for cursor in root:
            if cursor.kind() == CursorKind.FUNCTION_DECL:
                assert_equal(cursor.spelling(), "add")
                assert_equal(cursor.location().line(), 2)
                var function_type = cursor.type()
                assert_equal(function_type.spelling(), "int (int, int)")
                var tokens = cursor.tokens()
                assert_true(len(tokens) > 0)
                found = True
            elif cursor.kind() == CursorKind.STRUCT_DECL:
                var record_type = cursor.type()
                var fields = record_type.fields()
                assert_equal(len(fields), 2)
                assert_equal(fields[0].spelling(), "x")
                assert_equal(fields[1].spelling(), "y")
        assert_true(found)
    var invalid = index.parse("invalid.c")
    assert_true(Int(invalid.num_diagnostics()) > 0)
    for diagnostic in invalid.diagnostics():
        assert_true(diagnostic.format().byte_length() > 0)
    for filename in ["api.c", "api.cpp"]:
        var files = List[UnsavedFile]()
        files.append(
            UnsavedFile(filename=String(filename), contents="int from_buffer;")
        )
        var memory_tu = index.parse(String(filename), unsaved_files=files)
        assert_equal(Int(memory_tu.num_diagnostics()), 0)
        var memory_root = memory_tu.cursor()
        var memory_children = memory_root.children()
        assert_equal(len(memory_children), 1)
        assert_equal(memory_children[0].spelling(), "from_buffer")
        var updated = List[UnsavedFile]()
        updated.append(
            UnsavedFile(
                filename=String(filename), contents="int after_reparse;"
            )
        )
        memory_tu.reparse(unsaved_files=updated)
        var updated_root = memory_tu.cursor()
        var updated_children = updated_root.children()
        assert_equal(len(updated_children), 1)
        assert_equal(updated_children[0].spelling(), "after_reparse")
        var empty = List[UnsavedFile]()
        empty.append(UnsavedFile(filename=String(filename), contents=""))
        memory_tu.reparse(unsaved_files=empty)
        var empty_root = memory_tu.cursor()
        var empty_children = empty_root.children()
        assert_equal(len(empty_children), 0)
    var wide_tu = index.parse("many_children.c")
    assert_equal(Int(wide_tu.num_diagnostics()), 0)
    var wide_root = wide_tu.cursor()
    var wide_children = wide_root.children()
    assert_equal(len(wide_children), 5000)
    assert_equal(wide_children[4999].spelling(), "child_4999")
    var seen = 0
    for child in wide_root:
        assert_equal(child.spelling(), "child_" + String(seen))
        seen += 1
    assert_equal(seen, 5000)
    var preorder = wide_root.walk_preorder()
    assert_equal(len(preorder), 5001)
    assert_equal(preorder[5000].spelling(), "child_4999")
    var info = version_info()
    assert_true(info.runtime_clang_version.byte_length() > 0)
    assert_equal(info.libclang_mojo_version, "0.2.0")
    assert_equal(info.mojo_compiler_constraint, "=1.2.0")
    print("Shimless package consumer passed:", info.libclang_mojo_version)

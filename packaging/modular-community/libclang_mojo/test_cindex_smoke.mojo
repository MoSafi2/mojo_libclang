from clang.cindex import CursorKind, Index, version_info
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
    var info = version_info()
    assert_true(info.runtime_clang_version.byte_length() > 0)
    assert_equal(info.libclang_mojo_version, "0.3.0.dev20261031")
    assert_equal(info.mojo_compiler_constraint, "=1.3.0.dev2026103105")
    print("Shimless package consumer passed:", info.libclang_mojo_version)

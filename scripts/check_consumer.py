#!/usr/bin/env python3
"""Exercise the compiled package from outside the repository."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile


SOURCE = '''from clang.cindex import CursorKind, Index, version_info
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
    print("External consumer passed:", info.libclang_mojo_version)
'''


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    prefix = root / "dist" / "libclang_mojo-prefix"
    env = os.environ.copy()
    for name in ("MOJO_BINDGEN_LIBRARY_PATH", "MOJO_BINDGEN_CLANG_LIBRARY_PATH"):
        env.pop(name, None)
    if len(sys.argv) > 1:
        source = Path(sys.argv[1]).resolve(strict=True)
        subprocess.run(
            ["mojo", "run", "-I", str(prefix / "lib" / "mojo"), str(source), *sys.argv[2:]],
            cwd=source.parent, env=env, check=True,
        )
        return
    with tempfile.TemporaryDirectory(prefix="libclang-mojo-consumer-") as directory:
        work = Path(directory)
        (work / "main.mojo").write_text(SOURCE)
        for name in ("api.c", "api.cpp"):
            (work / name).write_text("struct Point { int x; int y; };\nint add(int a, int b) { return a + b; }\n")
        (work / "invalid.c").write_text("int broken = ;\n")
        subprocess.run(
            ["mojo", "build", "-I", str(prefix / "lib" / "mojo"), str(work / "main.mojo"), "-o", str(work / "consumer")],
            cwd=work, env=env, check=True,
        )
        subprocess.run([str(work / "consumer")], cwd=work, env=env, check=True)


if __name__ == "__main__":
    main()

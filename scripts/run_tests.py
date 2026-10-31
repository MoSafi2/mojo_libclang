#!/usr/bin/env python3
"""Run all Mojo tests at the compiler's normal optimization level."""

import os
from pathlib import Path
import subprocess
import sys


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    env = os.environ.copy()
    paths = [str(root / "shim"), str(Path(env["CONDA_PREFIX"]) / "lib")]
    for variable in ("LD_LIBRARY_PATH", "DYLD_LIBRARY_PATH"):
        env[variable] = os.pathsep.join(paths + [env.get(variable, "")])
    files = [root / "test" / "_ffi_layout_tests.mojo"]
    files.extend(sorted((root / "test").glob("test_*.mojo")))
    failed = []
    for path in files:
        print(f"\n== {path.relative_to(root)} ==", flush=True)
        result = subprocess.run(
            ["mojo", "run", "-I", str(root), str(path)], cwd=root, env=env
        )
        if result.returncode:
            failed.append(str(path.relative_to(root)))
    print(f"\n{len(files) - len(failed)}/{len(files)} test files passed", flush=True)
    if failed:
        print("Failed: " + ", ".join(failed), file=sys.stderr)
    return bool(failed)


if __name__ == "__main__":
    raise SystemExit(main())

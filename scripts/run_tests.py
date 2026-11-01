#!/usr/bin/env python3
"""Run the complete suite as JIT programs and compiled executables."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import argparse


def prepare_traversal_fixtures(directory: Path) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    for count in (0, 3, 4095, 4096, 4097, 5000, 10000):
        (directory / f"children_{count}.c").write_text(
            "".join(f"int child_{i};\n" for i in range(count)))
    (directory / "nested.c").write_text(
        "struct Parent {\n" + "".join(f"int child_{i};\n" for i in range(5000)) + "};\n")
    (directory / "tree.c").write_text("".join(
        f"struct Parent_{parent} {{\n" + "".join(f"int child_{child};\n" for child in range(150)) + "};\n"
        for parent in range(40)))


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    env = os.environ.copy()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("run", "build", "both"), default="both")
    options = parser.parse_args()
    subprocess.run([sys.executable, "-m", "unittest", "discover", "-s", "test", "-p", "test_direct_abi.py"], cwd=root, env=env, check=True)
    files = [root / "test" / "_ffi_layout_tests.mojo"]
    files.extend(sorted((root / "test").glob("test_*.mojo")))
    failed = []
    with tempfile.TemporaryDirectory(prefix="libclang-tests-") as directory:
        work = Path(directory)
        fixtures = work / "traversal-fixtures"
        prepare_traversal_fixtures(fixtures)
        env["LIBCLANG_TRAVERSAL_FIXTURES"] = str(fixtures)
        oracle = work / ("oracle.dylib" if sys.platform == "darwin" else "oracle.so")
        subprocess.run([os.environ.get("CC", "cc"),
                        "-dynamiclib" if sys.platform == "darwin" else "-shared", "-fPIC",
                        "-I" + str(Path(env["CONDA_PREFIX"]) / "include"),
                        str(root / "test/fixtures/abi_oracle.c"), "-o", str(oracle)], check=True)
        env["LIBCLANG_ABI_ORACLE"] = str(oracle)
        modes = ("run", "build") if options.mode == "both" else (options.mode,)
        cases = [(path, mode, []) for mode in modes for path in files]
        cases.extend((root / "test" / filename, "build", ["-O0"])
                     for filename in ("test_ffi.mojo", "test_abi.mojo", "test_cursor_traversal.mojo", "test_unsaved_files.mojo"))
        for path, mode, flags in cases:
            label = f"{path.relative_to(root)} [{mode} {' '.join(flags)}]"
            print(f"\n== {label} ==", flush=True)
            binary = work / path.stem
            cmd = ["mojo", mode, "-I", str(root), *flags, str(path)]
            if mode == "build":
                cmd.extend(["-o", str(binary)])
            result = subprocess.run(cmd, cwd=root, env=env)
            if not result.returncode and mode == "build":
                result = subprocess.run([str(binary)], cwd=root, env=env)
            if result.returncode:
                failed.append(label)
    print(f"\n{len(cases) - len(failed)}/{len(cases)} test invocations passed", flush=True)
    if failed:
        print("Failed: " + ", ".join(failed), file=sys.stderr)
    return bool(failed)


if __name__ == "__main__":
    raise SystemExit(main())

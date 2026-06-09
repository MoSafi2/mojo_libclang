#!/usr/bin/env python3
"""Generate raw Mojo FFI bindings for libclang with mojo-bindgen.

Environment overrides:
  LIBCLANG_HEADERS_DIR  Directory containing clang-c/*.h or the clang-c dir itself.
  LIBCLANG_LIBRARY      Path to libclang.so/dylib/dll for owned_dl_handle output.
  LIBCLANG_RAW_OUT      Output Mojo file. Defaults to src/libclang_raw.mojo.
  LIBCLANG_RAW_IR_OUT   Output JSON IR file. Defaults to build/libclang_raw.ir.json.
  LIBCLANG_APPLY_PATCHES Set to 0 to emit pristine mojo-bindgen output.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MOJO_OUT = REPO_ROOT / "src" / "libclang_raw.mojo"
DEFAULT_IR_OUT = REPO_ROOT / "build" / "libclang_raw.ir.json"
DEFAULT_LAYOUT_OUT = DEFAULT_MOJO_OUT.with_name(f"{DEFAULT_MOJO_OUT.stem}_layout_tests.mojo")
PATCH_FILES = (
    REPO_ROOT / "patches" / "0001-libclang-raw-manual-abi.patch",
)

HEADER_NAMES = (
    "Index.h",
    "CXString.h",
    "BuildSystem.h",
    "Documentation.h",
    "CXCompilationDatabase.h",
    "CXDiagnostic.h",
    "CXFile.h",
    "CXSourceLocation.h",
    "Rewrite.h",
    "FatalErrorHandler.h",
)


def main() -> int:
    mojo_bindgen = shutil.which("mojo-bindgen")
    if mojo_bindgen is None:
        print("error: mojo-bindgen not found; run through `pixi run generate`", file=sys.stderr)
        return 1

    clang_c_dir = discover_clang_c_dir()
    include_root = clang_c_dir.parent
    headers = [clang_c_dir / name for name in HEADER_NAMES if (clang_c_dir / name).is_file()]
    missing = [name for name in HEADER_NAMES if not (clang_c_dir / name).is_file()]
    if missing:
        print(
            "warning: missing optional clang-c headers: " + ", ".join(missing),
            file=sys.stderr,
        )

    primary = clang_c_dir / "Index.h"
    if primary not in headers:
        print(f"error: required header not found: {primary}", file=sys.stderr)
        return 1

    mojo_out = Path(os.environ.get("LIBCLANG_RAW_OUT", DEFAULT_MOJO_OUT)).resolve()
    ir_out = Path(os.environ.get("LIBCLANG_RAW_IR_OUT", DEFAULT_IR_OUT)).resolve()
    layout_out = mojo_out.with_name(f"{mojo_out.stem}_layout_tests.mojo")
    for path in (mojo_out, ir_out, layout_out):
        path.parent.mkdir(parents=True, exist_ok=True)

    compile_args = build_compile_args(include_root)
    library_path = discover_libclang_library()

    common = [
        mojo_bindgen,
        str(primary),
        "--library",
        "libclang",
        "--link-name",
        "clang",
        "--no-doc-comments",
        "--clang-macro-fallback",
    ]
    for header in headers:
        if header != primary:
            common.extend(["--include-header", str(header)])
    for arg in compile_args:
        common.append(f"--compile-arg={arg}")

    ir_cmd = [*common, "--json", "-o", str(ir_out)]
    run(ir_cmd)

    mojo_cmd = [
        *common,
        "--linking",
        "owned_dl_handle",
        "--layout-tests",
        "-o",
        str(mojo_out),
        "--layout-test-output",
        str(layout_out),
    ]
    if library_path is not None:
        mojo_cmd.extend(["--library-path-hint", str(library_path)])
    run(mojo_cmd)

    if should_apply_patches():
        apply_post_generation_patches(mojo_out, layout_out)
    else:
        print("patches:   skipped by LIBCLANG_APPLY_PATCHES=0")

    print(f"generated: {display_path(mojo_out)}")
    print(f"generated: {display_path(layout_out)}")
    print(f"generated: {display_path(ir_out)}")
    if library_path is not None:
        print(f"libclang:  {library_path}")
    else:
        print("libclang:  no explicit library path found; generated bindings use link name")
    return 0


def discover_clang_c_dir() -> Path:
    override = os.environ.get("LIBCLANG_HEADERS_DIR")
    if override:
        return normalize_clang_c_dir(Path(override))

    llvm_config = shutil.which("llvm-config")
    if llvm_config is not None:
        try:
            include_dir = subprocess.check_output(
                [llvm_config, "--includedir"],
                text=True,
                stderr=subprocess.DEVNULL,
            ).strip()
        except (OSError, subprocess.CalledProcessError):
            include_dir = ""
        if include_dir:
            candidate = normalize_clang_c_dir(Path(include_dir))
            if (candidate / "Index.h").is_file():
                return candidate

    candidates: list[Path] = []
    for version in range(30, 10, -1):
        candidates.append(Path(f"/usr/lib/llvm-{version}/include/clang-c"))
    candidates.extend(
        [
            Path("/usr/local/include/clang-c"),
            Path("/usr/include/clang-c"),
            Path("/opt/homebrew/opt/llvm/include/clang-c"),
            Path("/opt/homebrew/include/clang-c"),
        ]
    )
    for candidate in candidates:
        if (candidate / "Index.h").is_file():
            return candidate

    raise SystemExit(
        "error: could not find clang-c/Index.h; set LIBCLANG_HEADERS_DIR to LLVM's include directory"
    )


def normalize_clang_c_dir(path: Path) -> Path:
    path = path.expanduser().resolve()
    if path.name == "clang-c":
        return path
    return path / "clang-c"


def discover_libclang_library() -> Path | None:
    override = os.environ.get("LIBCLANG_LIBRARY")
    if override:
        path = Path(override).expanduser().resolve()
        if not path.is_file():
            raise SystemExit(f"error: LIBCLANG_LIBRARY does not exist: {path}")
        return path

    try:
        import clang.cindex as cindex

        filename = cindex.conf.get_filename()
        if filename:
            path = Path(filename).expanduser().resolve()
            if path.is_file():
                return path
    except Exception:
        pass

    candidates = (
        "libclang.so",
        "libclang.dylib",
        "libclang.dll",
    )
    for name in candidates:
        found = shutil.which(name)
        if found:
            return Path(found).resolve()
    return None


def build_compile_args(include_root: Path) -> list[str]:
    args = [f"-I{include_root}"]
    seen = set(args)

    try:
        from mojo_bindgen.parsing.parser import _default_system_compile_args

        defaults = _default_system_compile_args()
    except Exception:
        defaults = ["-I/usr/include"]

    for arg in defaults:
        normalized = arg
        if arg.startswith("-I"):
            normalized = "-isystem" + arg[2:]
        if normalized not in seen:
            args.append(normalized)
            seen.add(normalized)
    return args


def run(cmd: list[str]) -> None:
    print("+ " + shell_join(cmd))
    subprocess.run(cmd, cwd=REPO_ROOT, check=True)


def should_apply_patches() -> bool:
    return os.environ.get("LIBCLANG_APPLY_PATCHES", "1") not in {"0", "false", "False", "no"}


def apply_post_generation_patches(mojo_out: Path, layout_out: Path) -> None:
    """Apply deterministic manual patches on top of mojo-bindgen output."""
    if mojo_out != DEFAULT_MOJO_OUT or layout_out != DEFAULT_LAYOUT_OUT:
        raise SystemExit(
            "error: manual patches target the default src/libclang_raw*.mojo outputs; "
            "unset LIBCLANG_RAW_OUT or set LIBCLANG_APPLY_PATCHES=0 for pristine output"
        )

    for patch_file in PATCH_FILES:
        if not patch_file.is_file():
            raise SystemExit(f"error: missing post-generation patch: {display_path(patch_file)}")
        print(f"patch:     {display_path(patch_file)}")
        run(["git", "apply", "--check", "--whitespace=nowarn", str(patch_file)])
        run(["git", "apply", "--whitespace=nowarn", str(patch_file)])


def display_path(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def shell_join(args: list[str]) -> str:
    return " ".join(quote(arg) for arg in args)


def quote(arg: str) -> str:
    if not arg or any(ch.isspace() or ch in "\"'$`\\" for ch in arg):
        return "'" + arg.replace("'", "'\"'\"'") + "'"
    return arg


if __name__ == "__main__":
    raise SystemExit(main())

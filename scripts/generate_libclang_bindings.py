#!/usr/bin/env python3
"""Generate ABI-normalized Mojo FFI bindings for LLVM libclang.

The generator uses ``mojo-bindgen`` as a library:

1. Parse libclang's public ``clang-c`` headers to CIR.
2. Run mojo-bindgen's normal CIR validation/canonicalization passes.
3. Normalize by-value record layouts without changing C signatures.
4. Emit direct libclang bindings and layout tests.

Environment overrides:
  LIBCLANG_HEADERS_DIR     Directory containing clang-c/*.h or the clang-c dir.
  LIBCLANG_LIBRARY         Path to libclang used for generation metadata reporting.
  LIBCLANG_FFI_OUT         Output Mojo file. Defaults to clang/_ffi.mojo.
  LIBCLANG_FFI_IR_OUT      Optional layout-normalized CIR JSON output path.
  LIBCLANG_ORIGINAL_IR_OUT Optional pre-layout normalized CIR JSON output path.
"""

from __future__ import annotations

import os
import ctypes
import re
import shutil
import subprocess
import sys
import tempfile
import tomllib
from pathlib import Path
from dataclasses import replace

try:
    from scripts.direct_abi import normalize_direct_abi
except ModuleNotFoundError:
    from direct_abi import normalize_direct_abi

from mojo_bindgen.analysis.pipeline import AnalysisOrchestrator
from mojo_bindgen.codegen.mojo_ir_printer import MojoIRPrintOptions, render_mojo_module
from mojo_bindgen.ir import (
    Const,
    Decl,
    Enum,
    Function,
    FunctionDecl,
    FunctionKind,
    GlobalVar,
    MacroDecl,
    Struct,
    Typedef,
    Unit,
)
from mojo_bindgen.layout_tests import render_layout_test_module
from mojo_bindgen.orchestrator import BindgenOptions, BindgenOrchestrator
from mojo_bindgen.parsing.frontend import ClangOptions
from mojo_bindgen.parsing.parser import _default_system_compile_args


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_FFI_MOJO_OUT = REPO_ROOT / "clang" / "_ffi.mojo"
DEFAULT_LAYOUT_TEST_OUT = REPO_ROOT / "test" / "_ffi_layout_tests.mojo"
DEFAULT_METADATA_OUT = REPO_ROOT / "clang" / "_metadata.mojo"

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
    clang_c_dir = discover_clang_c_dir()
    include_root = clang_c_dir.parent
    primary = clang_c_dir / "Index.h"
    if not primary.is_file():
        print(f"error: required header not found: {primary}", file=sys.stderr)
        return 1

    headers = [clang_c_dir / name for name in HEADER_NAMES if (clang_c_dir / name).is_file()]
    missing = [name for name in HEADER_NAMES if not (clang_c_dir / name).is_file()]
    if missing:
        print(
            "warning: missing optional clang-c headers: " + ", ".join(missing),
            file=sys.stderr,
        )

    mojo_out = Path(os.environ.get("LIBCLANG_FFI_OUT", DEFAULT_FFI_MOJO_OUT)).resolve()
    ir_out = optional_output_path("LIBCLANG_FFI_IR_OUT")
    original_ir_out = optional_output_path("LIBCLANG_ORIGINAL_IR_OUT")
    layout_out = Path(os.environ.get("LIBCLANG_LAYOUT_TEST_OUT", DEFAULT_LAYOUT_TEST_OUT)).resolve()

    output_paths = [mojo_out, layout_out]
    if ir_out is not None:
        output_paths.append(ir_out)
    if original_ir_out is not None:
        output_paths.append(original_ir_out)

    for path in output_paths:
        path.parent.mkdir(parents=True, exist_ok=True)

    raw_unit = parse_unit(primary, headers, include_root)
    orchestrator = AnalysisOrchestrator(
        BindgenOrchestrator(
            BindgenOptions(
                header=primary,
                library="libclang",
                link_name="clang",
                linking="owned_dl_handle",
                module_comment=True,
                emit_doc_comments=True,
            )
        ).emit_options
    )
    normalized_unit = orchestrator.normalize_cir(raw_unit)
    if original_ir_out is not None:
        original_ir_out.write_text(normalized_unit.to_json(), encoding="utf-8")

    direct_unit = normalize_direct_abi(replace(normalized_unit, decls=[
        decl for decl in normalized_unit.decls if keep_libclang_decl(decl)
    ]))
    if ir_out is not None:
        ir_out.write_text(direct_unit.to_json(), encoding="utf-8")

    header_version = read_cindex_version(primary)
    library_path = discover_libclang_library()
    runtime_version = query_libclang_version(library_path)

    analysis = orchestrator.analyze_with_artifacts(direct_unit)
    expected = {decl.link_name for decl in direct_unit.decls if isinstance(decl, Function)}
    emitted = {decl.link_name for decl in analysis.mojo_module.decls if isinstance(decl, FunctionDecl)}
    if expected != emitted:
        raise SystemExit(f"Function inventory mismatch: {expected ^ emitted}")
    stubs = [decl.link_name for decl in analysis.mojo_module.decls
             if isinstance(decl, FunctionDecl) and decl.kind != FunctionKind.WRAPPER]
    if stubs:
        raise SystemExit(f"Unsupported direct FFI functions: {stubs}")
    mojo_source = render_mojo_module(
        analysis.mojo_module,
        MojoIRPrintOptions(module_comment=True, emit_doc_comments=False),
    )
    mojo_source = preserve_argument_origins(mojo_source)
    mojo_source = mojo_source.replace(str(primary), "clang-c/Index.h")
    layout_source = render_layout_test_module(
        normalized_unit=analysis.normalized_unit,
        mojo_module=analysis.mojo_module,
        main_module_name=layout_import_module(mojo_out),
    )
    metadata_source = render_metadata_module()
    mojo_out.write_text(mojo_source, encoding="utf-8")
    layout_out.write_text(layout_source, encoding="utf-8")
    DEFAULT_METADATA_OUT.write_text(metadata_source, encoding="utf-8")
    build_layout_tests(layout_out)

    print(f"generated: {display_path(mojo_out)}")
    print(f"generated: {display_path(layout_out)}")
    print(f"generated: {display_path(DEFAULT_METADATA_OUT)}")
    print(f"direct C functions: {len(emitted)}")
    if ir_out is not None:
        print(f"generated: {display_path(ir_out)}")
    if original_ir_out is not None:
        print(f"generated: {display_path(original_ir_out)}")
    if header_version is not None:
        print(f"headers:   CINDEX {header_version[0]}.{header_version[1]}")
    if library_path is not None:
        print(f"libclang:  {library_path}")
    else:
        print("libclang:  linked by name")
    if runtime_version is not None:
        print(f"runtime:   {runtime_version}")
    return 0


def parse_unit(primary: Path, headers: list[Path], include_root: Path) -> Unit:
    compile_args = build_compile_args(include_root)
    include_headers = [header for header in headers if header != primary]
    options = BindgenOptions(
        header=primary,
        include_headers=include_headers,
        library="libclang",
        link_name="clang",
        clang_options=ClangOptions(raw_args=tuple(compile_args)),
        linking="owned_dl_handle",
        module_comment=True,
        emit_doc_comments=False,
        clang_macro_fallback=True,
    )
    return BindgenOrchestrator(options).parse()


def preserve_argument_origins(source: str) -> str:
    """Infer origins of argument pointers, preserving caller storage lifetimes.

    C-owned return values, pointees of pointer-to-pointer outputs, and struct
    fields retain untracked origins. Each outer argument gets its own origin.
    """
    lines = []
    for line in source.splitlines(keepends=True):
        if line.startswith("def clang_"):
            signature, separator, result = line.partition(") ->")
            name, arguments = signature.split("(", 1)
            parts = []
            begin = depth = 0
            for index, char in enumerate(arguments):
                if char == "[":
                    depth += 1
                elif char == "]":
                    depth -= 1
                elif char == "," and depth == 0:
                    parts.append(arguments[begin:index].strip())
                    begin = index + 1
            parts.append(arguments[begin:].strip())
            parameters = []
            for index, part in enumerate(parts):
                arg_name, colon, typ = part.partition(": ")
                if not typ.startswith(("Pointer[", "Optional[Pointer[", "OpaquePointer[", "Optional[OpaquePointer[")):
                    continue
                match = re.search(r"(MutUntrackedOrigin|ImmUntrackedOrigin)(\]+)$", typ)
                if match is None:
                    continue
                original = match.group(1)
                origin = f"_origin{len(parameters)}"
                bound = "MutOrigin" if original.startswith("Mut") else "ImmOrigin"
                parameters.append(f"{origin}: {bound} = {original}")
                typ = typ[:match.start(1)] + origin + typ[match.end(1):]
                parts[index] = arg_name + colon + typ
            if parameters:
                name += "[" + ", ".join(parameters) + ", //]"
            line = name + "(" + ", ".join(parts) + separator + result
        lines.append(line)
    return "".join(lines)


def layout_import_module(mojo_out: Path) -> str:
    stem = mojo_out.stem
    if stem.startswith("_") and mojo_out.parent == (REPO_ROOT / "clang").resolve():
        return f"clang.{stem}"
    return stem




def keep_libclang_decl(decl: Decl) -> bool:
    if isinstance(decl, Function):
        return decl.link_name.startswith("clang_")
    if isinstance(decl, Struct):
        return decl.name.startswith("CX") or decl.name == "IndexerCallbacks"
    if isinstance(decl, Enum):
        return decl.name.startswith("CX")
    if isinstance(decl, Typedef):
        return (
            decl.name.startswith("CX")
            or decl.name == "IndexerCallbacks"
            or decl.name == "time_t"
        )
    if isinstance(decl, (Const, MacroDecl)):
        return decl.name.startswith(("CX", "CINDEX"))
    if isinstance(decl, GlobalVar):
        return decl.name.startswith("clang_")
    return True


def discover_clang_c_dir() -> Path:
    override = os.environ.get("LIBCLANG_HEADERS_DIR")
    if override:
        return normalize_clang_c_dir(Path(override))

    conda_prefix = os.environ.get("CONDA_PREFIX")
    candidates: list[Path] = []
    if conda_prefix:
        prefix = Path(conda_prefix).expanduser().resolve()
        candidates.extend([prefix / "include" / "clang-c", prefix / "include"])

    for prefix in active_environment_prefixes():
        candidates.extend([prefix / "include" / "clang-c", prefix / "include"])

    for candidate in candidates:
        normalized = normalize_clang_c_dir(candidate)
        if (normalized / "Index.h").is_file():
            return normalized

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
        "error: could not find clang-c/Index.h in the active Pixi/Conda environment; "
        "install clangdev 18 or set LIBCLANG_HEADERS_DIR to a compatible LLVM include directory"
    )


def normalize_clang_c_dir(path: Path) -> Path:
    path = path.expanduser().resolve()
    if path.name == "clang-c":
        return path
    return path / "clang-c"


def optional_output_path(name: str) -> Path | None:
    value = os.environ.get(name)
    if not value:
        return None
    return Path(value).expanduser().resolve()


def read_cindex_version(index_header: Path) -> tuple[int, int] | None:
    try:
        text = index_header.read_text(encoding="utf-8")
    except OSError:
        return None
    major_match = re.search(r"^#define\s+CINDEX_VERSION_MAJOR\s+(\d+)\s*$", text, re.MULTILINE)
    minor_match = re.search(r"^#define\s+CINDEX_VERSION_MINOR\s+(\d+)\s*$", text, re.MULTILINE)
    if major_match is None or minor_match is None:
        return None
    return int(major_match.group(1)), int(minor_match.group(1))


def render_metadata_module() -> str:
    with (REPO_ROOT / "pixi.toml").open("rb") as f:
        config = tomllib.load(f)

    package = config.get("package", {})
    run_deps = package.get("run-dependencies", {})
    version = package.get("version", "")
    mojo_constraint = run_deps.get("mojo-compiler", "")
    return (
        '"""Package metadata generated from repository package config."""\n'
        "\n"
        f'comptime LIBCLANG_MOJO_VERSION = "{version}"\n'
        f'comptime MOJO_COMPILER_CONSTRAINT = "{mojo_constraint}"\n'
    )


def query_libclang_version(library_path: Path | None) -> str | None:
    if library_path is None:
        return None

    class CXString(ctypes.Structure):
        _fields_ = [("data", ctypes.c_void_p), ("private_flags", ctypes.c_uint)]

    try:
        libclang = ctypes.CDLL(str(library_path))
        libclang.clang_getClangVersion.restype = CXString
        libclang.clang_getCString.argtypes = [CXString]
        libclang.clang_getCString.restype = ctypes.c_char_p
        libclang.clang_disposeString.argtypes = [CXString]
        value = libclang.clang_getClangVersion()
        try:
            text = libclang.clang_getCString(value)
            if text is None:
                return None
            return text.decode("utf-8", errors="replace")
        finally:
            libclang.clang_disposeString(value)
    except Exception:
        return None






def discover_libclang_library() -> Path | None:
    override = os.environ.get("LIBCLANG_LIBRARY")
    if override:
        path = Path(override).expanduser().resolve()
        if not path.is_file():
            raise SystemExit(f"error: LIBCLANG_LIBRARY does not exist: {path}")
        return path

    conda_prefix = os.environ.get("CONDA_PREFIX")
    candidates: list[Path] = []
    if conda_prefix:
        prefix = Path(conda_prefix).expanduser().resolve()
        candidates.extend(
            [
                prefix / "lib" / "libclang.so",
                prefix / "lib" / "libclang.dylib",
                prefix / "bin" / "libclang.dll",
            ]
        )
    for lib_dir in active_environment_library_dirs():
        candidates.extend(
            [
                lib_dir / "libclang.so",
                lib_dir / "libclang.dylib",
                lib_dir.parent / "bin" / "libclang.dll",
            ]
        )
    for candidate in candidates:
        if candidate.is_file():
            return candidate

    try:
        import clang.cindex as cindex

        filename = cindex.conf.get_filename()
        if filename:
            path = Path(filename).expanduser().resolve()
            if path.is_file():
                return path
    except Exception:
        pass

    for name in ("libclang.so", "libclang.dylib", "libclang.dll"):
        found = shutil.which(name)
        if found:
            return Path(found).resolve()
    return None


def build_compile_args(include_root: Path) -> list[str]:
    args = [f"-I{include_root}"]
    if sys.platform == "darwin":
        # libclang does not inherit Apple's SDK selection from the cc driver.
        sdk = os.environ.get("SDKROOT") or subprocess.check_output(
            ["xcrun", "--sdk", "macosx", "--show-sdk-path"], text=True
        ).strip()
        args.extend(["-isysroot", sdk])
    seen = set(args)
    try:
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






def active_environment_library_dirs() -> list[Path]:
    return [prefix / "lib" for prefix in active_environment_prefixes()]


def active_environment_prefixes() -> list[Path]:
    dirs: list[Path] = []

    conda_prefix = os.environ.get("CONDA_PREFIX")
    if conda_prefix:
        dirs.append(Path(conda_prefix).expanduser())

    pixi_project_root = os.environ.get("PIXI_PROJECT_ROOT")
    pixi_env_name = os.environ.get("PIXI_ENVIRONMENT_NAME")
    if pixi_project_root and pixi_env_name:
        dirs.append(Path(pixi_project_root).expanduser() / ".pixi" / "envs" / pixi_env_name)

    deduped: list[Path] = []
    seen: set[Path] = set()
    for prefix in dirs:
        resolved = prefix.resolve()
        if resolved in seen:
            continue
        deduped.append(resolved)
        seen.add(resolved)
    return deduped


def build_layout_tests(layout_out: Path) -> None:
    mojo = shutil.which("mojo")
    if mojo is None:
        raise SystemExit("error: mojo not found; required to verify generated layout tests")
    with tempfile.TemporaryDirectory(prefix="mojo-libclang-layout-") as temp_dir:
        binary_out = Path(temp_dir) / layout_out.stem
        run([mojo, "build", "-I", ".", "-o", str(binary_out), str(layout_out)])
        run([str(binary_out)])


def run(cmd: list[str]) -> None:
    print("+ " + shell_join(cmd))
    subprocess.run(cmd, cwd=REPO_ROOT, check=True)


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

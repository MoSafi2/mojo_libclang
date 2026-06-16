#!/usr/bin/env python3
"""Generate ABI-normalized Mojo FFI bindings for LLVM libclang.

The generator uses ``mojo-bindgen`` as a library:

1. Parse libclang's public ``clang-c`` headers to CIR.
2. Run mojo-bindgen's normal CIR validation/canonicalization passes.
3. Rewrite every libclang function so Mojo never calls a C signature that
   passes or returns libclang aggregate handles by value.
4. Emit a deterministic C shim/header from that same rewrite.
5. Emit Mojo bindings and layout tests from the rewritten CIR.

Environment overrides:
  LIBCLANG_HEADERS_DIR     Directory containing clang-c/*.h or the clang-c dir.
  LIBCLANG_LIBRARY         Path to libclang.so/dylib/dll used to build the shim.
  LIBCLANG_FFI_OUT         Output Mojo file. Defaults to src/_ffi.mojo.
  LIBCLANG_FFI_IR_OUT      Rewritten CIR JSON. Defaults to build/_ffi.ir.json.
  LIBCLANG_ORIGINAL_IR_OUT Pre-rewrite normalized CIR JSON.
  LIBCLANG_SHIM_OUT        Output shared library for the shim.
"""

from __future__ import annotations

import json
import os
import ctypes
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import replace
from pathlib import Path

from mojo_bindgen.analysis.pipeline import AnalysisOrchestrator
from mojo_bindgen.codegen.mojo_ir_printer import MojoIRPrintOptions, render_mojo_module
from mojo_bindgen.ir import (
    Array,
    AtomicType,
    Const,
    Decl,
    Enum,
    EnumRef,
    FloatKind,
    FloatType,
    Function,
    FunctionPtr,
    GlobalVar,
    IntKind,
    IntType,
    MacroDecl,
    Pointer,
    PointerMutability,
    PointerOrigin,
    QualifiedType,
    OpaqueRecordRef,
    Struct,
    StructRef,
    Type,
    TypeRef,
    Typedef,
    Unit,
    VoidType,
)
from mojo_bindgen.layout_tests import render_layout_test_module
from mojo_bindgen.orchestrator import BindgenOptions, BindgenOrchestrator
from mojo_bindgen.parsing.frontend import ClangOptions
from mojo_bindgen.parsing.parser import _default_system_compile_args


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_FFI_MOJO_OUT = REPO_ROOT / "src" / "_ffi.mojo"
DEFAULT_FFI_IR_OUT = REPO_ROOT / "build" / "_ffi.ir.json"
DEFAULT_ORIGINAL_IR_OUT = REPO_ROOT / "build" / "_ffi.original.ir.json"
DEFAULT_LAYOUT_TEST_OUT = REPO_ROOT / "test" / "_ffi_layout_tests.mojo"
DEFAULT_SHIM_OUT = REPO_ROOT / "build" / "libclang_mojo_shim.so"
DEFAULT_SHIM_HEADER = REPO_ROOT / "shim" / "libclang_mojo_shim.h"
DEFAULT_SHIM_SRC = REPO_ROOT / "shim" / "libclang_mojo_shim.c"
DEFAULT_PIXI_ENV_DIR = REPO_ROOT / ".pixi" / "envs" / "default"

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

AGGREGATE_NAMES = frozenset(
    {
        "CXString",
        "CXSourceLocation",
        "CXSourceRange",
        "CXCursor",
        "CXType",
        "CXToken",
        "CXIdxLoc",
        "CXComment",
        "CXCursorAndRangeVisitor",
    }
)


class RewriteError(RuntimeError):
    pass


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
    ir_out = Path(os.environ.get("LIBCLANG_FFI_IR_OUT", DEFAULT_FFI_IR_OUT)).resolve()
    original_ir_out = Path(
        os.environ.get("LIBCLANG_ORIGINAL_IR_OUT", DEFAULT_ORIGINAL_IR_OUT)
    ).resolve()
    layout_out = Path(os.environ.get("LIBCLANG_LAYOUT_TEST_OUT", DEFAULT_LAYOUT_TEST_OUT)).resolve()
    shim_out = Path(os.environ.get("LIBCLANG_SHIM_OUT", DEFAULT_SHIM_OUT)).resolve()

    for path in (mojo_out, ir_out, original_ir_out, layout_out, shim_out, DEFAULT_SHIM_HEADER, DEFAULT_SHIM_SRC):
        path.parent.mkdir(parents=True, exist_ok=True)

    raw_unit = parse_unit(primary, headers, include_root)
    orchestrator = AnalysisOrchestrator(
        BindgenOrchestrator(
            BindgenOptions(
                header=primary,
                library="libclang_mojo_shim",
                link_name="libclang_mojo_shim",
                linking="external_call",
                library_path_hint=str(shim_out),
                module_comment=True,
                emit_doc_comments=False,
            )
        ).emit_options
    )
    normalized_unit = orchestrator.normalize_cir(raw_unit)
    original_ir_out.write_text(normalized_unit.to_json(), encoding="utf-8")

    rewritten = LibclangABIRewriter(normalized_unit).rewrite()
    DEFAULT_SHIM_HEADER.write_text(rewritten.header_text, encoding="utf-8")
    DEFAULT_SHIM_SRC.write_text(rewritten.source_text, encoding="utf-8")
    ir_out.write_text(rewritten.unit.to_json(), encoding="utf-8")

    header_version = read_cindex_version(primary)
    library_path = discover_libclang_library()
    runtime_version = query_libclang_version(library_path)
    validate_header_runtime_compatibility(primary, runtime_version)
    build_shim(include_root, library_path, shim_out)

    analysis = orchestrator.analyze_with_artifacts(rewritten.unit)
    mojo_source = render_mojo_module(
        analysis.mojo_module,
        MojoIRPrintOptions(module_comment=True, emit_doc_comments=False),
    )
    layout_source = render_layout_test_module(
        normalized_unit=analysis.normalized_unit,
        mojo_module=analysis.mojo_module,
        main_module_name=layout_import_module(mojo_out),
    )
    mojo_out.write_text(mojo_source, encoding="utf-8")
    layout_out.write_text(layout_source, encoding="utf-8")
    build_layout_tests(layout_out)

    print(f"generated: {display_path(mojo_out)}")
    print(f"generated: {display_path(layout_out)}")
    print(f"generated: {display_path(ir_out)}")
    print(f"generated: {display_path(original_ir_out)}")
    print(f"generated: {display_path(DEFAULT_SHIM_HEADER)}")
    print(f"generated: {display_path(DEFAULT_SHIM_SRC)}")
    print(f"shim:      {display_path(shim_out)}")
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
        library="libclang_mojo_shim",
        link_name="libclang_mojo_shim",
        clang_options=ClangOptions(raw_args=tuple(compile_args)),
        linking="external_call",
        library_path_hint=str(DEFAULT_SHIM_OUT.resolve()),
        module_comment=True,
        emit_doc_comments=False,
        clang_macro_fallback=True,
    )
    return BindgenOrchestrator(options).parse()


def layout_import_module(mojo_out: Path) -> str:
    stem = mojo_out.stem
    if stem.startswith("_") and mojo_out.parent == (REPO_ROOT / "src").resolve():
        return f"src.{stem}"
    return stem


class RewrittenUnit:
    def __init__(self, unit: Unit, header_text: str, source_text: str) -> None:
        self.unit = unit
        self.header_text = header_text
        self.source_text = source_text


class LibclangABIRewriter:
    def __init__(self, unit: Unit) -> None:
        self.unit = unit
        self.structs = {decl.name: decl for decl in unit.decls if isinstance(decl, Struct)}
        self.typedef_names = {decl.name for decl in unit.decls if isinstance(decl, Typedef)}
        self.callback_typedefs: dict[str, FunctionPtr] = {}
        for decl in unit.decls:
            if isinstance(decl, Typedef):
                unwrapped = self._unwrap(decl.canonical)
                if isinstance(unwrapped, FunctionPtr):
                    self.callback_typedefs[decl.name] = unwrapped

    def rewrite(self) -> RewrittenUnit:
        decls: list[Decl] = []
        functions: list[Function] = []
        for decl in self.unit.decls:
            if not self._keep_decl(decl):
                continue
            if isinstance(decl, Struct):
                decls.append(self._rewrite_decl_types(decl))
            elif isinstance(decl, Typedef):
                decls.append(self._rewrite_typedef(decl))
            elif isinstance(decl, Function):
                rewritten = self._rewrite_function(decl)
                decls.append(rewritten)
                functions.append(rewritten)
            else:
                decls.append(self._rewrite_decl_types(decl))

        unit = replace(
            self.unit,
            library="libclang_mojo_shim",
            link_name="libclang_mojo_shim",
            decls=decls,
        )
        header = self._render_header(unit, functions)
        source = self._render_source(functions)
        return RewrittenUnit(unit, header, source)

    @staticmethod
    def _keep_decl(decl: Decl) -> bool:
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

    def _rewrite_decl_types(self, decl: Decl) -> Decl:
        if isinstance(decl, Enum | MacroDecl):
            return decl
        if isinstance(decl, Struct):
            return replace(
                decl,
                fields=[
                    replace(field, type=self._rewrite_type(field.type))
                    for field in decl.fields
                ],
            )
        if isinstance(decl, Const):
            return replace(decl, type=self._rewrite_type(decl.type))
        if isinstance(decl, GlobalVar):
            return replace(decl, type=self._rewrite_type(decl.type))
        return decl

    def _rewrite_typedef(self, decl: Typedef) -> Typedef:
        return replace(
            decl,
            aliased=self._rewrite_type(decl.aliased),
            canonical=self._rewrite_type(decl.canonical),
        )

    def _rewrite_function(self, decl: Function) -> Function:
        params = []
        for param in decl.params:
            params.append(replace(param, type=self._rewrite_param_type(param.type)))

        ret = self._rewrite_type(decl.ret)
        ret_agg = self._aggregate_name(ret)
        if ret_agg is not None:
            out_param = replace(
                decl.params[0] if decl.params else _synthetic_param(),
                name="out",
                type=self._ptr_to(ret, mut=True),
                doc=None,
            )
            params = [out_param, *params]
            ret = VoidType()

        return replace(
            decl,
            link_name=self._shim_symbol(decl.link_name),
            ret=ret,
            params=params,
        )

    def _rewrite_param_type(self, typ: Type) -> Type:
        rewritten = self._rewrite_type(typ)
        if self._aggregate_name(rewritten) is not None:
            return self._ptr_to(rewritten, mut=False)
        return rewritten

    def _rewrite_type(self, typ: Type) -> Type:
        if isinstance(typ, QualifiedType):
            return replace(typ, unqualified=self._rewrite_type(typ.unqualified))
        if isinstance(typ, AtomicType):
            return replace(typ, value_type=self._rewrite_type(typ.value_type))
        if isinstance(typ, Pointer):
            pointee = self._rewrite_type(typ.pointee) if typ.pointee is not None else None
            return replace(typ, pointee=pointee)
        if isinstance(typ, Array):
            return replace(typ, element=self._rewrite_type(typ.element))
        if isinstance(typ, FunctionPtr):
            return self._rewrite_function_ptr(typ)
        if isinstance(typ, TypeRef):
            return replace(typ, canonical=self._rewrite_type(typ.canonical))
        return typ

    def _rewrite_function_ptr(self, typ: FunctionPtr) -> FunctionPtr:
        params = [
            replace(param, type=self._rewrite_param_type(param.type))
            for param in typ.params
        ]
        ret = self._rewrite_type(typ.ret)
        ret_agg = self._aggregate_name(ret)
        if ret_agg is not None:
            params = [replace(_synthetic_param(), name="out", type=self._ptr_to(ret, mut=True)), *params]
            ret = VoidType()
        return replace(typ, ret=ret, params=params)

    def _ptr_to(self, typ: Type, *, mut: bool) -> Pointer:
        return Pointer(
            pointee=typ,
            size_bytes=self.unit.target_abi.pointer_size_bytes,
            align_bytes=self.unit.target_abi.pointer_align_bytes,
            mutability=PointerMutability.MUT if mut else PointerMutability.IMMUT,
            origin=PointerOrigin.EXTERNAL,
            nullable=True,
        )

    def _unwrap(self, typ: Type) -> Type:
        while isinstance(typ, (QualifiedType, TypeRef)):
            typ = typ.unqualified if isinstance(typ, QualifiedType) else typ.canonical
        return typ

    def _aggregate_name(self, typ: Type) -> str | None:
        typ = self._unwrap(typ)
        if isinstance(typ, StructRef) and typ.name in AGGREGATE_NAMES:
            return typ.name
        return None

    def _type_size(self, typ: Type) -> int:
        typ = self._unwrap(typ)
        if isinstance(typ, (IntType, FloatType, Pointer, Array, StructRef, EnumRef)):
            return typ.size_bytes
        if isinstance(typ, VoidType):
            return 0
        return self.unit.target_abi.pointer_size_bytes

    @staticmethod
    def _shim_symbol(link_name: str) -> str:
        return "mojo_" + link_name

    def _render_header(self, unit: Unit, functions: list[Function]) -> str:
        lines = [
            "/* Generated by scripts/generate_libclang_bindings.py - do not edit by hand. */",
            "#pragma once",
            "",
            "#include <clang-c/BuildSystem.h>",
            "#include <clang-c/CXCompilationDatabase.h>",
            "#include <clang-c/CXDiagnostic.h>",
            "#include <clang-c/CXFile.h>",
            "#include <clang-c/CXSourceLocation.h>",
            "#include <clang-c/CXString.h>",
            "#include <clang-c/Documentation.h>",
            "#include <clang-c/FatalErrorHandler.h>",
            "#include <clang-c/Index.h>",
            "#include <clang-c/Rewrite.h>",
            "",
            "#if defined(_WIN32)",
            "#define MOJO_SHIM_EXPORT __declspec(dllexport)",
            "#else",
            "#define MOJO_SHIM_EXPORT __attribute__((visibility(\"default\")))",
            "#endif",
            "",
        ]
        for alias, fp in sorted(self.callback_typedefs.items()):
            if self._function_ptr_has_aggregate(fp):
                lines.append(
                    f"typedef {self._c_function_pointer(self._rewrite_function_ptr(fp), 'mojo_' + alias)};"
                )
        lines.append("")
        for fn in functions:
            lines.append(f"MOJO_SHIM_EXPORT {self._c_function_decl(fn)};")
        lines.append("")
        return "\n".join(lines)

    def _render_source(self, functions: list[Function]) -> str:
        lines = [
            "/* Generated by scripts/generate_libclang_bindings.py - do not edit by hand. */",
            '#include "libclang_mojo_shim.h"',
            "#include <stdio.h>",
            "#include <stdlib.h>",
            "",
            "#if defined(_WIN32)",
            "#include <windows.h>",
            "#else",
            "#include <dlfcn.h>",
            "#endif",
            "",
            "#ifndef MOJO_LIBCLANG_RUNTIME_PATH",
            '#define MOJO_LIBCLANG_RUNTIME_PATH ""',
            "#endif",
            "",
        ]
        lines.extend(self._render_symbol_resolvers(functions))
        lines.extend(self._render_callback_trampolines())
        for fn in functions:
            lines.extend(self._render_function_body(fn))
            lines.append("")
        return "\n".join(lines)

    def _render_symbol_resolvers(self, functions: list[Function]) -> list[str]:
        lines = [
            "#if defined(_WIN32)",
            "static HMODULE mojo_libclang_handle(void) {",
            "    static HMODULE libclang_module = NULL;",
            "    static int initialized = 0;",
            "    if (!initialized) {",
            "        if (MOJO_LIBCLANG_RUNTIME_PATH[0] != '\\0') {",
            "            libclang_module = LoadLibraryA(MOJO_LIBCLANG_RUNTIME_PATH);",
            "        }",
            "        if (libclang_module == NULL) {",
            '            libclang_module = GetModuleHandleA("libclang.dll");',
            "        }",
            "        if (libclang_module == NULL) {",
            '            libclang_module = LoadLibraryA("libclang.dll");',
            "        }",
            "        initialized = 1;",
            "    }",
            "    return libclang_module;",
            "}",
            "#else",
            "static void *mojo_libclang_handle(void) {",
            "    static void *libclang_handle = NULL;",
            "    static int initialized = 0;",
            "    if (!initialized) {",
            "        if (MOJO_LIBCLANG_RUNTIME_PATH[0] != '\\0') {",
            "            libclang_handle = dlopen(MOJO_LIBCLANG_RUNTIME_PATH, RTLD_LAZY | RTLD_LOCAL);",
            "        }",
            "        if (libclang_handle == NULL) {",
            '            libclang_handle = dlopen("libclang.so", RTLD_LAZY | RTLD_LOCAL);',
            "        }",
            "        if (libclang_handle == NULL) {",
            '            libclang_handle = dlopen("libclang.so.1", RTLD_LAZY | RTLD_LOCAL);',
            "        }",
            "        initialized = 1;",
            "    }",
            "    return libclang_handle;",
            "}",
            "#endif",
            "",
            "static void *mojo_find_libclang_symbol(const char *name) {",
            "#if defined(_WIN32)",
            "    HMODULE libclang_module = mojo_libclang_handle();",
            "    if (libclang_module == NULL) {",
            "        return NULL;",
            "    }",
            "    return (void *)GetProcAddress(libclang_module, name);",
            "#else",
            "    void *libclang_handle = mojo_libclang_handle();",
            "    if (libclang_handle == NULL) {",
            "        return NULL;",
            "    }",
            "    return dlsym(libclang_handle, name);",
            "#endif",
            "}",
            "",
            "static void *mojo_require_libclang_symbol(const char *name) {",
            "    void *symbol = mojo_find_libclang_symbol(name);",
            "    if (symbol == NULL) {",
            '        fprintf(stderr, "libclang symbol not available at runtime: %s\\n", name);',
            "        abort();",
            "    }",
            "    return symbol;",
            "}",
            "",
        ]
        emitted: set[str] = set()
        for fn in functions:
            original = fn.link_name.removeprefix("mojo_")
            if original in emitted:
                continue
            emitted.add(original)
            original_fn = self._find_original_function(original)
            if original_fn is None:
                raise RewriteError(f"could not find original function for {original}")
            typedef_name = self._resolver_typedef_name(original)
            resolver_name = self._resolver_func_name(original)
            fn_ptr = FunctionPtr(ret=original_fn.ret, params=original_fn.params, is_variadic=original_fn.is_variadic)
            lines.extend(
                [
                    f"typedef {self._c_function_pointer(fn_ptr, typedef_name)};",
                    f"static {typedef_name} {resolver_name}(void) {{",
                    f"    static {typedef_name} fn = NULL;",
                    "    static int initialized = 0;",
                    "    if (!initialized) {",
                    f"        fn = ({typedef_name})mojo_require_libclang_symbol(\"{original}\");",
                    "        initialized = 1;",
                    "    }",
                    "    return fn;",
                    "}",
                    "",
                ]
            )
        return lines

    def _render_callback_trampolines(self) -> list[str]:
        lines: list[str] = []
        for alias, fp in sorted(self.callback_typedefs.items()):
            if alias not in {"CXCursorVisitor", "CXFieldVisitor"}:
                continue
            if not self._function_ptr_has_aggregate(fp):
                continue
            ret = self._c_type(fp.ret)
            params = ", ".join(
                f"{self._c_type(param.type)} arg{i}" for i, param in enumerate(fp.params)
            )
            mojo_params = []
            call_args = []
            for i, param in enumerate(fp.params):
                if self._aggregate_name(param.type) is not None:
                    mojo_params.append(f"{self._c_type(param.type)} *arg{i}")
                    call_args.append(f"&arg{i}")
                else:
                    mojo_params.append(f"{self._c_type(param.type)} arg{i}")
                    call_args.append(f"arg{i}")
            mojo_sig = f"{self._c_type(fp.ret)} (*fn)({', '.join(mojo_params)})"
            lines.extend(
                [
                    f"typedef struct Mojo{alias}Context {{",
                    f"    {mojo_sig};",
                    "    void *client_data;",
                    f"}} Mojo{alias}Context;",
                    "",
                    f"static {ret} mojo_{alias}_trampoline({params}) {{",
                    f"    Mojo{alias}Context *ctx = (Mojo{alias}Context *)arg{len(fp.params) - 1};",
                ]
            )
            call_args[-1] = "ctx->client_data"
            lines.append(f"    return ctx->fn({', '.join(call_args)});")
            lines.extend(["}", ""])

        lines.extend(
            [
                "typedef struct MojoCXCursorAndRangeVisitorContext {",
                "    CXCursorAndRangeVisitor *visitor;",
                "} MojoCXCursorAndRangeVisitorContext;",
                "",
                "static enum CXVisitorResult mojo_CXCursorAndRangeVisitor_trampoline(",
                "    void *context,",
                "    CXCursor cursor,",
                "    CXSourceRange range",
                ") {",
                "    MojoCXCursorAndRangeVisitorContext *ctx = (MojoCXCursorAndRangeVisitorContext *)context;",
                "    return ((enum CXVisitorResult (*)(void *, CXCursor *, CXSourceRange *))ctx->visitor->visit)(",
                "        ctx->visitor->context,",
                "        &cursor,",
                "        &range",
                "    );",
                "}",
                "",
            ]
        )
        return lines

    def _render_function_body(self, fn: Function) -> list[str]:
        original = fn.link_name.removeprefix("mojo_")
        if original in {
            "clang_visitChildren",
            "clang_Type_visitFields",
            "clang_visitCXXBaseClasses",
            "clang_visitCXXMethods",
        }:
            return self._render_top_level_callback_body(fn, original)
        original_fn = self._find_original_function(original)
        if original_fn is None:
            raise RewriteError(f"could not find original function for {original}")
        decl = self._c_function_decl(fn)
        lines = [f"MOJO_SHIM_EXPORT {decl} {{"]
        lines.append(f"    {self._resolver_typedef_name(original)} target = {self._resolver_func_name(original)}();")
        call_args: list[str] = []
        out_name: str | None = None

        rewritten_offset = 0
        if self._aggregate_name(original_fn.ret) is not None:
            out_name = fn.params[0].name or "out"
            rewritten_offset = 1

        for i, original_param in enumerate(original_fn.params):
            rewritten_param = fn.params[i + rewritten_offset]
            pname = rewritten_param.name or f"arg{i + rewritten_offset}"
            original_type = original_param.type
            original_unwrapped = self._unwrap(original_type)
            if isinstance(original_unwrapped, FunctionPtr):
                if self._function_ptr_has_aggregate(original_unwrapped):
                    call_args.append(self._callback_arg(original, rewritten_param))
                else:
                    call_args.append(pname)
            elif self._aggregate_name(original_type) == "CXCursorAndRangeVisitor":
                call_args.append(self._cursor_range_visitor_arg(pname, lines))
            elif self._aggregate_name(original_type) is not None:
                call_args.append(f"*{pname}")
            else:
                call_args.append(pname)

        call = f"target({', '.join(call_args)})"
        if out_name is not None:
            lines.append(f"    *{out_name} = {call};")
        elif isinstance(self._unwrap(fn.ret), VoidType):
            lines.append(f"    {call};")
        else:
            lines.append(f"    return {call};")
        lines.append("}")
        return lines

    def _render_top_level_callback_body(self, fn: Function, original: str) -> list[str]:
        decl = self._c_function_decl(fn)
        if original == "clang_visitChildren":
            ctx_type = "MojoCXCursorVisitorContext"
            trampoline = "mojo_CXCursorVisitor_trampoline"
        else:
            ctx_type = "MojoCXFieldVisitorContext"
            trampoline = "mojo_CXFieldVisitor_trampoline"
        first_param = fn.params[0].name or "arg0"
        first_arg = f"*{first_param}"
        lines = [
            f"MOJO_SHIM_EXPORT {decl} {{",
            f"    {self._resolver_typedef_name(original)} target = {self._resolver_func_name(original)}();",
            f"    {ctx_type} ctx = {{ .fn = visitor, .client_data = client_data }};",
            f"    return target({first_arg}, {trampoline}, &ctx);",
            "}",
        ]
        return lines

    @staticmethod
    def _resolver_typedef_name(link_name: str) -> str:
        return f"mojo_fn_{link_name}"

    @staticmethod
    def _resolver_func_name(link_name: str) -> str:
        return f"mojo_load_{link_name}"

    def _callback_arg(self, original: str, param) -> str:
        if original == "clang_visitChildren" and param.name == "visitor":
            return "mojo_CXCursorVisitor_trampoline"
        if original in {
            "clang_Type_visitFields",
            "clang_visitCXXBaseClasses",
            "clang_visitCXXMethods",
        } and param.name == "visitor":
            return "mojo_CXFieldVisitor_trampoline"
        raise RewriteError(f"unsupported callback parameter in {original}: {param.name}")

    def _cursor_range_visitor_arg(self, name: str, lines: list[str]) -> str:
        lines.extend(
            [
                f"    MojoCXCursorAndRangeVisitorContext {name}_ctx = {{ .visitor = {name} }};",
                "    CXCursorAndRangeVisitor normalized_visitor = {",
                f"        .context = &{name}_ctx,",
                "        .visit = mojo_CXCursorAndRangeVisitor_trampoline,",
                "    };",
            ]
        )
        return "normalized_visitor"

    def _find_original_function(self, link_name: str) -> Function | None:
        for decl in self.unit.decls:
            if isinstance(decl, Function) and decl.link_name == link_name:
                return decl
        return None

    def _points_to_aggregate(self, typ: Type) -> bool:
        typ = self._unwrap(typ)
        return isinstance(typ, Pointer) and typ.pointee is not None and self._aggregate_name(typ.pointee) is not None

    def _points_to_named_aggregate(self, typ: Type, name: str) -> bool:
        typ = self._unwrap(typ)
        return (
            isinstance(typ, Pointer)
            and typ.pointee is not None
            and self._aggregate_name(typ.pointee) == name
        )

    def _function_ptr_has_aggregate(self, fp: FunctionPtr) -> bool:
        if self._aggregate_name(fp.ret) is not None:
            return True
        return any(self._aggregate_name(param.type) is not None for param in fp.params)

    def _c_function_decl(self, fn: Function) -> str:
        params = ", ".join(self._c_param_decl(param.type, param.name or f"arg{i}") for i, param in enumerate(fn.params))
        if not params:
            params = "void"
        return f"{self._c_type(fn.ret)} {fn.link_name}({params})"

    def _c_function_pointer(self, fp: FunctionPtr, name: str) -> str:
        params = ", ".join(self._c_param_decl(param.type, param.name or f"arg{i}") for i, param in enumerate(fp.params))
        if not params:
            params = "void"
        return f"{self._c_type(fp.ret)} (*{name})({params})"

    def _c_param_decl(self, typ: Type, name: str) -> str:
        typ_unwrapped = self._unwrap(typ)
        if isinstance(typ_unwrapped, FunctionPtr):
            return self._c_function_pointer(typ_unwrapped, name)
        return f"{self._c_type(typ)} {name}"

    def _c_type(self, typ: Type) -> str:
        if isinstance(typ, QualifiedType):
            base = self._c_type(typ.unqualified)
            return f"const {base}" if typ.qualifiers.is_const else base
        if isinstance(typ, TypeRef):
            canonical = self._unwrap(typ.canonical)
            if isinstance(canonical, EnumRef):
                return typ.name
            return typ.name
        if isinstance(typ, VoidType):
            return "void"
        if isinstance(typ, IntType):
            return self._c_int_type(typ)
        if isinstance(typ, FloatType):
            return self._c_float_type(typ)
        if isinstance(typ, Pointer):
            base = "void" if typ.pointee is None else self._c_type(typ.pointee)
            const = (
                "const "
                if typ.mutability == PointerMutability.IMMUT
                and typ.pointee is not None
                and not base.startswith("const ")
                else ""
            )
            return f"{const}{base} *"
        if isinstance(typ, Array):
            return f"{self._c_type(typ.element)} *"
        if isinstance(typ, FunctionPtr):
            return self._c_function_pointer(typ, "")
        if isinstance(typ, StructRef):
            if typ.c_name in self.typedef_names:
                return typ.c_name
            return f"struct {typ.c_name}"
        if isinstance(typ, EnumRef):
            return f"enum {typ.c_name}"
        if isinstance(typ, OpaqueRecordRef):
            return typ.c_name
        raise RewriteError(f"unsupported C type in shim: {typ!r}")

    @staticmethod
    def _c_int_type(typ: IntType) -> str:
        table = {
            IntKind.BOOL: "bool",
            IntKind.CHAR_S: "char",
            IntKind.CHAR_U: "unsigned char",
            IntKind.SCHAR: "signed char",
            IntKind.UCHAR: "unsigned char",
            IntKind.SHORT: "short",
            IntKind.USHORT: "unsigned short",
            IntKind.INT: "int",
            IntKind.UINT: "unsigned int",
            IntKind.LONG: "long",
            IntKind.ULONG: "unsigned long",
            IntKind.LONGLONG: "long long",
            IntKind.ULONGLONG: "unsigned long long",
            IntKind.WCHAR: "wchar_t",
            IntKind.CHAR16: "char16_t",
            IntKind.CHAR32: "char32_t",
        }
        try:
            return table[typ.int_kind]
        except KeyError as exc:
            raise RewriteError(f"unsupported integer kind in shim: {typ.int_kind}") from exc

    @staticmethod
    def _c_float_type(typ: FloatType) -> str:
        table = {
            FloatKind.FLOAT: "float",
            FloatKind.DOUBLE: "double",
            FloatKind.LONG_DOUBLE: "long double",
            FloatKind.FLOAT16: "_Float16",
        }
        try:
            return table[typ.float_kind]
        except KeyError as exc:
            raise RewriteError(f"unsupported float kind in shim: {typ.float_kind}") from exc


def _synthetic_param():
    from mojo_bindgen.ir import Param

    return Param(name="out", type=VoidType())


def discover_clang_c_dir() -> Path:
    override = os.environ.get("LIBCLANG_HEADERS_DIR")
    if override:
        return normalize_clang_c_dir(Path(override))

    conda_prefix = os.environ.get("CONDA_PREFIX")
    candidates: list[Path] = []
    if conda_prefix:
        prefix = Path(conda_prefix).expanduser().resolve()
        candidates.extend([prefix / "include" / "clang-c", prefix / "include"])

    candidates.extend([DEFAULT_PIXI_ENV_DIR / "include" / "clang-c", DEFAULT_PIXI_ENV_DIR / "include"])

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


def parse_runtime_major(version_text: str | None) -> int | None:
    if not version_text:
        return None
    match = re.search(r"\bclang version\s+(\d+)", version_text)
    if match is None:
        return None
    return int(match.group(1))


def validate_header_runtime_compatibility(primary: Path, runtime_version: str | None) -> None:
    del primary, runtime_version


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
    candidates.extend(
        [
            DEFAULT_PIXI_ENV_DIR / "lib" / "libclang.so",
            DEFAULT_PIXI_ENV_DIR / "lib" / "libclang.dylib",
            DEFAULT_PIXI_ENV_DIR / "bin" / "libclang.dll",
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


def build_shim(include_root: Path, library_path: Path | None, shim_out: Path) -> None:
    cc = shutil.which("cc")
    if cc is None:
        raise SystemExit("error: C compiler not found; required to build libclang shim")
    runtime_dir = shim_out.parent
    if library_path is not None:
        ensure_soname_link(library_path, runtime_dir)
    cmd = [
        cc,
        "-shared",
        "-fPIC",
        "-I",
        str(include_root),
        "-I",
        str(DEFAULT_SHIM_HEADER.parent),
        "-o",
        str(shim_out),
        str(DEFAULT_SHIM_SRC),
    ]
    if library_path is not None:
        cmd.extend(
            [
                "-DMOJO_LIBCLANG_RUNTIME_PATH="
                + json.dumps(str(library_path.resolve())),
            ]
        )
        cmd.extend(
            [
                "-L",
                str(library_path.parent),
                f"-l:{library_path.name}",
                "-Wl,-rpath," + str(library_path.parent),
                "-Wl,-rpath," + str(runtime_dir),
            ]
        )
    else:
        cmd.append("-lclang")
    run(cmd)


def ensure_soname_link(library_path: Path, runtime_dir: Path) -> None:
    soname = shared_library_soname(library_path)
    if soname is None or soname == library_path.name:
        return
    runtime_dir.mkdir(parents=True, exist_ok=True)
    link = runtime_dir / soname
    target = library_path.resolve()
    if link.exists() or link.is_symlink():
        if link.is_symlink() and link.resolve() == target:
            return
        link.unlink()
    link.symlink_to(target)


def shared_library_soname(library_path: Path) -> str | None:
    readelf = shutil.which("readelf")
    if readelf is None:
        return None
    try:
        output = subprocess.check_output(
            [readelf, "-d", str(library_path)],
            text=True,
            stderr=subprocess.DEVNULL,
        )
    except (OSError, subprocess.CalledProcessError):
        return None
    marker = "Library soname: ["
    for line in output.splitlines():
        if marker in line:
            return line.split(marker, 1)[1].split("]", 1)[0]
    return None


def build_layout_tests(layout_out: Path) -> None:
    mojo = shutil.which("mojo")
    if mojo is None:
        raise SystemExit("error: mojo not found; required to verify generated layout tests")
    binary_out = REPO_ROOT / "build" / layout_out.stem
    binary_out.parent.mkdir(parents=True, exist_ok=True)
    run([mojo, "build", "-I", ".", "-o", str(binary_out), str(layout_out)])


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

"""Generic CIR-to-C ABI shim normalizer for Mojo bindgen output."""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, replace
from typing import Any

from mojo_bindgen.analysis.traversal import iter_decl_types
from mojo_bindgen.analysis.type_walk import TypeWalkOptions, iter_type_nodes
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
    OpaqueRecordRef,
    Pointer,
    PointerMutability,
    PointerOrigin,
    QualifiedType,
    Struct,
    StructRef,
    Type,
    TypeRef,
    Typedef,
    Unit,
    VoidType,
)


class RewriteError(RuntimeError):
    pass


@dataclass(frozen=True)
class RewrittenUnit:
    unit: Unit
    header_text: str
    source_text: str


def _keep_all(_: Decl) -> bool:
    return True


_DIRECT_TYPE_OPTIONS = TypeWalkOptions(
    descend_pointer=False,
    descend_array=False,
    descend_function_ptr=False,
)


_C_INT_TYPE_SPELLINGS = {
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


_C_FLOAT_TYPE_SPELLINGS = {
    FloatKind.FLOAT: "float",
    FloatKind.DOUBLE: "double",
    FloatKind.LONG_DOUBLE: "long double",
    FloatKind.FLOAT16: "_Float16",
}


@dataclass(frozen=True)
class ABIShimConfig:
    shim_library: str
    shim_link_name: str
    header_includes: tuple[str, ...]
    generated_by: str
    runtime_symbol_subject: str
    runtime_path_macro: str
    windows_runtime_library_names: tuple[str, ...]
    posix_runtime_library_names: tuple[str, ...]
    keep_decl: Callable[[Decl], bool] = _keep_all
    shim_symbol_prefix: str = "mojo_"
    export_macro: str = "MOJO_SHIM_EXPORT"


@dataclass(frozen=True)
class DirectCallbackAdapter:
    function_name: str
    param_index: int
    context_param_index: int
    context_param_index_in_callback: int
    original_fp: FunctionPtr
    rewritten_fp: FunctionPtr
    context_param_type: Type


@dataclass(frozen=True)
class StructCallbackAdapter:
    struct_name: str
    callback_field: str
    context_field: str
    context_param_index: int
    original_fp: FunctionPtr
    rewritten_fp: FunctionPtr


@dataclass(frozen=True)
class RewrittenSignature:
    ret: Type
    params: list[Any]


@dataclass(frozen=True)
class ABIShimAnalysis:
    kept_decls: list[Decl]
    structs: dict[str, Struct]
    typedef_names: set[str]
    functions_by_link_name: dict[str, Function]
    callback_typedefs: dict[str, FunctionPtr]
    aggregate_names: frozenset[str]
    direct_callback_adapters: dict[tuple[str, int], DirectCallbackAdapter]
    struct_callback_adapters: dict[str, StructCallbackAdapter]


def _unwrap(typ: Type) -> Type:
    while isinstance(typ, (QualifiedType, TypeRef)):
        typ = typ.unqualified if isinstance(typ, QualifiedType) else typ.canonical
    return typ


def _struct_value_name(typ: Type) -> str | None:
    typ = _unwrap(typ)
    if isinstance(typ, StructRef):
        return typ.name
    return None


def _is_plain_pointer(typ: Type) -> bool:
    return isinstance(_unwrap(typ), Pointer)


def _direct_function_ptrs(typ: Type) -> tuple[FunctionPtr, ...]:
    return tuple(
        node
        for node in iter_type_nodes(typ, options=_DIRECT_TYPE_OPTIONS)
        if isinstance(node, FunctionPtr)
    )


def _safe_name(name: str) -> str:
    return "".join(ch if ch.isalnum() else "_" for ch in name)


class ABIShimAnalyzer:
    def __init__(self, unit: Unit, config: ABIShimConfig) -> None:
        self.unit = unit
        self.config = config
        self.kept_decls = [decl for decl in unit.decls if config.keep_decl(decl)]
        self.structs = {decl.name: decl for decl in unit.decls if isinstance(decl, Struct)}
        self.typedef_names = {decl.name for decl in unit.decls if isinstance(decl, Typedef)}
        self.functions_by_link_name = {
            decl.link_name: decl
            for decl in unit.decls
            if isinstance(decl, Function)
        }
        self.callback_typedefs: dict[str, FunctionPtr] = {}
        for decl in unit.decls:
            if isinstance(decl, Typedef):
                unwrapped = _unwrap(decl.canonical)
                if isinstance(unwrapped, FunctionPtr):
                    self.callback_typedefs[decl.name] = unwrapped

    def analyze(self) -> ABIShimAnalysis:
        aggregate_names = self.discover_aggregate_names()
        type_rewriter = ABITypeRewriter(
            self.unit,
            self.config,
            aggregate_names=aggregate_names,
        )
        return ABIShimAnalysis(
            kept_decls=self.kept_decls,
            structs=self.structs,
            typedef_names=self.typedef_names,
            functions_by_link_name=self.functions_by_link_name,
            callback_typedefs=self.callback_typedefs,
            aggregate_names=aggregate_names,
            direct_callback_adapters=self.discover_direct_callback_adapters(
                aggregate_names,
                type_rewriter,
            ),
            struct_callback_adapters=self.discover_struct_callback_adapters(
                aggregate_names,
                type_rewriter,
            ),
        )

    def discover_aggregate_names(self) -> frozenset[str]:
        names: set[str] = set()
        queue: list[str] = []

        def add_type(typ: Type) -> None:
            name = _struct_value_name(typ)
            if name is not None and name not in names:
                names.add(name)
                queue.append(name)

        def add_function_ptr(fp: FunctionPtr) -> None:
            add_type(fp.ret)
            for param in fp.params:
                add_type(param.type)

        for decl in self.kept_decls:
            for typ in iter_decl_types(decl):
                add_type(typ)
                for fp in _direct_function_ptrs(typ):
                    add_function_ptr(fp)

        while queue:
            name = queue.pop()
            struct = self.structs.get(name)
            if struct is None:
                continue
            for field in struct.fields:
                for fp in _direct_function_ptrs(field.type):
                    add_function_ptr(fp)

        return frozenset(names)

    def discover_direct_callback_adapters(
        self,
        aggregate_names: frozenset[str],
        type_rewriter: "ABITypeRewriter",
    ) -> dict[tuple[str, int], DirectCallbackAdapter]:
        adapters: dict[tuple[str, int], DirectCallbackAdapter] = {}
        for decl in self.kept_decls:
            if not isinstance(decl, Function):
                continue
            for index, param in enumerate(decl.params):
                original_fp = _unwrap(param.type)
                if not isinstance(original_fp, FunctionPtr):
                    continue
                if not self._function_ptr_has_aggregate(original_fp, aggregate_names):
                    continue
                (
                    context_param_index,
                    context_param_index_in_callback,
                ) = self._direct_callback_context_param_indexes(decl, index, original_fp)
                rewritten_fp = type_rewriter.rewrite_function_ptr(original_fp)
                adapters[(decl.link_name, index)] = DirectCallbackAdapter(
                    function_name=decl.link_name,
                    param_index=index,
                    context_param_index=context_param_index,
                    context_param_index_in_callback=context_param_index_in_callback,
                    original_fp=original_fp,
                    rewritten_fp=rewritten_fp,
                    context_param_type=decl.params[context_param_index].type,
                )
        return adapters

    def _direct_callback_context_param_indexes(
        self, fn: Function, callback_index: int, fp: FunctionPtr
    ) -> tuple[int, int]:
        pointer_param_indexes = [
            index for index, param in enumerate(fp.params) if _is_plain_pointer(param.type)
        ]
        if not pointer_param_indexes:
            raise RewriteError(
                f"callback parameter in {fn.link_name} needs aggregate normalization "
                "but has no pointer context parameter"
            )
        if callback_index + 1 >= len(fn.params):
            raise RewriteError(
                f"callback parameter in {fn.link_name} needs aggregate normalization "
                "but has no following context parameter"
            )
        context_param_index = callback_index + 1
        context_param_index_in_callback = pointer_param_indexes[-1]
        callback_context_type = fp.params[context_param_index_in_callback].type
        function_context_type = fn.params[context_param_index].type
        if not (
            _is_plain_pointer(callback_context_type)
            and _is_plain_pointer(function_context_type)
        ):
            raise RewriteError(
                f"callback parameter in {fn.link_name} has unsupported context shape: "
                f"{callback_context_type!r} vs {function_context_type!r}"
            )
        return context_param_index, context_param_index_in_callback

    def discover_struct_callback_adapters(
        self,
        aggregate_names: frozenset[str],
        type_rewriter: "ABITypeRewriter",
    ) -> dict[str, StructCallbackAdapter]:
        adapters: dict[str, StructCallbackAdapter] = {}
        for name in sorted(aggregate_names):
            struct = self.structs.get(name)
            if struct is None:
                continue
            callback_fields = [
                field for field in struct.fields
                if isinstance(_unwrap(field.type), FunctionPtr)
                and self._function_ptr_has_aggregate(_unwrap(field.type), aggregate_names)
            ]
            if not callback_fields:
                continue
            if len(callback_fields) != 1:
                raise RewriteError(
                    f"{name} has multiple aggregate-bearing callback fields; "
                    "provide an explicit adapter"
                )
            context_fields = [
                field for field in struct.fields
                if _is_plain_pointer(field.type)
                and (field.name or "").lower() in {"context", "client_data", "userdata", "user_data"}
            ]
            if len(context_fields) != 1:
                raise RewriteError(
                    f"{name} has an aggregate-bearing callback field but no single context field"
                )
            callback_field = callback_fields[0]
            context_field = context_fields[0]
            original_fp = _unwrap(callback_field.type)
            assert isinstance(original_fp, FunctionPtr)
            context_param_index = self._struct_callback_context_param_index(
                name, context_field.type, original_fp
            )
            adapters[name] = StructCallbackAdapter(
                struct_name=name,
                callback_field=callback_field.name,
                context_field=context_field.name,
                context_param_index=context_param_index,
                original_fp=original_fp,
                rewritten_fp=type_rewriter.rewrite_function_ptr(original_fp),
            )
        return adapters

    def _struct_callback_context_param_index(
        self, struct_name: str, context_field_type: Type, fp: FunctionPtr
    ) -> int:
        matches = [
            index for index, param in enumerate(fp.params)
            if _is_plain_pointer(param.type)
            and _is_plain_pointer(context_field_type)
        ]
        if len(matches) != 1:
            raise RewriteError(
                f"{struct_name} callback has unsupported context parameter shape"
            )
        return matches[0]

    def _function_ptr_has_aggregate(
        self,
        fp: FunctionPtr,
        aggregate_names: frozenset[str],
    ) -> bool:
        return self._type_needs_aggregate_rewrite(fp.ret, aggregate_names) or any(
            self._type_needs_aggregate_rewrite(param.type, aggregate_names)
            for param in fp.params
        )

    def _type_needs_aggregate_rewrite(
        self,
        typ: Type,
        aggregate_names: frozenset[str],
    ) -> bool:
        return _struct_value_name(typ) in aggregate_names


class ABITypeRewriter:
    def __init__(
        self,
        unit: Unit,
        config: ABIShimConfig,
        *,
        aggregate_names: frozenset[str],
    ) -> None:
        self.unit = unit
        self.config = config
        self.aggregate_names = aggregate_names

    def rewrite_decls(self, decls: list[Decl]) -> tuple[list[Decl], list[Function]]:
        rewritten_decls: list[Decl] = []
        functions: list[Function] = []
        for decl in decls:
            if isinstance(decl, Struct):
                rewritten_decls.append(self.rewrite_decl_types(decl))
            elif isinstance(decl, Typedef):
                rewritten_decls.append(self.rewrite_typedef(decl))
            elif isinstance(decl, Function):
                rewritten = self.rewrite_function(decl)
                rewritten_decls.append(rewritten)
                functions.append(rewritten)
            else:
                rewritten_decls.append(self.rewrite_decl_types(decl))
        return rewritten_decls, functions

    def rewrite_decl_types(self, decl: Decl) -> Decl:
        if isinstance(decl, Enum | MacroDecl):
            return decl
        if isinstance(decl, Struct):
            return replace(
                decl,
                fields=[
                    replace(field, type=self.rewrite_type(field.type))
                    for field in decl.fields
                ],
            )
        if isinstance(decl, Const):
            return replace(decl, type=self.rewrite_type(decl.type))
        if isinstance(decl, GlobalVar):
            return replace(decl, type=self.rewrite_type(decl.type))
        return decl

    def rewrite_typedef(self, decl: Typedef) -> Typedef:
        return replace(
            decl,
            aliased=self.rewrite_type(decl.aliased),
            canonical=self.rewrite_type(decl.canonical),
        )

    def rewrite_function(self, decl: Function) -> Function:
        signature = self.rewrite_signature(
            decl.ret,
            decl.params,
            out_template=decl.params[0] if decl.params else _synthetic_param(),
        )
        return replace(
            decl,
            link_name=self.shim_symbol(decl.link_name),
            ret=signature.ret,
            params=signature.params,
        )

    def rewrite_param_type(self, typ: Type) -> Type:
        rewritten = self.rewrite_type(typ)
        if self.aggregate_name(rewritten) is not None:
            return self._ptr_to(rewritten, mut=False)
        return rewritten

    def rewrite_type(self, typ: Type) -> Type:
        if isinstance(typ, QualifiedType):
            return replace(typ, unqualified=self.rewrite_type(typ.unqualified))
        if isinstance(typ, AtomicType):
            return replace(typ, value_type=self.rewrite_type(typ.value_type))
        if isinstance(typ, Pointer):
            pointee = self.rewrite_type(typ.pointee) if typ.pointee is not None else None
            return replace(typ, pointee=pointee)
        if isinstance(typ, Array):
            return replace(typ, element=self.rewrite_type(typ.element))
        if isinstance(typ, FunctionPtr):
            return self.rewrite_function_ptr(typ)
        if isinstance(typ, TypeRef):
            return replace(typ, canonical=self.rewrite_type(typ.canonical))
        return typ

    def rewrite_function_ptr(self, typ: FunctionPtr) -> FunctionPtr:
        signature = self.rewrite_signature(
            typ.ret,
            typ.params,
            out_template=_synthetic_param(),
        )
        return replace(typ, ret=signature.ret, params=signature.params)

    def rewrite_signature(
        self,
        ret: Type,
        params: list[Any],
        *,
        out_template: Any,
    ) -> RewrittenSignature:
        rewritten_params = [
            replace(param, type=self.rewrite_param_type(param.type))
            for param in params
        ]
        rewritten_ret = self.rewrite_type(ret)
        if self.aggregate_name(rewritten_ret) is not None:
            out_param = replace(
                out_template,
                name="out",
                type=self._ptr_to(rewritten_ret, mut=True),
                doc=None,
            )
            return RewrittenSignature(
                ret=VoidType(),
                params=[out_param, *rewritten_params],
            )
        return RewrittenSignature(
            ret=rewritten_ret,
            params=rewritten_params,
        )

    def aggregate_name(self, typ: Type) -> str | None:
        name = _struct_value_name(typ)
        if name in self.aggregate_names:
            return name
        return None

    def shim_symbol(self, link_name: str) -> str:
        return self.config.shim_symbol_prefix + link_name

    def _ptr_to(self, typ: Type, *, mut: bool) -> Pointer:
        return Pointer(
            pointee=typ,
            size_bytes=self.unit.target_abi.pointer_size_bytes,
            align_bytes=self.unit.target_abi.pointer_align_bytes,
            mutability=PointerMutability.MUT if mut else PointerMutability.IMMUT,
            origin=PointerOrigin.EXTERNAL,
            nullable=True,
        )


class CDeclRenderer:
    def __init__(self, typedef_names: set[str]) -> None:
        self.typedef_names = typedef_names

    def c_function_decl(self, fn: Function) -> str:
        params = ", ".join(
            self.c_param_decl(param.type, param.name or f"arg{i}")
            for i, param in enumerate(fn.params)
        )
        if not params:
            params = "void"
        return f"{self.c_type(fn.ret)} {fn.link_name}({params})"

    def c_function_pointer(self, fp: FunctionPtr, name: str) -> str:
        params = ", ".join(
            self.c_param_decl(param.type, param.name or f"arg{i}")
            for i, param in enumerate(fp.params)
        )
        if not params:
            params = "void"
        return f"{self.c_type(fp.ret)} (*{name})({params})"

    def c_param_decl(self, typ: Type, name: str) -> str:
        typ_unwrapped = _unwrap(typ)
        if isinstance(typ_unwrapped, FunctionPtr):
            return self.c_function_pointer(typ_unwrapped, name)
        return f"{self.c_type(typ)} {name}"

    def c_type(self, typ: Type) -> str:
        if isinstance(typ, QualifiedType):
            base = self.c_type(typ.unqualified)
            return f"const {base}" if typ.qualifiers.is_const else base
        if isinstance(typ, TypeRef):
            canonical = _unwrap(typ.canonical)
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
            base = "void" if typ.pointee is None else self.c_type(typ.pointee)
            const = (
                "const "
                if typ.mutability == PointerMutability.IMMUT
                and typ.pointee is not None
                and not base.startswith("const ")
                else ""
            )
            return f"{const}{base} *"
        if isinstance(typ, Array):
            return f"{self.c_type(typ.element)} *"
        if isinstance(typ, FunctionPtr):
            return self.c_function_pointer(typ, "")
        if isinstance(typ, StructRef):
            if typ.c_name in self.typedef_names:
                return typ.c_name
            return f"struct {typ.c_name}"
        if isinstance(typ, EnumRef):
            return f"enum {typ.c_name}"
        if isinstance(typ, OpaqueRecordRef):
            return typ.c_name
        raise RewriteError(f"unsupported C type in shim: {typ!r}")

    def c_record_type(self, name: str) -> str:
        if name in self.typedef_names:
            return name
        return f"struct {name}"

    @staticmethod
    def _c_int_type(typ: IntType) -> str:
        try:
            return _C_INT_TYPE_SPELLINGS[typ.int_kind]
        except KeyError as exc:
            raise RewriteError(f"unsupported integer kind in shim: {typ.int_kind}") from exc

    @staticmethod
    def _c_float_type(typ: FloatType) -> str:
        try:
            return _C_FLOAT_TYPE_SPELLINGS[typ.float_kind]
        except KeyError as exc:
            raise RewriteError(f"unsupported float kind in shim: {typ.float_kind}") from exc


class ABIShimRenderer:
    def __init__(
        self,
        unit: Unit,
        config: ABIShimConfig,
        analysis: ABIShimAnalysis,
        type_rewriter: ABITypeRewriter,
        c_decl: CDeclRenderer,
    ) -> None:
        self.unit = unit
        self.config = config
        self.analysis = analysis
        self.type_rewriter = type_rewriter
        self.c_decl = c_decl

    def render_header(self, functions: list[Function]) -> str:
        lines = [
            f"/* Generated by {self.config.generated_by} - do not edit by hand. */",
            "#pragma once",
            "",
        ]
        lines.extend(f"#include {include}" for include in self.config.header_includes)
        lines.extend(
            [
                "",
                "#if defined(_WIN32)",
                f"#define {self.config.export_macro} __declspec(dllexport)",
                "#else",
                f"#define {self.config.export_macro} __attribute__((visibility(\"default\")))",
                "#endif",
                "",
            ]
        )
        for alias, fp in sorted(self.analysis.callback_typedefs.items()):
            if self._function_ptr_has_aggregate(fp):
                lines.append(
                    f"typedef {self.c_decl.c_function_pointer(self.type_rewriter.rewrite_function_ptr(fp), 'mojo_' + alias)};"
                )
        lines.append("")
        for fn in functions:
            lines.append(f"{self.config.export_macro} {self.c_decl.c_function_decl(fn)};")
        lines.append("")
        return "\n".join(lines)

    def render_source(self, functions: list[Function]) -> str:
        lines = [
            f"/* Generated by {self.config.generated_by} - do not edit by hand. */",
            f'#include "{self.config.shim_library}.h"',
            "#include <stdio.h>",
            "#include <stdlib.h>",
            "",
            "#if defined(_WIN32)",
            "#include <windows.h>",
            "#else",
            "#include <dlfcn.h>",
            "#endif",
            "",
            f"#ifndef {self.config.runtime_path_macro}",
            f'#define {self.config.runtime_path_macro} ""',
            "#endif",
            "",
        ]
        lines.extend(self._render_symbol_resolvers(functions))
        lines.extend(self._render_direct_callback_trampolines())
        lines.extend(self._render_struct_callback_trampolines())
        for fn in functions:
            lines.extend(self.render_function_body(fn))
            lines.append("")
        return "\n".join(lines)

    def _render_symbol_resolvers(self, functions: list[Function]) -> list[str]:
        return [
            *self._render_windows_runtime_loader(),
            *self._render_posix_runtime_loader(),
            *self._render_find_symbol(),
            *self._render_require_symbol(),
            *self._render_function_resolvers(functions),
        ]

    def _runtime_handle_name(self) -> str:
        return f"mojo_{self.config.runtime_symbol_subject}_handle"

    def _runtime_find_symbol_name(self) -> str:
        return f"mojo_find_{self.config.runtime_symbol_subject}_symbol"

    def _runtime_require_symbol_name(self) -> str:
        return f"mojo_require_{self.config.runtime_symbol_subject}_symbol"

    def _render_windows_runtime_loader(self) -> list[str]:
        subject = self.config.runtime_symbol_subject
        handle_name = self._runtime_handle_name()
        lines = [
            "#if defined(_WIN32)",
            f"static HMODULE {handle_name}(void) {{",
            f"    static HMODULE {subject}_module = NULL;",
            "    static int initialized = 0;",
            "    if (!initialized) {",
            f"        if ({self.config.runtime_path_macro}[0] != '\\0') {{",
            f"            {subject}_module = LoadLibraryA({self.config.runtime_path_macro});",
            "        }",
        ]
        for library_name in self.config.windows_runtime_library_names:
            lines.extend(
                [
                    f"        if ({subject}_module == NULL) {{",
                    f'            {subject}_module = GetModuleHandleA("{library_name}");',
                    "        }",
                    f"        if ({subject}_module == NULL) {{",
                    f'            {subject}_module = LoadLibraryA("{library_name}");',
                    "        }",
                ]
            )
        lines.extend(
            [
                "        initialized = 1;",
                "    }",
                f"    return {subject}_module;",
                "}",
            ]
        )
        return lines

    def _render_posix_runtime_loader(self) -> list[str]:
        subject = self.config.runtime_symbol_subject
        handle_name = self._runtime_handle_name()
        lines = [
            "#else",
            f"static void *{handle_name}(void) {{",
            f"    static void *{subject}_handle = NULL;",
            "    static int initialized = 0;",
            "    if (!initialized) {",
            f"        if ({self.config.runtime_path_macro}[0] != '\\0') {{",
            f"            {subject}_handle = dlopen({self.config.runtime_path_macro}, RTLD_LAZY | RTLD_LOCAL);",
            "        }",
        ]
        for library_name in self.config.posix_runtime_library_names:
            lines.extend(
                [
                    f"        if ({subject}_handle == NULL) {{",
                    f'            {subject}_handle = dlopen("{library_name}", RTLD_LAZY | RTLD_LOCAL);',
                    "        }",
                ]
            )
        lines.extend(
            [
                "        initialized = 1;",
                "    }",
                f"    return {subject}_handle;",
                "}",
                "#endif",
                "",
            ]
        )
        return lines

    def _render_find_symbol(self) -> list[str]:
        subject = self.config.runtime_symbol_subject
        handle_name = self._runtime_handle_name()
        find_name = self._runtime_find_symbol_name()
        return [
            f"static void *{find_name}(const char *name) {{",
            "#if defined(_WIN32)",
            f"    HMODULE {subject}_module = {handle_name}();",
            f"    if ({subject}_module == NULL) {{",
            "        return NULL;",
            "    }",
            f"    return (void *)GetProcAddress({subject}_module, name);",
            "#else",
            f"    void *{subject}_handle = {handle_name}();",
            f"    if ({subject}_handle == NULL) {{",
            "        return NULL;",
            "    }",
            f"    return dlsym({subject}_handle, name);",
            "#endif",
            "}",
            "",
        ]

    def _render_require_symbol(self) -> list[str]:
        subject = self.config.runtime_symbol_subject
        find_name = self._runtime_find_symbol_name()
        require_name = self._runtime_require_symbol_name()
        return [
            f"static void *{require_name}(const char *name) {{",
            f"    void *symbol = {find_name}(name);",
            "    if (symbol == NULL) {",
            f'        fprintf(stderr, "{subject} symbol not available at runtime: %s\\n", name);',
            "        abort();",
            "    }",
            "    return symbol;",
            "}",
            "",
        ]

    def _render_function_resolvers(self, functions: list[Function]) -> list[str]:
        require_name = self._runtime_require_symbol_name()
        lines: list[str] = []
        emitted: set[str] = set()
        for fn in functions:
            original = fn.link_name.removeprefix(self.config.shim_symbol_prefix)
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
                    f"typedef {self.c_decl.c_function_pointer(fn_ptr, typedef_name)};",
                    f"static {typedef_name} {resolver_name}(void) {{",
                    f"    static {typedef_name} fn = NULL;",
                    "    static int initialized = 0;",
                    "    if (!initialized) {",
                    f"        fn = ({typedef_name}){require_name}(\"{original}\");",
                    "        initialized = 1;",
                    "    }",
                    "    return fn;",
                    "}",
                    "",
                ]
            )
        return lines

    def _render_direct_callback_trampolines(self) -> list[str]:
        lines: list[str] = []
        for adapter in self.analysis.direct_callback_adapters.values():
            context_type = self._direct_callback_context_type(adapter)
            trampoline = self._direct_callback_trampoline_name(adapter)
            lines.extend(
                [
                    f"typedef struct {context_type} {{",
                    f"    {self.c_decl.c_function_pointer(adapter.rewritten_fp, 'fn')};",
                    f"    {self.c_decl.c_type(adapter.context_param_type)} client_data;",
                    f"}} {context_type};",
                    "",
                ]
            )
            lines.extend(
                self._render_callback_trampoline_body(
                    trampoline,
                    context_type,
                    "ctx->fn",
                    "ctx->client_data",
                    adapter.context_param_index_in_callback,
                    adapter.original_fp,
                )
            )
        return lines

    def _render_struct_callback_trampolines(self) -> list[str]:
        lines: list[str] = []
        for adapter in self.analysis.struct_callback_adapters.values():
            context_type = self._struct_callback_context_type(adapter)
            trampoline = self._struct_callback_trampoline_name(adapter)
            struct_type = self.c_decl.c_record_type(adapter.struct_name)
            lines.extend(
                [
                    f"typedef struct {context_type} {{",
                    f"    const {struct_type} *value;",
                    f"}} {context_type};",
                    "",
                ]
            )
            lines.extend(
                self._render_callback_trampoline_body(
                    trampoline,
                    context_type,
                    (
                        f"(({self.c_decl.c_function_pointer(adapter.rewritten_fp, '')})"
                        f"ctx->value->{adapter.callback_field})"
                    ),
                    f"ctx->value->{adapter.context_field}",
                    adapter.context_param_index,
                    adapter.original_fp,
                )
            )
        return lines

    def _render_callback_trampoline_body(
        self,
        trampoline: str,
        context_type: str,
        fn_expr: str,
        client_data_expr: str,
        context_param_index: int,
        original_fp: FunctionPtr,
    ) -> list[str]:
        ret = self.c_decl.c_type(original_fp.ret)
        params = ", ".join(
            f"{self.c_decl.c_type(param.type)} arg{i}" for i, param in enumerate(original_fp.params)
        )
        lines = [
            f"static {ret} {trampoline}({params}) {{",
            f"    {context_type} *ctx = ({context_type} *)arg{context_param_index};",
        ]
        call_args: list[str] = []
        for i, param in enumerate(original_fp.params):
            if i == context_param_index:
                call_args.append(client_data_expr)
            elif self.type_rewriter.aggregate_name(param.type) is not None:
                call_args.append(f"&arg{i}")
            else:
                call_args.append(f"arg{i}")
        ret_is_aggregate = self.type_rewriter.aggregate_name(original_fp.ret) is not None
        if ret_is_aggregate:
            call_args = ["&result", *call_args]
        call = f"{fn_expr}({', '.join(call_args)})"
        if isinstance(_unwrap(original_fp.ret), VoidType):
            lines.append(f"    {call};")
        elif ret_is_aggregate:
            lines.extend(
                [
                    f"    {ret} result;",
                    f"    {call};",
                    "    return result;",
                ]
            )
        else:
            lines.append(f"    return {call};")
        lines.extend(["}", ""])
        return lines

    def render_function_body(self, fn: Function) -> list[str]:
        original = fn.link_name.removeprefix(self.config.shim_symbol_prefix)
        original_fn = self._find_original_function(original)
        if original_fn is None:
            raise RewriteError(f"could not find original function for {original}")
        decl = self.c_decl.c_function_decl(fn)
        lines = [f"{self.config.export_macro} {decl} {{"]
        lines.append(f"    {self._resolver_typedef_name(original)} target = {self._resolver_func_name(original)}();")
        call_args: list[str] = []
        out_name: str | None = None

        rewritten_offset = 0
        if self.type_rewriter.aggregate_name(original_fn.ret) is not None:
            out_name = fn.params[0].name or "out"
            rewritten_offset = 1

        direct_context_args: dict[int, str] = {}
        for i, original_param in enumerate(original_fn.params):
            adapter = self.analysis.direct_callback_adapters.get((original, i))
            if adapter is None:
                continue
            rewritten_param = fn.params[i + rewritten_offset]
            pname = rewritten_param.name or f"arg{i + rewritten_offset}"
            context_param = fn.params[adapter.context_param_index + rewritten_offset]
            context_name = context_param.name or f"arg{adapter.context_param_index + rewritten_offset}"
            local_name = f"{pname}_ctx"
            lines.append(
                f"    {self._direct_callback_context_type(adapter)} {local_name} = "
                f"{{ .fn = {pname}, .client_data = {context_name} }};"
            )
            direct_context_args[adapter.context_param_index] = f"&{local_name}"

        for i, original_param in enumerate(original_fn.params):
            rewritten_param = fn.params[i + rewritten_offset]
            pname = rewritten_param.name or f"arg{i + rewritten_offset}"
            original_type = original_param.type
            original_unwrapped = _unwrap(original_type)
            adapter = self.analysis.direct_callback_adapters.get((original, i))
            if adapter is not None:
                call_args.append(self._direct_callback_trampoline_name(adapter))
            elif i in direct_context_args:
                call_args.append(direct_context_args[i])
            elif isinstance(original_unwrapped, FunctionPtr):
                call_args.append(pname)
            elif self.type_rewriter.aggregate_name(original_type) in self.analysis.struct_callback_adapters:
                call_args.append(self._adapt_struct_callback_arg(pname, original_type, lines))
            elif self.type_rewriter.aggregate_name(original_type) is not None:
                call_args.append(f"*{pname}")
            else:
                call_args.append(pname)

        call = f"target({', '.join(call_args)})"
        if out_name is not None:
            lines.append(f"    *{out_name} = {call};")
        elif isinstance(_unwrap(fn.ret), VoidType):
            lines.append(f"    {call};")
        else:
            lines.append(f"    return {call};")
        lines.append("}")
        return lines

    def _adapt_struct_callback_arg(self, name: str, typ: Type, lines: list[str]) -> str:
        aggregate_name = self.type_rewriter.aggregate_name(typ)
        if aggregate_name is None:
            raise RewriteError(f"{name} is not an aggregate callback struct")
        adapter = self.analysis.struct_callback_adapters[aggregate_name]
        struct = self.analysis.structs[aggregate_name]
        context_name = f"{name}_ctx"
        adapted_name = f"{name}_adapter"
        lines.append(
            f"    {self._struct_callback_context_type(adapter)} {context_name} = "
            f"{{ .value = {name} }};"
        )
        lines.append(f"    {self.c_decl.c_type(typ)} {adapted_name} = {{")
        for field in struct.fields:
            if field.name == adapter.context_field:
                value = f"&{context_name}"
            elif field.name == adapter.callback_field:
                value = self._struct_callback_trampoline_name(adapter)
            else:
                value = f"{name}->{field.name}"
            lines.append(f"        .{field.name} = {value},")
        lines.append("    };")
        return adapted_name

    @staticmethod
    def _resolver_typedef_name(link_name: str) -> str:
        return f"mojo_fn_{link_name}"

    @staticmethod
    def _resolver_func_name(link_name: str) -> str:
        return f"mojo_load_{link_name}"

    @staticmethod
    def _safe_name(name: str) -> str:
        return _safe_name(name)

    def _direct_callback_context_type(self, adapter: DirectCallbackAdapter) -> str:
        return (
            "MojoCallbackContext_"
            + self._safe_name(adapter.function_name)
            + "_"
            + str(adapter.param_index)
        )

    def _direct_callback_trampoline_name(self, adapter: DirectCallbackAdapter) -> str:
        return (
            "mojo_callback_trampoline_"
            + self._safe_name(adapter.function_name)
            + "_"
            + str(adapter.param_index)
        )

    def _struct_callback_context_type(self, adapter: StructCallbackAdapter) -> str:
        return "MojoStructCallbackContext_" + self._safe_name(adapter.struct_name)

    def _struct_callback_trampoline_name(self, adapter: StructCallbackAdapter) -> str:
        return "mojo_struct_callback_trampoline_" + self._safe_name(adapter.struct_name)

    def _find_original_function(self, link_name: str) -> Function | None:
        return self.analysis.functions_by_link_name.get(link_name)

    def _function_ptr_has_aggregate(self, fp: FunctionPtr) -> bool:
        return self.type_rewriter.aggregate_name(fp.ret) is not None or any(
            self.type_rewriter.aggregate_name(param.type) is not None
            for param in fp.params
        )


class ABIShimRewriter:
    def __init__(self, unit: Unit, config: ABIShimConfig) -> None:
        self.unit = unit
        self.config = config

    def rewrite(self) -> RewrittenUnit:
        analysis = ABIShimAnalyzer(self.unit, self.config).analyze()
        type_rewriter = ABITypeRewriter(
            self.unit,
            self.config,
            aggregate_names=analysis.aggregate_names,
        )
        decls, functions = type_rewriter.rewrite_decls(analysis.kept_decls)
        unit = replace(
            self.unit,
            library=self.config.shim_library,
            link_name=self.config.shim_link_name,
            decls=decls,
        )
        c_decl = CDeclRenderer(analysis.typedef_names)
        renderer = ABIShimRenderer(
            self.unit,
            self.config,
            analysis,
            type_rewriter,
            c_decl,
        )
        return RewrittenUnit(
            unit=unit,
            header_text=renderer.render_header(functions),
            source_text=renderer.render_source(functions),
        )


def _synthetic_param() -> Any:
    from mojo_bindgen.ir import Param

    return Param(name="out", type=VoidType())

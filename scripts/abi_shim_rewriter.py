"""Generic CIR-to-C ABI shim normalizer for Mojo bindgen output."""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, replace
from typing import Any

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


class RewrittenUnit:
    def __init__(self, unit: Unit, header_text: str, source_text: str) -> None:
        self.unit = unit
        self.header_text = header_text
        self.source_text = source_text


def _keep_all(_: Decl) -> bool:
    return True


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


class ABIShimRewriter:
    def __init__(self, unit: Unit, config: ABIShimConfig) -> None:
        self.unit = unit
        self.config = config
        self.structs = {decl.name: decl for decl in unit.decls if isinstance(decl, Struct)}
        self.typedef_names = {decl.name for decl in unit.decls if isinstance(decl, Typedef)}
        self.callback_typedefs: dict[str, FunctionPtr] = {}
        for decl in unit.decls:
            if isinstance(decl, Typedef):
                unwrapped = self._unwrap(decl.canonical)
                if isinstance(unwrapped, FunctionPtr):
                    self.callback_typedefs[decl.name] = unwrapped

        self.kept_decls = [decl for decl in unit.decls if self.config.keep_decl(decl)]
        self.aggregate_names = self._discover_aggregate_names()
        self.struct_callback_adapters = self._discover_struct_callback_adapters()
        self.direct_callback_adapters = self._discover_direct_callback_adapters()

    def rewrite(self) -> RewrittenUnit:
        decls: list[Decl] = []
        functions: list[Function] = []
        for decl in self.kept_decls:
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
            library=self.config.shim_library,
            link_name=self.config.shim_link_name,
            decls=decls,
        )
        header = self._render_header(functions)
        source = self._render_source(functions)
        return RewrittenUnit(unit, header, source)

    def _discover_aggregate_names(self) -> frozenset[str]:
        names: set[str] = set()
        changed = True
        while changed:
            changed = False
            for decl in self.kept_decls:
                before = len(names)
                if isinstance(decl, Function):
                    self._collect_value_struct_names(decl.ret, names)
                    for param in decl.params:
                        self._collect_value_struct_names(param.type, names)
                        unwrapped = self._unwrap(param.type)
                        if isinstance(unwrapped, FunctionPtr):
                            self._collect_function_ptr_value_struct_names(unwrapped, names)
                elif isinstance(decl, Typedef):
                    unwrapped = self._unwrap(decl.canonical)
                    if isinstance(unwrapped, FunctionPtr):
                        self._collect_function_ptr_value_struct_names(unwrapped, names)

                for name in tuple(names):
                    struct = self.structs.get(name)
                    if struct is None:
                        continue
                    for field in struct.fields:
                        unwrapped = self._unwrap(field.type)
                        if isinstance(unwrapped, FunctionPtr):
                            self._collect_function_ptr_value_struct_names(unwrapped, names)

                changed = changed or len(names) != before
        return frozenset(names)

    def _collect_value_struct_names(self, typ: Type, names: set[str]) -> None:
        name = self._struct_value_name(typ)
        if name is not None:
            names.add(name)

    def _collect_function_ptr_value_struct_names(self, fp: FunctionPtr, names: set[str]) -> None:
        self._collect_value_struct_names(fp.ret, names)
        for param in fp.params:
            self._collect_value_struct_names(param.type, names)

    def _discover_direct_callback_adapters(self) -> dict[tuple[str, int], DirectCallbackAdapter]:
        adapters: dict[tuple[str, int], DirectCallbackAdapter] = {}
        for decl in self.kept_decls:
            if not isinstance(decl, Function):
                continue
            for index, param in enumerate(decl.params):
                original_fp = self._unwrap(param.type)
                if not isinstance(original_fp, FunctionPtr):
                    continue
                if not self._function_ptr_has_aggregate(original_fp):
                    continue
                (
                    context_param_index,
                    context_param_index_in_callback,
                ) = self._direct_callback_context_param_indexes(decl, index, original_fp)
                rewritten_fp = self._rewrite_function_ptr(original_fp)
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
            index for index, param in enumerate(fp.params) if self._is_plain_pointer(param.type)
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
            self._is_plain_pointer(callback_context_type)
            and self._is_plain_pointer(function_context_type)
        ):
            raise RewriteError(
                f"callback parameter in {fn.link_name} has unsupported context shape: "
                f"{self._c_type(callback_context_type)} vs {self._c_type(function_context_type)}"
            )
        return context_param_index, context_param_index_in_callback

    def _discover_struct_callback_adapters(self) -> dict[str, StructCallbackAdapter]:
        adapters: dict[str, StructCallbackAdapter] = {}
        for name in sorted(self.aggregate_names):
            struct = self.structs.get(name)
            if struct is None:
                continue
            callback_fields = [
                field for field in struct.fields
                if isinstance(self._unwrap(field.type), FunctionPtr)
                and self._function_ptr_has_aggregate(self._unwrap(field.type))
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
                if self._is_plain_pointer(field.type)
                and (field.name or "").lower() in {"context", "client_data", "userdata", "user_data"}
            ]
            if len(context_fields) != 1:
                raise RewriteError(
                    f"{name} has an aggregate-bearing callback field but no single context field"
                )
            callback_field = callback_fields[0]
            context_field = context_fields[0]
            original_fp = self._unwrap(callback_field.type)
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
                rewritten_fp=self._rewrite_function_ptr(original_fp),
            )
        return adapters

    def _struct_callback_context_param_index(
        self, struct_name: str, context_field_type: Type, fp: FunctionPtr
    ) -> int:
        matches = [
            index for index, param in enumerate(fp.params)
            if self._is_plain_pointer(param.type)
            and self._is_plain_pointer(context_field_type)
        ]
        if len(matches) != 1:
            raise RewriteError(
                f"{struct_name} callback has unsupported context parameter shape"
            )
        return matches[0]

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
        if self._aggregate_name(ret) is not None:
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
        if self._aggregate_name(ret) is not None:
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

    def _struct_value_name(self, typ: Type) -> str | None:
        typ = self._unwrap(typ)
        if isinstance(typ, StructRef):
            return typ.name
        return None

    def _aggregate_name(self, typ: Type) -> str | None:
        name = self._struct_value_name(typ)
        if name in self.aggregate_names:
            return name
        return None

    def _is_plain_pointer(self, typ: Type) -> bool:
        return isinstance(self._unwrap(typ), Pointer)

    def _shim_symbol(self, link_name: str) -> str:
        return self.config.shim_symbol_prefix + link_name

    def _render_header(self, functions: list[Function]) -> str:
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
        for alias, fp in sorted(self.callback_typedefs.items()):
            if self._function_ptr_has_aggregate(fp):
                lines.append(
                    f"typedef {self._c_function_pointer(self._rewrite_function_ptr(fp), 'mojo_' + alias)};"
                )
        lines.append("")
        for fn in functions:
            lines.append(f"{self.config.export_macro} {self._c_function_decl(fn)};")
        lines.append("")
        return "\n".join(lines)

    def _render_source(self, functions: list[Function]) -> str:
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
            lines.extend(self._render_function_body(fn))
            lines.append("")
        return "\n".join(lines)

    def _render_symbol_resolvers(self, functions: list[Function]) -> list[str]:
        subject = self.config.runtime_symbol_subject
        handle_name = f"mojo_{subject}_handle"
        find_name = f"mojo_find_{subject}_symbol"
        require_name = f"mojo_require_{subject}_symbol"
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
                "#else",
                f"static void *{handle_name}(void) {{",
                f"    static void *{subject}_handle = NULL;",
                "    static int initialized = 0;",
                "    if (!initialized) {",
                f"        if ({self.config.runtime_path_macro}[0] != '\\0') {{",
                f"            {subject}_handle = dlopen({self.config.runtime_path_macro}, RTLD_LAZY | RTLD_LOCAL);",
                "        }",
            ]
        )
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
        )
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
                    f"typedef {self._c_function_pointer(fn_ptr, typedef_name)};",
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
        for adapter in self.direct_callback_adapters.values():
            context_type = self._direct_callback_context_type(adapter)
            trampoline = self._direct_callback_trampoline_name(adapter)
            lines.extend(
                [
                    f"typedef struct {context_type} {{",
                    f"    {self._c_function_pointer(adapter.rewritten_fp, 'fn')};",
                    f"    {self._c_type(adapter.context_param_type)} client_data;",
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
        for adapter in self.struct_callback_adapters.values():
            context_type = self._struct_callback_context_type(adapter)
            trampoline = self._struct_callback_trampoline_name(adapter)
            struct_type = self._c_record_type(adapter.struct_name)
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
                        f"(({self._c_function_pointer(adapter.rewritten_fp, '')})"
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
        ret = self._c_type(original_fp.ret)
        params = ", ".join(
            f"{self._c_type(param.type)} arg{i}" for i, param in enumerate(original_fp.params)
        )
        lines = [
            f"static {ret} {trampoline}({params}) {{",
            f"    {context_type} *ctx = ({context_type} *)arg{context_param_index};",
        ]
        call_args: list[str] = []
        for i, param in enumerate(original_fp.params):
            if i == context_param_index:
                call_args.append(client_data_expr)
            elif self._aggregate_name(param.type) is not None:
                call_args.append(f"&arg{i}")
            else:
                call_args.append(f"arg{i}")
        call = f"{fn_expr}({', '.join(call_args)})"
        if isinstance(self._unwrap(original_fp.ret), VoidType):
            lines.append(f"    {call};")
        else:
            lines.append(f"    return {call};")
        lines.extend(["}", ""])
        return lines

    def _render_function_body(self, fn: Function) -> list[str]:
        original = fn.link_name.removeprefix(self.config.shim_symbol_prefix)
        original_fn = self._find_original_function(original)
        if original_fn is None:
            raise RewriteError(f"could not find original function for {original}")
        decl = self._c_function_decl(fn)
        lines = [f"{self.config.export_macro} {decl} {{"]
        lines.append(f"    {self._resolver_typedef_name(original)} target = {self._resolver_func_name(original)}();")
        call_args: list[str] = []
        out_name: str | None = None

        rewritten_offset = 0
        if self._aggregate_name(original_fn.ret) is not None:
            out_name = fn.params[0].name or "out"
            rewritten_offset = 1

        direct_context_args: dict[int, str] = {}
        for i, original_param in enumerate(original_fn.params):
            adapter = self.direct_callback_adapters.get((original, i))
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
            original_unwrapped = self._unwrap(original_type)
            adapter = self.direct_callback_adapters.get((original, i))
            if adapter is not None:
                call_args.append(self._direct_callback_trampoline_name(adapter))
            elif i in direct_context_args:
                call_args.append(direct_context_args[i])
            elif isinstance(original_unwrapped, FunctionPtr):
                call_args.append(pname)
            elif self._aggregate_name(original_type) in self.struct_callback_adapters:
                call_args.append(self._adapt_struct_callback_arg(pname, original_type, lines))
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

    def _adapt_struct_callback_arg(self, name: str, typ: Type, lines: list[str]) -> str:
        aggregate_name = self._aggregate_name(typ)
        if aggregate_name is None:
            raise RewriteError(f"{name} is not an aggregate callback struct")
        adapter = self.struct_callback_adapters[aggregate_name]
        struct = self.structs[aggregate_name]
        context_name = f"{name}_ctx"
        adapted_name = f"{name}_adapter"
        lines.append(
            f"    {self._struct_callback_context_type(adapter)} {context_name} = "
            f"{{ .value = {name} }};"
        )
        lines.append(f"    {self._c_type(typ)} {adapted_name} = {{")
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
        return "".join(ch if ch.isalnum() else "_" for ch in name)

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
        for decl in self.unit.decls:
            if isinstance(decl, Function) and decl.link_name == link_name:
                return decl
        return None

    def _function_ptr_has_aggregate(self, fp: FunctionPtr) -> bool:
        if self._aggregate_name(fp.ret) is not None or self._struct_value_name(fp.ret) in self.aggregate_names:
            return True
        return any(
            self._aggregate_name(param.type) is not None
            or self._struct_value_name(param.type) in self.aggregate_names
            for param in fp.params
        )

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

    def _c_record_type(self, name: str) -> str:
        if name in self.typedef_names:
            return name
        return f"struct {name}"

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


def _synthetic_param() -> Any:
    from mojo_bindgen.ir import Param

    return Param(name="out", type=VoidType())

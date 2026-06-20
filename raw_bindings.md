# Raw libclang Mojo Bindings Notes

This repository now generates the raw libclang FFI as a normalized low-level
Mojo module, `clang/_ffi.mojo`, plus a matching C ABI normalization shim. The
generator is deterministic and is run through Pixi:

```bash
rtk pixi run generate
```

The important change is that `mojo-bindgen` is now treated as a library
component inside `scripts/generate_libclang_bindings.py`, not as a code
emitter whose output is hand-patched after the fact. The generator consumes the
bindgen CIR, passes it through the reusable ABI shim rewriter in
`scripts/abi_shim_rewriter.py`, emits the raw Mojo FFI, emits the C shim, and
builds layout tests as part of the same pipeline.

## Why This Exists

libclang exposes a lot of C ABI surface through aggregates:

- value returns such as `CXCursor`, `CXType`, `CXSourceLocation`, and
  `CXSourceRange`
- value parameters in APIs like cursor/type inspectors
- callback signatures that pass those aggregates through `CXCursorVisitor`,
  `CXFieldVisitor`, `CXInclusionVisitor`, `CXCursorAndRangeVisitor`, and the
  indexing callback tables

Mojo FFI is not a safe place to expose those signatures directly. The problem
is not just a missing convenience wrapper. The raw boundary itself is the
wrong abstraction because value-return and value-parameter lowering can diverge
from C ABI expectations once aggregates get large or contain layouts that Mojo
does not lower the same way as C.

The repo uses a C shim because that gives one stable rule:

- every aggregate is passed by pointer
- every aggregate return is written to an out-parameter
- callbacks are normalized through a trampoline that only speaks the pointer
  form

That is the boundary the higher-level API can rely on.

## Generation Pipeline

`scripts/generate_libclang_bindings.py` now does the whole job:

1. Parse the libclang headers through `mojo-bindgen`.
2. Run the CIR normalization and analysis passes.
3. Rewrite the CIR so discovered aggregate-by-value signatures are normalized
   into a pointer or out-parameter form.
4. Emit the raw Mojo FFI to `clang/_ffi.mojo`.
5. Emit the C shim header and implementation to
   `shim/libclang_mojo_shim.h` and `shim/libclang_mojo_shim.c`.
6. Build the shim shared library at `shim/libclang_mojo_shim.so`.
7. Build the generated layout test module at `test/_ffi_layout_tests.mojo`.

The generated FFI layout tests are part of the generator, not a separate
hand-maintained fixture. The verification binary is built in a temporary
directory, not under the repo.

The ABI rewrite logic is split into two layers:

- `scripts/abi_shim_rewriter.py` contains the generic CIR scan, aggregate
  discovery, pointer/out-parameter signature rewrite, C type rendering, dynamic
  symbol resolver emission, and callback trampoline generation.
- `scripts/generate_libclang_bindings.py` keeps libclang-specific policy:
  clang-c header discovery, declaration filtering, include lists, libclang
  runtime lookup, shim compilation, shim installation, and layout-test
  orchestration.

The generic rewriter discovers aggregates from the selected API surface instead
of using a libclang-only allowlist. Any struct that crosses a kept function or
callback boundary by value is normalized. This includes `CXTUResourceUsage`,
whose raw functions now use the same out-parameter/pointer pattern as the other
aggregate handles.

By default the generator now parses the `clang-c` headers installed in the
active Pixi environment, falling back to `.pixi/envs/default/include/clang-c`
when `CONDA_PREFIX` is not set. That keeps generation tied to the repo's pinned
`clangdev` package instead of whichever LLVM headers happen to be installed on
the host. Set `LIBCLANG_HEADERS_DIR` only when you intentionally want to
override the Pixi-provided headers.

## Header/Runtime Version Matching

The Pixi environment pins both `clangdev` and `libclang` to the 18.x line so
the parsed headers and linked runtime come from the same LLVM release family.

Refresh the local Pixi environment with:

```bash
rtk pixi install
```

The default generate path uses the installed Pixi headers and library directly,
without saving intermediate IR files:

```bash
rtk pixi run generate
```

## Generated Surface

The low-level module keeps the layout that `mojo-bindgen` discovers for the raw
C records. That means the generated Mojo still uses `InlineArray` for C array
members instead of flattening them into synthetic fields. That choice matters:

- it preserves the C record shape in the low-level layer
- it lets higher-level wrappers store the raw aggregate in a 1-element
  `InlineArray`
- it avoids inventing a fake layout just to work around the generator

The low-level module is the only place that should care about these raw record
details. Higher-level code should wrap them, not duplicate them.

## What The Shim Guarantees

The shim takes the libclang API and makes it boring:

```c
void mojo_clang_getNullLocation(CXSourceLocation *out);
void mojo_clang_getCursorType(CXCursor cursor, CXType *out);
void mojo_clang_visitChildren(CXCursor cursor, CXCursorVisitor visitor,
                              CXClientData client_data, unsigned *out);
```

The exact function names and coverage are generated, but the rule is fixed.
Anything that would otherwise rely on a by-value aggregate crossing the Mojo
FFI boundary is rewritten into pointer-based storage or an out-parameter.

That includes:

- aggregate returns
- aggregate parameters
- callback trampolines
- callback-bearing structs with a single context pointer and aggregate-bearing
  function pointer field
- helper surfaces for location, range, cursor, type, and token workflows

## How Higher-Level API Code Should Be Written

Higher-level wrappers should be written on top of `clang/_ffi.mojo`, not on top of
raw libclang signatures and not on top of ad hoc manual patches.

Use this pattern:

- keep the raw aggregate in caller-owned storage, usually
  `InlineArray[AggregateType, 1]`
- add a private `_ptr()` helper that rebinds that storage to the pointer type
  expected by the raw FFI
- initialize the storage with the zero/null aggregate form the generated FFI
  expects
- call the out-parameter form to populate the storage
- expose small, typed methods that return domain objects or scalars

Examples of the intended shape:

- `SourceLocation` stores `InlineArray[CXSourceLocation, 1]` and exposes
  methods like `file()`, `line()`, `column()`, and `offset()`
- `Cursor` stores `InlineArray[CXCursor, 1]` and exposes methods like
  `kind()`, `spelling()`, `type()`, `semantic_parent()`, and `definition()`
- `Type` should follow the same pattern for `CXType`

Higher-level wrappers should also:

- convert `CXString` to `String` as soon as possible and dispose the raw string
  immediately
- use the shared string helpers in `clang/common.mojo` for all
  Mojo-to-C and C-to-Mojo string movement
- use the optional `CXString` path only for APIs that can return a null
  sentinel; empty strings should stay empty, not become `None`
- keep pointer ownership clear, especially for borrowed values from a
  translation unit
- hide callback trampolines behind wrapper methods rather than exposing raw
  callback signatures to callers
- treat the raw `_ffi` module as the stable ABI contract and the wrapper layer
  as the ergonomic API

Do not flatten C arrays in higher-level code just to make a wrapper easier to
write. The raw aggregate should remain a faithful low-level representation, and
the wrapper should adapt around it.

## String Model

There are three string paths, and they are intentionally different:

- Mojo `String` to libclang C string: use `_borrow_c_string(text)` for
  immediate calls when the string only needs to stay alive for the duration of
  the libclang invocation. Use `_alloc_c_string(text)` plus `_c_string(...)`
  when you need owned storage.
- libclang `CXString` to Mojo `String`: use `_CXStringStorage` plus either
  `take()` for normal string-returning APIs or `take_optional()` for APIs that
  use a null `CXString` sentinel.
- borrowed `const char *` from existing owned storage: use `_borrow_c_string_unsafe`
  only when the pointed-to bytes are already owned and known to stay alive for
  the duration of the call.

## Lessons Learned From `SourceLocation` And `SourceRange`

The source-location and source-range wrappers exposed a second class of bugs
that is different from raw ABI normalization: repeated FFI round-trips on
wrapper-owned state can still be unstable even when the raw binding compiles
and the basic one-shot probe passes.

Key takeaways:

- Cache derived data in the wrapper after the first successful libclang call.
  `SourceLocation` was safe once `file`, `line`, `column`, and `offset` returned
  cached fields instead of re-calling `clang_getSpellingLocation` on every
  accessor.
- Prefer value-object semantics for borrowed wrapper state. `SourceRange`
  became stable once it stored copies of the start and end `SourceLocation`
  values instead of asking libclang to reconstruct them on demand.
- If a non-null object crashes while a null object survives, the bug is often
  in the wrapper's post-construction query path, not in the raw zero/null
  initialization.
- When a test fails only after the same borrowed value is reused, suspect
  wrapper lifetime or mutation, then copy the inputs before handing them to the
  C API.
- Keep the test surface focused on behavior the wrapper can guarantee. For
  these types, nullness, equality, and start/end or line/column access were the
  reliable acceptance checks once the wrappers stopped round-tripping through
  libclang unnecessarily.

## Lessons Learned From `Token`

Token wrapping shows the same general rule, but with a sharper edge:

- A token wrapper should cache `kind` and `spelling` immediately, but token
  location queries are more fragile than plain location objects.
- `clang_getTokenLocation` produced a raw `CXSourceLocation` that crashed when
  we tried to feed it through the usual location-formatting helpers
  (`clang_getSpellingLocation`, `clang_getExpansionLocation`, and
  `clang_getFileLocation`).
- That means a token location should not be assumed to behave like a normal
  `SourceLocation` obtained from `TranslationUnit.get_location`.
- If token location support is needed, the wrapper likely needs a separate
  probe and possibly a different strategy than the current location cache
  pattern.
- `TokenGroup` should still own and dispose the token buffer, but `Token`
  accessors should avoid repeated FFI round-trips and should only expose fields
  that are known to be stable.

Current status:

- `kind()`, `spelling()`, and `cursor()` are implemented and exercised by the
  token tests.
- `location()` and `extent()` are intentionally left as documented failures.
  In this checkout, the raw token location path crashed when we tried to feed
  it through the usual location helpers, so those methods are not part of the
  supported surface yet.

## Additional Wrapper Stability Notes

Recent high-level wrapper expansion exposed one more unstable surface:

- `TranslationUnit.target_info()` currently compiles, but calling
  `clang_TargetInfo_getTriple()` crashed at runtime in this checkout.
- Treat `TargetInfo` the same way as the unstable token location paths: do not
  consider it part of the supported high-level API until a dedicated runtime
  probe shows it is stable.
- Keep the rest of the added stable wrapper surfaces enabled: resource usage,
  skipped ranges, macro preprocessing cursors, cursor evaluation, comment/name
  ranges, cursor sets, and direct type field visitation all passed runtime
  tests in this repo.

## What Not To Do

- Do not reintroduce direct libclang signatures into Mojo FFI when they pass or
  return aggregates by value.
- Do not depend on patch files to paper over generator output.
- Do not treat compile success on a generated struct as proof that by-value ABI
  lowering is correct.
- Do not move shim logic into the higher-level API. The higher-level API should
  consume the normalized raw boundary, not recreate it.

## Layout Tests

The generator also emits and builds layout tests for the raw FFI. This is the
fastest way to catch accidental layout drift in the generated low-level module.

Run:

```bash
rtk pixi run generate
```

That command now validates the generated raw FFI and the layout test module in
the same pass.

## Functional Probe

The repository includes a probe runner at `test/raw_ffi_probe.mojo`:

```bash
rtk pixi run raw-ffi-probe
```

This is not a narrow unit test. It exercises the normalized raw boundary
directly and checks that the new approach actually works for:

- version and string APIs
- null aggregate construction
- translation-unit parsing
- cursor, type, location, and range inspection
- diagnostics
- unsaved-file parsing
- callback traversal through `clang_visitChildren`

## Current Files

The generated or probe-related files currently in use are:

- `clang/_ffi.mojo`
- `test/_ffi_layout_tests.mojo`
- `shim/libclang_mojo_shim.h`
- `shim/libclang_mojo_shim.c`
- `shim/libclang_mojo_shim.so`
- `test/raw_ffi_probe.mojo`

These are all produced from the generator pipeline and should be updated by
changing the generator, not by hand-editing the generated output.

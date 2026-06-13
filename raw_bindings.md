# Raw libclang Mojo Bindings Notes

This repository currently generates raw Mojo FFI bindings from LLVM's
`clang-c` headers with `mojo-bindgen`. Generation is repeatable with
`pixi run generate`. The generator first runs `mojo-bindgen`, then applies
repository patch files from `patches/` so the final raw bindings are
deterministic.

## Current Status

- `build/libclang_raw.ir.json` and `src/libclang_raw.mojo` are generated from
  local LLVM 18 headers.
- The generated IR covers every function registered by Python's `clang.cindex`
  function list and also includes additional public `clang_*` C API functions.
- The generated Mojo originally failed on libclang value-return structs because
  `OwnedDLHandle.call` requires a `RegisterPassable` return type.
- The file now contains deterministic post-generation patches for:
  - aggregate layout fixes needed to make the generated Mojo structs compile
  - a C shim route for selected by-value aggregate APIs whose direct Mojo/C ABI
    lowering is not trustworthy
  - removal of spurious FFI declarations from transitive system headers
- The generator also builds `build/libclang_mojo_shim.so` from
  `shim/libclang_mojo_shim.c` before applying patches.

## Manual Fix 1: By-Value Aggregate ABI

Affected structs:

- `CXSourceLocation`
- `CXSourceRange`
- `CXCursor`
- `CXType`
- `CXToken`
- `CXIdxLoc`

C, Python, and Rust all model these as plain C ABI structs. Examples:

- C `CXCursor`: `enum CXCursorKind kind; int xdata; const void *data[3];`
- C `CXType`: `enum CXTypeKind kind; void *data[2];`
- Python `clang.cindex`: `ctypes.Structure` fields matching the C layout.
- Rust `clang-sys`: `#[repr(C)]` structs with matching pointer arrays.

Mojo FFI currently requires the return type passed to `OwnedDLHandle.call` or
`external_call` to conform to `RegisterPassable`. The field-structured
`mojo-bindgen` output used `InlineArray` members and only conformed to
`Copyable, Movable`, so functions like `clang_getNullLocation()` and
`clang_getCursorType()` were rejected by the Mojo compiler.

The local manual patch keeps normal Mojo fields for scalar C members and uses
typed Mojo pointer fields for C pointer members. C pointer arrays are flattened
into individual pointer fields because `InlineArray` currently prevents these
value-return structs from satisfying `RegisterPassable`:

- `CXSourceLocation`: `ptr_data0`, `ptr_data1`, `int_data`.
- `CXSourceRange`: `ptr_data0`, `ptr_data1`, `begin_int_data`, `end_int_data`.
- `CXCursor`: `kind`, `xdata`, `data0`, `data1`, `data2`.
- `CXType`: `kind`, `data0`, `data1`.
- `CXToken`: `int_data0`, `int_data1`, `int_data2`, `int_data3`, `ptr_data`.
- `CXIdxLoc`: `ptr_data0`, `ptr_data1`, `int_data`.

This preserves size and 8-byte alignment on the current Linux x86_64 target and
makes the structs `Copyable, Movable, RegisterPassable`. Integer enum and scalar
fields are directly readable/writable as normal fields. `const void *` fields use
`Optional[ImmutOpaquePointer[ImmutExternalOrigin]]`; `void *` fields use
`Optional[MutOpaquePointer[MutExternalOrigin]]`.

This repository now uses that safer C shim approach for the most failure-prone
aggregate-by-value APIs. The shim rewrites libclang entrypoints into pointer-out
or pointer-in APIs, for example:

```c
void mojo_clang_getNullLocation(CXSourceLocation *out) {
  *out = clang_getNullLocation();
}

void mojo_clang_getCursorType(CXCursor cursor, CXType *out) {
  *out = clang_getCursorType(cursor);
}
```

The flattened-struct patch is still required so Mojo can store these records and
pass pointers to them, but it is no longer treated as sufficient proof that the
direct by-value call ABI is correct.

Current shim coverage includes:

- source location/range construction and null/equality predicates
- source-location inspectors such as `clang_getSpellingLocation`
- TU cursor and cursor-location/range/type fetches
- selected cursor metadata and cursor-to-string surfaces
- selected token APIs

Because Mojo currently corrupts `CXSourceLocation` values when they are
materialized as ordinary Mojo values, the repository now also carries a small
set of pointer-only helper entry points in `libclang_raw` for location/range,
cursor lookup, and tokenization workflows. These helpers keep the aggregate
records in caller-owned storage and pass pointers back into the shim, avoiding
the broken value-copy path.

Remaining direct by-value surfaces should still be treated as suspect until they
move behind the shim or are proven safe with targeted probes.

## Manual Fix 4: CXIndexOptions Bitfields

`CXIndexOptions` contains C bitfields:

- `ExcludeDeclarationsFromPCH : 1`
- `DisplayDiagnostics : 1`
- `StorePreamblesInMemory : 1`
- reserved bits in the same unsigned storage unit

`mojo-bindgen` correctly avoided emitting normal fields for these overlapping
members and emitted opaque storage instead. Keep this representation for ABI
correctness.

Known LLVM 18 layout on Linux x86_64:

- byte `0`: `Size` (`unsigned`)
- byte `4`: `ThreadBackgroundPriorityForIndexing` (`unsigned char`)
- byte `5`: `ThreadBackgroundPriorityForEditing` (`unsigned char`)
- byte `6`: packed bitfield storage
- byte `8`: `PreambleStoragePath`
- byte `16`: `InvocationEmissionPath`
- total size: `24`
- alignment: `8`

Manual usage rule: initialize `Size` to `sizeof(CXIndexOptions)` before passing
the struct to `clang_createIndexWithOptions`.

Do not expose regular Mojo fields for these bitfields unless the generator can
prove the exact target ABI packing. Prefer explicit helper functions or a C shim
for construction.

## Manual Fix 5: Callback ABI

Affected callback types include:

- `CXCursorVisitor`
- `CXFieldVisitor`
- `CXInclusionVisitor`
- `CXCursorAndRangeVisitor_visit_cb`
- `IndexerCallbacks` function pointer fields

These callbacks pass `CXCursor`, `CXSourceRange`, `CXSourceLocation`, or
`CXIdxLoc` directly or indirectly through the C ABI. They are only as correct as
the by-value aggregate representations above.

Before relying on callbacks, validate at least:

- `clang_visitChildren`
- `clang_Type_visitFields`
- `clang_getInclusions`
- `clang_findReferencesInFile`

The safest production-grade solution is a C shim with callback trampolines that
hide aggregate-by-value details from Mojo and pass pointers or opaque handles
instead.

## Upstream mojo-bindgen Issues

These are good candidates to fix upstream:

- Source filtering: emit only declarations whose source location belongs to the
  configured headers, not transitive libc declarations.
- Aggregate ABI classification: detect structs used by value in function
  returns, function parameters, and function-pointer callback signatures.
- ABI policy: for by-value aggregates, choose between target-specific
  `RegisterPassable` storage, rejecting with diagnostics, or generating C-shim
  declarations.
- Bitfield helpers: preserve bitfield metadata and optionally generate explicit
  accessor/mutator helpers instead of only opaque storage.
- Regression fixtures: add tests for libclang-like value-return structs,
  callback value parameters, bitfield records, and system-header leakage.

## Manual Fix 6: System Header FFI Leakage

`mojo-bindgen` currently emits some declarations from transitive system headers
that are visible while parsing libclang headers. This repository removes the
most obvious non-libclang FFI surface in
`patches/0002-remove-system-header-ffi.patch`:

- libc time/clock wrappers such as `time`, `mktime`, `clock_gettime`,
  `timer_create`, and related functions.
- timezone globals such as `tzname`, `daylight`, and their glibc aliases.
- system structs used only by those wrappers, including `tm`, `timespec`,
  `itimerspec`, `sigevent`, `__fsid_t`, and `__locale_struct`.
- system-header macro constants and function-like macro comments such as
  `_TIME_H`, `__GLIBC__`, `CLOCK_MONOTONIC`, `TIME_UTC`, and glibc attribute
  helper macros.
- matching generated layout tests for those removed structs.

Primitive aliases that libclang APIs still use, such as `time_t` for
`clang_getFileTime`, are intentionally retained.

## Regeneration

Run:

```bash
pixi run generate
```

The script applies patches from `patches/` in order with `git apply --check`
before applying each patch. If upstream `mojo-bindgen` output changes enough
that a patch no longer applies, generation fails instead of silently producing a
different binding.

Set `LIBCLANG_APPLY_PATCHES=0` only when intentionally inspecting pristine
`mojo-bindgen` output. The stored patch targets the default
`src/libclang_raw*.mojo` output paths.

## Functional Probe Runner

The repository now includes a capability-probing runner at
`test/raw_ffi_probe.mojo`, exposed through:

```bash
pixi run raw-ffi-probe
```

This runner is intentionally not a narrow pass-only unit test. It reports which
raw libclang surfaces currently work across the Mojo/C boundary, which are
known-broken, and which are still blocked by probe-harness gaps.

Current observations from the default probe task:

- working:
  - `clang_getClangVersion` / `clang_getCString` / `clang_disposeString`
    complete without throwing
  - `clang_defaultEditingTranslationUnitOptions`
  - filesystem-backed `clang_parseTranslationUnit`
  - `clang_getTranslationUnitCursor`
  - `clang_getTranslationUnitSpelling`
  - `clang_getFile`, `clang_getFileName`, `clang_File_tryGetRealPathName`,
    `clang_getFileTime`, and `clang_File_isEqual(file, file)`
  - TU-cursor metadata calls such as `clang_getCursorKind`,
    `clang_getCursorKindSpelling`, `clang_getCursorAvailability`,
    `clang_getCursorSemanticParent`, `clang_getCursorLexicalParent`,
    `clang_getCursorDefinition`, and `clang_getCursorReferenced`
  - diagnostics fetch/dispose on malformed source
  - `clang_visitChildren` with a Mojo `abi("C")` callback completes without
    throwing and returns 0 (all children visited)
  - `clang_tokenize` through the pointer-only `_ref` path returns usable tokens
  - `clang_equalTypes`, `clang_equalCursors`, `clang_equalLocations`, and
    `clang_equalRanges` are classified as known-broken probes that confirm the
    register-to-memory corruption hypothesis
- known-broken:
  - cursor lookup by file/line/column still returns corrupted cursor metadata on
    the current probe fixture path
  - single-token lookup and tokenization still do not return usable tokens on
    the current probe fixture path
  - `clang_equalTypes(a_type, a_type)` (direct dl, CXType by-value) returns 0,
    confirming that CXType > 16 bytes is corrupted when passed through the
    direct libclang call path
  - `clang_equalCursors(self, self)` returns 0 even through the shim, proving
    that by-value CXCursor return corrupts the data-pointer fields while
    preserving the first scalar (kind) field
  - `clang_equalLocations`, `clang_equalRanges` exhibit the same corruption
    pattern through the shim — the first scalar fields survive but pointer or
    integer fields at higher offsets are corrupted
- unknown / crash-prone:
  - value-returned `CXSourceLocation` / `CXSourceRange` records are still not
    trustworthy as ordinary Mojo values; use the pointer-only helper path for
    functional location/range workflows
  - `clang_getNullCursor()` followed by `clang_getCursorKind()` /
    `clang_isInvalid()` does not currently classify as an invalid cursor in the
    probe runner
- unknown / blocked:
  - `clang_visitChildren` callback receives by-value cursors that may have
    corrupted data fields beyond `kind`; the probe only verifies the callback
    does not crash
  - `clang_getCursorType` on a cursor obtained through a by-value return (e.g.
    TU cursor) goes through the shim pointer path in the working probe, but the
    direct by-value path is untested

Treat these probe results as the live compatibility map for the current raw
bindings, not as a final ABI claim.

## Lessons Learned From Probe-Driven Analysis

A systematic analysis of `src/libclang_raw.mojo` identified the following
categories of fragile FFI surfaces, ranked by risk:

### 1. Direct libclang calls with by-value struct parameters (highest risk)

**118 functions** pass `CXCursor` (32 B), `CXType` (24 B), `CXSourceLocation`
(24 B), `CXSourceRange` (24 B), or `CXCursorAndRangeVisitor` through
`_bindgen_dl().call[...]` directly. No shim indirection protects them. The new
`clang_equalTypes` probe confirms that CXType by-value through this path is
corrupted.

| Struct type | Direct dl count | Example |
|-------------|----------------|---------|
| CXCursor | 72 | `clang_isInvalidDeclaration`, `clang_Cursor_hasAttrs` |
| CXType | 40 | `clang_equalTypes`, `clang_getCanonicalType` |
| CXSourceLocation | 2 | `clang_CXRewriter_insertTextBefore` |
| CXSourceRange | 2 | `clang_CXRewriter_replaceText` |
| CXCursorAndRangeVisitor | 2 | `clang_findReferencesInFile` |

The fact that `clang_equalTypes(a_type, a_type)` returns 0 for a type fetched
through the working shim path proves that the direct dl ABI path for
RegisterPassable structs > 16 bytes is broken on this x86_64 target.

### 2. By-value struct returns through direct libclang (very high risk)

**28 functions** return `CXCursor` (5), `CXType` (19), `CXSourceRange` (3), or
`CXSourceLocation` (1) through the direct dl return path. These are the most
brittle because both input and output go through the register-to-memory
conversion:

- `clang_getCanonicalType`, `clang_getPointeeType`, `clang_getResultType`
- `clang_Cursor_getArgument`, `clang_getOverloadedDecl`
- `clang_Cursor_getSpellingNameRange`, `clang_Cursor_getCommentRange`

### 3. Shim-based by-value returns with field corruption (confirmed)

The shim approach uses `InlineArray[T, 1](fill=val)` to spill the RegisterPassable
struct to a pointer, then the shim reads it back. The new `clang_equalCursors`,
`clang_equalLocations`, and `clang_equalRanges` probes all fail, proving that:

**The RegisterPassable-to-memory spilling is corrupting data fields beyond the
first scalar field of each struct.**

| Struct | First field (survives) | Corrupted fields |
|--------|----------------------|------------------|
| CXCursor | `kind` (bytes 0-3) | `xdata`, `data0`, `data1`, `data2` |
| CXType | possibly `kind` | `data0`, `data1` |
| CXSourceLocation | possibly `ptr_data0` | `ptr_data1`, `int_data` |
| CXSourceRange | possibly `ptr_data0` | `ptr_data1`, `begin_int_data`, `end_int_data` |

Existing probes that only read the first scalar field (e.g.,
`clang_getCursorKind(cursor)` reads `kind`) appear to work even though the rest
of the struct is corrupted.

**Implication:** Every cursor, type, location, or range obtained through a
by-value return from any shim or direct dl function has corrupted data after the
first 4--8 bytes. Only the pointer-only `_ref` / `_into` paths (which keep the
struct in caller-allocated memory) produce trustworthy values.

### 4. Callback ABI (high risk, partially verified)

Three callback types receive `CXCursor` by value from C:

- `CXCursorVisitor` -- used by `clang_visitChildren` (probe passes: callback
  returns `CXChildVisit_Continue` and doesn't crash, but cursor values received
  by the callback are likely corrupted)
- `CXFieldVisitor` -- used by `clang_Type_visitFields`
- `CXCursorAndRangeVisitor_visit_cb` -- used by `clang_findReferencesInFile`

The `clang_visitChildren` probe completes without crashing, but the cursors
received by the callback would have corrupted data fields if inspected beyond
the `kind` field.

### 5. CXIndexOptions opaque struct (low risk)

`CXIndexOptions` is kept as opaque byte storage (24 bytes, alignment 8) because
it contains C bitfields. Used only via pointer in
`clang_createIndexWithOptions`. No probe coverage yet.

### 6. Hardcoded library paths (maintenance risk)

Lines 17--18 of `src/libclang_raw.mojo` hardcode `libclang.so.18` and
`libclang_mojo_shim.so` paths. These are platform-specific and will need
updating for other LLVM versions or platforms.

### Probe Coverage Summary

| Surface | Probes | Status |
|---------|--------|--------|
| Version/string lifecycle | 1 | Working |
| Index/TU creation | 2 | Working |
| File metadata | 2 | Working |
| Null struct returns | 1 | Known-broken |
| Cursor metadata (kind only) | 3 | Working but limited |
| Location round-trip (pointer path) | 1 | Working |
| Cursor lookup (pointer path) | 2 | Working |
| Type surface (shim + pointer path) | 1 | Working |
| Tokenize (pointer path) | 2 | Working |
| Token metadata (pointer path) | 1 | Working |
| Diagnostics | 1 | Working |
| Unsaved file parsing | 1 | Working |
| Visit children (callback ABI) | 1 | Working (callback doesn't crash) |
| **By-value equality probes (new)** | **4** | **Known-broken — confirms ABI corruption** |
| **Remaining direct dl calls (CXCursor)** | **72** | **Untested — highest risk** |
| **Remaining direct dl calls (CXType)** | **40** | **Untested — highest risk** |
| Remaining direct dl calls (other) | 5 | Untested |
| CXIndexOptions | 0 | Untested (low risk) |
| CXCursorAndRangeVisitor callbacks | 0 | Untested |

### Recommended Remediation Path

1. **All 72 direct dl CXCursor functions** and **all 40 direct dl CXType
   functions** need C shim wrappers or pointer-only `_ref` variants for
   production use.
2. **28 by-value struct return functions** through direct dl need C shim
   out-parameter wrappers.
3. The 3 callback types that receive `CXCursor` / `CXSourceRange` by value from
   C need C shim trampolines that pass opaque handles or pointers instead of raw
   struct values.
4. All shim functions that return structs by value also corrupt fields beyond
   the first scalar. These should be converted to out-parameter style.
5. The `InlineArray[T, 1](fill=val)` + `unsafe_ptr()` spilling pattern is
    untrustworthy for any `RegisterPassable` struct > 8 bytes. Prefer
    caller-owned storage with pointer-only APIs everywhere.

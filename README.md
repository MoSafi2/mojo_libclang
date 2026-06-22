# mojo_libclang

High-level Mojo bindings for LLVM `libclang`.

Goal: make libclang usable from Mojo for practical source-code tooling, similar
to Python's `clang.cindex` bindings. Use it to parse C/C++ headers, inspect
translation units, walk AST cursors, read diagnostics, query types, tokenize
source ranges, and build small code-analysis tools without writing C FFI calls
by hand.

## What You Can Do

- Create `Index` and `TranslationUnit` values
- Parse files or in-memory unsaved files
- Read diagnostics with formatted messages
- Walk cursor trees with normal Mojo iteration
- Inspect cursor kind, spelling, location, extent, semantic parent, and type
- Query type spelling, canonical types, pointee types, result types, and fields
- Work with source locations, source ranges, files, tokens, and skipped ranges
- Use compilation databases for real projects
- Use rewriter and printing-policy helpers where libclang exposes them

## Example Shape

```mojo
from clang.cindex import Index, UnsavedFile

def main() raises:
    var index = Index.create()
    var header = UnsavedFile(
        "/virtual/example.h",
        """
        typedef struct Point { int x; int y; } Point;
        int add(int a, int b);
        """,
    )

    var tu = index.parse(
        "/virtual/example.h",
        args=List[String]("-x", "c", "-std=c11"),
        unsaved_files=List[UnsavedFile](header),
    )

    for diagnostic in tu.diagnostics():
        print(diagnostic.format())

    for cursor in tu.cursor():
        print(cursor.kind(), ": ", cursor.spelling(), sep="")
```

See `examples/parse_header_example.mojo` and `examples/header_inspector.mojo`
for fuller workflows.

## Setup

```bash
pixi install
```

Pixi pins `clangdev` and `libclang` to LLVM 18.x. Headers and runtime library
come from the Pixi environment, not from vendored headers.

## Pixi Packaging

This repo builds the conda package `libclang_mojo`, which installs the Mojo
package `clang` so downstream Mojo code can use:

```mojo
from clang.cindex import Index, UnsavedFile
```

For local install and packaging, use Pixi's Mojo backend from `pixi.toml`.
`pixi install` sets up dev env, and `pixi run generate` refreshes raw
FFI + shim outputs.

The staged Modular Community recipe lives under
`packaging/modular-community/libclang_mojo/`. It is intended to be copied into a
fork of `modular/modular-community` for a PR; this repository intentionally does
not define a publish/upload task.

To mirror the recipe's install layout locally without publishing, run:

```bash
pixi run build-package
```

This writes the package-style prefix to `dist/libclang_mojo-prefix/`.

To build the staged `rattler-build` recipe as a real conda package for your own
prefix.dev channel, run:

```bash
PREFIX_CHANNEL=your-channel pixi run render-recipe
PREFIX_CHANNEL=your-channel pixi run build-recipe
```

`PREFIX_CHANNEL` is optional for local builds unless the recipe needs packages
from your channel. Upload is explicit and guarded:

```bash
PREFIX_CHANNEL=your-channel pixi run upload-recipe
```

The upload task only uploads existing `.conda` artifacts from `dist/conda/`; it
does not build or publish unless you run it yourself. For non-interactive auth,
set `PREFIX_API_KEY` in the environment:

```bash
PREFIX_CHANNEL=your-channel PREFIX_API_KEY=... pixi run upload-recipe
```

## Run Examples Or Tests

The Mojo code links through the local generated shim in `shim/` and the Pixi
`libclang` runtime:

```bash
pixi run run-test examples/parse_header_example.mojo
pixi run run-test examples/header_inspector.mojo
pixi run run-test test/test_translation_unit.mojo
```

For build-only checks:

```bash
pixi run build-test test/test_ffi.mojo
```

## Repository Layout

- `clang/`: high-level Mojo API
- `clang/_ffi.mojo`: low-level generated boundary used by wrappers
- `examples/`: practical header parsing and inspection examples
- `test/`: wrapper tests and generated layout test source
- `shim/`: generated C shim source/header and local shim shared library
- `scripts/generate_libclang_bindings.py`: binding/shim generator
- `packaging/modular-community/libclang_mojo/`: PR-ready community recipe staging
- `raw_bindings.md`: implementation notes for ABI and wrapper details

## Regenerate Low-Level Bindings

Most users should not need this unless updating LLVM/libclang coverage or
changing ABI handling:

```bash
pixi run generate
```

Generation updates only files needed to run the project:

- `clang/_ffi.mojo`
- `test/_ffi_layout_tests.mojo`
- `shim/libclang_mojo_shim.h`
- `shim/libclang_mojo_shim.c`
- `shim/libclang_mojo_shim.so`

Generated IR is not saved by default. `build/` is not used.

## Development Notes

- Prefer high-level wrappers in `clang/` over direct `_ffi` usage.
- Keep wrapper APIs close to practical `clang.cindex` workflows.
- Keep raw generated functions in `clang._ffi`; do not make `clang.cindex` a
  dump of all raw `clang_*` symbols.
- Do not vendor `clang-c` headers; use Pixi `clangdev` headers.
- Do not edit generated low-level files without updating generator logic.

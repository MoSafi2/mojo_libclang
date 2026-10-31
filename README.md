# libclang_mojo

High-level Mojo bindings for LLVM `libclang`.

`libclang_mojo` provides a Python `clang.cindex`-style API for source-code tooling in Mojo.

## Highlights

- Exposes most of `libclang` API for `C`, `C++`, and some `obj-C`
- Parse C and C++ source files with libclang.
- Inspect cursor spelling, kind, location, extent, parents, and type.
- Read diagnostics with formatted messages.
- Query canonical types, pointee types, result types, fields, and declarations.

## Example

```c
//math_api.h
typedef struct Point { int x; int y; } Point;
int add(int a, int b);
```

```mojo
# main.mojo
from clang.cindex import CursorKind, Index


def main() raises:
    var index = Index.create()
    var tu = index.parse("math_api.h")

    for diagnostic in tu.diagnostics():
        print(diagnostic.format())

    for cursor in tu.cursor():
        if cursor.kind() == CursorKind.FUNCTION_DECL:
            print("function: ", cursor.spelling(), sep="")
        elif cursor.kind() == CursorKind.TYPEDEF_DECL:
            print("typedef: ", cursor.spelling(), sep="")
```

```bash
pixi run mojo run main.mojo
```

## Compatibility

Choose a source revision matching your compiler:

| Source | Mojo | Purpose |
| --- | --- | --- |
| `v0.2.0` / `codex/mojo-1.2` | `1.2.0` | Stable release / stable maintenance |
| `master` | Exact nightly pinned in its manifest and lockfile | Nightly development |

Both tracks use libclang 18. Rebuild compiled Mojo modules with the selected
toolchain; compiled packages are not interchangeable across compiler versions.
The raw FFI and layout checks are regenerated with mojo-bindgen at
`ad2ae77898a738ac88d7d4b9b4d87ca96e874790`.

## Installation

Install Pixi:

```bash
curl -fsSL https://pixi.sh/install.sh | sh
```

Source releases include the Mojo bindings and C shim source. Install a native
C compiler first (GCC or Clang on Linux, Xcode Command Line Tools on macOS),
then build the stable release:

```bash
git clone --branch v0.2.0 https://github.com/MoSafi2/mojo_libclang.git
cd mojo_libclang
pixi install --locked -e dev
pixi run --locked -e dev build-package-layout
```

```bash
pixi run --locked -e dev run-consumer /absolute/path/to/clang-demo/main.mojo
```

`run-consumer` compiles your program against `dist/libclang_mojo-prefix/lib/mojo`
and makes the matching native shim available. It runs from your program's
directory, so relative source/header paths resolve there. The program can use
`from clang.cindex import Index` as in the example above.

For nightly, clone `master` instead and follow the same commands. Pin a published
nightly prerelease tag rather than `master` when you need a reproducible consumer.
GitHub releases provide source archives; this repository does not publish binary
downloads or conda packages as part of these releases.

## Developing From Source

Clone this repository and install the development environment:

```bash
git clone https://github.com/MoSafi2/mojo_libclang.git
cd mojo_libclang
pixi install --locked -e dev
```

Run the wrapper test suite through the local shim:

```bash
pixi run --locked -e dev test
```

To run one test file after building the shim:

```bash
pixi run --locked -e dev build-shim
pixi run --locked -e dev run-test test/test_translation_unit.mojo
```

For build-only checks:

```bash
pixi run --locked -e dev build-test -o /tmp/libclang-layout-test test/_ffi_layout_tests.mojo
```

### Regenerate Low-Level Bindings

Regenerate only when updating LLVM/libclang
coverage or changing ABI handling:

```bash
pixi run -e dev generate
```

Generation updates:

- `clang/_ffi.mojo`
- `test/_ffi_layout_tests.mojo`
- `shim/libclang_mojo_shim.h`
- `shim/libclang_mojo_shim.c`
- `shim/libclang_mojo_shim.so`

Do not edit generated low-level files by hand, either update the generator or
add a deterministic patch.

`pixi run --locked -e dev check-generated` regenerates twice and checks all
generated source files for drift. CI also tests native Linux x86-64, Linux ARM64,
and macOS ARM64, builds the package layout, and exercises an external consumer.

## Packaging

This repository builds the conda package `libclang_mojo`:

```mojo
from clang.cindex import Index
```

The staged Modular Community recipe lives in
`packaging/modular-community/libclang_mojo/`. To mirror the recipe install
layout locally:

```bash
pixi run --locked -e dev build-package-layout
```

Verify the installed layout, without importing this source checkout:

```bash
pixi run --locked -e dev check-consumer
```

To build the staged recipe for a prefix.dev channel:

```bash
pixi install -e package
PREFIX_CHANNEL=your-channel pixi run -e package render-recipe
PREFIX_CHANNEL=your-channel pixi run -e package build-recipe
```

Upload is explicit and only uploads existing `.conda` artifacts from
`dist/conda/`:

```bash
PREFIX_CHANNEL=your-channel PREFIX_API_KEY=... pixi run -e package upload-recipe
```

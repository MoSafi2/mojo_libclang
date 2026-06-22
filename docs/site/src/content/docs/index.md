---
title: Overview
description: Professional Mojo bindings for LLVM libclang.
---

# mojo_libclang

`mojo_libclang` is a high-level Mojo API for LLVM `libclang`. It is designed
for source-code tooling: parse C and C++ translation units, inspect AST cursors,
read diagnostics, query types, tokenize source ranges, and work with
compilation databases from Mojo.

The public API is exposed through `clang.cindex`, following the practical shape
of Python's `clang.cindex` bindings while keeping the low-level FFI boundary
internal.

```mojo
from clang.cindex import Index
```

## Install

Install Pixi on a fresh system:

```bash
curl -fsSL https://pixi.sh/install.sh | sh
```

Create a project and add the channels used by the package:

```bash
pixi init clang-demo
cd clang-demo
pixi workspace channel add conda-forge https://conda.modular.com/max https://repo.prefix.dev/modular-community
pixi add mojo libclang_mojo
```

## First Parse

Create `math_api.h`:

```c
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
```

```bash
pixi run mojo run main.mojo
```

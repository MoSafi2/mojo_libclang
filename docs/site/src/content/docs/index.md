---
title: Overview
description: High-level Mojo bindings for LLVM libclang.
---

# mojo_libclang

`mojo_libclang` provides high-level Mojo bindings for LLVM `libclang`.

The public API is modeled around practical source-code tooling workflows:
creating indexes and translation units, parsing C and C++ headers, walking AST
cursors, reading diagnostics, querying types, tokenizing source ranges, and
using compilation databases.

Most users should import from `clang.cindex`:

```mojo
from clang.cindex import Index, UnsavedFile
```

The generated raw boundary lives in `clang._ffi` and is used by the wrapper
layer. It is intentionally not re-exported wholesale from `clang.cindex`.

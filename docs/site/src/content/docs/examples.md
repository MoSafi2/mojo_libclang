---
title: Examples
description: Practical libclang workflows from Mojo.
---

# Examples

## Parse A Header

Create `image_api.h`:

```c
typedef struct Image {
    int width;
    int height;
    unsigned char* pixels;
} Image;

Image* image_open(const char* path);
void image_free(Image* image);
```

This example parses the header, reports diagnostics, and prints top-level
declarations.

```mojo
from clang.cindex import CursorKind, Index


def main() raises:
    var index = Index.create()
    var tu = index.parse("image_api.h")

    for diagnostic in tu.diagnostics():
        print(diagnostic.format())

    for cursor in tu.cursor():
        if cursor.kind() == CursorKind.STRUCT_DECL:
            print("struct: ", cursor.spelling(), sep="")
        elif cursor.kind() == CursorKind.FUNCTION_DECL:
            print("function: ", cursor.spelling(), sep="")
```

When using the packaged install, run it with:

```bash
pixi run mojo run -I "$CONDA_PREFIX/lib/mojo" main.mojo
```

When working from this repository, use the local shim task:

```bash
pixi run run-test test/test_translation_unit.mojo
```

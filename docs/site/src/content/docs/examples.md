---
title: Examples
description: Small libclang workflows from Mojo.
---

# Examples

Parse an in-memory C header and walk the translation unit:

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

See `examples/parse_header_example.mojo` and
`examples/header_inspector.mojo` for complete workflows.

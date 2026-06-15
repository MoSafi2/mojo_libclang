"""Example: parse a C header file and traverse the cursor tree.

Usage:
  mojo run -I . -Xlinker -L$PWD/build -Xlinker -lclang_mojo_shim \
      examples/parse_header_example.mojo
"""
from src.libclang import Index, SourceExtentInput
from src.libclang.cursor import Cursor
from src.libclang.translation_unit import TranslationUnit


comptime HEADER: String = "/usr/include/stdio.h"


def print_cursor(mut cursor: Cursor, indent: Int, depth: Int) raises:
    """Recursively print a cursor and its children up to `depth`."""
    if depth <= 0:
        return
    for _ in range(indent):
        print("  ", end="")
    print(cursor.spelling(), " [", cursor.kind(), "]", sep="")


def print_tokens(mut tu: TranslationUnit, path: String) raises:
    """Tokenize the first 10 lines of a file and print each token."""
    var extent = tu.get_extent(
        path,
        SourceExtentInput.from_line_columns(1, 1, 10, 1),
    )
    var tokens = tu.get_tokens(extent)
    print("token count:", tokens.__len__())
    for i in range(min(10, tokens.__len__())):
        var t = tokens[i]
        print("  [", i, "]", t.kind(), ":", t.spelling(), sep="")


def main() raises:
    var index = Index.create()
    var tu = index.parse(HEADER)
    print("parsed:", tu)
    print("diagnostics:", tu.__len__())
    var root = tu.cursor()
    print_cursor(root, 0, 3)
    print_tokens(tu, HEADER)

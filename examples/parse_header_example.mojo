"""Example: inspect a real-world-style C API header with libclang.

This example parses a small C library header from an unsaved in-memory file,
then:

1. Reports parse diagnostics.
2. Lists top-level public API declarations.
3. Prints a shallow cursor tree.
4. Tokenizes the first part of the header.

Usage:
mojo run -I . -Xlinker -L$PWD/build -Xlinker -lclang_mojo_shim 
examples/parse_header_example.mojo
"""

from src._ffi import (
    CXCursorKind,
    CXCursor_FunctionDecl,
    CXCursor_StructDecl,
    CXCursor_EnumDecl,
    CXCursor_TypedefDecl,
)

from src.libclang import Index, SourceExtentInput, UnsavedFile
from src.libclang.cursor import Cursor
from src.libclang.translation_unit import TranslationUnit

comptime HEADER_PATH: String = "/virtual/acme_image.h"

comptime HEADER_TEXT: String = """
#ifndef ACME_IMAGE_H
#define ACME_IMAGE_H

#ifdef __cplusplus
extern "C" {
#endif

typedef enum AcmeStatus {
ACME_OK = 0,
ACME_ERROR_INVALID_ARGUMENT = 1,
ACME_ERROR_IO = 2,
ACME_ERROR_UNSUPPORTED_FORMAT = 3,
} AcmeStatus;

typedef struct AcmeImage {
int width;
int height;
int channels;
unsigned char* pixels;
} AcmeImage;

typedef struct AcmeResizeOptions {
int target_width;
int target_height;
int preserve_aspect_ratio;
} AcmeResizeOptions;

AcmeImage* acme_image_open(const char* path);

void acme_image_free(AcmeImage* image);

AcmeStatus acme_image_resize(
AcmeImage* image,
const AcmeResizeOptions* options
);

AcmeStatus acme_image_write_png(
const AcmeImage* image,
const char* path
);

#ifdef __cplusplus
}
#endif

#endif
"""


def kind_label(kind: CXCursorKind) -> String:
    if kind == CXCursor_FunctionDecl:
        return "function"
    if kind == CXCursor_StructDecl:
        return "struct"
    if kind == CXCursor_EnumDecl:
        return "enum"
    if kind == CXCursor_TypedefDecl:
        return "typedef"
    return "other"


def is_public_api_kind(kind: CXCursorKind) -> Bool:
    return (
        kind == CXCursor_FunctionDecl
        or kind == CXCursor_StructDecl
        or kind == CXCursor_EnumDecl
        or kind == CXCursor_TypedefDecl
    )


def print_cursor_line(mut cursor: Cursor, indent: Int) raises:
    for _ in range(indent):
        print("  ", end="")

    print(
        kind_label(cursor.kind()),
        ": ",
        cursor.spelling(),
        " [",
        cursor.kind(),
        "]",
        sep="",
    )


def print_cursor_tree(
    mut cursor: Cursor,
    indent: Int,
    max_depth: Int,
) raises:
    """Recursively print a cursor and children up to `max_depth`."""
    if max_depth < 0:
        return

    print_cursor_line(cursor, indent)

    if max_depth == 0:
        return

    var children = cursor.get_children()

    for i in range(Int(children.__len__())):
        var child = children[i].copy()
        print_cursor_tree(child, indent + 1, max_depth - 1)


def print_public_declarations(mut tu: TranslationUnit) raises:
    """Print top-level declarations that form the C API surface."""
    print("")
    print("Public API declarations:")

    var root = tu.cursor()
    var children = root.get_children()

    for i in range(Int(children.__len__())):
        var cursor = children[i].copy()
        var kind = cursor.kind()

        if not is_public_api_kind(kind):
            continue

        print("  - ", kind_label(kind), ": ", cursor.spelling(), sep="")


def print_diagnostics(mut tu: TranslationUnit) raises:
    """Print translation-unit diagnostics."""
    print("Diagnostics:")

    for i in range(Int(tu.__len__())):
        var d = tu.diagnostic(UInt32(i))
        print("  - ", d.format(), sep="")


def print_tokens(mut tu: TranslationUnit) raises:
    """Tokenize the top part of the header and print a small sample."""
    var extent = tu.get_extent(
        HEADER_PATH,
        SourceExtentInput.from_line_columns(1, 1, 35, 1),
    )

    var tokens = tu.get_tokens(extent)
    print("")
    print("Token sample:")
    print("  token count:", tokens.__len__())

    var limit = tokens.__len__()
    if limit > 40:
        limit = 40

    for i in range(limit):
        var token = tokens[i]
        print("  [", i, "] ", token.kind(), ": ", token.spelling(), sep="")


def main() raises:
    index = Index.create()

    var args = List[String]()

    # Use "-xc" initially instead of "-x", "c" while debugging CStringArray.
    # If CStringArray is correct, both forms should work.
    args.append("-xc")
    args.append("-std=c11")
    args.append("-Wall")

    var unsaved_files = List[UnsavedFile]()
    unsaved_files.append(
        UnsavedFile(
            filename=String(HEADER_PATH),
            contents=String(HEADER_TEXT),
        )
    )

    var tu = index.parse(
        String(HEADER_PATH),
        args=args,
        unsaved_files=unsaved_files,
    )

    print("Parsed translation unit:")
    print("  ", tu, sep="")

    print_diagnostics(tu)
    print_public_declarations(tu)

    print("")
    print("Cursor tree, depth=2:")
    var root = tu.cursor()
    print_cursor_tree(root, 0, 2)

    print_tokens(tu)

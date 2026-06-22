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

from clang.cindex import Index, UnsavedFile, CursorKind
from clang.cursor import Cursor
from clang.translation_unit import TranslationUnit

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


def kind_label(kind: CursorKind) -> String:
    if kind == CursorKind.FUNCTION_DECL:
        return "function"
    if kind == CursorKind.STRUCT_DECL:
        return "struct"
    if kind == CursorKind.ENUM_DECL:
        return "enum"
    if kind == CursorKind.TYPEDEF_DECL:
        return "typedef"
    return "other"


def is_public_api_kind(kind: CursorKind) -> Bool:
    return (
        kind == CursorKind.FUNCTION_DECL
        or kind == CursorKind.STRUCT_DECL
        or kind == CursorKind.ENUM_DECL
        or kind == CursorKind.TYPEDEF_DECL
    )


def print_cursor_line(cursor: Cursor, indent: Int) raises:
    for _ in range(indent):
        print("  ", end="")

    print(
        cursor.kind().as_c_uint(),
        ": ",
        cursor.spelling(),
        " [",
        cursor.kind(),
        "]",
        sep="",
    )


def print_cursor_tree(
    cursor: Cursor,
    indent: Int,
    max_depth: Int,
) raises:
    """Recursively print a cursor and children up to `max_depth`."""
    if max_depth < 0:
        return

    print_cursor_line(cursor, indent)

    if max_depth == 0:
        return

    for child in cursor:
        print_cursor_tree(child, indent + 1, max_depth - 1)


def print_public_declarations(tu: TranslationUnit) raises:
    """Print top-level declarations that form the C API surface."""
    print("")
    print("Public API declarations:")

    var root = tu.cursor()

    for cursor in root:
        var kind = cursor.kind()

        if not is_public_api_kind(kind):
            continue

        print("  - ", kind_label(kind), ": ", cursor.spelling(), sep="")


def print_diagnostics(tu: TranslationUnit) raises:
    """Print translation-unit diagnostics."""
    print("Diagnostics:")

    for d in tu.diagnostics():
        print("  - ", d.format(), sep="")


def print_tokens(tu: TranslationUnit) raises:
    """Tokenize the top part of the header and print a small sample."""
    var extent = tu.extent(
        HEADER_PATH,
        1, 1, 35, 1,
    )

    var tokens = tu.tokens(extent)
    print("")
    print("Token sample:")
    print("  token count:", len(tokens))

    var limit = len(tokens)
    if limit > 40:
        limit = 40

    var i = 0
    for token in tokens:
        if i >= limit:
            break
        print(
            "  [",
            i,
            "] ",
            token.kind().as_c_uint(),
            ": ",
            token.spelling(),
            sep="",
        )
        i += 1


def main() raises:
    index = Index.create()

    args: List[String] = ["-xc", "-std=c11", "-Wall"]

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

    print_diagnostics(tu)
    print_public_declarations(tu)

    print("")
    print("Cursor tree, depth=2:")
    var root = tu.cursor()
    print_cursor_tree(root, 0, 2)

    print_tokens(tu)

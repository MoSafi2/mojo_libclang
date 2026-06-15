"""Example: comprehensive C header inspection with libclang Mojo API.

Demonstrates the full workflow that a Python clang.cindex user would expect:

  1. Parse a C header (in-memory, with compile args)
  2. Print diagnostics using the new for-in iterator
  3. Walk the full AST with walk_preorder
  4. Inspect cursor properties (kind, spelling, location, type info)
  5. Resolve types (canonical, pointee, fields)
  6. Tokenize a source range using the new for-in iterator

Usage:
  mojo run -I . -Xlinker -L$PWD/build -Xlinker -lclang_mojo_shim \
    examples/header_inspector.mojo
"""

from src.libclang import (
    Index,
    TranslationUnit,
    UnsavedFile,
    SourceExtentInput,
    CursorKind,
    TypeKind,
    Cursor,
    Type,
    SourceLocation,
)
from src.libclang.cursor import walk_preorder
from std.ffi import c_uint


comptime HEADER_PATH: String = "/virtual/sensor_api.h"

comptime HEADER_TEXT: String = """
#ifndef SENSOR_API_H
#define SENSOR_API_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum SensorType {
    SENSOR_TEMPERATURE = 0,
    SENSOR_HUMIDITY    = 1,
    SENSOR_PRESSURE    = 2,
} SensorType;

typedef struct SensorConfig {
    const char*  name;
    int          sample_rate_hz;
    float        threshold;
    int          enable_filtering;
    int          enable_logging;
} SensorConfig;

typedef struct SensorReading {
    SensorType  type;
    double      value;
    long long   timestamp_us;
} SensorReading;

SensorConfig* sensor_create(const SensorType type, const char* name);

void sensor_free(SensorConfig* cfg);

int sensor_configure(SensorConfig* cfg, const SensorReading* reading);

int sensor_start_stream(SensorConfig* cfg, int buffer_size);

int sensor_stop_stream(SensorConfig* cfg);

const char* sensor_last_error(SensorConfig* cfg);

#ifdef __cplusplus
}
#endif

#endif
"""


# -- Helpers -----------------------------------------------------------------


def print_diagnostics(tu: TranslationUnit) raises:
    """Print diagnostics from the translation unit."""
    var diags = tu.diagnostics()
    if len(diags) == 0:
        print("  (no diagnostics)")
        return

    for var d in diags:
        print("  [diag] ", d.format(), sep="")


def indent(level: Int):
    for _ in range(level):
        print("  ", end="")


def cursor_summary(c: Cursor) raises -> String:
    """Build a one-line summary of a cursor."""
    var kind = c.kind()
    var spell = c.spelling()
    var loc = c.location()
    var line = loc.line()
    var col = loc.column()

    var result = String(
        t"[line={Int(line)}:{Int(col)}] kind={Int(kind.as_c_uint())}({kind})",
    )

    if spell.byte_length() > 0:
        result += String(t" name='{spell}'")

    var typ = c.type()
    if typ.kind().as_c_uint() != 0:
        result += String(
            t" type={typ.spelling()}(kind={Int(typ.kind().as_c_uint())})",
        )

    return result


def print_children_detail(cursor: Cursor, level: Int) raises:
    """Print a cursor and its children recursively with details."""
    indent(level)
    print("- ", cursor_summary(cursor), sep="")

    var t = cursor.type()
    if t.kind() == TypeKind.RECORD or t.kind() == TypeKind.POINTER:
        # Show canonical type for structs
        var canon = t.get_canonical()
        if canon.spelling() != t.spelling():
            indent(level + 1)
            print("  (canonical: ", canon.spelling(), ")", sep="")

    # Iterate over children using the new for-in protocol
    for child in cursor:
        print_children_detail(child, level + 1)


def print_type_fields(c: Cursor) raises:
    """If cursor has a record type, list its fields."""
    var t = c.type()
    if t.kind() != TypeKind.RECORD:
        return

    var fields = t.get_fields()
    if len(fields) == 0:
        return

    print()
    indent(1)
    print("Fields of '", c.spelling(), "':", sep="")
    for i, field in enumerate(fields):
        var ft = field.type()
        indent(2)
        var x = (
            t" [{i}] {field.spelling()} :"
            t" {ft.spelling()} (kind='{ft.kind().as_c_uint()}')' "
        )
        print(x)


def print_type_canon(c: Cursor) raises:
    """Show canonical type resolution for typedef cursors."""
    if c.kind() != CursorKind.TYPEDEF_DECL:
        return

    var t = c.type()
    var canon = t.get_canonical()

    print()
    indent(1)
    print(t"Typedef: '{c.spelling()} -> canonical: {canon.spelling()}'")

    # If canonical is a pointer, show pointee
    if canon.kind() == TypeKind.POINTER:
        var pointee = canon.get_pointee()
        indent(2)
        print(t"pointee: {pointee.spelling()}")

        var pointee_canon = pointee.get_canonical()
        if pointee_canon.spelling() != pointee.spelling():
            indent(2)
            print("  pointee canonical: ", pointee_canon.spelling(), sep="")


def print_enumerators(root: Cursor) raises:
    """Find enum declarations and list their enumerator values."""
    for c in root.walk_preorder():
        if c.kind() != CursorKind.ENUM_DECL:
            continue

        print()
        indent(1)
        print("Enum '", c.spelling(), "':", sep="")
        for e in c:
            indent(2)
            print(
                "  ",
                e.spelling(),
                " (kind=",
                Int(e.kind().as_c_uint()),
                ")",
                sep="",
            )


def print_token_stream(tu: TranslationUnit) raises:
    """Tokenize a portion of the header using the new for-in TokenGroup iterator.
    """
    var extent = tu.get_extent(
        String(HEADER_PATH),
        SourceExtentInput.from_line_columns(1, 1, 25, 1),
    )
    var tokens = tu.get_tokens(extent)

    print()
    print("Tokens (lines 1-25):")
    print("  count: ", tokens.__len__(), sep="")

    var limit = len(tokens)
    if limit > 25:
        limit = 25

    i = 1
    for var tok in tokens:
        indent(2)
        print(t"[{i}] kind = {tok.kind()} {tok.spelling()}")
        i += 1


# -- Main --------------------------------------------------------------------


def main() raises:
    print("=== libclang Mojo API: C Header Inspector =========================")
    print()

    # 1. Parse ---------------------------------------------------------------
    var index = Index.create()

    var unsaved = List[UnsavedFile]()
    unsaved.append(
        UnsavedFile(filename=String(HEADER_PATH), contents=String(HEADER_TEXT))
    )

    var args: List[String] = ["-xc", "-std=c11", "-Wall"]
    var tu = index.parse(String(HEADER_PATH), args=args, unsaved_files=unsaved)
    print("Parsed '", tu, "'", sep="")

    # 2. Diagnostics ---------------------------------------------------------
    print()
    print("Diagnostics (for-in over DiagnosticSet):")
    print_diagnostics(tu)

    # 3. Cursor tree ---------------------------------------------------------
    print()
    print("Full cursor tree:")
    var root = tu.cursor()
    print_children_detail(root, 0)

    # 4. Type details --------------------------------------------------------
    print()
    print("=== Type Details =================================================")

    for c in root.walk_preorder():
        if c.kind() == CursorKind.TYPEDEF_DECL:
            print_type_canon(c)
        if c.kind() == CursorKind.STRUCT_DECL:
            print_type_fields(c)

    print_enumerators(root)

    # 5. Tokens --------------------------------------------------------------
    print_token_stream(tu)

    print()
    print("=== Done ==========================================================")

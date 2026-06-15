"""Typed error constructors for libclang Mojo operations.

Mojo raises `Error` values, so these are functions that build a prefixed
`Error` and return it. Callers can use them exactly like the Python classes:

    raise TranslationUnitLoadError("could not parse file")

which expands to an `Error` whose message starts with the type name.
"""

from std.ffi import c_uint

from src.libclang.enums import SaveError


def TranslationUnitLoadError(message: String = "") -> Error:
    """Return an Error for TranslationUnit load/parse failures."""
    return Error("TranslationUnitLoadError: " + message)


def TranslationUnitSaveError(save_error: SaveError, message: String = "") -> Error:
    """Return an Error for TranslationUnit save failures."""
    return Error(
        "TranslationUnitSaveError: "
        + String(Int(save_error.as_c_uint()))
        + ": "
        + message
    )


def CompilationDatabaseError(error_code: c_uint, message: String = "") -> Error:
    """Return an Error for compilation database failures."""
    return Error(
        "CompilationDatabaseError: "
        + String(Int(error_code))
        + ": "
        + message
    )

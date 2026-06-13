"""Common helpers used by every high-level wrapper."""
from src.libclang_raw import (
    CXString,
    clang_getCString,
    clang_disposeString,
    CXSourceLocation,
    CXSourceRange,
    CXCursor,
    CXType,
)
from std.ffi import c_char
from std.memory import UnsafePointer


def _c_string(text: String) -> UnsafePointer[c_char, ImmutExternalOrigin]:
    """Return a null-terminated C string pointer to `text` contents.

    Mojo `String.unsafe_ptr()` already points to a null-terminated buffer on
    this toolchain (verified: byte `len(text)` is 0). Callers must keep the
    backing `String` alive for the duration of any C call that consumes the
    pointer.
    """
    return rebind[UnsafePointer[c_char, ImmutExternalOrigin]](text.unsafe_ptr())


def take_cxstring(cxstr: CXString) raises -> String:
    """Copy a `CXString` into a Mojo `String` and dispose the C side.

    Never returns a borrowed view; the input `CXString` is consumed.
    """
    var c_string = clang_getCString(cxstr)
    if not c_string:
        clang_disposeString(cxstr)
        return String("")
    var value = String(unsafe_from_utf8_ptr=c_string.value())
    clang_disposeString(cxstr)
    return value


def _loc_ptr(
    loc: CXSourceLocation,
) -> UnsafePointer[CXSourceLocation, MutExternalOrigin]:
    return rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](
        UnsafePointer.address_of(loc),
    )


def _range_ptr(
    rng: CXSourceRange,
) -> UnsafePointer[CXSourceRange, MutExternalOrigin]:
    return rebind[UnsafePointer[CXSourceRange, MutExternalOrigin]](
        UnsafePointer.address_of(rng),
    )


def _cursor_ptr(
    cursor: CXCursor,
) -> UnsafePointer[CXCursor, MutExternalOrigin]:
    return rebind[UnsafePointer[CXCursor, MutExternalOrigin]](
        UnsafePointer.address_of(cursor),
    )


def _type_ptr(
    type: CXType,
) -> UnsafePointer[CXType, MutExternalOrigin]:
    return rebind[UnsafePointer[CXType, MutExternalOrigin]](
        UnsafePointer.address_of(type),
    )

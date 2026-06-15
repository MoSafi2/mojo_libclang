"""Common helpers used by every high-level wrapper.

Provides:
- ``take_cxstring()`` — extract a ``CXString`` via pointer, return owned ``String``.
- ``_CXStringStorage`` — pre-allocated in-place storage so CXString out-param
  calls need minimal boilerplate.
- ``_c_string()`` — null-terminated pointer from a Mojo ``String``.
"""
from src._ffi import CXString, clang_getCString, clang_disposeString
from std.ffi import c_char, c_uint
from std.memory import UnsafePointer


def _c_string(text: String) -> UnsafePointer[c_char, ImmutExternalOrigin]:
    """Return a null-terminated C string pointer to ``text`` contents.

    ``text.unsafe_ptr()`` is already null-terminated: byte ``text.byte_length()``
    is ``0``. Callers must keep the backing ``String`` alive for the duration of
    any C call that consumes the pointer.
    """
    return rebind[UnsafePointer[c_char, ImmutExternalOrigin]](text.unsafe_ptr())


def _take_cxstring(
    mut cxstr_ref: UnsafePointer[CXString, MutExternalOrigin],
) raises -> String:
    """Copy a ``CXString`` into a Mojo ``String`` and dispose the C side.

    Never returns a borrowed view; the input ``CXString`` is consumed through
    the pointer.
    """
    var c_string = clang_getCString(cxstr_ref)
    if not c_string:
        clang_disposeString(cxstr_ref)
        return String("")
    var value = String(unsafe_from_utf8_ptr=c_string.value())
    clang_disposeString(cxstr_ref)
    return value


struct _CXStringStorage:
    """Allocated ``CXString`` storage with safe extraction.

    Usage::

        var cs = _CXStringStorage()
        clang_getCursorSpelling(cs.ptr(), self._ptr())
        return cs.take()
    """

    var _raw: UnsafePointer[CXString, MutExternalOrigin]
    var _owned: UnsafePointer[CXString, MutAnyOrigin]

    def __init__(out self):
        self._owned = alloc[CXString](1)
        self._owned[] = CXString(data=None, private_flags=c_uint(0))
        self._raw = rebind[UnsafePointer[CXString, MutExternalOrigin]](
            self._owned,
        )

    def ptr(mut self) -> UnsafePointer[CXString, MutExternalOrigin]:
        return self._raw

    def take(mut self) raises -> String:
        return _take_cxstring(self._raw)

    def __del__(deinit self):
        self._owned.free()

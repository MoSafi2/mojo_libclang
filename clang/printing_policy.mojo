"""Printing policy wrapper.

Mirrors the Python ``PrintingPolicy`` class.
"""

from clang._ffi import (
    CXCursor,
    CXPrintingPolicy,
    CXPrintingPolicyProperty,
    clang_getCursorPrintingPolicy,
    clang_PrintingPolicy_dispose,
    clang_PrintingPolicy_getProperty,
    clang_PrintingPolicy_setProperty,
    c_uint,
)

from clang.enums import PrintingPolicyProperty
from clang.cursor import Cursor

from std.memory import UnsafePointer


struct PrintingPolicy(Movable, Writable):
    """Owning wrapper around ``CXPrintingPolicy``."""

    var _raw: CXPrintingPolicy

    def __init__(out self, ref cursor: Cursor) raises:
        cursor._check_valid()
        self._raw = clang_getCursorPrintingPolicy(cursor._ptr())
        if not self._raw:
            raise Error(
                "PrintingPolicy: clang_getCursorPrintingPolicy returned null"
            )

    def __init__(
        out self, cursor_ptr: UnsafePointer[CXCursor, MutUntrackedOrigin]
    ) raises:
        """Create a policy from a cursor.

        The caller must ensure the cursor pointer is valid for the duration of
        the call.
        """
        self._raw = clang_getCursorPrintingPolicy(cursor_ptr)
        if not self._raw:
            raise Error(
                "PrintingPolicy: clang_getCursorPrintingPolicy returned null"
            )

    @staticmethod
    def create(ref cursor: Cursor) raises -> Self:
        return Self(cursor)

    def __del__(deinit self):
        if self._raw:
            clang_PrintingPolicy_dispose(self._raw)

    def property(ref self, property: PrintingPolicyProperty) -> Int:
        return Int(
            clang_PrintingPolicy_getProperty(self._raw, property.as_c_uint())
        )

    def set_property(
        ref self,
        property: PrintingPolicyProperty,
        value: Int,
    ) raises:
        if value < 0:
            raise Error("PrintingPolicy.set_property: value must be >= 0")
        clang_PrintingPolicy_setProperty(
            self._raw,
            property.as_c_uint(),
            c_uint(value),
        )

    def write_to(self, mut writer: Some[Writer]):
        writer.write("PrintingPolicy()")

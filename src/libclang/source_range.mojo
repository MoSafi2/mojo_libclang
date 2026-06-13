"""`SourceRange` — a wrapper around `CXSourceRange`."""
from src.libclang_raw import (
    CXSourceLocation,
    CXSourceRange,
    CXTranslationUnit,
    clang_getNullRange_into,
    clang_getRange_into,
    clang_Range_isNull_ref,
    clang_getRangeStart_into,
    clang_getRangeEnd_into,
    clang_equalRanges_ref,
    c_uint,
)
from src.libclang.source_location import SourceLocation
from std.memory import UnsafePointer


@fieldwise_init
struct SourceRange(Copyable, Movable):
    """A `[begin, end)` source range. Borrowed from a `TranslationUnit`."""

    var _tu: CXTranslationUnit
    var _raw: InlineArray[CXSourceRange, 1]

    def __init__(out self, tu: CXTranslationUnit) raises:
        self._tu = tu
        self._raw = InlineArray[CXSourceRange, 1](
            fill=CXSourceRange(
                ptr_data0=None,
                ptr_data1=None,
                begin_int_data=c_uint(0),
                end_int_data=c_uint(0),
            ),
        )
        clang_getNullRange_into(self._ptr())

    def _ptr(mut self) -> UnsafePointer[CXSourceRange, MutExternalOrigin]:
        return rebind[UnsafePointer[CXSourceRange, MutExternalOrigin]](
            self._raw.unsafe_ptr(),
        )

    @staticmethod
    def null(tu: CXTranslationUnit) -> Self:
        return Self(tu=tu)

    @staticmethod
    def from_locations(start: SourceLocation, end: SourceLocation) raises -> Self:
        var out = Self(tu=start._tu)
        clang_getRange_into(
            out._ptr(),
            rebind[UnsafePointer[
                CXSourceLocation, MutExternalOrigin
            ]](start._raw.unsafe_ptr()),
            rebind[UnsafePointer[
                CXSourceLocation, MutExternalOrigin
            ]](end._raw.unsafe_ptr()),
        )
        return out^

    def start(mut self) raises -> SourceLocation:
        var out = SourceLocation(tu=self._tu)
        clang_getRangeStart_into(out._ptr(), self._ptr())
        return out^

    def end(mut self) raises -> SourceLocation:
        var out = SourceLocation(tu=self._tu)
        clang_getRangeEnd_into(out._ptr(), self._ptr())
        return out^

    def is_null(mut self) raises -> Bool:
        return Bool(clang_Range_isNull_ref(self._ptr()))

    def __eq__(self, other: SourceRange) -> Bool:
        return Bool(
            clang_equalRanges_ref(
                self._ptr(),
                rebind[UnsafePointer[CXSourceRange, MutExternalOrigin]](
                    other._raw.unsafe_ptr(),
                ),
            ),
        )

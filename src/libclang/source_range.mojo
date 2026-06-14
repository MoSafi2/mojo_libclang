"""`SourceRange` — a wrapper around `CXSourceRange`."""
from src._ffi import (
    CXSourceLocation,
    CXSourceRange,
    CXTranslationUnit,
    clang_getNullRange,
    clang_getRange,
    clang_Range_isNull,
    clang_getRangeStart,
    clang_getRangeEnd,
    clang_equalRanges,
    c_uint,
)
from src.libclang.source_location import SourceLocation
from std.memory import UnsafePointer, ImmutOpaquePointer


@fieldwise_init
struct SourceRange(Copyable, Movable):
    """A `[begin, end)` source range. Borrowed from a `TranslationUnit`."""

    var _tu: CXTranslationUnit
    var _raw: InlineArray[CXSourceRange, 1]

    def __init__(out self, tu: CXTranslationUnit) raises:
        self._tu = tu
        self._raw = InlineArray[CXSourceRange, 1](
            fill=CXSourceRange(
                ptr_data=InlineArray[
                    Optional[ImmutOpaquePointer[ImmutExternalOrigin]], 2
                ](fill=None),
                begin_int_data=c_uint(0),
                end_int_data=c_uint(0),
            ),
        )
        clang_getNullRange(self._ptr())

    def _ptr(mut self) -> UnsafePointer[CXSourceRange, MutExternalOrigin]:
        return rebind[UnsafePointer[CXSourceRange, MutExternalOrigin]](
            self._raw.unsafe_ptr(),
        )

    @staticmethod
    def null(tu: CXTranslationUnit) raises-> Self:
        return Self(tu=tu)

    @staticmethod
    def from_locations(start: SourceLocation, end: SourceLocation) raises -> Self:
        var out = Self(tu=start._tu)
        clang_getRange(
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
        clang_getRangeStart(out._ptr(), self._ptr())
        return out^

    def end(mut self) raises -> SourceLocation:
        var out = SourceLocation(tu=self._tu)
        clang_getRangeEnd(out._ptr(), self._ptr())
        return out^

    def is_null(mut self) raises -> Bool:
        return Bool(clang_Range_isNull(self._ptr()))

    def __eq__(self, mut other: SourceRange) -> Bool:
        return Bool(
            clang_equalRanges(
                self._ptr(),
                rebind[UnsafePointer[CXSourceRange, MutExternalOrigin]](
                    other._raw.unsafe_ptr(),
                ),
            ),
        )

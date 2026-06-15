"""`SourceRange` — a wrapper around `CXSourceRange`."""
from src._ffi import (
    CXSourceLocation,
    CXSourceRange,
    CXTranslationUnit,
    clang_getNullRange,
    clang_getRange,
    clang_Range_isNull,
    clang_equalRanges,
    c_uint,
)
from src.libclang.source_location import SourceLocation
from std.memory import UnsafePointer


@fieldwise_init
struct SourceRange(Copyable, Movable, Writable):
    """A `[begin, end)` source range. Borrowed from a `TranslationUnit`."""

    var _tu: CXTranslationUnit
    var _raw: InlineArray[CXSourceRange, 1]
    var _start: SourceLocation
    var _end: SourceLocation

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
        self._start = SourceLocation.null(tu)
        self._end = SourceLocation.null(tu)
        clang_getNullRange(self._ptr())

    def _ptr(mut self) -> UnsafePointer[CXSourceRange, MutExternalOrigin]:
        return rebind[UnsafePointer[CXSourceRange, MutExternalOrigin]](
            self._raw.unsafe_ptr(),
        )

    def write_to(self, mut writer: Some[Writer]):
        writer.write("SourceRange(", self._start, ", ", self._end, ")")

    @staticmethod
    def null(tu: CXTranslationUnit) raises -> Self:
        return Self(tu=tu)

    @staticmethod
    def from_locations(
        start: SourceLocation, end: SourceLocation
    ) raises -> Self:
        var start_copy = start.copy()
        var end_copy = end.copy()
        var out = Self(tu=start._tu)
        clang_getRange(
            out._ptr(),
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](
                start_copy._raw.unsafe_ptr()
            ),
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](
                end_copy._raw.unsafe_ptr()
            ),
        )
        out._start = start_copy.copy()
        out._end = end_copy.copy()
        return out^

    def start(mut self) raises -> SourceLocation:
        return self._start.copy()

    def end(mut self) raises -> SourceLocation:
        return self._end.copy()

    def is_null(mut self) raises -> Bool:
        return Bool(clang_Range_isNull(self._ptr()))

    def __eq__(mut self, mut other: SourceRange) -> Bool:
        return Bool(
            clang_equalRanges(
                self._ptr(),
                rebind[UnsafePointer[CXSourceRange, MutExternalOrigin]](
                    other._raw.unsafe_ptr(),
                ),
            ),
        )

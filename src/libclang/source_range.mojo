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
    clang_getSpellingLocation,
    clang_getFileName,
    clang_equalRanges,
    c_uint,
    CXFile,
)
from src.libclang.source_location import SourceLocation
from src.libclang.common import _CXStringStorage
from std.memory import UnsafePointer, ImmutOpaquePointer


@fieldwise_init
struct SourceRange(Copyable, Movable, Writable):
    """A `[begin, end)` source range. Borrowed from a `TranslationUnit`."""

    var _tu: CXTranslationUnit
    var _raw: InlineArray[CXSourceRange, 1]
    var _display: String

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
        self._display = String()
        clang_getNullRange(self._ptr())
        self._cache_display()

    def _ptr(mut self) -> UnsafePointer[CXSourceRange, MutExternalOrigin]:
        return rebind[UnsafePointer[CXSourceRange, MutExternalOrigin]](
            self._raw.unsafe_ptr(),
        )

    def _cache_display(mut self) raises:
        # Get start spelling parts
        var s_loc = InlineArray[CXSourceLocation, 1](
            fill=CXSourceLocation(
                ptr_data=InlineArray[
                    Optional[ImmutOpaquePointer[ImmutExternalOrigin]], 2
                ](fill=None),
                int_data=c_uint(0),
            ),
        )
        clang_getRangeStart(
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](
                s_loc.unsafe_ptr(),
            ),
            self._ptr(),
        )
        var s_file = InlineArray[CXFile, 1](fill=CXFile(None))
        var s_line = InlineArray[c_uint, 1](fill=c_uint(0))
        var s_col = InlineArray[c_uint, 1](fill=c_uint(0))
        var s_off = InlineArray[c_uint, 1](fill=c_uint(0))
        clang_getSpellingLocation(
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](
                s_loc.unsafe_ptr(),
            ),
            rebind[UnsafePointer[CXFile, MutExternalOrigin]](s_file.unsafe_ptr()),
            rebind[UnsafePointer[c_uint, MutExternalOrigin]](s_line.unsafe_ptr()),
            rebind[UnsafePointer[c_uint, MutExternalOrigin]](s_col.unsafe_ptr()),
            rebind[UnsafePointer[c_uint, MutExternalOrigin]](s_off.unsafe_ptr()),
        )
        # Get end spelling parts
        var e_loc = InlineArray[CXSourceLocation, 1](
            fill=CXSourceLocation(
                ptr_data=InlineArray[
                    Optional[ImmutOpaquePointer[ImmutExternalOrigin]], 2
                ](fill=None),
                int_data=c_uint(0),
            ),
        )
        clang_getRangeEnd(
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](
                e_loc.unsafe_ptr(),
            ),
            self._ptr(),
        )
        var e_file = InlineArray[CXFile, 1](fill=CXFile(None))
        var e_line = InlineArray[c_uint, 1](fill=c_uint(0))
        var e_col = InlineArray[c_uint, 1](fill=c_uint(0))
        var e_off = InlineArray[c_uint, 1](fill=c_uint(0))
        clang_getSpellingLocation(
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](
                e_loc.unsafe_ptr(),
            ),
            rebind[UnsafePointer[CXFile, MutExternalOrigin]](e_file.unsafe_ptr()),
            rebind[UnsafePointer[c_uint, MutExternalOrigin]](e_line.unsafe_ptr()),
            rebind[UnsafePointer[c_uint, MutExternalOrigin]](e_col.unsafe_ptr()),
            rebind[UnsafePointer[c_uint, MutExternalOrigin]](e_off.unsafe_ptr()),
        )
        # Get file names
        var s_name = String()
        if s_file[0]:
            var cs = _CXStringStorage()
            clang_getFileName(cs.ptr(), s_file[0])
            s_name = cs.take()
        var e_name = String()
        if e_file[0]:
            var cs = _CXStringStorage()
            clang_getFileName(cs.ptr(), e_file[0])
            e_name = cs.take()
        # Format: [file:line:col, file:line:col]
        self._display = "["
        self._display += s_name
        self._display += ":"
        self._display += String(Int(s_line[0]))
        self._display += ":"
        self._display += String(Int(s_col[0]))
        self._display += ", "
        self._display += e_name
        self._display += ":"
        self._display += String(Int(e_line[0]))
        self._display += ":"
        self._display += String(Int(e_col[0]))
        self._display += "]"

    def write_to(self, mut writer: Some[Writer]):
        writer.write("SourceRange(", self._display, ")")

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
        out._cache_display()
        return out^

    def start(mut self) raises -> SourceLocation:
        var out = SourceLocation(tu=self._tu)
        clang_getRangeStart(out._ptr(), self._ptr())
        out._cache_from_ffi()
        return out^

    def end(mut self) raises -> SourceLocation:
        var out = SourceLocation(tu=self._tu)
        clang_getRangeEnd(out._ptr(), self._ptr())
        out._cache_from_ffi()
        return out^

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

"""`SourceLocation` — a wrapper around `CXSourceLocation`.

Stores the raw aggregate in caller-owned `InlineArray[CXSourceLocation, 1]`
storage and passes a pointer to every shim function. The TU is kept so we can
return a borrowed `File` from the `file()` accessor.
"""
from src._ffi import (
    CXSourceLocation,
    CXFile,
    CXTranslationUnit,
    clang_getNullLocation,
    clang_getLocation,
    clang_getLocationForOffset,
    clang_getSpellingLocation,
    clang_getFileName,
    clang_Location_isInSystemHeader,
    clang_Location_isFromMainFile,
    c_uint,
)
from src.libclang.common import _CXStringStorage
from std.memory import UnsafePointer, ImmutOpaquePointer


@fieldwise_init
struct SourceLocation(Copyable, Movable, Writable):
    """A cursor location. Borrowed from a `TranslationUnit`."""

    var _tu: CXTranslationUnit
    var _raw: InlineArray[CXSourceLocation, 1]
    var _file: CXFile
    var _line: c_uint
    var _column: c_uint
    var _offset: c_uint
    var _file_name: String

    def __init__(out self, tu: CXTranslationUnit) raises:
        self._tu = tu
        self._raw = InlineArray[CXSourceLocation, 1](
            fill=CXSourceLocation(
                ptr_data=InlineArray[
                    Optional[ImmutOpaquePointer[ImmutExternalOrigin]], 2
                ](fill=None),
                int_data=c_uint(0),
            ),
        )
        self._file = CXFile(None)
        self._line = c_uint(0)
        self._column = c_uint(0)
        self._offset = c_uint(0)
        self._file_name = String()
        clang_getNullLocation(self._ptr())
        self._cache_from_ffi()

    def _ptr(mut self) -> UnsafePointer[CXSourceLocation, MutExternalOrigin]:
        return rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](
            self._raw.unsafe_ptr(),
        )

    def _cache_from_ffi(mut self) raises:
        var (file, line, col, off) = self._spelling_parts()
        self._file = file
        self._line = line
        self._column = col
        self._offset = off
        if file:
            var cs = _CXStringStorage()
            clang_getFileName(cs.ptr(), file)
            self._file_name = cs.take()

    def write_to(self, mut writer: Some[Writer]):
        writer.write("SourceLocation(")
        if self._file_name:
            writer.write(self._file_name, ":", self._line, ":", self._column)
        else:
            writer.write("<no file>:0:0")
        writer.write(")")

    @staticmethod
    def null(tu: CXTranslationUnit) raises -> Self:
        return Self(tu=tu)

    @staticmethod
    def from_position(
        tu: CXTranslationUnit,
        file: CXFile,
        line: c_uint,
        column: c_uint,
    ) raises -> Self:
        var out = Self(tu=tu)
        clang_getLocation(out._ptr(), tu, file, line, column)
        out._cache_from_ffi()
        return out^

    @staticmethod
    def from_offset(
        tu: CXTranslationUnit,
        file: CXFile,
        offset: c_uint,
    ) raises -> Self:
        var out = Self(tu=tu)
        clang_getLocationForOffset(out._ptr(), tu, file, offset)
        out._cache_from_ffi()
        return out^

    def _spelling_parts(
        mut self,
    ) raises -> Tuple[CXFile, c_uint, c_uint, c_uint]:
        var file_out = InlineArray[CXFile, 1](fill=CXFile(None))
        var line_out = InlineArray[c_uint, 1](fill=c_uint(0))
        var col_out = InlineArray[c_uint, 1](fill=c_uint(0))
        var off_out = InlineArray[c_uint, 1](fill=c_uint(0))
        clang_getSpellingLocation(
            self._ptr(),
            rebind[UnsafePointer[CXFile, MutExternalOrigin]](file_out.unsafe_ptr()),
            rebind[UnsafePointer[c_uint, MutExternalOrigin]](line_out.unsafe_ptr()),
            rebind[UnsafePointer[c_uint, MutExternalOrigin]](col_out.unsafe_ptr()),
            rebind[UnsafePointer[c_uint, MutExternalOrigin]](off_out.unsafe_ptr()),
        )
        return (file_out[0], line_out[0], col_out[0], off_out[0])

    def file(mut self) raises -> CXFile:
        return self._file

    def line(mut self) raises -> c_uint:
        return self._line

    def column(mut self) raises -> c_uint:
        return self._column

    def offset(mut self) raises -> c_uint:
        return self._offset

    def is_in_system_header(mut self) raises -> Bool:
        return Bool(clang_Location_isInSystemHeader(self._ptr()))

    def is_from_main_file(mut self) raises -> Bool:
        return Bool(clang_Location_isFromMainFile(self._ptr()))

    def __eq__(self, other: SourceLocation) -> Bool:
        return (
            self._raw[0].ptr_data[0] == other._raw[0].ptr_data[0]
            and self._raw[0].ptr_data[1] == other._raw[0].ptr_data[1]
            and self._raw[0].int_data == other._raw[0].int_data
        )

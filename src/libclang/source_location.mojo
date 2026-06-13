"""`SourceLocation` — a wrapper around `CXSourceLocation`.

Stores the raw aggregate in caller-owned `InlineArray[CXSourceLocation, 1]`
storage and passes a pointer to every shim function. The TU is kept so we can
return a borrowed `File` from the `file()` accessor.
"""
from src.libclang_raw import (
    CXSourceLocation,
    CXFile,
    CXTranslationUnit,
    clang_getNullLocation_ref,
    clang_getLocation_into,
    clang_getLocationForOffset_into,
    clang_getSpellingLocation_ref,
    clang_Location_isInSystemHeader_ref,
    clang_Location_isFromMainFile_ref,
    c_uint,
)
from std.memory import UnsafePointer


@fieldwise_init
struct SourceLocation(Copyable, Movable):
    """A cursor location. Borrowed from a `TranslationUnit`."""

    var _tu: CXTranslationUnit
    var _raw: InlineArray[CXSourceLocation, 1]

    def __init__(out self, tu: CXTranslationUnit) raises:
        self._tu = tu
        self._raw = InlineArray[CXSourceLocation, 1](
            fill=CXSourceLocation(
                ptr_data0=None,
                ptr_data1=None,
                int_data=c_uint(0),
            ),
        )
        clang_getNullLocation_ref(self._ptr())

    def _ptr(mut self) -> UnsafePointer[CXSourceLocation, MutExternalOrigin]:
        return rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](
            self._raw.unsafe_ptr(),
        )

    @staticmethod
    def null(tu: CXTranslationUnit) -> Self:
        return Self(tu=tu)

    @staticmethod
    def from_position(
        tu: CXTranslationUnit,
        file: CXFile,
        line: c_uint,
        column: c_uint,
    ) raises -> Self:
        var out = Self(tu=tu)
        clang_getLocation_into(out._ptr(), tu, file, line, column)
        return out^

    @staticmethod
    def from_offset(
        tu: CXTranslationUnit,
        file: CXFile,
        offset: c_uint,
    ) raises -> Self:
        var out = Self(tu=tu)
        clang_getLocationForOffset_into(out._ptr(), tu, file, offset)
        return out^

    def _spelling_parts(
        mut self,
    ) raises -> Tuple[CXFile, c_uint, c_uint, c_uint]:
        var file_out = InlineArray[CXFile, 1](fill=CXFile(None))
        var line_out = InlineArray[c_uint, 1](fill=c_uint(0))
        var col_out = InlineArray[c_uint, 1](fill=c_uint(0))
        var off_out = InlineArray[c_uint, 1](fill=c_uint(0))
        clang_getSpellingLocation_ref(
            self._ptr(),
            rebind[UnsafePointer[CXFile, MutExternalOrigin]](file_out.unsafe_ptr()),
            rebind[UnsafePointer[c_uint, MutExternalOrigin]](line_out.unsafe_ptr()),
            rebind[UnsafePointer[c_uint, MutExternalOrigin]](col_out.unsafe_ptr()),
            rebind[UnsafePointer[c_uint, MutExternalOrigin]](off_out.unsafe_ptr()),
        )
        return (file_out[0], line_out[0], col_out[0], off_out[0])

    def file(mut self) raises -> CXFile:
        return self._spelling_parts()[0]

    def line(mut self) raises -> c_uint:
        return self._spelling_parts()[1]

    def column(mut self) raises -> c_uint:
        return self._spelling_parts()[2]

    def offset(mut self) raises -> c_uint:
        return self._spelling_parts()[3]

    def is_in_system_header(mut self) raises -> Bool:
        return Bool(clang_Location_isInSystemHeader_ref(self._ptr()))

    def is_from_main_file(mut self) raises -> Bool:
        return Bool(clang_Location_isFromMainFile_ref(self._ptr()))

    def __eq__(self, other: SourceLocation) -> Bool:
        return (
            self._raw[0].ptr_data0 == other._raw[0].ptr_data0
            and self._raw[0].ptr_data1 == other._raw[0].ptr_data1
            and self._raw[0].int_data == other._raw[0].int_data
        )

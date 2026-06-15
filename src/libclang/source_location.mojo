"""`SourceLocation` — a wrapper around `CXSourceLocation`.

A `SourceLocation` is a copied `CXSourceLocation` value plus an ARC keepalive
reference to the owning `TranslationUnitState`.

Important:

* The raw `CXSourceLocation` value is stored in `InlineArray[CXSourceLocation, 1]`.
* The owning translation unit is kept alive through `ArcPointer[TranslationUnitState]`.
* The location becomes stale after `TranslationUnit.reparse()` if the generation changes.
* Every FFI call passes `CXSourceLocation *` to the shim, never `CXSourceLocation` by value.
  """

from src._ffi import (
    CXSourceLocation,
    CXFile,
    clang_getNullLocation,
    clang_getLocation,
    clang_getLocationForOffset,
    clang_getSpellingLocation,
    clang_getFileName,
    clang_Location_isInSystemHeader,
    clang_Location_isFromMainFile,
    c_uint,
    CXTranslationUnit,
)

from src.libclang.common import _CXStringStorage
from src.libclang.state import TranslationUnitState

from std.memory import ArcPointer, UnsafePointer, ImmutOpaquePointer


@fieldwise_init
struct SourceLocation(Copyable, Movable, Writable):
    """A source location borrowed from a `TranslationUnit`.

    ```
    This object keeps the underlying translation unit alive by storing
    `ArcPointer[TranslationUnitState]`.
    """

    var _tu: ArcPointer[TranslationUnitState]
    var _generation: Int
    var _raw: InlineArray[CXSourceLocation, 1]
    var _file: CXFile
    var _line: c_uint
    var _column: c_uint
    var _offset: c_uint
    var _file_name: String

    def __init__(out self, tu: TranslationUnit) raises:
        self._tu = tu.state()
        self._generation = self._tu[].generation
        self._raw = InlineArray[CXSourceLocation, 1](
            fill=_zero_source_location(),
        )
        self._file = CXFile(None)
        self._line = c_uint(0)
        self._column = c_uint(0)
        self._offset = c_uint(0)
        self._file_name = String()

        clang_getNullLocation(self._ptr())

    def __init__(
        out self,
        tu: ArcPointer[TranslationUnitState],
    ) raises:
        self._tu = tu
        self._generation = tu[].generation
        self._raw = InlineArray[CXSourceLocation, 1](
            fill=_zero_source_location(),
        )
        self._file = CXFile(None)
        self._line = c_uint(0)
        self._column = c_uint(0)
        self._offset = c_uint(0)
        self._file_name = String()

        clang_getNullLocation(self._ptr())

    def _check_valid(self) raises:
        if not self._tu[].alive:
            raise Error("SourceLocation used after TranslationUnit disposal")

        if self._generation != self._tu[].generation:
            raise Error("SourceLocation used after TranslationUnit.reparse()")

    def _tu_raw(self) raises -> CXTranslationUnit:
        self._check_valid()
        return self._tu[].raw()

    def _ptr(mut self) -> UnsafePointer[CXSourceLocation, MutExternalOrigin]:
        return rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](
            self._raw.unsafe_ptr(),
        )

    def _cache_from_ffi(mut self) raises:
        self._check_valid()

        var (file, line, col, off) = self._spelling_parts()
        self._file = file
        self._line = line
        self._column = col
        self._offset = off

        self._file_name = String()
        if file:
            var cs = _CXStringStorage()
            clang_getFileName(cs.ptr_for_out(), file)
            self._file_name = cs.take()

    def write_to(self, mut writer: Some[Writer]):
        writer.write("SourceLocation(")
        if self._file_name:
            writer.write(
                self._file_name,
                ":",
                self._line,
                ":",
                self._column,
            )
        else:
            writer.write("<no file>:0:0")
        writer.write(")")

    @staticmethod
    def null(tu: TranslationUnit) raises -> Self:
        return Self(tu=tu)

    @staticmethod
    def null(
        tu: ArcPointer[TranslationUnitState],
    ) raises -> Self:
        return Self(tu=tu)

    @staticmethod
    def from_position(
        tu: TranslationUnit,
        file: CXFile,
        line: c_uint,
        column: c_uint,
    ) raises -> Self:
        var out = Self(tu=tu)
        clang_getLocation(
            out._ptr(),
            out._tu_raw(),
            file,
            line,
            column,
        )
        out._cache_from_ffi()
        return out^

    @staticmethod
    def from_position(
        tu: ArcPointer[TranslationUnitState],
        file: CXFile,
        line: c_uint,
        column: c_uint,
    ) raises -> Self:
        var out = Self(tu=tu)
        clang_getLocation(
            out._ptr(),
            out._tu_raw(),
            file,
            line,
            column,
        )
        out._cache_from_ffi()
        return out^

    @staticmethod
    def from_offset(
        tu: TranslationUnit,
        file: CXFile,
        offset: c_uint,
    ) raises -> Self:
        var out = Self(tu=tu)
        clang_getLocationForOffset(
            out._ptr(),
            out._tu_raw(),
            file,
            offset,
        )
        out._cache_from_ffi()
        return out^

    @staticmethod
    def from_offset(
        tu: ArcPointer[TranslationUnitState],
        file: CXFile,
        offset: c_uint,
    ) raises -> Self:
        var out = Self(tu=tu)
        clang_getLocationForOffset(
            out._ptr(),
            out._tu_raw(),
            file,
            offset,
        )
        out._cache_from_ffi()
        return out^

    def _spelling_parts(
        mut self,
    ) raises -> Tuple[CXFile, c_uint, c_uint, c_uint]:
        self._check_valid()

        var file_out = InlineArray[CXFile, 1](fill=CXFile(None))
        var line_out = InlineArray[c_uint, 1](fill=c_uint(0))
        var col_out = InlineArray[c_uint, 1](fill=c_uint(0))
        var off_out = InlineArray[c_uint, 1](fill=c_uint(0))

        clang_getSpellingLocation(
            self._ptr(),
            rebind[UnsafePointer[CXFile, MutExternalOrigin]](
                file_out.unsafe_ptr(),
            ),
            rebind[UnsafePointer[c_uint, MutExternalOrigin]](
                line_out.unsafe_ptr(),
            ),
            rebind[UnsafePointer[c_uint, MutExternalOrigin]](
                col_out.unsafe_ptr(),
            ),
            rebind[UnsafePointer[c_uint, MutExternalOrigin]](
                off_out.unsafe_ptr(),
            ),
        )

        return (file_out[0], line_out[0], col_out[0], off_out[0])

    def file(mut self) raises -> CXFile:
        self._check_valid()
        return self._file

    def file_name(mut self) raises -> String:
        self._check_valid()
        return self._file_name

    def line(mut self) raises -> c_uint:
        self._check_valid()
        return self._line

    def column(mut self) raises -> c_uint:
        self._check_valid()
        return self._column

    def offset(mut self) raises -> c_uint:
        self._check_valid()
        return self._offset

    def spelling_tuple(
        mut self,
    ) raises -> Tuple[CXFile, c_uint, c_uint, c_uint]:
        """Return fresh spelling-location parts from libclang."""
        return self._spelling_parts()

    def refresh(mut self) raises:
        """Refresh cached file, line, column, offset, and file name."""
        self._cache_from_ffi()

    def is_in_system_header(mut self) raises -> Bool:
        self._check_valid()
        return Bool(clang_Location_isInSystemHeader(self._ptr()))

    def is_from_main_file(mut self) raises -> Bool:
        self._check_valid()
        return Bool(clang_Location_isFromMainFile(self._ptr()))

    def __eq__(self, other: SourceLocation) -> Bool:
        return (
            self._generation == other._generation
            and self._raw[0].ptr_data[0] == other._raw[0].ptr_data[0]
            and self._raw[0].ptr_data[1] == other._raw[0].ptr_data[1]
            and self._raw[0].int_data == other._raw[0].int_data
        )


def _zero_source_location() -> CXSourceLocation:
    return CXSourceLocation(
        ptr_data=InlineArray[
            Optional[ImmutOpaquePointer[ImmutExternalOrigin]], 2
        ](fill=None),
        int_data=c_uint(0),
    )

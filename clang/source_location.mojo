"""`SourceLocation` — a wrapper around `CXSourceLocation`.

A `SourceLocation` is a copied `CXSourceLocation` value plus an ARC keepalive
reference to the owning `TranslationUnitState`.

Important:

* The raw `CXSourceLocation` value is stored in `InlineArray[CXSourceLocation, 1]`.
* The owning translation unit is kept alive through `ArcPointer[TranslationUnitState]`.
* The location becomes stale after `TranslationUnit.reparse()` if the generation changes.
* Every FFI call passes `CXSourceLocation *` to the shim, never `CXSourceLocation` by value.
"""

from clang._ffi import (
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

from clang.common import _CXStringStorage
from clang.state import TranslationUnitState
from clang.file import File

from std.memory import ArcPointer, UnsafePointer, ImmutOpaquePointer


@fieldwise_init
struct SourceLocation(Copyable, Movable, Writable):
    """A source location borrowed from a `TranslationUnit`.

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
        self._tu = tu._shared_state()
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

    def _ptr(ref self) -> UnsafePointer[CXSourceLocation, MutUntrackedOrigin]:
        return rebind[UnsafePointer[CXSourceLocation, MutUntrackedOrigin]](
            self._raw.unsafe_ptr(),
        )

    def _raw_value(ref self) raises -> CXSourceLocation:
        """Return a copied raw ``CXSourceLocation`` value."""
        self._check_valid()
        return self._raw[0].copy()

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
        """Return libclang's null source location for `tu`."""
        return Self(tu=tu)

    @staticmethod
    def null(
        tu: ArcPointer[TranslationUnitState],
    ) raises -> Self:
        """Return libclang's null source location for a shared TU state."""
        return Self(tu=tu)

    @staticmethod
    def from_raw(
        tu: ArcPointer[TranslationUnitState],
        raw: CXSourceLocation,
    ) raises -> Self:
        """Create a ``SourceLocation`` from a copied raw value."""
        var out = Self(tu=tu)
        out._raw[0] = raw.copy()
        out._cache_from_ffi()
        return out^

    @staticmethod
    def from_position(
        tu: TranslationUnit,
        file: CXFile,
        line: Int,
        column: Int,
    ) raises -> Self:
        """Create a location from one-based `line` and `column` in `file`."""
        if line < 1 or column < 1:
            raise Error("SourceLocation.from_position: line and column must be >= 1")

        var out = Self(tu=tu)
        clang_getLocation(
            out._ptr(),
            out._tu_raw(),
            file,
            c_uint(line),
            c_uint(column),
        )
        out._cache_from_ffi()
        return out^

    @staticmethod
    def from_position(
        tu: ArcPointer[TranslationUnitState],
        file: CXFile,
        line: Int,
        column: Int,
    ) raises -> Self:
        """Create a location from one-based `line` and `column` in `file`."""
        if line < 1 or column < 1:
            raise Error("SourceLocation.from_position: line and column must be >= 1")

        var out = Self(tu=tu)
        clang_getLocation(
            out._ptr(),
            out._tu_raw(),
            file,
            c_uint(line),
            c_uint(column),
        )
        out._cache_from_ffi()
        return out^

    @staticmethod
    def from_offset(
        tu: TranslationUnit,
        file: CXFile,
        offset: Int,
    ) raises -> Self:
        """Create a location from a zero-based byte `offset` in `file`."""
        if offset < 0:
            raise Error("SourceLocation.from_offset: offset must be >= 0")

        var out = Self(tu=tu)
        clang_getLocationForOffset(
            out._ptr(),
            out._tu_raw(),
            file,
            c_uint(offset),
        )
        out._cache_from_ffi()
        return out^

    @staticmethod
    def from_offset(
        tu: ArcPointer[TranslationUnitState],
        file: CXFile,
        offset: Int,
    ) raises -> Self:
        """Create a location from a zero-based byte `offset` in `file`."""
        if offset < 0:
            raise Error("SourceLocation.from_offset: offset must be >= 0")

        var out = Self(tu=tu)
        clang_getLocationForOffset(
            out._ptr(),
            out._tu_raw(),
            file,
            c_uint(offset),
        )
        out._cache_from_ffi()
        return out^

    def _spelling_parts(
        ref self,
    ) raises -> Tuple[CXFile, c_uint, c_uint, c_uint]:
        self._check_valid()

        var file_out = InlineArray[CXFile, 1](fill=CXFile(None))
        var line_out = InlineArray[c_uint, 1](fill=c_uint(0))
        var col_out = InlineArray[c_uint, 1](fill=c_uint(0))
        var off_out = InlineArray[c_uint, 1](fill=c_uint(0))

        clang_getSpellingLocation(
            self._ptr(),
            rebind[UnsafePointer[CXFile, MutUntrackedOrigin]](
                file_out.unsafe_ptr(),
            ),
            rebind[UnsafePointer[c_uint, MutUntrackedOrigin]](
                line_out.unsafe_ptr(),
            ),
            rebind[UnsafePointer[c_uint, MutUntrackedOrigin]](
                col_out.unsafe_ptr(),
            ),
            rebind[UnsafePointer[c_uint, MutUntrackedOrigin]](
                off_out.unsafe_ptr(),
            ),
        )

        return (file_out[0], line_out[0], col_out[0], off_out[0])

    def _raw_file(ref self) raises -> CXFile:
        """Return the raw ``CXFile`` handle for this location."""
        self._check_valid()
        return self._file

    def file(ref self) raises -> Optional[File]:
        """Return the ``File`` wrapper for this location.

        Matches the Python ``SourceLocation.file`` property.
        """
        self._check_valid()
        if not self._file:
            return None
        var f = File(tu=self._tu, raw=self._file)
        return Optional[File](f^)

    def file_name(ref self) raises -> String:
        """Return the cached spelling file name, or an empty string for none."""
        self._check_valid()
        return self._file_name

    def line(ref self) raises -> Int:
        """Return the cached one-based spelling line."""
        self._check_valid()
        return Int(self._line)

    def column(ref self) raises -> Int:
        """Return the cached one-based spelling column."""
        self._check_valid()
        return Int(self._column)

    def offset(ref self) raises -> Int:
        """Return the cached zero-based spelling offset."""
        self._check_valid()
        return Int(self._offset)

    def spelling_tuple(
        ref self,
    ) raises -> Tuple[CXFile, Int, Int, Int]:
        """Return fresh spelling-location parts from libclang."""
        var (file, line, column, offset) = self._spelling_parts()
        return (file, Int(line), Int(column), Int(offset))

    def refresh(mut self) raises:
        """Refresh cached file, line, column, offset, and file name."""
        self._cache_from_ffi()

    def is_in_system_header(ref self) raises -> Bool:
        """Return true when this location is in a system header."""
        self._check_valid()
        return Bool(clang_Location_isInSystemHeader(self._ptr()))

    def is_from_main_file(ref self) raises -> Bool:
        """Return true when this location comes from the main file."""
        self._check_valid()
        return Bool(clang_Location_isFromMainFile(self._ptr()))

    def __eq__(self, other: SourceLocation) -> Bool:
        return (
            self._generation == other._generation
            and self._raw[0].ptr_data[0] == other._raw[0].ptr_data[0]
            and self._raw[0].ptr_data[1] == other._raw[0].ptr_data[1]
            and self._raw[0].int_data == other._raw[0].int_data
        )

    def __ne__(self, other: SourceLocation) -> Bool:
        return not self.__eq__(other)

    def __lt__(ref self, ref other: SourceLocation) raises -> Bool:
        """Ordering based on cached spelling location.

        Note: The upstream Python bindings use ``clang_isBeforeInTranslationUnit``,
        which is not exposed by this libclang FFI. This fallback orders by file
        name, line, and column.
        """
        self._check_valid()
        other._check_valid()

        if self._file_name != other._file_name:
            return self._file_name < other._file_name
        if self._line != other._line:
            return self._line < other._line
        return self._column < other._column

    def __le__(ref self, ref other: SourceLocation) raises -> Bool:
        return self.__lt__(other) or self.__eq__(other)

    def __gt__(ref self, ref other: SourceLocation) raises -> Bool:
        return not self.__le__(other)

    def __ge__(ref self, ref other: SourceLocation) raises -> Bool:
        return not self.__lt__(other)


def _zero_source_location() -> CXSourceLocation:
    return CXSourceLocation(
        ptr_data=InlineArray[
            Optional[ImmutOpaquePointer[ImmutUntrackedOrigin]], 2
        ](fill=None),
        int_data=c_uint(0),
    )

"""`SourceLocation` — a wrapper around `CXSourceLocation`.

A `SourceLocation` is a copied `CXSourceLocation` value plus an ARC keepalive
reference to the owning `TranslationUnitState`.

Important:

* The raw `CXSourceLocation` value is stored inline.
* The owning translation unit is kept alive through `ArcPointer[TranslationUnitState]`.
* The location becomes stale after `TranslationUnit.reparse()` if the generation changes.
* FFI calls pass `CXSourceLocation` values using the native C calling convention.

Typical usage:

```mojo
from clang.cindex import TranslationUnit

def main() raises:
    var tu = TranslationUnit.from_source("test/fixtures/test_fixture.c")
    var loc = tu.location("test/fixtures/test_fixture.c", 1, 1)
    print(loc.file_name(), loc.line(), loc.column())
```
"""

import clang.translation_unit as tu_module


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

from clang.common import _out_ptr

from std.memory import ArcPointer


@fieldwise_init
struct SourceLocation(Copyable, Movable, Writable):
    """A source location borrowed from a `TranslationUnit`.

    This object keeps the underlying translation unit alive by storing
    `ArcPointer[TranslationUnitState]`.

    Example:

    ```mojo
    var loc = cursor.location()
    print(loc.file_name(), loc.offset())
    ```
    """

    var _tu: ArcPointer[TranslationUnitState]
    var _generation: Int
    var _raw: CXSourceLocation
    var _file: CXFile
    var _line: c_uint
    var _column: c_uint
    var _offset: c_uint
    var _file_name: String

    def __init__(out self, tu: tu_module.TranslationUnit) raises:
        self._tu = tu._shared_state()
        self._generation = self._tu[].generation
        self._raw = clang_getNullLocation()
        self._file = CXFile(None)
        self._line = c_uint(0)
        self._column = c_uint(0)
        self._offset = c_uint(0)
        self._file_name = String()

    def __init__(
        out self,
        tu: ArcPointer[TranslationUnitState],
    ) raises:
        self._tu = tu
        self._generation = tu[].generation
        self._raw = clang_getNullLocation()
        self._file = CXFile(None)
        self._line = c_uint(0)
        self._column = c_uint(0)
        self._offset = c_uint(0)
        self._file_name = String()

    def _check_valid(self) raises:
        if not self._tu[].alive:
            raise Error("SourceLocation used after TranslationUnit disposal")

        if self._generation != self._tu[].generation:
            raise Error("SourceLocation used after TranslationUnit.reparse()")

    def _tu_raw(self) raises -> CXTranslationUnit:
        self._check_valid()
        return self._tu[].raw()

    def _raw_value(ref self) raises -> CXSourceLocation:
        """Return a copied raw ``CXSourceLocation`` value."""
        self._check_valid()
        return self._raw.copy()

    def _cache_from_ffi(mut self) raises:
        self._check_valid()

        var (file, line, col, off) = self._spelling_parts()
        self._file = file
        self._line = line
        self._column = col
        self._offset = off

        self._file_name = String()
        if file:
            var cs = _CXStringStorage(raw=clang_getFileName(file))
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
    def null(tu: tu_module.TranslationUnit) raises -> Self:
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
        out._raw = raw.copy()
        out._cache_from_ffi()
        return out^

    @staticmethod
    def from_position(
        tu: tu_module.TranslationUnit,
        file: CXFile,
        line: Int,
        column: Int,
    ) raises -> Self:
        """Create a location from one-based `line` and `column` in `file`."""
        if line < 1 or column < 1:
            raise Error(
                "SourceLocation.from_position: line and column must be >= 1"
            )

        var out = Self(tu=tu)
        out._raw = clang_getLocation(
            out._tu_raw(), file, c_uint(line), c_uint(column)
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
            raise Error(
                "SourceLocation.from_position: line and column must be >= 1"
            )

        var out = Self(tu=tu)
        out._raw = clang_getLocation(
            out._tu_raw(), file, c_uint(line), c_uint(column)
        )
        out._cache_from_ffi()
        return out^

    @staticmethod
    def from_offset(
        tu: tu_module.TranslationUnit,
        file: CXFile,
        offset: Int,
    ) raises -> Self:
        """Create a location from a zero-based byte `offset` in `file`."""
        if offset < 0:
            raise Error("SourceLocation.from_offset: offset must be >= 0")

        var out = Self(tu=tu)
        out._raw = clang_getLocationForOffset(
            out._tu_raw(), file, c_uint(offset)
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
        out._raw = clang_getLocationForOffset(
            out._tu_raw(), file, c_uint(offset)
        )
        out._cache_from_ffi()
        return out^

    def _spelling_parts(
        ref self,
    ) raises -> Tuple[CXFile, c_uint, c_uint, c_uint]:
        self._check_valid()

        var file_out = CXFile(None)
        var line_out = c_uint(0)
        var col_out = c_uint(0)
        var off_out = c_uint(0)

        clang_getSpellingLocation(
            self._raw,
            _out_ptr(file_out),
            _out_ptr(line_out),
            _out_ptr(col_out),
            _out_ptr(off_out),
        )

        return (file_out, line_out, col_out, off_out)

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
        return Bool(clang_Location_isInSystemHeader(self._raw))

    def is_from_main_file(ref self) raises -> Bool:
        """Return true when this location comes from the main file."""
        self._check_valid()
        return Bool(clang_Location_isFromMainFile(self._raw))

    def __eq__(self, other: SourceLocation) -> Bool:
        return (
            self._generation == other._generation
            and self._raw.ptr_data_0 == other._raw.ptr_data_0
            and self._raw.ptr_data_1 == other._raw.ptr_data_1
            and self._raw.int_data == other._raw.int_data
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

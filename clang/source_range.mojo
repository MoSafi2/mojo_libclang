"""`SourceRange` — a wrapper around `CXSourceRange`.

A `SourceRange` is a copied `CXSourceRange` value plus an ARC keepalive
reference to the owning `TranslationUnitState`.

Important:

* The raw `CXSourceRange` value is stored inline.
* The owning translation unit is kept alive through `ArcPointer[TranslationUnitState]`.
* The range becomes stale after `TranslationUnit.reparse()` if the generation changes.
* FFI calls pass `CXSourceRange` values using the native C calling convention.

Typical usage:

```mojo
from clang.cindex import TranslationUnit

def main() raises:
    var tu = TranslationUnit.from_source("test/fixtures/test_fixture.c")
    var extent = tu.cursor().extent()
    print(extent.start(), extent.end())
```
"""

import clang.translation_unit as tu_module


from clang._ffi import (
    CXSourceRange,
    clang_getNullRange,
    clang_getRange,
    clang_getRangeStart,
    clang_getRangeEnd,
    clang_Range_isNull,
    clang_equalRanges,
)

from clang.source_location import SourceLocation
from clang.state import TranslationUnitState

from std.memory import ArcPointer


@fieldwise_init
struct SourceRange(Copyable, Movable, Writable):
    """A `[begin, end)` source range borrowed from a `TranslationUnit`.

    This object keeps the underlying translation unit alive by storing
    `ArcPointer[TranslationUnitState]`.

    Example:

    ```mojo
    var extent = cursor.extent()
    print(extent.start().line(), extent.end().line())
    ```
    """

    var _tu: ArcPointer[TranslationUnitState]
    var _generation: Int
    var _raw: CXSourceRange
    var _start: SourceLocation
    var _end: SourceLocation

    def __init__(out self, tu: tu_module.TranslationUnit) raises:
        self._tu = tu._shared_state()
        self._generation = self._tu[].generation
        self._raw = clang_getNullRange()
        self._start = SourceLocation.null(self._tu)
        self._end = SourceLocation.null(self._tu)

    def __init__(
        out self,
        tu: ArcPointer[TranslationUnitState],
    ) raises:
        self._tu = tu
        self._generation = tu[].generation
        self._raw = clang_getNullRange()
        self._start = SourceLocation.null(tu)
        self._end = SourceLocation.null(tu)

    def _check_valid(self) raises:
        if not self._tu[].alive:
            raise Error("SourceRange used after TranslationUnit disposal")

        if self._generation != self._tu[].generation:
            raise Error("SourceRange used after TranslationUnit.reparse()")

    def _raw_value(ref self) raises -> CXSourceRange:
        """Return a copied raw ``CXSourceRange`` value."""
        self._check_valid()
        return self._raw.copy()

    def write_to(self, mut writer: Some[Writer]):
        writer.write("SourceRange(", self._start, ", ", self._end, ")")

    @staticmethod
    def null(tu: tu_module.TranslationUnit) raises -> Self:
        """Return libclang's null source range for `tu`."""
        return Self(tu=tu)

    @staticmethod
    def null(
        tu: ArcPointer[TranslationUnitState],
    ) raises -> Self:
        """Return libclang's null source range for a shared TU state."""
        return Self(tu=tu)

    @staticmethod
    def from_locations(
        start: SourceLocation,
        end: SourceLocation,
    ) raises -> Self:
        """Create a range from two locations in the same translation unit."""
        var start_copy = start.copy()
        var end_copy = end.copy()

        start_copy._check_valid()
        end_copy._check_valid()

        if start_copy._generation != end_copy._generation:
            raise Error(
                (
                    "SourceRange.from_locations: start and end have different "
                    "TranslationUnit generations"
                ),
            )

        if start_copy._tu[].raw() != end_copy._tu[].raw():
            raise Error(
                (
                    "SourceRange.from_locations: start and end belong to "
                    "different TranslationUnits"
                ),
            )

        var out = Self(tu=start_copy._tu)

        out._raw = clang_getRange(start_copy._raw, end_copy._raw)

        out._start = start_copy.copy()
        out._end = end_copy.copy()
        return out^

    @staticmethod
    def from_raw(
        tu: ArcPointer[TranslationUnitState],
        raw: CXSourceRange,
    ) raises -> Self:
        """Create a range from a copied raw `CXSourceRange` value."""
        var out = Self(tu=tu)
        out._raw = raw.copy()
        var start = clang_getRangeStart(raw)
        var end = clang_getRangeEnd(raw)
        out._start = SourceLocation.from_raw(tu, start)
        out._end = SourceLocation.from_raw(tu, end)
        return out^

    def start(ref self) raises -> SourceLocation:
        """Return a copy of the range start location."""
        self._check_valid()
        return self._start.copy()

    def end(ref self) raises -> SourceLocation:
        """Return a copy of the range end location."""
        self._check_valid()
        return self._end.copy()

    def is_null(ref self) raises -> Bool:
        """Return true when this is libclang's null source range."""
        self._check_valid()
        return Bool(clang_Range_isNull(self._raw))

    def __eq__(ref self, ref other: SourceRange) raises -> Bool:
        self._check_valid()
        other._check_valid()

        if self._generation != other._generation:
            return False

        if self._tu[].raw() != other._tu[].raw():
            return False

        return Bool(
            clang_equalRanges(self._raw, other._raw),
        )

    def __ne__(ref self, ref other: SourceRange) raises -> Bool:
        return not self.__eq__(other)

    def __contains__(ref self, ref other: SourceLocation) raises -> Bool:
        """Return true if ``other`` lies inside this range (inclusive)."""
        self._check_valid()
        other._check_valid()

        if self._generation != other._generation:
            return False

        if self._tu[].raw() != other._tu[].raw():
            return False

        return self._start <= other and other <= self._end

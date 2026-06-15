"""`SourceRange` — a wrapper around `CXSourceRange`.

A `SourceRange` is a copied `CXSourceRange` value plus an ARC keepalive
reference to the owning `TranslationUnitState`.

Important:

* The raw `CXSourceRange` value is stored in `InlineArray[CXSourceRange, 1]`.
* The owning translation unit is kept alive through `ArcPointer[TranslationUnitState]`.
* The range becomes stale after `TranslationUnit.reparse()` if the generation changes.
* Every FFI call passes `CXSourceRange *` to the shim, never `CXSourceRange` by value.
  """

from src._ffi import (
    CXSourceLocation,
    CXSourceRange,
    clang_getNullRange,
    clang_getRange,
    clang_Range_isNull,
    clang_equalRanges,
    c_uint,
)

from src.libclang.source_location import SourceLocation
from src.libclang.state import TranslationUnitState

from std.memory import ArcPointer, UnsafePointer, ImmutOpaquePointer


@fieldwise_init
struct SourceRange(Copyable, Movable, Writable):
    """A `[begin, end)` source range borrowed from a `TranslationUnit`.

    ```
    This object keeps the underlying translation unit alive by storing
    `ArcPointer[TranslationUnitState]`.
    """

    var _tu: ArcPointer[TranslationUnitState]
    var _generation: Int
    var _raw: InlineArray[CXSourceRange, 1]
    var _start: SourceLocation
    var _end: SourceLocation

    def __init__(
        out self,
        tu: ArcPointer[TranslationUnitState],
    ) raises:
        self._tu = tu
        self._generation = tu[].generation
        self._raw = InlineArray[CXSourceRange, 1](
            fill=_zero_source_range(),
        )
        self._start = SourceLocation.null(tu)
        self._end = SourceLocation.null(tu)

        clang_getNullRange(self._ptr())

    def _check_valid(self) raises:
        if not self._tu[].alive:
            raise Error("SourceRange used after TranslationUnit disposal")

        if self._generation != self._tu[].generation:
            raise Error("SourceRange used after TranslationUnit.reparse()")

    def _ptr(mut self) -> UnsafePointer[CXSourceRange, MutExternalOrigin]:
        return rebind[UnsafePointer[CXSourceRange, MutExternalOrigin]](
            self._raw.unsafe_ptr(),
        )

    def write_to(self, mut writer: Some[Writer]):
        writer.write("SourceRange(", self._start, ", ", self._end, ")")

    @staticmethod
    def null(
        tu: ArcPointer[TranslationUnitState],
    ) raises -> Self:
        return Self(tu=tu)

    @staticmethod
    def from_locations(
        start: SourceLocation,
        end: SourceLocation,
    ) raises -> Self:
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

        clang_getRange(
            out._ptr(),
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](
                start_copy._raw.unsafe_ptr(),
            ),
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](
                end_copy._raw.unsafe_ptr(),
            ),
        )

        out._start = start_copy.copy()
        out._end = end_copy.copy()
        return out^

    def start(mut self) raises -> SourceLocation:
        self._check_valid()
        return self._start.copy()

    def end(mut self) raises -> SourceLocation:
        self._check_valid()
        return self._end.copy()

    def is_null(mut self) raises -> Bool:
        self._check_valid()
        return Bool(clang_Range_isNull(self._ptr()))

    def __eq__(mut self, mut other: SourceRange) raises -> Bool:
        self._check_valid()
        other._check_valid()

        if self._generation != other._generation:
            return False

        if self._tu[].raw() != other._tu[].raw():
            return False

        return Bool(
            clang_equalRanges(
                self._ptr(),
                rebind[UnsafePointer[CXSourceRange, MutExternalOrigin]](
                    other._raw.unsafe_ptr(),
                ),
            ),
        )


def _zero_source_range() -> CXSourceRange:
    return CXSourceRange(
        ptr_data=InlineArray[
            Optional[ImmutOpaquePointer[ImmutExternalOrigin]], 2
        ](fill=None),
        begin_int_data=c_uint(0),
        end_int_data=c_uint(0),
    )

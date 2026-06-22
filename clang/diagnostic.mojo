"""`Diagnostic`, `DiagnosticSet`, and `FixIt` wrappers.

Diagnostics are libclang-owned/returned handles that may refer back to source
locations, source ranges, and files in a translation unit.

This module follows the new lifetime model:

* `Diagnostic` keeps `ArcPointer[TranslationUnitState]`.
* `DiagnosticSet` keeps `ArcPointer[TranslationUnitState]`.
* Source locations/ranges produced from diagnostics use the same TU state.
* Objects become stale after `TranslationUnit.reparse()` if the generation changes.

Ownership notes:

* Diagnostics returned directly from `clang_getDiagnostic()` are owned by
  `Diagnostic` and disposed in `__del__`.
* Diagnostics returned by `clang_getDiagnosticInSet()` are wrapped as owned
  diagnostics here.
* Diagnostic sets returned from `clang_getDiagnosticSetFromTU()` are owned.
* Diagnostic sets returned from `clang_getChildDiagnostics()` are borrowed and
  should not be disposed.

Typical usage:

```mojo
from clang.cindex import TranslationUnit

def main() raises:
    var tu = TranslationUnit.from_source("test/fixtures/test_fixture_invalid.c")
    for diag in tu.diagnostics():
        print(diag.severity(), diag.formatted())
```
"""

from clang._ffi import (
    CXDiagnostic,
    CXDiagnosticSet,
    c_uint,
    clang_getDiagnosticSeverity,
    clang_getDiagnosticSpelling,
    clang_getDiagnosticCategory,
    clang_getDiagnosticCategoryText,
    clang_getDiagnosticOption,
    clang_getDiagnosticNumRanges,
    clang_getDiagnosticNumFixIts,
    clang_getDiagnosticLocation,
    clang_getDiagnosticRange,
    clang_getDiagnosticFixIt,
    clang_getNumDiagnosticsInSet,
    clang_getDiagnosticInSet,
    clang_getChildDiagnostics,
    clang_formatDiagnostic,
    clang_defaultDiagnosticDisplayOptions,
    clang_disposeDiagnostic,
)

from clang.enums import DiagnosticSeverity, DiagnosticDisplayOptions
from clang.common import _CXStringStorage
from clang.state import TranslationUnitState
from clang.source_location import SourceLocation
from clang.source_range import SourceRange
from clang._ffi import clang_disposeDiagnosticSet


from std.iter import Iterable, Iterator, StopIteration
from std.memory import ArcPointer


@fieldwise_init
struct FixIt(Copyable, Movable, Writable):
    """A `clang::FixIt` replacement suggestion."""

    var range: SourceRange
    var value: String

    def write_to(self, mut writer: Some[Writer]):
        writer.write("FixIt(")
        self.range.write_to(writer)
        writer.write(", ", self.value, ")")


@fieldwise_init
struct Diagnostic(Movable, Writable):
    """Owning wrapper around `CXDiagnostic`.

    The diagnostic keeps its originating translation unit alive so that
    locations, ranges, and fix-its can safely create TU-borrowed wrappers.

    Example:

    ```mojo
    var diag = tu.diagnostic(0)
    print(diag.spelling())
    print(diag.location())
    ```
    """

    var _tu: ArcPointer[TranslationUnitState]
    var _generation: Int
    var _raw: CXDiagnostic
    var _owns: Bool
    var _formatted: String

    def __init__(
        out self,
        tu: TranslationUnit,
        raw: CXDiagnostic,
        owns: Bool = True,
    ) raises:
        """Wrap a diagnostic tied to `tu`."""
        self._tu = tu._shared_state()
        self._generation = self._tu[].generation
        self._raw = raw
        self._owns = owns
        self._formatted = String()

        if raw:
            self._cache_format()

    def __init__(
        out self,
        tu: ArcPointer[TranslationUnitState],
        raw: CXDiagnostic,
        owns: Bool = True,
    ) raises:
        """Wrap a diagnostic tied to a shared translation-unit state."""
        self._tu = tu
        self._generation = tu[].generation
        self._raw = raw
        self._owns = owns
        self._formatted = String()

        if raw:
            self._cache_format()

    def __init__(
        out self,
        tu: ArcPointer[TranslationUnitState],
        raw: CXDiagnostic,
        owns: Bool,
        _unchecked: Bool,
    ):
        """Internal non-raising constructor used by iterators.

        The caller must ensure the TU is alive and at the expected generation.
        """
        self._tu = tu
        self._generation = tu[].generation
        self._raw = raw
        self._owns = owns
        self._formatted = String()

        if raw:
            self._cache_format_unchecked()

    def _check_valid(self) raises:
        if not self._tu[].alive:
            raise Error("Diagnostic used after TranslationUnit disposal")

        if self._generation != self._tu[].generation:
            raise Error("Diagnostic used after TranslationUnit.reparse()")

        if not self._raw:
            raise Error("Diagnostic contains null CXDiagnostic")

    def _cache_format(mut self) raises:
        self._check_valid()
        self._cache_format_unchecked()

    def _cache_format_unchecked(mut self):
        """Cache the formatted string without validity checks.

        Used by the internal non-raising constructor. The caller must ensure
        the diagnostic raw handle is usable.
        """
        var options = DiagnosticDisplayOptions(
            clang_defaultDiagnosticDisplayOptions(),
        )
        var cs = _CXStringStorage()
        clang_formatDiagnostic(cs.ptr_for_out(), self._raw, options.as_c_uint())
        self._formatted = cs._take_unchecked()

    def write_to(self, mut writer: Some[Writer]):
        writer.write("Diagnostic(", self._formatted, ")")

    def severity(ref self) raises -> DiagnosticSeverity:
        """Return the diagnostic severity."""
        self._check_valid()
        return DiagnosticSeverity(clang_getDiagnosticSeverity(self._raw))

    def spelling(ref self) raises -> String:
        """Return the diagnostic spelling text."""
        self._check_valid()

        var cs = _CXStringStorage()
        clang_getDiagnosticSpelling(cs.ptr_for_out(), self._raw)
        return cs.take()

    def location(ref self) raises -> SourceLocation:
        """Return the primary source location for this diagnostic."""
        self._check_valid()

        var out = SourceLocation(tu=self._tu)
        clang_getDiagnosticLocation(out._ptr(), self._raw)
        out._cache_from_ffi()
        return out^

    def category_number(ref self) raises -> Int:
        """Return the libclang numeric category for this diagnostic."""
        self._check_valid()
        return Int(clang_getDiagnosticCategory(self._raw))

    def category_name(ref self) raises -> String:
        """Return the category name for this diagnostic."""
        self._check_valid()

        var cs = _CXStringStorage()
        clang_getDiagnosticCategoryText(cs.ptr_for_out(), self._raw)
        return cs.take()

    def option(ref self) raises -> String:
        """Return the warning option associated with this diagnostic."""
        self._check_valid()

        var option = _CXStringStorage()
        var disable = _CXStringStorage()

        clang_getDiagnosticOption(
            option.ptr_for_out(),
            self._raw,
            disable.ptr_for_out(),
        )

        # Dispose the disable-option string by converting it to owned Mojo
        # string and letting it go out of scope.
        _ = disable.take()

        return option.take()

    def disable_option(ref self) raises -> String:
        """Return the option that disables this diagnostic."""
        self._check_valid()

        var option = _CXStringStorage()
        var disable = _CXStringStorage()

        clang_getDiagnosticOption(
            option.ptr_for_out(),
            self._raw,
            disable.ptr_for_out(),
        )

        # Dispose the option string by converting it to owned Mojo string and
        # letting it go out of scope.
        _ = option.take()

        return disable.take()

    def num_ranges(ref self) raises -> Int:
        """Return the number of source ranges attached to this diagnostic."""
        self._check_valid()
        return Int(clang_getDiagnosticNumRanges(self._raw))

    def range(ref self, i: Int) raises -> SourceRange:
        """Return source range `i` for this diagnostic."""
        self._check_valid()

        if i < 0 or i >= self.num_ranges():
            raise Error("Diagnostic.range: index out of range")

        var out = SourceRange(tu=self._tu)
        clang_getDiagnosticRange(out._ptr(), self._raw, c_uint(i))
        return out^

    def num_fixits(ref self) raises -> Int:
        """Return the number of fix-it suggestions."""
        self._check_valid()
        return Int(clang_getDiagnosticNumFixIts(self._raw))

    def fixit(ref self, i: Int) raises -> FixIt:
        """Return fix-it suggestion `i`."""
        self._check_valid()

        if i < 0 or i >= self.num_fixits():
            raise Error("Diagnostic.fixit: index out of range")

        var range_out = SourceRange(tu=self._tu)
        var cs = _CXStringStorage()

        clang_getDiagnosticFixIt(
            cs.ptr_for_out(),
            self._raw,
            c_uint(i),
            range_out._ptr(),
        )

        return FixIt(range=range_out^, value=cs.take())

    def children(ref self) raises -> DiagnosticSet:
        """Return child diagnostics attached to this diagnostic."""
        self._check_valid()

        # The child diagnostic set is borrowed from this diagnostic according
        # to libclang's ownership model, so DiagnosticSet must not dispose it.
        return DiagnosticSet._from_handle(
            self._tu,
            clang_getChildDiagnostics(self._raw),
            owns=False,
        )

    def format(
        ref self,
        options: DiagnosticDisplayOptions = DiagnosticDisplayOptions.DEFAULT,
    ) raises -> String:
        """Format this diagnostic with the requested display options."""
        self._check_valid()

        var opts = options
        if opts == DiagnosticDisplayOptions.DEFAULT:
            opts = DiagnosticDisplayOptions(
                clang_defaultDiagnosticDisplayOptions(),
            )
        var cs = _CXStringStorage()
        clang_formatDiagnostic(cs.ptr_for_out(), self._raw, opts.as_c_uint())
        return cs.take()

    def formatted(mut self) raises -> String:
        """Return the cached default formatted diagnostic string."""
        self._check_valid()

        if not self._formatted:
            self._cache_format()

        return self._formatted

    def __del__(deinit self):
        if self._owns:
            if self._raw:
                clang_disposeDiagnostic(self._raw)


struct DiagnosticSetIterator[
    mut: Bool, //, origin: Origin[mut=mut]
](Movable, Iterator):
    """Iterator over diagnostics in a `DiagnosticSet`."""

    comptime Element = Diagnostic

    var _tu: ArcPointer[TranslationUnitState]
    var _generation: Int
    var _raw: CXDiagnosticSet
    var _index: c_uint

    def __init__(out self, ref set: DiagnosticSet):
        self._tu = set._tu
        self._generation = set._generation
        self._raw = set._raw
        self._index = c_uint(0)

    def __next__(mut self) raises StopIteration -> Diagnostic:
        if not self._tu[].alive or self._generation != self._tu[].generation:
            raise StopIteration()

        if self._index >= clang_getNumDiagnosticsInSet(self._raw):
            raise StopIteration()

        var raw = clang_getDiagnosticInSet(self._raw, self._index)
        self._index += 1
        return Diagnostic(
            tu=self._tu,
            raw=raw,
            owns=True,
            _unchecked=True,
        )


struct DiagnosticSet(Movable, Sized, Writable, Iterable):
    """Wrapper around `CXDiagnosticSet`.

    A `DiagnosticSet` may either own the raw diagnostic set or borrow it,
    depending on where the set came from.
    """

    comptime IteratorType[
        iterable_mut: Bool, //, iterable_origin: Origin[mut=iterable_mut]
    ]: Iterator = DiagnosticSetIterator[mut=iterable_mut, origin=iterable_origin]

    var _tu: ArcPointer[TranslationUnitState]
    var _generation: Int
    var _raw: CXDiagnosticSet
    var _owns: Bool
    var _count: Int

    def __init__(
        out self,
        tu: TranslationUnit,
        raw: CXDiagnosticSet,
        owns: Bool = True,
    ) raises:
        """Wrap a diagnostic set tied to `tu`."""
        self._tu = tu._shared_state()
        self._generation = self._tu[].generation
        self._raw = raw
        self._owns = owns

        if raw:
            self._count = Int(clang_getNumDiagnosticsInSet(raw))
        else:
            self._count = 0

    def __init__(
        out self,
        tu: ArcPointer[TranslationUnitState],
        raw: CXDiagnosticSet,
        owns: Bool = True,
    ) raises:
        """Wrap a diagnostic set tied to a shared translation-unit state."""
        self._tu = tu
        self._generation = tu[].generation
        self._raw = raw
        self._owns = owns

        if raw:
            self._count = Int(clang_getNumDiagnosticsInSet(raw))
        else:
            self._count = 0

    @staticmethod
    def _from_handle(
        tu: ArcPointer[TranslationUnitState],
        raw: CXDiagnosticSet,
        owns: Bool = True,
    ) raises -> Self:
        return Self(tu=tu, raw=raw, owns=owns)

    def _check_valid(self) raises:
        if not self._tu[].alive:
            raise Error("DiagnosticSet used after TranslationUnit disposal")

        if self._generation != self._tu[].generation:
            raise Error("DiagnosticSet used after TranslationUnit.reparse()")

        if not self._raw:
            raise Error("DiagnosticSet contains null CXDiagnosticSet")

    def write_to(self, mut writer: Some[Writer]):
        writer.write("DiagnosticSet(count=", self._count, ")")

    def __len__(self) -> Int:
        """Return the number of diagnostics in this set."""
        return self._count

    def __getitem__(ref self, i: Int) raises -> Diagnostic:
        """Return diagnostic `i` from this set."""
        self._check_valid()

        if i < 0 or i >= Int(clang_getNumDiagnosticsInSet(self._raw)):
            raise Error("DiagnosticSet index out of range")

        return Diagnostic(
            tu=self._tu,
            raw=clang_getDiagnosticInSet(self._raw, c_uint(i)),
            owns=True,
        )

    def __iter__(ref self) -> Self.IteratorType[origin_of(self)]:
        return DiagnosticSetIterator[origin_of(self)](self)

    def __del__(deinit self):
        if self._owns:
            if self._raw:
                clang_disposeDiagnosticSet(self._raw)

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
  """

from src._ffi import (
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

from src.libclang.enums import DiagnosticSeverity, DiagnosticDisplayOptions
from src.libclang.common import _CXStringStorage
from src.libclang.state import TranslationUnitState
from src.libclang.source_location import SourceLocation
from src.libclang.source_range import SourceRange
from src._ffi import clang_disposeDiagnosticSet


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

    ```
    The diagnostic keeps its originating translation unit alive so that
    locations, ranges, and fix-its can safely create TU-borrowed wrappers.
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
        self._tu = tu.state()
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
        self._tu = tu
        self._generation = tu[].generation
        self._raw = raw
        self._owns = owns
        self._formatted = String()

        if raw:
            self._cache_format()

    def _check_valid(self) raises:
        if not self._tu[].alive:
            raise Error("Diagnostic used after TranslationUnit disposal")

        if self._generation != self._tu[].generation:
            raise Error("Diagnostic used after TranslationUnit.reparse()")

        if not self._raw:
            raise Error("Diagnostic contains null CXDiagnostic")

    def _cache_format(mut self) raises:
        self._check_valid()

        var options = DiagnosticDisplayOptions(
            clang_defaultDiagnosticDisplayOptions(),
        )
        var cs = _CXStringStorage()
        clang_formatDiagnostic(cs.ptr_for_out(), self._raw, options.as_c_uint())
        self._formatted = cs.take()

    def write_to(self, mut writer: Some[Writer]):
        writer.write("Diagnostic(", self._formatted, ")")

    def severity(ref self) raises -> DiagnosticSeverity:
        self._check_valid()
        return DiagnosticSeverity(clang_getDiagnosticSeverity(self._raw))

    def spelling(ref self) raises -> String:
        self._check_valid()

        var cs = _CXStringStorage()
        clang_getDiagnosticSpelling(cs.ptr_for_out(), self._raw)
        return cs.take()

    def location(ref self) raises -> SourceLocation:
        self._check_valid()

        var out = SourceLocation(tu=self._tu)
        clang_getDiagnosticLocation(out._ptr(), self._raw)
        out._cache_from_ffi()
        return out^

    def category_number(ref self) raises -> c_uint:
        self._check_valid()
        return clang_getDiagnosticCategory(self._raw)

    def category_name(ref self) raises -> String:
        self._check_valid()

        var cs = _CXStringStorage()
        clang_getDiagnosticCategoryText(cs.ptr_for_out(), self._raw)
        return cs.take()

    def option(ref self) raises -> String:
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

    def num_ranges(ref self) raises -> c_uint:
        self._check_valid()
        return clang_getDiagnosticNumRanges(self._raw)

    def range(ref self, i: c_uint) raises -> SourceRange:
        self._check_valid()

        if i >= self.num_ranges():
            raise Error("Diagnostic.range: index out of range")

        var out = SourceRange(tu=self._tu)
        clang_getDiagnosticRange(out._ptr(), self._raw, i)
        return out^

    def num_fixits(ref self) raises -> c_uint:
        self._check_valid()
        return clang_getDiagnosticNumFixIts(self._raw)

    def fixit(ref self, i: c_uint) raises -> FixIt:
        self._check_valid()

        if i >= self.num_fixits():
            raise Error("Diagnostic.fixit: index out of range")

        var range_out = SourceRange(tu=self._tu)
        var cs = _CXStringStorage()

        clang_getDiagnosticFixIt(
            cs.ptr_for_out(),
            self._raw,
            i,
            range_out._ptr(),
        )

        return FixIt(range=range_out^, value=cs.take())

    def children(ref self) raises -> DiagnosticSet:
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
        self._check_valid()

        var opts = options
        if opts == DiagnosticDisplayOptions.DEFAULT:
            opts = DiagnosticDisplayOptions(
                clang_defaultDiagnosticDisplayOptions(),
            )
        var cs = _CXStringStorage()
        clang_formatDiagnostic(cs.ptr_for_out(), self._raw, opts.as_c_uint())
        return cs.take()

    def formatted(ref self) raises -> String:
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
](Movable):
    """Iterator over diagnostics in a `DiagnosticSet`."""

    var _tu: ArcPointer[TranslationUnitState]
    var _raw: CXDiagnosticSet
    var _index: c_uint

    def __init__(out self, ref set: DiagnosticSet):
        self._tu = set._tu
        self._raw = set._raw
        self._index = c_uint(0)

    def __next__(mut self) raises -> Diagnostic:
        if self._index >= clang_getNumDiagnosticsInSet(self._raw):
            raise StopIteration()

        var raw = clang_getDiagnosticInSet(self._raw, self._index)
        self._index += 1
        return Diagnostic(tu=self._tu, raw=raw, owns=True)


struct DiagnosticSet(Movable, Sized, Writable):
    """Wrapper around `CXDiagnosticSet`.

    ```
    A `DiagnosticSet` may either own the raw diagnostic set or borrow it,
    depending on where the set came from.
    """

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
        self._tu = tu.state()
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
        return self._count

    def __getitem__(ref self, i: c_uint) raises -> Diagnostic:
        self._check_valid()

        if i >= clang_getNumDiagnosticsInSet(self._raw):
            raise Error("DiagnosticSet index out of range")

        return Diagnostic(
            tu=self._tu,
            raw=clang_getDiagnosticInSet(self._raw, i),
            owns=True,
        )

    def __iter__(ref self) -> DiagnosticSetIterator[mut=False, origin=origin_of(self)]:
        return DiagnosticSetIterator[mut=False, origin=origin_of(self)](self)

    def __del__(deinit self):
        if self._owns:
            if self._raw:
                clang_disposeDiagnosticSet(self._raw)

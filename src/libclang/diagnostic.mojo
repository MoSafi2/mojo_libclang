"""`Diagnostic`, `DiagnosticSet`, and `FixIt` wrappers."""
from src._ffi import (
    CXDiagnostic,
    CXDiagnosticSet,
    CXDiagnosticSeverity,
    CXString,
    CXSourceRange,
    CXTranslationUnit,
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
    clang_disposeString,
)
from src.libclang.common import _CXStringStorage
from src.libclang.source_location import SourceLocation
from src.libclang.source_range import SourceRange
from std.memory import UnsafePointer


@fieldwise_init
struct FixIt(Copyable, Movable):
    """A `clang::FixIt` replacement suggestion."""

    var range: SourceRange
    var value: String


@fieldwise_init
struct Diagnostic(Movable):
    """Owning wrapper around `CXDiagnostic`."""

    var _raw: CXDiagnostic

    def severity(mut self) raises -> CXDiagnosticSeverity:
        return clang_getDiagnosticSeverity(self._raw)

    def spelling(mut self) raises -> String:
        var cs = _CXStringStorage()
        clang_getDiagnosticSpelling(cs.ptr(), self._raw)
        return cs.take()

    def location(mut self) raises -> SourceLocation:
        var out = SourceLocation(tu=CXTranslationUnit())
        clang_getDiagnosticLocation(out._ptr(), self._raw)
        return out^

    def category_number(mut self) -> c_uint:
        return clang_getDiagnosticCategory(self._raw)

    def category_name(mut self) raises -> String:
        var cs = _CXStringStorage()
        clang_getDiagnosticCategoryText(cs.ptr(), self._raw)
        return cs.take()

    def option(mut self) raises -> String:
        var cs = _CXStringStorage()
        var disable = _CXStringStorage()
        clang_getDiagnosticOption(cs.ptr(), self._raw, disable.ptr())
        clang_disposeString(disable.ptr())
        return cs.take()

    def disable_option(mut self) raises -> String:
        var cs = _CXStringStorage()
        var disable = _CXStringStorage()
        clang_getDiagnosticOption(cs.ptr(), self._raw, disable.ptr())
        var value = disable.take()
        return value

    def num_ranges(mut self) -> c_uint:
        return clang_getDiagnosticNumRanges(self._raw)

    def range(mut self, i: c_uint) raises -> SourceRange:
        var out = SourceRange(tu=CXTranslationUnit())
        clang_getDiagnosticRange(out._ptr(), self._raw, i)
        return out^

    def num_fixits(mut self) -> c_uint:
        return clang_getDiagnosticNumFixIts(self._raw)

    def fixit(mut self, i: c_uint) raises -> FixIt:
        var range_out = SourceRange(tu=CXTranslationUnit())
        var cs = _CXStringStorage()
        clang_getDiagnosticFixIt(cs.ptr(), self._raw, i, range_out._ptr())
        return FixIt(range=range_out^, value=cs.take())

    def children(mut self) raises -> DiagnosticSet:
        return DiagnosticSet(_raw=clang_getChildDiagnostics(self._raw))

    def format(mut self) raises -> String:
        var options = clang_defaultDiagnosticDisplayOptions()
        var cs = _CXStringStorage()
        clang_formatDiagnostic(cs.ptr(), self._raw, options)
        return cs.take()

    def __del__(deinit self):
        try:
            clang_disposeDiagnostic(self._raw)
        except:
            pass


struct DiagnosticSet(Movable):
    """Owning wrapper around `CXDiagnosticSet`."""

    var _raw: CXDiagnosticSet
    var _index: c_uint

    def __init__(out self, raw: CXDiagnosticSet):
        self._raw = raw
        self._index = c_uint(0)

    @staticmethod
    def _from_handle(raw: CXDiagnosticSet) -> Self:
        return Self(raw)

    def __len__(self) raises -> c_uint:
        return clang_getNumDiagnosticsInSet(self._raw)

    def __getitem__(self, i: c_uint) raises -> Diagnostic:
        if i >= clang_getNumDiagnosticsInSet(self._raw):
            raise Error("DiagnosticSet index out of range")
        return Diagnostic(_raw=clang_getDiagnosticInSet(self._raw, i))

    def __iter__(mut self) -> Self:
        self._index = c_uint(0)
        return self^

    def __next__(mut self) raises -> Diagnostic:
        if self._index >= clang_getNumDiagnosticsInSet(self._raw):
            raise StopIteration()
        var n = clang_getNumDiagnosticsInSet(self._raw)
        var result = Diagnostic(
            _raw=clang_getDiagnosticInSet(self._raw, self._index),
        )
        self._index += 1
        _ = n
        return result^

    def __del__(deinit self):
        from src._ffi import clang_disposeDiagnosticSet
        try:
            clang_disposeDiagnosticSet(self._raw)
        except:
            pass

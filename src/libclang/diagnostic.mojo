"""`Diagnostic`, `DiagnosticSet`, and `FixIt` wrappers."""
from src.libclang_raw import (
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
    clang_getDiagnosticLocation_into,
    clang_getDiagnosticRange_into,
    clang_getDiagnosticFixIt_into,
    clang_getDiagnosticFixIt_text,
    clang_getNumDiagnosticsInSet,
    clang_getDiagnosticInSet,
    clang_getChildDiagnostics,
    clang_formatDiagnostic,
    clang_defaultDiagnosticDisplayOptions,
    clang_disposeDiagnostic,
    clang_disposeString,
)
from src.libclang.common import take_cxstring
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
        return take_cxstring(clang_getDiagnosticSpelling(self._raw))

    def location(mut self) raises -> SourceLocation:
        # Diagnostic locations do not depend on a TU; the empty TU is fine.
        var out = SourceLocation(tu=CXTranslationUnit())
        clang_getDiagnosticLocation_into(out._ptr(), self._raw)
        return out^

    def category_number(mut self) -> c_uint:
        return clang_getDiagnosticCategory(self._raw)

    def category_name(mut self) raises -> String:
        return take_cxstring(clang_getDiagnosticCategoryText(self._raw))

    def option(mut self) raises -> String:
        var disable = CXString(data=None, private_flags=c_uint(0))
        var result = take_cxstring(
            clang_getDiagnosticOption(self._raw, UnsafePointer.address_of(disable)),
        )
        clang_disposeString(disable)
        return result

    def disable_option(mut self) raises -> String:
        var disable = CXString(data=None, private_flags=c_uint(0))
        _ = take_cxstring(clang_getDiagnosticOption(self._raw, UnsafePointer.address_of(disable)))
        var value = take_cxstring(disable)
        return value

    def num_ranges(mut self) -> c_uint:
        return clang_getDiagnosticNumRanges(self._raw)

    def range(mut self, i: c_uint) raises -> SourceRange:
        var out = SourceRange(tu=CXTranslationUnit())
        clang_getDiagnosticRange_into(out._ptr(), self._raw, i)
        return out^

    def num_fixits(mut self) -> c_uint:
        return clang_getDiagnosticNumFixIts(self._raw)

    def fixit(mut self, i: c_uint) raises -> FixIt:
        var range_out = SourceRange(tu=CXTranslationUnit())
        var value = take_cxstring(clang_getDiagnosticFixIt_text(self._raw, i))
        clang_getDiagnosticFixIt_into(range_out._ptr(), self._raw, i)
        return FixIt(range=range_out^, value=value)

    def children(mut self) raises -> DiagnosticSet:
        return DiagnosticSet(_raw=clang_getChildDiagnostics(self._raw))

    def format(mut self) raises -> String:
        var options = clang_defaultDiagnosticDisplayOptions()
        return take_cxstring(clang_formatDiagnostic(self._raw, options))

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
        var result = Diagnostic(_raw=clang_getDiagnosticInSet(self._raw, self._index))
        self._index += 1
        _ = n
        return result^

    def __del__(deinit self):
        from src.libclang_raw import clang_disposeDiagnosticSet
        try:
            clang_disposeDiagnosticSet(self._raw)
        except:
            pass

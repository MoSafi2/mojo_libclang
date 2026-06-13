"""`TranslationUnit` — owns a `CXTranslationUnit` and exposes queries."""
from src.libclang_raw import (
    CXTranslationUnit,
    CXFile,
    CXUnsavedFile,
    CXSourceLocation,
    CXSourceRange,
    CXCursor,
    clang_disposeTranslationUnit,
    clang_getTranslationUnitSpelling,
    clang_getTranslationUnitCursor_ref,
    clang_getNumDiagnostics,
    clang_getDiagnostic,
    clang_getDiagnosticSetFromTU,
    clang_defaultSaveOptions,
    clang_getFile,
    clang_getLocation_into,
    clang_getLocationForOffset_into,
    clang_getCursor_ref,
    clang_reparseTranslationUnit,
    clang_saveTranslationUnit,
    clang_defaultReparseOptions,
    c_uint,
    c_int,
    c_ulong,
)
from src.libclang.support import UnsavedFile, SourcePosition, SourceExtentInput
from src.libclang.common import take_cxstring, _c_string
from src.libclang.cursor import Cursor
from src.libclang.file import File
from src.libclang.source_location import SourceLocation
from src.libclang.source_range import SourceRange
from src.libclang.token import TokenGroup
from src.libclang.diagnostic import Diagnostic, DiagnosticSet
from std.memory import UnsafePointer
from std.ffi import c_char


struct TranslationUnit(Movable):
    """Owns a `CXTranslationUnit`."""

    var _raw: CXTranslationUnit

    def __init__(out self, handle: CXTranslationUnit):
        """Wrap a `CXTranslationUnit` handle produced by a shim call."""
        self._raw = handle

    def __del__(deinit self):
        try:
            clang_disposeTranslationUnit(self._raw)
        except:
            pass

    def spelling(mut self) raises -> String:
        return take_cxstring(clang_getTranslationUnitSpelling(self._raw))

    def cursor(mut self) raises -> Cursor:
        var out = Cursor(tu=self._raw)
        clang_getTranslationUnitCursor_ref(out._ptr(), self._raw)
        return out^

    def num_diagnostics(mut self) raises -> c_uint:
        return clang_getNumDiagnostics(self._raw)

    def diagnostic(mut self, index: c_uint) raises -> Diagnostic:
        return Diagnostic(_raw=clang_getDiagnostic(self._raw, index))

    def diagnostics(mut self) raises -> DiagnosticSet:
        return DiagnosticSet._from_handle(clang_getDiagnosticSetFromTU(self._raw))

    def get_file(mut self, filename: String) raises -> Optional[File]:
        return File.from_name(self._raw, filename)

    def get_location(
        mut self,
        filename: String,
        position: SourcePosition,
    ) raises -> SourceLocation:
        var pos = position.copy()
        pos.validate()
        var file_handle = clang_getFile(self._raw, _c_string(filename))
        if not file_handle:
            raise Error("TranslationUnit.get_location: unknown filename")
        if pos.is_offset_only():
            return SourceLocation.from_offset(self._raw, file_handle, pos.offset.value())
        return SourceLocation.from_position(
            self._raw,
            file_handle,
            pos.line.value(),
            pos.column.value(),
        )

    def get_location_for_offset(
        mut self,
        filename: String,
        offset: c_uint,
    ) raises -> SourceLocation:
        var file_handle = clang_getFile(self._raw, _c_string(filename))
        if not file_handle:
            raise Error("TranslationUnit.get_location_for_offset: unknown filename")
        return SourceLocation.from_offset(self._raw, file_handle, offset)

    def get_extent(
        mut self,
        filename: String,
        locations: SourceExtentInput,
    ) raises -> SourceRange:
        var start = self.get_location(
            filename,
            locations.start,
        )
        var end = self.get_location(
            filename,
            locations.end,
        )
        return SourceRange.from_locations(start, end)

    def get_tokens(mut self, extent: SourceRange) raises -> TokenGroup:
        return TokenGroup(tu=self._raw, extent=extent)

    def get_cursor(mut self, mut loc: SourceLocation) raises -> Cursor:
        var out = Cursor(tu=self._raw)
        clang_getCursor_ref(out._ptr(), self._raw, loc._ptr())
        return out^

    def save(mut self, filename: String) raises:
        var options = clang_defaultSaveOptions(self._raw)
        var result = clang_saveTranslationUnit(
            self._raw,
            _c_string(filename),
            options,
        )
        if result != 0:
            raise Error(
                "TranslationUnitSaveError: clang_saveTranslationUnit returned "
                + String(Int(result)),
            )

    def reparse(
        mut self,
        unsaved_files: List[UnsavedFile] = List[UnsavedFile](),
        var options: c_uint = 0,
    ) raises:
        if options == 0:
            options = clang_defaultReparseOptions(self._raw)
        var unsaved = _build_unsaved_files(unsaved_files)
        var result = clang_reparseTranslationUnit(
            self._raw,
            unsaved[1],
            unsaved[0],
            options,
        )
        if result != 0:
            raise Error(
                "TranslationUnitReparseError: clang_reparseTranslationUnit "
                "returned " + String(Int(result)),
            )


def _build_unsaved_files(
    files: List[UnsavedFile],
) -> Tuple[Optional[UnsafePointer[CXUnsavedFile, MutExternalOrigin]], c_uint]:
    if len(files) == 0:
        return (None, c_uint(0))
    var slot = alloc[CXUnsavedFile](len(files))
    for i in range(len(files)):
        var f = files[i].copy()
        slot[i] = CXUnsavedFile(
            Filename=_c_string(f.filename),
            Contents=rebind[UnsafePointer[c_char, ImmutExternalOrigin]](_c_string(f.contents)),
            Length=c_ulong(f.contents.byte_length()),
        )
    return (slot, c_uint(len(files)))

"""`TranslationUnit` — owns a `CXTranslationUnit` and exposes queries."""
from src._ffi import (
    CXTranslationUnit,
    CXFile,
    CXUnsavedFile,
    clang_disposeTranslationUnit,
    clang_getTranslationUnitSpelling,
    clang_getTranslationUnitCursor,
    clang_getNumDiagnostics,
    clang_getDiagnostic,
    clang_getDiagnosticSetFromTU,
    clang_defaultSaveOptions,
    clang_getFile,
    clang_getCursor,
    clang_reparseTranslationUnit,
    clang_saveTranslationUnit,
    clang_defaultReparseOptions,
    c_uint,
    c_int,
    c_ulong,
    clang_parseTranslationUnit2,
    clang_createTranslationUnit2,
    CXError_Success,
)
from src.libclang.common import (
    UnsavedFile,
    SourcePosition,
    SourceExtentInput,
    _c_string,
)
from src.libclang.index import IndexState, Index
from src.libclang.common import _CXStringStorage, CStringArray, UnsavedFileArena
from src.libclang.cursor import Cursor
from src.libclang.file import File
from src.libclang.source_location import SourceLocation
from src.libclang.source_range import SourceRange
from src.libclang.token import TokenGroup
from src.libclang.diagnostic import Diagnostic, DiagnosticSet
from std.memory import UnsafePointer, ArcPointer
from std.ffi import c_char


struct TranslationUnitState(Movable):
    var _raw: CXTranslationUnit
    var alive: Bool
    var generation: Int

    def __init__(
        out self,
        raw: CXTranslationUnit,
    ):
        self._raw = raw
        self.alive = True
        self.generation = 0

    def raw(self) raises -> CXTranslationUnit:
        if not self.alive:
            raise Error("TranslationUnit used after dispose")
        return self._raw

    def __del__(deinit self):
        if self.alive:
            if self._raw:
                clang_disposeTranslationUnit(self._raw)


struct TranslationUnit(Copyable, Movable, Writable):
    var _state: ArcPointer[TranslationUnitState]
    var _spelling: String

    def __init__(
        out self,
        raw: CXTranslationUnit,
    ) raises:
        if not raw:
            raise Error("TranslationUnit received null CXTranslationUnit")

        self._state = ArcPointer(TranslationUnitState(raw))
        self._spelling = String()

    def raw(self) raises -> CXTranslationUnit:
        return self._state[].raw()

    def generation(self) -> Int:
        return self._state[].generation

    def _handle(self) raises -> CXTranslationUnit:
        """Expose raw handle for internal use."""
        return self.raw()

    def write_to(self, mut writer: Some[Writer]):
        writer.write("TranslationUnit(", self._spelling, ")")

    def __len__(self) raises -> Int:
        return Int(clang_getNumDiagnostics(self.raw()))

    def spelling(mut self) raises -> String:
        var cs = _CXStringStorage()
        clang_getTranslationUnitSpelling(cs.ptr_for_out(), self.raw())
        return cs.take()

    def cursor(mut self) raises -> Cursor:
        var out = Cursor(tu=self.raw())
        clang_getTranslationUnitCursor(out._ptr(), self.raw())
        out._cache_spelling()
        return out^

    def num_diagnostics(mut self) raises -> c_uint:
        return clang_getNumDiagnostics(self.raw())

    def diagnostic(mut self, index: c_uint) raises -> Diagnostic:
        var d = Diagnostic(
            _raw=clang_getDiagnostic(self.raw(), index),
            _formatted=String(),
        )
        d._cache_format()
        return d^

    def diagnostics(mut self) raises -> DiagnosticSet:
        return DiagnosticSet._from_handle(
            clang_getDiagnosticSetFromTU(self.raw()),
        )

    def get_file(mut self, filename: String) raises -> Optional[File]:
        return File.from_name(self.raw(), filename)

    def get_location(
        mut self,
        filename: String,
        position: SourcePosition,
    ) raises -> SourceLocation:
        var pos = position.copy()
        pos.validate()
        var file_handle = clang_getFile(self.raw(), _c_string(filename))
        if not file_handle:
            raise Error("TranslationUnit.get_location: unknown filename")
        if pos.is_offset_only():
            return SourceLocation.from_offset(
                self.raw(), file_handle, pos.offset.value()
            )
        return SourceLocation.from_position(
            self.raw(),
            file_handle,
            pos.line.value(),
            pos.column.value(),
        )

    def get_location_for_offset(
        mut self,
        filename: String,
        offset: c_uint,
    ) raises -> SourceLocation:
        var file_handle = clang_getFile(self.raw(), _c_string(filename))
        if not file_handle:
            raise Error(
                "TranslationUnit.get_location_for_offset: unknown filename",
            )
        return SourceLocation.from_offset(self.raw(), file_handle, offset)

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
        return TokenGroup(tu=self.raw(), extent=extent)

    def get_cursor(mut self, mut loc: SourceLocation) raises -> Cursor:
        var out = Cursor(tu=self.raw())
        clang_getCursor(out._ptr(), self.raw(), loc._ptr())
        out._cache_spelling()
        return out^

    def save(mut self, filename: String) raises:
        var options = clang_defaultSaveOptions(self.raw())
        var result = clang_saveTranslationUnit(
            self.raw(),
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
            options = clang_defaultReparseOptions(self.raw())
        var unsaved = _build_unsaved_files(unsaved_files)
        var result = clang_reparseTranslationUnit(
            self.raw(),
            unsaved[1],
            unsaved[0],
            options,
        )
        if result != 0:
            raise Error(
                "TranslationUnitReparseError: clang_reparseTranslationUnit "
                "returned "
                + String(Int(result)),
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
            Filename=Optional[UnsafePointer[c_char, ImmutExternalOrigin]](
                _c_string(f.filename),
            ),
            Contents=Optional[UnsafePointer[c_char, ImmutExternalOrigin]](
                rebind[UnsafePointer[c_char, ImmutExternalOrigin]](
                    _c_string(f.contents),
                ),
            ),
            Length=c_ulong(f.contents.byte_length()),
        )
    return (slot, c_uint(len(files)))


def _check_translation_unit_alive(
    state: ArcPointer[TranslationUnitState],
) raises:
    if not state[].alive:
        raise Error("TranslationUnit used after disposal")


def _check_translation_unit_generation(
    state: ArcPointer[TranslationUnitState],
    generation: Int,
) raises:
    _check_translation_unit_alive(state)

    if generation != state[].generation:
        raise Error(
            "libclang object used after TranslationUnit.reparse()",
        )


def _translation_unit_raw(
    state: ArcPointer[TranslationUnitState],
) raises -> CXTranslationUnit:
    _check_translation_unit_alive(state)
    return state[].raw()

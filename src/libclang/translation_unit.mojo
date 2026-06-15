"""`TranslationUnit` — shared ARC handle for a `CXTranslationUnit`."""

from src._ffi import (
    CXTranslationUnit,
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
)

from src.libclang.common import (
    UnsavedFile,
    SourcePosition,
    SourceExtentInput,
    _c_string,
    _CXStringStorage,
    UnsavedFileArena,
)

from src.libclang.state import IndexState, TranslationUnitState

from src.libclang.cursor import Cursor
from src.libclang.file import File
from src.libclang.source_location import SourceLocation
from src.libclang.source_range import SourceRange
from src.libclang.token import TokenGroup
from src.libclang.diagnostic import Diagnostic, DiagnosticSet

from std.memory import ArcPointer


struct TranslationUnit(Copyable, Movable, Writable):
    """High-level owner handle for a `CXTranslationUnit`.

    The actual libclang handle is owned by `TranslationUnitState`.
    All derived objects should hold `ArcPointer[TranslationUnitState]`,
    not a raw `CXTranslationUnit`.
    """

    var _state: ArcPointer[TranslationUnitState]
    var _spelling: String

    def __init__(
        out self,
        index: ArcPointer[IndexState],
        raw: CXTranslationUnit,
    ) raises:
        if not raw:
            raise Error("TranslationUnit received null CXTranslationUnit")

        self._state = ArcPointer(TranslationUnitState(index, raw))
        self._spelling = String()

    def __init__(out self, *, copy: Self):
        self._state = copy._state
        self._spelling = copy._spelling

    def raw(self) raises -> CXTranslationUnit:
        return self._state[].raw()

    def state(self) -> ArcPointer[TranslationUnitState]:
        return self._state

    def generation(self) -> Int:
        return self._state[].generation

    def _handle(self) raises -> CXTranslationUnit:
        """Expose raw handle for internal FFI calls."""
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
        var out = Cursor(tu=self.state())
        clang_getTranslationUnitCursor(out._ptr(), self.raw())
        return out^

    def num_diagnostics(mut self) raises -> c_uint:
        return clang_getNumDiagnostics(self.raw())

    # def diagnostic(mut self, index: c_uint) raises -> Diagnostic:
    #     var d = Diagnostic(
    #         tu=self.state(),
    #         raw=clang_getDiagnostic(self.raw(), index),
    #     )
    #     d._cache_format()
    #     return d^

    # def diagnostics(mut self) raises -> DiagnosticSet:
    #     return DiagnosticSet._from_handle(
    #         self.state(),
    #         clang_getDiagnosticSetFromTU(self.raw()),
    #     )

    # def get_file(mut self, filename: String) raises -> Optional[File]:
    #     return File.from_name(self.state(), filename)

    def get_location(
        mut self,
        filename: String,
        position: SourcePosition,
    ) raises -> SourceLocation:
        var pos = position.copy()
        pos.validate()

        # Keep filename alive during the C call.
        var filename_owner = filename.copy()
        var file_handle = clang_getFile(
            self.raw(),
            _c_string(filename_owner),
        )

        if not file_handle:
            raise Error("TranslationUnit.get_location: unknown filename")

        if pos.is_offset_only():
            return SourceLocation.from_offset(
                self.state(),
                file_handle,
                pos.offset.value(),
            )

        return SourceLocation.from_position(
            self.state(),
            file_handle,
            pos.line.value(),
            pos.column.value(),
        )

    def get_location_for_offset(
        mut self,
        filename: String,
        offset: c_uint,
    ) raises -> SourceLocation:
        var filename_owner = filename.copy()
        var file_handle = clang_getFile(
            self.raw(),
            _c_string(filename_owner),
        )

        if not file_handle:
            raise Error(
                "TranslationUnit.get_location_for_offset: unknown filename",
            )

        return SourceLocation.from_offset(
            self.state(),
            file_handle,
            offset,
        )

    # def get_extent(
    #     mut self,
    #     filename: String,
    #     locations: SourceExtentInput,
    # ) raises -> SourceRange:
    #     locations.validate()

    #     var start = self.get_location(
    #         filename,
    #         locations.start,
    #     )
    #     var end = self.get_location(
    #         filename,
    #         locations.end,
    #     )

    #     return SourceRange.from_locations(start, end)

    # def get_tokens(mut self, extent: SourceRange) raises -> TokenGroup:
    #     return TokenGroup(tu=self.state(), extent=extent)

    def get_cursor(mut self, mut loc: SourceLocation) raises -> Cursor:
        var out = Cursor(tu=self.state())
        clang_getCursor(out._ptr(), self.raw(), loc._ptr())
        return out^

    def save(mut self, filename: String) raises:
        var filename_owner = filename.copy()
        var options = clang_defaultSaveOptions(self.raw())

        var result = clang_saveTranslationUnit(
            self.raw(),
            _c_string(filename_owner),
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

        var unsaved_arena = UnsavedFileArena(unsaved_files)

        var result = clang_reparseTranslationUnit(
            self.raw(),
            unsaved_arena.count(),
            unsaved_arena.ptr(),
            options,
        )

        if result != 0:
            raise Error(
                "TranslationUnitReparseError: clang_reparseTranslationUnit "
                "returned "
                + String(Int(result)),
            )

        self._state[].bump_generation()

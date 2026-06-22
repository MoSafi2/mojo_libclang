"""`TranslationUnit` — shared ARC handle for a `CXTranslationUnit`."""

from clang._ffi import (
    CXTranslationUnit,
    CXCodeCompleteResults,
    CXFile,
    CXSourceLocation,
    CXClientData,
    CXSourceRangeList,
    CXTargetInfo,
    CXTUResourceUsage,
    CXTUResourceUsageEntry,
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
    clang_getInclusions,
    clang_createTranslationUnit2,
    clang_parseTranslationUnit2,
    clang_suspendTranslationUnit,
    clang_getFileContents,
    clang_getSkippedRanges,
    clang_getAllSkippedRanges,
    clang_disposeSourceRangeList,
    clang_TargetInfo_dispose,
    clang_TargetInfo_getPointerWidth,
    clang_TargetInfo_getTriple,
    clang_disposeCXTUResourceUsage,
    clang_getCXTUResourceUsage,
    clang_getTUResourceUsageName,
    clang_getTranslationUnitTargetInfo,
    c_uint,
    c_ulong,
    size_t,
)

from clang.enums import TranslationUnitFlags, SaveError

from clang.common import (
    UnsavedFile,
    _CXStringStorage,
    UnsavedFileArena,
    _borrow_c_string,
)

from clang.state import IndexState, TranslationUnitState

from clang.errors import TranslationUnitLoadError, TranslationUnitSaveError
from clang.cursor import Cursor
from clang.file import File
from clang.source_location import SourceLocation
from clang.source_range import SourceRange
from clang.token import TokenGroup
from clang.diagnostic import Diagnostic, DiagnosticSet
from clang.file_inclusion import FileInclusion

from std.memory import ArcPointer, MutOpaquePointer, UnsafePointer, alloc


@fieldwise_init
struct TUResourceUsageItem(Copyable, Movable, Writable):
    var kind: c_uint
    var kind_name: String
    var amount: c_ulong


struct TargetInfo(Movable, Writable):
    var _raw: CXTargetInfo

    def __init__(out self, raw: CXTargetInfo) raises:
        if not raw:
            raise Error("TargetInfo: libclang returned null target info")
        self._raw = raw

    def __del__(deinit self):
        if self._raw:
            clang_TargetInfo_dispose(self._raw)

    def triple(ref self) raises -> String:
        var cs = _CXStringStorage()
        clang_TargetInfo_getTriple(cs.ptr_for_out(), self._raw)
        return cs.take()

    def pointer_width(ref self) -> Int:
        return Int(clang_TargetInfo_getPointerWidth(self._raw))

    def write_to(self, mut writer: Some[Writer]):
        try:
            writer.write(
                "TargetInfo(triple=",
                self.triple(),
                ", pointer_width=",
                self.pointer_width(),
                ")",
            )
        except:
            writer.write("TargetInfo(<invalid>)")


struct TUResourceUsage(Movable, Sized, Writable):
    var _raw: UnsafePointer[CXTUResourceUsage, MutAnyOrigin]
    var _owns: Bool

    def __init__(out self, raw: CXTUResourceUsage):
        self._raw = alloc[CXTUResourceUsage](1)
        self._raw[] = CXTUResourceUsage(
            data=raw.data,
            numEntries=raw.numEntries,
            entries=raw.entries,
        )
        self._owns = True

    def _ptr(ref self) -> UnsafePointer[CXTUResourceUsage, MutUntrackedOrigin]:
        return rebind[UnsafePointer[CXTUResourceUsage, MutUntrackedOrigin]](
            self._raw
        )

    def __del__(deinit self):
        if self._owns:
            clang_disposeCXTUResourceUsage(
                rebind[UnsafePointer[CXTUResourceUsage, MutUntrackedOrigin]](
                    self._raw
                )
            )
        self._raw.free()

    def __len__(self) -> Int:
        return Int(self._raw[].numEntries)

    def __getitem__(ref self, i: Int) raises -> TUResourceUsageItem:
        if i < 0 or i >= Int(self._raw[].numEntries):
            raise Error("TUResourceUsage index out of range")
        if not self._raw[].entries:
            raise Error("TUResourceUsage has no entry buffer")

        var raw = (self._raw[].entries.value() + i)[]
        var name_ptr = clang_getTUResourceUsageName(raw.kind)
        var name = String("")
        if name_ptr:
            name = String(unsafe_from_utf8_ptr=name_ptr.value())

        return TUResourceUsageItem(
            kind=c_uint(raw.kind),
            kind_name=name,
            amount=raw.amount,
        )

    def entries(ref self) raises -> List[TUResourceUsageItem]:
        var out = List[TUResourceUsageItem]()
        for i in range(Int(self._raw[].numEntries)):
            out.append(self[i])
        return out^

    def total(ref self) -> Int:
        var total = c_ulong(0)
        if not self._raw[].entries:
            return 0
        for i in range(Int(self._raw[].numEntries)):
            total += (self._raw[].entries.value() + i)[].amount
        return Int(total)

    def write_to(self, mut writer: Some[Writer]):
        writer.write(
            "TUResourceUsage(count=",
            Int(self._raw[].numEntries),
            ", total=",
            self.total(),
            ")",
        )


def target_info_for_tu(raw: CXTranslationUnit) raises -> TargetInfo:
    return TargetInfo(clang_getTranslationUnitTargetInfo(raw))


def resource_usage_for_tu(raw: CXTranslationUnit) -> TUResourceUsage:
    var out = TUResourceUsage(
        CXTUResourceUsage(
            data=Optional[MutOpaquePointer[MutUntrackedOrigin]](),
            numEntries=c_uint(0),
            entries=Optional[
                UnsafePointer[CXTUResourceUsageEntry, MutUntrackedOrigin]
            ](),
        )
    )
    clang_getCXTUResourceUsage(out._ptr(), raw)
    return out^


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
            raise TranslationUnitLoadError(
                "TranslationUnit received null CXTranslationUnit"
            )

        self._state = ArcPointer(TranslationUnitState(index, raw))
        self._spelling = String()

    def __init__(out self, state: ArcPointer[TranslationUnitState]):
        """Return a TranslationUnit that shares an existing state object.

        This does not take ownership of the raw ``CXTranslationUnit``; the
        returned wrapper keeps the shared state alive.
        """
        self._state = state
        self._spelling = String()

    def __init__(out self, *, copy: Self):
        self._state = copy._state
        self._spelling = copy._spelling

    def _raw_handle(self) raises -> CXTranslationUnit:
        return self._state[].raw()

    def _shared_state(self) -> ArcPointer[TranslationUnitState]:
        return self._state

    def _generation_id(self) -> Int:
        return self._state[].generation

    def _handle(self) raises -> CXTranslationUnit:
        """Expose raw handle for internal FFI calls."""
        return self._raw_handle()

    def write_to(self, mut writer: Some[Writer]):
        writer.write("TranslationUnit(", self._spelling, ")")

    def __len__(self) raises -> Int:
        return Int(clang_getNumDiagnostics(self._raw_handle()))

    def spelling(ref self) raises -> String:
        var cs = _CXStringStorage()
        clang_getTranslationUnitSpelling(cs.ptr_for_out(), self._raw_handle())
        return cs.take()

    def cursor(ref self) raises -> Cursor:
        var out = Cursor(tu=self._shared_state())
        clang_getTranslationUnitCursor(out._ptr(), self._raw_handle())
        return out^

    def num_diagnostics(ref self) raises -> Int:
        return Int(clang_getNumDiagnostics(self._raw_handle()))

    def diagnostic(ref self, index: Int) raises -> Diagnostic:
        if index < 0 or index >= self.num_diagnostics():
            raise Error("TranslationUnit.diagnostic: index out of range")
        var d = Diagnostic(
            tu=self._shared_state(),
            raw=clang_getDiagnostic(self._raw_handle(), c_uint(index)),
        )
        d._cache_format()
        return d^

    def diagnostics(ref self) raises -> DiagnosticSet:
        return DiagnosticSet._from_handle(
            self._shared_state(),
            clang_getDiagnosticSetFromTU(self._raw_handle()),
        )

    def file(ref self, filename: String) raises -> Optional[File]:
        return File.from_name(self._shared_state(), filename)

    def target_info(ref self) raises -> TargetInfo:
        return target_info_for_tu(self._raw_handle())

    def resource_usage(ref self) raises -> TUResourceUsage:
        return resource_usage_for_tu(self._raw_handle())

    def location(
        ref self,
        filename: String,
        line: Int,
        column: Int,
    ) raises -> SourceLocation:
        if line < 1 or column < 1:
            raise Error(
                "TranslationUnit.location: line and column must be >= 1",
            )

        return SourceLocation.from_position(
            self._shared_state(),
            self._get_file_handle(filename),
            line,
            column,
        )

    def location_for_offset(
        ref self,
        filename: String,
        offset: Int,
    ) raises -> SourceLocation:
        if offset < 0:
            raise Error("TranslationUnit.location_for_offset: offset must be >= 0")

        return SourceLocation.from_offset(
            self._shared_state(),
            self._get_file_handle(filename),
            offset,
        )

    def _get_file_handle(ref self, filename: String) raises -> CXFile:
        var file_handle = clang_getFile(
            self._raw_handle(),
            _borrow_c_string(filename),
        )
        if not file_handle:
            raise Error("TranslationUnit: unknown filename")

        return file_handle

    def extent(
        ref self,
        filename: String,
        start: SourceLocation,
        end: SourceLocation,
    ) raises -> SourceRange:
        return SourceRange.from_locations(start, end)

    def extent(
        ref self,
        filename: String,
        start_line: Int,
        start_column: Int,
        end_line: Int,
        end_column: Int,
    ) raises -> SourceRange:
        var start = self.location(filename, start_line, start_column)
        var end = self.location(filename, end_line, end_column)
        return SourceRange.from_locations(start, end)

    def extent_from_offsets(
        ref self,
        filename: String,
        start_offset: Int,
        end_offset: Int,
    ) raises -> SourceRange:
        if start_offset < 0 or end_offset < 0:
            raise Error(
                "TranslationUnit.extent_from_offsets: offsets must be >= 0",
            )
        var start = self.location_for_offset(filename, start_offset)
        var end = self.location_for_offset(filename, end_offset)
        return SourceRange.from_locations(start, end)

    def tokens(ref self, extent: SourceRange) raises -> TokenGroup:
        return TokenGroup(tu=self._shared_state(), extent=extent)

    def cursor_for_location(ref self, ref loc: SourceLocation) raises -> Cursor:
        var out = Cursor(tu=self._shared_state())
        clang_getCursor(out._ptr(), self._raw_handle(), loc._ptr())
        return out^

    def save(
        ref self,
        filename: String,
        options: TranslationUnitFlags = TranslationUnitFlags.NONE,
    ) raises:
        var opts = options
        if opts == TranslationUnitFlags.NONE:
            opts = TranslationUnitFlags(clang_defaultSaveOptions(self._raw_handle()))
        var result_raw = clang_saveTranslationUnit(
            self._raw_handle(),
            _borrow_c_string(filename),
            opts.as_c_uint(),
        )
        var result = SaveError(c_uint(result_raw))
        if result != SaveError.NONE:
            raise TranslationUnitSaveError(
                result,
                "save failed: " + String(Int(result.as_c_uint())),
            )

    def reparse(
        ref self,
        unsaved_files: List[UnsavedFile] = List[UnsavedFile](),
        options: TranslationUnitFlags = TranslationUnitFlags.NONE,
    ) raises:
        var opts = options
        if opts == TranslationUnitFlags.NONE:
            opts = TranslationUnitFlags(clang_defaultReparseOptions(self._raw_handle()))

        var unsaved_arena = UnsavedFileArena(unsaved_files)

        var result = clang_reparseTranslationUnit(
            self._raw_handle(),
            unsaved_arena.count(),
            unsaved_arena.ptr(),
            opts.as_c_uint(),
        )

        if result != 0:
            raise TranslationUnitLoadError(
                "reparse failed: clang_reparseTranslationUnit returned "
                + String(Int(result)),
            )

        self._state[].bump_generation()

    def suspend(ref self) raises -> Bool:
        return Bool(clang_suspendTranslationUnit(self._raw_handle()))

    def file_contents(ref self, file: File) raises -> String:
        var size = size_t(0)
        var size_ptr = UnsafePointer[size_t, MutAnyOrigin](to=size)
        var raw = clang_getFileContents(
            self._raw_handle(),
            file._raw_value(),
            rebind[UnsafePointer[size_t, MutUntrackedOrigin]](size_ptr),
        )
        if not raw:
            return String("")
        return String(unsafe_from_utf8_ptr=raw.value())

    def file_contents(ref self, filename: String) raises -> String:
        var file_opt = self.file(filename)
        if not file_opt:
            raise Error("TranslationUnit.file_contents: unknown filename")
        return self.file_contents(file_opt.value())

    def skipped_ranges(ref self, file: File) raises -> List[SourceRange]:
        var out = List[SourceRange]()
        var raw_list = clang_getSkippedRanges(self._raw_handle(), file._raw_value())
        if not raw_list:
            return out^
        for i in range(Int(raw_list.value()[].count)):
            var raw = (raw_list.value()[].ranges.value() + i)[].copy()
            out.append(SourceRange.from_raw(self._shared_state(), raw))
        clang_disposeSourceRangeList(raw_list.value())
        return out^

    def skipped_ranges(ref self, filename: String) raises -> List[SourceRange]:
        var file_opt = self.file(filename)
        if not file_opt:
            raise Error("TranslationUnit.skipped_ranges: unknown filename")
        return self.skipped_ranges(file_opt.value())

    def all_skipped_ranges(ref self) raises -> List[SourceRange]:
        var out = List[SourceRange]()
        var raw_list = clang_getAllSkippedRanges(self._raw_handle())
        if not raw_list:
            return out^
        for i in range(Int(raw_list.value()[].count)):
            var raw = (raw_list.value()[].ranges.value() + i)[].copy()
            out.append(SourceRange.from_raw(self._shared_state(), raw))
        clang_disposeSourceRangeList(raw_list.value())
        return out^

    # -----------------------------------------------------------------------
    # Classmethod construction
    # -----------------------------------------------------------------------

    @staticmethod
    def from_source(
        filename: String,
        args: List[String] = List[String](),
        unsaved_files: List[UnsavedFile] = List[UnsavedFile](),
        options: TranslationUnitFlags = TranslationUnitFlags.NONE,
        index: Optional[Index] = None,
    ) raises -> TranslationUnit:
        """Parse a source file into a ``TranslationUnit``.

        If ``index`` is not provided, a default ``Index`` is created and kept
        alive by the returned translation unit.
        """
        from clang.index import Index

        var idx: Index
        if index:
            idx = index.value().copy()
        else:
            idx = Index()

        return idx.parse(filename, args, unsaved_files, options)

    @staticmethod
    def from_ast_file(
        filename: String,
        index: Optional[Index] = None,
    ) raises -> TranslationUnit:
        """Load a serialized AST file into a ``TranslationUnit``."""
        from clang.index import Index

        var idx: Index
        if index:
            idx = index.value().copy()
        else:
            idx = Index()

        return idx.read(filename)

    # -----------------------------------------------------------------------
    # Includes
    # -----------------------------------------------------------------------

    def includes(ref self) raises -> List[FileInclusion]:
        """Return all inclusion relationships in this translation unit."""
        var collector_box = alloc[_InclusionCollector](1)
        collector_box.init_pointee_move(
            _InclusionCollector(
                tu=self._state,
                out=List[FileInclusion](),
            )
        )

        var client_data = CXClientData(
            rebind[MutOpaquePointer[MutUntrackedOrigin]](
                rebind[UnsafePointer[UInt8, MutUntrackedOrigin]](
                    rebind[UnsafePointer[UInt8, MutAnyOrigin]](
                        collector_box,
                    )
                )
            )
        )

        clang_getInclusions(
            self._raw_handle(),
            _inclusion_visitor_trampoline,
            client_data,
        )

        var out = List[FileInclusion]()
        for i in range(len(collector_box[].out)):
            out.append(collector_box[].out[i].copy())
        collector_box.free()
        return out^


@fieldwise_init
struct _InclusionCollector(Movable):
    var tu: ArcPointer[TranslationUnitState]
    var out: List[FileInclusion]


def _inclusion_visitor_trampoline(
    included_file: CXFile,
    inclusion_stack: Optional[
        UnsafePointer[CXSourceLocation, MutUntrackedOrigin]
    ],
    include_len: c_uint,
    client_data: CXClientData,
) abi("C") -> None:
    if not included_file:
        return

    if not inclusion_stack or include_len == c_uint(0):
        return

    var opaque = client_data.value()
    var collector = rebind[UnsafePointer[_InclusionCollector, MutAnyOrigin]](
        rebind[UnsafePointer[UInt8, MutAnyOrigin]](
            rebind[UnsafePointer[UInt8, MutUntrackedOrigin]](opaque),
        ),
    )

    try:
        var source_loc_raw = (
            inclusion_stack.value() + Int(include_len) - 1
        )[].copy()
        var source_loc = SourceLocation.from_raw(collector[].tu, source_loc_raw)

        var source_file_opt = source_loc.file()
        if not source_file_opt:
            return

        var included_f = File(tu=collector[].tu, raw=included_file)
        var inclusion = FileInclusion(
            source=source_file_opt.value().copy(),
            included=included_f.copy(),
            location=source_loc.copy(),
            depth=Int(include_len),
        )
        collector[].out.append(inclusion^)
    except:
        return

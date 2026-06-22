"""Advanced high-level libclang wrappers built on top of the stable raw FFI."""

from clang._ffi import (
    CXCursor,
    CXCursorSet,
    CXEvalResult,
    CXEvalResultKind,
    CXFile,
    CXModule,
    CXPlatformAvailability,
    CXString,
    CXSourceLocation,
    CXTargetInfo,
    CXTranslationUnit,
    CXType,
    CXTUResourceUsage,
    CXTUResourceUsageEntry,
    clang_CXCursorSet_contains,
    clang_CXCursorSet_insert,
    clang_Cursor_Evaluate,
    clang_EvalResult_dispose,
    clang_EvalResult_getAsDouble,
    clang_EvalResult_getAsInt,
    clang_EvalResult_getAsLongLong,
    clang_EvalResult_getAsStr,
    clang_EvalResult_getAsUnsigned,
    clang_EvalResult_getKind,
    clang_EvalResult_isUnsignedInt,
    clang_Module_getASTFile,
    clang_Module_getFullName,
    clang_Module_getName,
    clang_Module_getNumTopLevelHeaders,
    clang_Module_getParent,
    clang_Module_getTopLevelHeader,
    clang_Module_isSystem,
    clang_TargetInfo_dispose,
    clang_TargetInfo_getPointerWidth,
    clang_TargetInfo_getTriple,
    clang_createCXCursorSet,
    clang_disposeCXCursorSet,
    clang_disposeCXTUResourceUsage,
    clang_disposeCXPlatformAvailability,
    clang_getCXTUResourceUsage,
    clang_getCString,
    clang_getTUResourceUsageName,
    clang_getTranslationUnitTargetInfo,
    c_double,
    c_int,
    c_long_long,
    c_uint,
    c_ulong,
    c_ulong_long,
)

from clang.common import _CXStringStorage
from clang.common import _take_cxstring, _take_cxstring_optional
from clang.file import File
from clang.source_location import SourceLocation
from clang.state import TranslationUnitState

from std.collections import InlineArray, List
from std.memory import ArcPointer, MutOpaquePointer, UnsafePointer, alloc


@fieldwise_init
struct VersionTriple(Copyable, Movable, Writable):
    var major: Int
    var minor: Int
    var subminor: Int


@fieldwise_init
struct PlatformAvailability(Copyable, Movable, Writable):
    var platform: String
    var introduced: VersionTriple
    var deprecated: VersionTriple
    var obsoleted: VersionTriple
    var unavailable: Bool
    var message: Optional[String]


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


@fieldwise_init
struct Module(Copyable, Movable, Writable):
    var _tu: ArcPointer[TranslationUnitState]
    var _generation: Int
    var _raw: CXModule

    def _check_valid(self) raises:
        if not self._tu[].alive:
            raise Error("Module used after TranslationUnit disposal")
        if self._generation != self._tu[].generation:
            raise Error("Module used after TranslationUnit.reparse()")

    def name(ref self) raises -> String:
        self._check_valid()
        var cs = _CXStringStorage()
        clang_Module_getName(cs.ptr_for_out(), self._raw)
        return cs.take()

    def full_name(ref self) raises -> String:
        self._check_valid()
        var cs = _CXStringStorage()
        clang_Module_getFullName(cs.ptr_for_out(), self._raw)
        return cs.take()

    def is_system(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_Module_isSystem(self._raw))

    def ast_file(ref self) raises -> Optional[File]:
        self._check_valid()
        return File.from_handle(self._tu, clang_Module_getASTFile(self._raw))

    def parent(ref self) raises -> Optional[Module]:
        self._check_valid()
        var parent_raw = clang_Module_getParent(self._raw)
        if not parent_raw:
            return None
        return Optional[Module](
            Module(
                _tu=self._tu,
                _generation=self._generation,
                _raw=parent_raw,
            )
        )

    def top_level_headers(ref self) raises -> List[File]:
        self._check_valid()
        var out = List[File]()
        var count = clang_Module_getNumTopLevelHeaders(
            self._tu[].raw(), self._raw
        )
        for i in range(Int(count)):
            var header = clang_Module_getTopLevelHeader(
                self._tu[].raw(),
                self._raw,
                c_uint(i),
            )
            if header:
                out.append(File(tu=self._tu, raw=header))
        return out^

    def write_to(self, mut writer: Some[Writer]):
        try:
            writer.write("Module(", self.full_name(), ")")
        except:
            writer.write("Module(<invalid>)")


struct EvalResult(Movable, Writable):
    var _raw: CXEvalResult

    def __init__(out self, raw: CXEvalResult) raises:
        if not raw:
            raise Error("EvalResult: libclang returned null")
        self._raw = raw

    def __del__(deinit self):
        if self._raw:
            clang_EvalResult_dispose(self._raw)

    def kind(ref self) -> Int:
        return Int(clang_EvalResult_getKind(self._raw))

    def as_int(ref self) -> Int:
        return Int(clang_EvalResult_getAsInt(self._raw))

    def as_long_long(ref self) -> Int:
        return Int(clang_EvalResult_getAsLongLong(self._raw))

    def is_unsigned_int(ref self) -> Bool:
        return Bool(clang_EvalResult_isUnsignedInt(self._raw))

    def as_unsigned(ref self) -> Int:
        return Int(clang_EvalResult_getAsUnsigned(self._raw))

    def as_double(ref self) -> Float64:
        return Float64(clang_EvalResult_getAsDouble(self._raw))

    def as_string(ref self) -> Optional[String]:
        var ptr = clang_EvalResult_getAsStr(self._raw)
        if not ptr:
            return None
        return Optional[String](String(unsafe_from_utf8_ptr=ptr.value()))

    def write_to(self, mut writer: Some[Writer]):
        writer.write("EvalResult(kind=", Int(self.kind()), ")")


struct CursorSet(Movable, Writable):
    var _raw: CXCursorSet

    def __init__(out self) raises:
        self._raw = clang_createCXCursorSet()
        if not self._raw:
            raise Error("CursorSet: clang_createCXCursorSet returned null")

    def __del__(deinit self):
        if self._raw:
            clang_disposeCXCursorSet(self._raw)

    def contains(ref self, ref cursor: Cursor) raises -> Bool:
        cursor._check_valid()
        return Bool(clang_CXCursorSet_contains(self._raw, cursor._ptr()))

    def insert(ref self, ref cursor: Cursor) raises -> Bool:
        cursor._check_valid()
        return Bool(clang_CXCursorSet_insert(self._raw, cursor._ptr()))

    def write_to(self, mut writer: Some[Writer]):
        writer.write("CursorSet()")


def target_info_for_tu(raw: CXTranslationUnit) raises -> TargetInfo:
    return TargetInfo(clang_getTranslationUnitTargetInfo(raw))


def resource_usage_for_tu(raw: CXTranslationUnit) -> TUResourceUsage:
    var out = TUResourceUsage(
        CXTUResourceUsage(
            data=Optional[MutOpaquePointer[MutUntrackedOrigin]](),
            numEntries=c_uint(0),
            entries=Optional[UnsafePointer[CXTUResourceUsageEntry, MutUntrackedOrigin]](),
        )
    )
    clang_getCXTUResourceUsage(out._ptr(), raw)
    return out^


def wrap_module(
    tu: ArcPointer[TranslationUnitState],
    raw: CXModule,
) -> Optional[Module]:
    if not raw:
        return None
    return Optional[Module](
        Module(
            _tu=tu,
            _generation=tu[].generation,
            _raw=raw,
        )
    )


def copy_platform_availabilities(
    raw_items: UnsafePointer[CXPlatformAvailability, MutUntrackedOrigin],
    count: Int,
) raises -> List[PlatformAvailability]:
    var out = List[PlatformAvailability]()
    for i in range(count):
        var raw_ptr = raw_items + i
        out.append(
            PlatformAvailability(
                platform=_take_cxstring_value(raw_ptr[].Platform),
                introduced=VersionTriple(
                    major=Int(raw_ptr[].Introduced.Major),
                    minor=Int(raw_ptr[].Introduced.Minor),
                    subminor=Int(raw_ptr[].Introduced.Subminor),
                ),
                deprecated=VersionTriple(
                    major=Int(raw_ptr[].Deprecated.Major),
                    minor=Int(raw_ptr[].Deprecated.Minor),
                    subminor=Int(raw_ptr[].Deprecated.Subminor),
                ),
                obsoleted=VersionTriple(
                    major=Int(raw_ptr[].Obsoleted.Major),
                    minor=Int(raw_ptr[].Obsoleted.Minor),
                    subminor=Int(raw_ptr[].Obsoleted.Subminor),
                ),
                unavailable=Bool(raw_ptr[].Unavailable),
                message=_take_cxstring_optional_value(raw_ptr[].Message),
            )
        )
    return out^


def _take_cxstring_value(raw: CXString) raises -> String:
    var slot = alloc[CXString](1)
    slot[] = CXString(data=raw.data, private_flags=raw.private_flags)
    var ptr = rebind[UnsafePointer[CXString, MutUntrackedOrigin]](slot)
    var out = _take_cxstring(ptr)
    slot.free()
    return out


def _take_cxstring_optional_value(raw: CXString) raises -> Optional[String]:
    var slot = alloc[CXString](1)
    slot[] = CXString(data=raw.data, private_flags=raw.private_flags)
    var ptr = rebind[UnsafePointer[CXString, MutUntrackedOrigin]](slot)
    var out = _take_cxstring_optional(ptr)
    slot.free()
    return out

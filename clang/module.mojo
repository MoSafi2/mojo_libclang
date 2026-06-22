"""High-level `CXModule` wrapper."""

from clang._ffi import (
    CXModule,
    clang_Module_getASTFile,
    clang_Module_getFullName,
    clang_Module_getName,
    clang_Module_getNumTopLevelHeaders,
    clang_Module_getParent,
    clang_Module_getTopLevelHeader,
    clang_Module_isSystem,
    c_uint,
)

from clang.common import _CXStringStorage
from clang.file import File
from clang.state import TranslationUnitState

from std.collections import List
from std.memory import ArcPointer


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

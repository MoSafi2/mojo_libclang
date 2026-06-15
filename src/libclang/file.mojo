"""`File` — borrowed `CXFile` handle from a `TranslationUnit`.

A `File` is a borrowed libclang file handle plus an ARC keepalive reference to
the owning `TranslationUnitState`.

Important:

* `CXFile` is not independently owned by this wrapper.
* The owning translation unit is kept alive through `ArcPointer[TranslationUnitState]`.
* The file becomes stale after `TranslationUnit.reparse()` if the generation changes.
  """

from src._ffi import (
    CXFile,
    clang_getFile,
    clang_getFileName,
    clang_getFileTime,
    clang_File_tryGetRealPathName,
    clang_File_isEqual,
    clang_isFileMultipleIncludeGuarded,
    time_t,
    CXTranslationUnit,
)

from src.libclang.common import _c_string, _CXStringStorage, _alloc_c_string
from src.libclang.state import TranslationUnitState

from std.memory import ArcPointer


@fieldwise_init
struct File(Copyable, Movable, Writable):
    """A `CXFile` borrowed from a `TranslationUnit`.

    ```
    This object keeps the underlying translation unit alive by storing
    `ArcPointer[TranslationUnitState]`.
    """

    var _tu: ArcPointer[TranslationUnitState]
    var _generation: Int
    var _raw: CXFile
    var _name: String

    def __init__(
        out self,
        tu: TranslationUnit,
        raw: CXFile,
    ) raises:
        self._tu = tu.state()
        self._generation = self._tu[].generation
        self._raw = raw
        self._name = String()

        if raw:
            self._cache_name()

    def __init__(
        out self,
        tu: ArcPointer[TranslationUnitState],
        raw: CXFile,
    ) raises:
        self._tu = tu
        self._generation = tu[].generation
        self._raw = raw
        self._name = String()

        if raw:
            self._cache_name()

    def __init__(out self, *, copy: Self):
        self._tu = copy._tu
        self._generation = copy._generation
        self._raw = copy._raw
        self._name = copy._name

    def _check_valid(self) raises:
        if not self._tu[].alive:
            raise Error("File used after TranslationUnit disposal")

        if self._generation != self._tu[].generation:
            raise Error("File used after TranslationUnit.reparse()")

    def raw_value(ref self) raises -> CXFile:
        """Return the raw ``CXFile`` handle."""
        self._check_valid()
        return self._raw

    def _tu_raw(self) raises -> CXTranslationUnit:
        self._check_valid()
        return self._tu[].raw()

    def _cache_name(mut self) raises:
        self._check_valid()

        self._name = String()
        if self._raw:
            var cs = _CXStringStorage()
            clang_getFileName(cs.ptr_for_out(), self._raw)
            self._name = cs.take()

    @staticmethod
    def null(tu: TranslationUnit) raises -> Self:
        return Self(tu=tu, raw=CXFile(None))

    @staticmethod
    def null(tu: ArcPointer[TranslationUnitState]) raises -> Self:
        return Self(tu=tu, raw=CXFile(None))

    @staticmethod
    def from_handle(
        tu: TranslationUnit,
        handle: CXFile,
    ) raises -> Optional[Self]:
        if not handle:
            return None

        var result = Self(tu=tu, raw=handle)
        return Optional[Self](result^)

    @staticmethod
    def from_handle(
        tu: ArcPointer[TranslationUnitState],
        handle: CXFile,
    ) raises -> Optional[Self]:
        if not handle:
            return None

        var result = Self(tu=tu, raw=handle)
        return Optional[Self](result^)

    @staticmethod
    def from_name(
        tu: TranslationUnit,
        filename: String,
    ) raises -> Optional[Self]:
        var tu_state = tu.state()
        if not tu_state[].alive:
            raise Error("File.from_name: TranslationUnit used after disposal")

        var filename_c = _alloc_c_string(filename)

        var handle = clang_getFile(
            tu_state[].raw(),
            _c_string(filename_c),
        )

        filename_c.free()

        if not handle:
            return None

        var result = Self(tu=tu_state, raw=handle)
        return Optional[Self](result^)

    @staticmethod
    def from_name(
        tu: ArcPointer[TranslationUnitState],
        filename: String,
    ) raises -> Optional[Self]:
        if not tu[].alive:
            raise Error("File.from_name: TranslationUnit used after disposal")

        var filename_c = _alloc_c_string(filename)

        var handle = clang_getFile(
            tu[].raw(),
            _c_string(filename_c),
        )

        filename_c.free()

        if not handle:
            return None

        var result = Self(tu=tu, raw=handle)
        return Optional[Self](result^)

    def write_to(self, mut writer: Some[Writer]):
        writer.write("File(", self._name, ")")

    def name(mut self) raises -> String:
        self._check_valid()

        if not self._name:
            self._cache_name()

        return self._name

    def time(ref self) raises -> time_t:
        self._check_valid()
        return clang_getFileTime(self._raw)

    def real_path(ref self) raises -> String:
        self._check_valid()

        var cs = _CXStringStorage()
        clang_File_tryGetRealPathName(cs.ptr_for_out(), self._raw)
        return cs.take()

    def is_multiple_include_guarded(ref self) raises -> Bool:
        self._check_valid()
        return Bool(
            clang_isFileMultipleIncludeGuarded(
                self._tu[].raw(),
                self._raw,
            )
        )

    def __eq__(ref self, ref other: Self) raises -> Bool:
        self._check_valid()
        other._check_valid()

        if self._generation != other._generation:
            return False

        if self._tu[].raw() != other._tu[].raw():
            return False

        return Bool(clang_File_isEqual(self._raw, other._raw))

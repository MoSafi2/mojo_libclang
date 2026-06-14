"""`File` — borrowed `CXFile` handle from a `TranslationUnit`."""
from src._ffi import (
    CXFile,
    CXTranslationUnit,
    clang_getFile,
    clang_getFileName,
    clang_getFileTime,
    clang_File_tryGetRealPathName,
    clang_File_isEqual,
    clang_isFileMultipleIncludeGuarded,
    time_t,
)
from src.libclang.common import _c_string, _CXStringStorage


@fieldwise_init
struct File(Copyable, Movable):
    """A `CXFile` borrowed from a `TranslationUnit`."""

    var _tu: CXTranslationUnit
    var _raw: CXFile

    @staticmethod
    def null(tu: CXTranslationUnit) -> Self:
        return Self(_tu=tu, _raw=None)

    @staticmethod
    def from_name(tu: CXTranslationUnit, filename: String) raises -> Optional[Self]:
        var handle = clang_getFile(tu, _c_string(filename))
        if not handle:
            return None
        return Optional[Self](Self(_tu=tu, _raw=handle))

    def name(self) raises -> String:
        var cs = _CXStringStorage()
        clang_getFileName(cs.ptr(), self._raw)
        return cs.take()

    def time(self) raises -> time_t:
        return clang_getFileTime(self._raw)

    def real_path(self) raises -> String:
        var cs = _CXStringStorage()
        clang_File_tryGetRealPathName(cs.ptr(), self._raw)
        return cs.take()

    def is_multiple_include_guarded(self) raises -> Bool:
        return Bool(clang_isFileMultipleIncludeGuarded(self._tu, self._raw))

    def __eq__(self, other: Self) raises -> Bool:
        return Bool(clang_File_isEqual(self._raw, other._raw))

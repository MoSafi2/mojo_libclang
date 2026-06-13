"""`File` — borrowed `CXFile` handle from a `TranslationUnit`."""
from src.libclang_raw import (
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
from src.libclang.common import take_cxstring, _c_string


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
        return take_cxstring(clang_getFileName(self._raw))

    def time(self) raises -> time_t:
        return clang_getFileTime(self._raw)

    def real_path(self) raises -> String:
        return take_cxstring(clang_File_tryGetRealPathName(self._raw))

    def is_multiple_include_guarded(self) raises -> Bool:
        return Bool(clang_isFileMultipleIncludeGuarded(self._tu, self._raw))

    def __eq__(self, other: Self) raises -> Bool:
        return Bool(clang_File_isEqual(self._raw, other._raw))

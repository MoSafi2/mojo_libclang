"""`File` — borrowed `CXFile` handle from a `TranslationUnit`.

A `File` is a borrowed libclang file handle plus an ARC keepalive reference to
the owning `TranslationUnitState`.

Important:

* `CXFile` is not independently owned by this wrapper.
* The owning translation unit is kept alive through `ArcPointer[TranslationUnitState]`.
* The file becomes stale after `TranslationUnit.reparse()` if the generation changes.

Typical usage:

```mojo
from clang.cindex import TranslationUnit

def main() raises:
    var tu = TranslationUnit.from_source("test/fixtures/test_fixture.c")
    var file = tu.file("test/fixtures/test_fixture.c")
    if file:
        print(file.value().name())
```
"""

from clang._ffi import (
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

from clang.common import _borrow_c_string, _CXStringStorage
from clang.state import TranslationUnitState

from std.memory import ArcPointer


@fieldwise_init
struct File(Copyable, Movable, Writable):
    """A `CXFile` borrowed from a `TranslationUnit`.

    This object keeps the underlying translation unit alive by storing
    `ArcPointer[TranslationUnitState]`.

    Example:

    ```mojo
    var file = tu.file("test/fixtures/test_fixture.c")
    if file:
        print(file.value().real_path())
    ```
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
        self._tu = tu._shared_state()
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

    def _raw_value(ref self) raises -> CXFile:
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
        """Return a null file handle associated with `tu`."""
        return Self(tu=tu, raw=CXFile(None))

    @staticmethod
    def null(tu: ArcPointer[TranslationUnitState]) raises -> Self:
        """Return a null file handle associated with a shared TU state."""
        return Self(tu=tu, raw=CXFile(None))

    @staticmethod
    def from_handle(
        tu: TranslationUnit,
        handle: CXFile,
    ) raises -> Optional[Self]:
        """Wrap `handle`, or return `None` if it is a null `CXFile`."""
        if not handle:
            return None

        var result = Self(tu=tu, raw=handle)
        return Optional[Self](result^)

    @staticmethod
    def from_handle(
        tu: ArcPointer[TranslationUnitState],
        handle: CXFile,
    ) raises -> Optional[Self]:
        """Wrap `handle`, or return `None` if it is a null `CXFile`."""
        if not handle:
            return None

        var result = Self(tu=tu, raw=handle)
        return Optional[Self](result^)

    @staticmethod
    def from_name(
        tu: TranslationUnit,
        filename: String,
    ) raises -> Optional[Self]:
        """Look up `filename` in `tu`, returning `None` when absent."""
        var tu_state = tu._shared_state()
        if not tu_state[].alive:
            raise Error("File.from_name: TranslationUnit used after disposal")

        var handle = clang_getFile(
            tu_state[].raw(),
            _borrow_c_string(filename),
        )

        if not handle:
            return None

        var result = Self(tu=tu_state, raw=handle)
        return Optional[Self](result^)

    @staticmethod
    def from_name(
        tu: ArcPointer[TranslationUnitState],
        filename: String,
    ) raises -> Optional[Self]:
        """Look up `filename` in a shared TU state, returning `None` when absent."""
        if not tu[].alive:
            raise Error("File.from_name: TranslationUnit used after disposal")

        var handle = clang_getFile(
            tu[].raw(),
            _borrow_c_string(filename),
        )

        if not handle:
            return None

        var result = Self(tu=tu, raw=handle)
        return Optional[Self](result^)

    def write_to(self, mut writer: Some[Writer]):
        writer.write("File(", self._name, ")")

    def name(mut self) raises -> String:
        """Return libclang's file name, caching it after the first lookup."""
        self._check_valid()

        if not self._name:
            self._cache_name()

        return self._name

    def time(ref self) raises -> time_t:
        """Return libclang's modification time for this file."""
        self._check_valid()
        return clang_getFileTime(self._raw)

    def real_path(ref self) raises -> String:
        """Return the real path name reported by libclang."""
        self._check_valid()

        var cs = _CXStringStorage()
        clang_File_tryGetRealPathName(cs.ptr_for_out(), self._raw)
        return cs.take()

    def is_multiple_include_guarded(ref self) raises -> Bool:
        """Return true if libclang sees this file as include-guarded."""
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

"""Core support layer for the high-level libclang API.

This module intentionally contains no `Index`, `TranslationUnit`, `Cursor`,
`Type`, `SourceLocation`, or `Token` public wrappers. It provides the shared
foundation those modules use:

- public pure value inputs:
    UnsavedFile

- temporary C-call arenas:
    UnsavedFileArena

- string handling:
    _borrow_c_string()
    _alloc_c_string()
    _c_string()
    _CXStringStorage (Movable, inline CXString)
    _take_cxstring()
    _take_cxstring_optional()
    _borrow_c_string_unsafe()

- validation helpers:
    _check_index_alive()
    _check_translation_unit_alive()
    _check_translation_unit_generation()
"""

from clang._ffi import (
    CXIndex,
    CXPlatformAvailability,
    CXTranslationUnit,
    CXUnsavedFile,
    CXString,
    clang_disposeIndex,
    clang_disposeCXPlatformAvailability,
    clang_disposeTranslationUnit,
    clang_getCString,
    clang_disposeString,
)

from std.collections import List
from std.ffi import c_char, c_int, c_uint, c_ulong
from std.memory import ArcPointer, UnsafePointer, alloc


# ---------------------------------------------------------------------------
# Public pure value support types
# ---------------------------------------------------------------------------


@fieldwise_init
struct UnsavedFile(Copyable, Movable, Writable):
    """In-memory source content supplied to parse or reparse calls.

    `filename` must match the path libclang sees on the command line, and
    `contents` is the full replacement text for that file.
    """

    var filename: String
    var contents: String

    def write_to(self, mut writer: Some[Writer]):
        writer.write(
            "UnsavedFile(filename=",
            self.filename,
            ", contents=",
            self.contents,
            ")",
        )


@fieldwise_init
struct VersionTriple(Copyable, Movable, Writable):
    """Major/minor/subminor version triple reported by libclang."""

    var major: Int
    var minor: Int
    var subminor: Int


@fieldwise_init
struct PlatformAvailability(Copyable, Movable, Writable):
    """Availability metadata for one platform on a declaration cursor."""

    var platform: String
    var introduced: VersionTriple
    var deprecated: VersionTriple
    var obsoleted: VersionTriple
    var unavailable: Bool
    var message: Optional[String]


def _copy_platform_availabilities(
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


def _dispose_platform_availabilities(
    raw_items: UnsafePointer[CXPlatformAvailability, MutUntrackedOrigin],
    count: Int,
):
    for i in range(count):
        clang_disposeCXPlatformAvailability(raw_items + i)


# ---------------------------------------------------------------------------
# Unsafe borrowed C-string helper
# ---------------------------------------------------------------------------


def _borrow_c_string_unsafe(
    text: String,
) -> UnsafePointer[c_char, ImmutUntrackedOrigin]:
    """Borrow a null-terminated C string pointer from a Mojo `String`.

    The returned pointer does not own the string data.

    The caller must guarantee that `text` stays alive until the C call returns.
    Prefer `UnsavedFileArena` for arrays or persisted C structs.
    """
    return rebind[UnsafePointer[c_char, ImmutUntrackedOrigin]](
        text.unsafe_ptr(),
    )


def _borrow_c_string(
    text: String,
) -> UnsafePointer[c_char, ImmutUntrackedOrigin]:
    """Borrow a null-terminated C string pointer from a Mojo `String`.

    The returned pointer does not own the string data. The string may be
    mutated to materialize a trailing NUL terminator if it does not already
    have one.
    """
    var mutable_text = text
    var c_string = mutable_text.as_c_string_slice()
    return rebind[UnsafePointer[c_char, ImmutUntrackedOrigin]](
        c_string.unsafe_ptr()
    )


# ---------------------------------------------------------------------------
# CXString helpers
# ---------------------------------------------------------------------------


def _take_cxstring(
    mut cxstr_ref: UnsafePointer[CXString, MutUntrackedOrigin],
) raises -> String:
    """Copy a `CXString` into an owned Mojo `String` and dispose it.

    The input `CXString` is consumed. Public wrapper APIs should return
    `String`, never `CXString`.
    """
    var value = _take_cxstring_optional(cxstr_ref)
    if not value:
        return String("")

    return value.value()


def _take_cxstring_optional(
    mut cxstr_ref: UnsafePointer[CXString, MutUntrackedOrigin],
) raises -> Optional[String]:
    """Copy a `CXString` into `Optional[String]` and dispose it.

    Use this for libclang APIs that can return a null `CXString` sentinel.
    Empty strings remain `Some(String(""))`.
    """
    var c_string = clang_getCString(cxstr_ref)
    if not c_string:
        clang_disposeString(cxstr_ref)
        return None

    var value = String(unsafe_from_utf8_ptr=c_string.value())
    clang_disposeString(cxstr_ref)
    return Optional[String](value)


def _take_cxstring_value(raw: CXString) raises -> String:
    var cs = _CXStringStorage(raw=raw)
    return cs.take()


def _take_cxstring_optional_value(raw: CXString) raises -> Optional[String]:
    var cs = _CXStringStorage(raw=raw)
    return cs.take_optional()


struct _CXStringStorage(Movable):
    """Inline `CXString` wrapper with Mojo `String` conversion.

    Usage:

        var cs = _CXStringStorage()
        clang_getCursorSpelling(cs.ptr_for_out(), cursor_ptr)
        var spelling = cs.take()

    The `CXString` is stored inline — no heap allocation.  `ptr_for_out()`
    marks the storage as containing a libclang-owned CXString.  If `take()`
    is forgotten, the destructor disposes it.
    """

    var _value: CXString
    var _has_value: Bool

    def __init__(out self):
        self._value = CXString(data=None, private_flags=c_uint(0))
        self._has_value = False

    def __init__(out self, raw: CXString):
        self._value = CXString(data=raw.data, private_flags=raw.private_flags)
        self._has_value = True

    @always_inline
    def _as_ptr(mut self) -> UnsafePointer[CXString, MutUntrackedOrigin]:
        return rebind[UnsafePointer[CXString, MutUntrackedOrigin]](
            UnsafePointer[CXString, MutAnyOrigin](to=self._value),
        )

    def ptr_for_out(mut self) -> UnsafePointer[CXString, MutUntrackedOrigin]:
        self._has_value = True
        return self._as_ptr()

    def ptr(mut self) -> UnsafePointer[CXString, MutUntrackedOrigin]:
        return self._as_ptr()

    def take(mut self) raises -> String:
        if not self._has_value:
            return String("")
        self._has_value = False
        var ptr = self._as_ptr()
        return _take_cxstring(ptr)

    def _take_unchecked(mut self) -> String:
        if not self._has_value:
            return String("")
        self._has_value = False
        var ptr = self._as_ptr()
        var c_string = clang_getCString(ptr)
        if not c_string:
            clang_disposeString(ptr)
            return String("")
        var value = String(unsafe_from_utf8_ptr=c_string.value())
        clang_disposeString(ptr)
        return value

    def take_optional(mut self) raises -> Optional[String]:
        if not self._has_value:
            return None
        self._has_value = False
        var ptr = self._as_ptr()
        return _take_cxstring_optional(ptr)

    def __del__(deinit self):
        if self._has_value:
            clang_disposeString(self._as_ptr())


# ---------------------------------------------------------------------------
# Temporary arenas for synchronous libclang calls
# ---------------------------------------------------------------------------
struct UnsavedFileArena(Movable):
    """Owns C strings and a `CXUnsavedFile[]` array."""

    var _filenames: List[UnsafePointer[c_char, MutAnyOrigin]]
    var _contents: List[UnsafePointer[c_char, MutAnyOrigin]]
    var _slots: Optional[UnsafePointer[CXUnsavedFile, MutAnyOrigin]]
    var _count: c_uint

    def __init__(out self, files: List[UnsavedFile]) raises:
        self._filenames = List[UnsafePointer[c_char, MutAnyOrigin]]()
        self._contents = List[UnsafePointer[c_char, MutAnyOrigin]]()
        self._slots = None
        self._count = c_uint(len(files))

        if len(files) == 0:
            return

        var slots = alloc[CXUnsavedFile](len(files))
        self._slots = slots

        for i in range(len(files)):
            var filename = _alloc_c_string(files[i].filename)
            var contents = _alloc_c_string(files[i].contents)

            self._filenames.append(filename)
            self._contents.append(contents)

            slots[i] = CXUnsavedFile(
                Filename=Optional[UnsafePointer[c_char, ImmutUntrackedOrigin]](
                    _c_string(filename),
                ),
                Contents=Optional[UnsafePointer[c_char, ImmutUntrackedOrigin]](
                    _c_string(contents),
                ),
                Length=c_ulong(files[i].contents.byte_length()),
            )

    def ptr(
        self,
    ) -> Optional[UnsafePointer[CXUnsavedFile, MutUntrackedOrigin]]:
        if not self._slots:
            return None

        return Optional[UnsafePointer[CXUnsavedFile, MutUntrackedOrigin]](
            rebind[UnsafePointer[CXUnsavedFile, MutUntrackedOrigin]](
                self._slots.value(),
            )
        )

    def count(self) -> c_uint:
        return self._count

    def __del__(deinit self):
        for i in range(len(self._filenames)):
            self._filenames[i].free()

        for i in range(len(self._contents)):
            self._contents[i].free()

        if self._slots:
            self._slots.value().free()


# ---------------------------------------------------------------------------
# Shared validation helpers
# ---------------------------------------------------------------------------


def _alloc_c_string(text: String) -> UnsafePointer[c_char, MutAnyOrigin]:
    """Allocate a null-terminated C string.

    Caller owns the returned pointer and must free it.
    """
    var bytes = text.as_bytes()
    var ptr = alloc[c_char](len(bytes) + 1)

    for i in range(len(bytes)):
        ptr[i] = c_char(bytes[i])

    ptr[len(bytes)] = c_char(0)
    return ptr


def _c_string(
    ptr: UnsafePointer[c_char, MutAnyOrigin],
) -> UnsafePointer[c_char, ImmutUntrackedOrigin]:
    """View an owned mutable C string pointer as const char* for C APIs."""
    return rebind[UnsafePointer[c_char, ImmutUntrackedOrigin]](ptr)

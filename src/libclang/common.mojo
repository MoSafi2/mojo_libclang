"""Core support layer for the high-level libclang API.

This module intentionally contains no `Index`, `TranslationUnit`, `Cursor`,
`Type`, `SourceLocation`, or `Token` public wrappers. It provides the shared
foundation those modules use:

- public pure value inputs:
    UnsavedFile
    SourcePosition
    SourceExtentInput

- safe copied source-location result values:
    FileLocationValue
    PresumedLocationValue

- temporary C-call arenas:
    CStringArray
    UnsavedFileArena

- string handling:
    _alloc_c_string()
    _c_string()
    _CXStringStorage
    _take_cxstring()
    _take_cxstring_optional()
    _borrow_c_string_unsafe()

- validation helpers:
    _check_index_alive()
    _check_translation_unit_alive()
    _check_translation_unit_generation()
"""

from src._ffi import (
    CXIndex,
    CXTranslationUnit,
    CXUnsavedFile,
    CXString,
    clang_disposeIndex,
    clang_disposeTranslationUnit,
    clang_getCString,
    clang_disposeString,
)

from std.ffi import c_char, c_int, c_uint, c_ulong
from std.memory import ArcPointer, UnsafePointer


# ---------------------------------------------------------------------------
# Public pure value support types
# ---------------------------------------------------------------------------


@fieldwise_init
struct UnsavedFile(Copyable, Movable, Writable):
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
struct SourcePosition(Copyable, Movable, Writable):
    """Either `(line, column)` or `offset` addressing.

    Use one of:

        SourcePosition.from_line_column(line, column)
        SourcePosition.from_offset(offset)

    `line` and `column` are 1-based, matching libclang source locations.
    `offset` is byte-offset based.
    """

    var line: Optional[c_uint]
    var column: Optional[c_uint]
    var offset: Optional[c_uint]

    def write_to(self, mut writer: Some[Writer]):
        if self.is_line_column():
            writer.write("SourcePosition(line=", self.line, ", column=", self.column, ")")
        elif self.is_offset_only():
            writer.write("SourcePosition(offset=", self.offset, ")")
        else:
            writer.write("SourcePosition(<unset>)")

    @staticmethod
    def from_line_column(line: c_uint, column: c_uint) -> Self:
        return Self(
            line=Optional[c_uint](line),
            column=Optional[c_uint](column),
            offset=None,
        )

    @staticmethod
    def from_offset(offset: c_uint) -> Self:
        return Self(
            line=None,
            column=None,
            offset=Optional[c_uint](offset),
        )

    def is_offset_only(self) -> Bool:
        return self.offset and not (self.line or self.column)

    def is_line_column(self) -> Bool:
        return self.line and self.column and not self.offset

    def validate(self) raises:
        if self.is_offset_only():
            return

        if self.is_line_column():
            if self.line.value() == 0 or self.column.value() == 0:
                raise Error(
                    "SourcePositionError: line and column must be >= 1",
                )
            return

        raise Error(
            (
                "SourcePositionError: must set either offset alone, or both "
                "line and column"
            ),
        )


@fieldwise_init
struct SourceExtentInput(Copyable, Movable, Writable):
    """Two `SourcePosition` values that delimit a `SourceRange`."""

    var start: SourcePosition
    var end: SourcePosition

    def write_to(self, mut writer: Some[Writer]):
        writer.write("SourceExtentInput(start=", self.start, ", end=", self.end, ")")

    @staticmethod
    def from_positions(start: SourcePosition, end: SourcePosition) -> Self:
        return Self(start=start.copy(), end=end.copy())

    @staticmethod
    def from_offsets(start: c_uint, end: c_uint) -> Self:
        return Self(
            start=SourcePosition.from_offset(start),
            end=SourcePosition.from_offset(end),
        )

    @staticmethod
    def from_line_columns(
        start_line: c_uint,
        start_column: c_uint,
        end_line: c_uint,
        end_column: c_uint,
    ) -> Self:
        return Self(
            start=SourcePosition.from_line_column(start_line, start_column),
            end=SourcePosition.from_line_column(end_line, end_column),
        )

    def validate(self) raises:
        self.start.validate()
        self.end.validate()


@fieldwise_init
struct FileLocationValue(Copyable, Movable, Writable):
    """Copied spelling/expansion/file location result.

    This is deliberately a plain value. It is safe to keep after the
    corresponding `SourceLocation` wrapper is destroyed.

    `file_name` is copied instead of storing a `File` wrapper to avoid import
    cycles in the core module.
    """

    var file_name: Optional[String]
    var line: c_uint
    var column: c_uint
    var offset: c_uint

    def write_to(self, mut writer: Some[Writer]):
        writer.write(
            "FileLocationValue(file_name=",
            self.file_name,
            ", line=",
            self.line,
            ", column=",
            self.column,
            ", offset=",
            self.offset,
            ")",
        )


@fieldwise_init
struct PresumedLocationValue(Copyable, Movable, Writable):
    """Copied presumed-location result."""

    var filename: String
    var line: c_uint
    var column: c_uint

    def write_to(self, mut writer: Some[Writer]):
        writer.write(
            "PresumedLocationValue(filename=",
            self.filename,
            ", line=",
            self.line,
            ", column=",
            self.column,
            ")",
        )


# ---------------------------------------------------------------------------
# Unsafe borrowed C-string helper
# ---------------------------------------------------------------------------


def _borrow_c_string_unsafe(
    text: String,
) -> UnsafePointer[c_char, ImmutExternalOrigin]:
    """Borrow a null-terminated C string pointer from a Mojo `String`.

    The returned pointer does not own the string data.

    The caller must guarantee that `text` stays alive until the C call returns.
    Prefer `CStringArray` or `UnsavedFileArena` for arrays or persisted C
    structs.
    """
    return rebind[UnsafePointer[c_char, ImmutExternalOrigin]](
        text.unsafe_ptr(),
    )


# ---------------------------------------------------------------------------
# CXString helpers
# ---------------------------------------------------------------------------


def _take_cxstring(
    mut cxstr_ref: UnsafePointer[CXString, MutExternalOrigin],
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
    mut cxstr_ref: UnsafePointer[CXString, MutExternalOrigin],
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


struct _CXStringStorage:
    """Allocated `CXString` out-param storage.

    Usage:

        var cs = _CXStringStorage()
        clang_getCursorSpelling(cs.ptr_for_out(), cursor_ptr)
        var spelling = cs.take()

    `ptr_for_out()` marks the storage as containing a libclang-owned CXString.
    If `take()` is forgotten, the destructor attempts to dispose it.
    """

    var _raw: UnsafePointer[CXString, MutExternalOrigin]
    var _owned: UnsafePointer[CXString, MutAnyOrigin]
    var _has_value: Bool

    def __init__(out self):
        self._owned = alloc[CXString](1)
        self._owned[] = CXString(data=None, private_flags=c_uint(0))
        self._raw = rebind[UnsafePointer[CXString, MutExternalOrigin]](
            self._owned,
        )
        self._has_value = False

    def ptr_for_out(mut self) -> UnsafePointer[CXString, MutExternalOrigin]:
        """Return pointer for a libclang out-param call.

        This assumes the next C call writes a valid CXString into the storage.
        Use this method for functions like:

            clang_getCursorSpelling(out, cursor)
            clang_getFileName(out, file)
        """
        self._has_value = True
        return self._raw

    def ptr(mut self) -> UnsafePointer[CXString, MutExternalOrigin]:
        """Return the raw pointer without changing ownership state.

        Prefer `ptr_for_out()` for libclang functions that write a CXString.
        """
        return self._raw

    def take(mut self) raises -> String:
        """Consume the stored CXString and return an owned Mojo `String`."""
        if not self._has_value:
            return String("")

        self._has_value = False
        return _take_cxstring(self._raw)

    def _take_unchecked(mut self) -> String:
        """Consume the stored CXString without propagating raises.

        Used by hot iterator paths that have already validated the TU state.
        """
        if not self._has_value:
            return String("")

        self._has_value = False
        var c_string = clang_getCString(self._raw)
        if not c_string:
            clang_disposeString(self._raw)
            return String("")

        var value = String(unsafe_from_utf8_ptr=c_string.value())
        clang_disposeString(self._raw)
        return value

    def take_optional(mut self) raises -> Optional[String]:
        """Consume the stored CXString and preserve null-vs-empty."""
        if not self._has_value:
            return None

        self._has_value = False
        return _take_cxstring_optional(self._raw)

    def __del__(deinit self):
        if self._has_value:
            clang_disposeString(self._raw)

        self._owned.free()


# ---------------------------------------------------------------------------
# Temporary arenas for synchronous libclang calls
# ---------------------------------------------------------------------------
struct CStringArray(Movable):
    """Owns C strings and a `const char*[]` slot array."""

    var _strings: List[UnsafePointer[c_char, MutAnyOrigin]]
    var _slots: Optional[
        UnsafePointer[
            Optional[UnsafePointer[c_char, ImmutExternalOrigin]],
            MutAnyOrigin,
        ]
    ]
    var _count: c_int

    def __init__(out self, args: List[String]) raises:
        self._strings = List[UnsafePointer[c_char, MutAnyOrigin]]()
        self._slots = None
        self._count = c_int(len(args))

        if len(args) == 0:
            return

        var slots = alloc[
            Optional[UnsafePointer[c_char, ImmutExternalOrigin]]
        ](len(args))

        self._slots = slots

        for i in range(len(args)):
            var s = _alloc_c_string(args[i])
            self._strings.append(s)
            slots[i] = Optional[UnsafePointer[c_char, ImmutExternalOrigin]](
                _c_string(s),
            )

    def ptr(
        self,
    ) -> Optional[
        UnsafePointer[
            Optional[UnsafePointer[c_char, ImmutExternalOrigin]],
            ImmutExternalOrigin,
        ]
    ]:
        if not self._slots:
            return None

        return Optional[
            UnsafePointer[
                Optional[UnsafePointer[c_char, ImmutExternalOrigin]],
                ImmutExternalOrigin,
            ]
        ](
            rebind[
                UnsafePointer[
                    Optional[UnsafePointer[c_char, ImmutExternalOrigin]],
                    ImmutExternalOrigin,
                ]
            ](self._slots.value())
        )

    def count(self) -> c_int:
        return self._count

    def __del__(deinit self):
        for i in range(len(self._strings)):
            self._strings[i].free()

        if self._slots:
            self._slots.value().free()

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
                Filename=Optional[
                    UnsafePointer[c_char, ImmutExternalOrigin]
                ](
                    _c_string(filename),
                ),
                Contents=Optional[
                    UnsafePointer[c_char, ImmutExternalOrigin]
                ](
                    _c_string(contents),
                ),
                Length=c_ulong(files[i].contents.byte_length()),
            )

    def ptr(
        self,
    ) -> Optional[UnsafePointer[CXUnsavedFile, MutExternalOrigin]]:
        if not self._slots:
            return None

        return Optional[UnsafePointer[CXUnsavedFile, MutExternalOrigin]](
            rebind[UnsafePointer[CXUnsavedFile, MutExternalOrigin]](
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


def _alloc_c_string(text: String) raises -> UnsafePointer[c_char, MutAnyOrigin]:
    """Allocate a null-terminated C string.

    Caller owns the returned pointer and must free it. Embedded NUL bytes are
    rejected because libclang expects a single null-terminated C string.
    """
    var bytes = text.as_bytes()
    var ptr = alloc[c_char](len(bytes) + 1)

    for i in range(len(bytes)):
        if bytes[i] == 0:
            ptr.free()
            raise Error("CStringError: embedded NUL byte")
        ptr[i] = c_char(bytes[i])

    ptr[len(bytes)] = c_char(0)
    return ptr


def _c_string(
    ptr: UnsafePointer[c_char, MutAnyOrigin],
) -> UnsafePointer[c_char, ImmutExternalOrigin]:
    """View an owned mutable C string pointer as const char* for C APIs."""
    return rebind[UnsafePointer[c_char, ImmutExternalOrigin]](ptr)

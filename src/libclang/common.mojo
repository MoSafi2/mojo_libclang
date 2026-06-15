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

- CXString handling:
    _CXStringStorage
    _take_cxstring()
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
struct UnsavedFile(Copyable, Movable):
    """A single in-memory source file passed to `Index.parse` or `reparse`."""

    var filename: String
    var contents: String


@fieldwise_init
struct SourcePosition(Copyable, Movable):
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
struct SourceExtentInput(Copyable, Movable):
    """Two `SourcePosition` values that delimit a `SourceRange`."""

    var start: SourcePosition
    var end: SourcePosition

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
    var c_string = clang_getCString(cxstr_ref)
    if not c_string:
        clang_disposeString(cxstr_ref)
        return String("")

    var value = String(unsafe_from_utf8_ptr=c_string.value())
    clang_disposeString(cxstr_ref)
    return value


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

    def __del__(deinit self):
        if self._has_value:
            clang_disposeString(self._raw)

        self._owned.free()


# ---------------------------------------------------------------------------
# Temporary arenas for synchronous libclang calls
# ---------------------------------------------------------------------------


struct CStringArray:
    """Owns copied command-line strings and a `const char **` array.

    Use for `clang_parseTranslationUnit2` command-line args. The arena must
    stay alive until the C call returns.
    """

    var _args: List[String]
    var _slot: Optional[
        UnsafePointer[
            Optional[UnsafePointer[c_char, ImmutExternalOrigin]],
            MutAnyOrigin,
        ]
    ]
    var _count: c_int

    def __init__(out self, args: List[String]):
        self._args = List[String]()
        self._count = c_int(len(args))

        if len(args) == 0:
            self._slot = None
            return

        for i in range(len(args)):
            self._args.append(args[i].copy())

        var slot = alloc[Optional[UnsafePointer[c_char, ImmutExternalOrigin]]](
            len(args)
        )

        for i in range(len(args)):
            slot[i] = Optional[UnsafePointer[c_char, ImmutExternalOrigin]](
                rebind[UnsafePointer[c_char, ImmutExternalOrigin]](
                    self._args[i].unsafe_ptr(),
                )
            )

        self._slot = Optional[
            UnsafePointer[
                Optional[UnsafePointer[c_char, ImmutExternalOrigin]],
                MutAnyOrigin,
            ]
        ](slot)

    def ptr(
        self,
    ) -> Optional[
        UnsafePointer[
            Optional[UnsafePointer[c_char, ImmutExternalOrigin]],
            ImmutExternalOrigin,
        ]
    ]:
        if not self._slot:
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
            ](self._slot.value())
        )

    def count(self) -> c_int:
        return self._count

    def __del__(deinit self):
        if self._slot:
            self._slot.value().free()


struct UnsavedFileArena:
    """Owns copied `UnsavedFile` values and a `CXUnsavedFile *` array.

    This avoids dangling pointers from temporary strings. Keep this arena alive
    until `clang_parseTranslationUnit2` or `clang_reparseTranslationUnit`
    returns.
    """

    var _files: List[UnsavedFile]
    var _slot: Optional[UnsafePointer[CXUnsavedFile, MutAnyOrigin]]
    var _count: c_uint

    def __init__(out self, files: List[UnsavedFile]):
        self._files = List[UnsavedFile]()
        self._count = c_uint(len(files))

        if len(files) == 0:
            self._slot = None
            return

        for i in range(len(files)):
            self._files.append(files[i].copy())

        var slot = alloc[CXUnsavedFile](len(files))

        for i in range(len(files)):
            slot[i] = CXUnsavedFile(
                Filename=Optional[UnsafePointer[c_char, ImmutExternalOrigin]](
                    rebind[UnsafePointer[c_char, ImmutExternalOrigin]](
                        self._files[i].filename.unsafe_ptr(),
                    )
                ),
                Contents=Optional[UnsafePointer[c_char, ImmutExternalOrigin]](
                    rebind[UnsafePointer[c_char, ImmutExternalOrigin]](
                        self._files[i].contents.unsafe_ptr(),
                    )
                ),
                Length=c_ulong(self._files[i].contents.byte_length()),
            )

        self._slot = Optional[UnsafePointer[CXUnsavedFile, MutAnyOrigin]](
            slot,
        )

    def ptr(self) -> Optional[UnsafePointer[CXUnsavedFile, MutExternalOrigin]]:
        if not self._slot:
            return None

        return Optional[UnsafePointer[CXUnsavedFile, MutExternalOrigin]](
            rebind[UnsafePointer[CXUnsavedFile, MutExternalOrigin]](
                self._slot.value(),
            )
        )

    def count(self) -> c_uint:
        return self._count

    def __del__(deinit self):
        if self._slot:
            self._slot.value().free()


# ---------------------------------------------------------------------------
# Shared validation helpers
# ---------------------------------------------------------------------------


def _c_string(text: String) -> UnsafePointer[c_char, ImmutExternalOrigin]:
    """Copy a Mojo `String` into a null-terminated C string pointer.

    The caller is responsible for freeing the returned pointer with `free()`.
    Prefer `CStringArray` or `UnsavedFileArena` for arrays or persisted C
    structs.
    """
    var bytes = text.as_bytes()
    var c_string = alloc[c_char](len(bytes) + 1)
    for i in range(len(bytes)):
        c_string[i] = Int8(bytes[i])
    c_string[len(bytes)] = c_char(0)
    return c_string

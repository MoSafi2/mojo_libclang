"""Public support types for the high-level libclang API.

These are value types used to build call sites that read like Python
`clang.cindex`. They do not own libclang resources.

`FixIt` lives in `diagnostic.mojo` because it depends on `SourceRange`.
"""
from std.ffi import c_uint


@fieldwise_init
struct UnsavedFile(Copyable, Movable):
    """A single in-memory source file passed to `Index.parse`."""

    var filename: String
    var contents: String


@fieldwise_init
struct SourcePosition(Copyable, Movable, RegisterPassable):
    """Either `(line, column)` or `offset` addressing for `get_location`.

    Exactly one mode must be set. Callers should pass the result of
    `SourcePosition.from_line_column(...)` or `SourcePosition.from_offset(...)`
    to `TranslationUnit.get_location`.
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
        return Self(line=None, column=None, offset=Optional[c_uint](offset))

    def is_offset_only(self) -> Bool:
        return self.offset and not (self.line and self.column)

    def is_line_column(self) -> Bool:
        return self.line and self.column and not self.offset

    def validate(mut self) raises:
        if self.is_offset_only():
            return
        if self.is_line_column():
            return
        raise Error(
            "SourcePositionError: must set either offset alone, or both "
            "line and column",
        )


@fieldwise_init
struct SourceExtentInput(Copyable, Movable, RegisterPassable):
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

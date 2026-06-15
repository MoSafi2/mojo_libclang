"""`Token` and `TokenGroup` - tokenization output.

`TokenGroup` owns the buffer returned by `clang_tokenize` and disposes it
in `__del__`. Each `Token` is a borrowed pointer into that buffer plus
the originating `CXTranslationUnit` so it can issue follow-up queries.

The working surface here is token kind, spelling, and cursor annotation.
Token location/extent queries are currently documented as unstable and are
left out of the active test surface.
"""
from src._ffi import (
    CXToken,
    CXTranslationUnit,
    CXTokenKind,
    c_uint,
    clang_getTokenKind,
    clang_getTokenSpelling,
    clang_annotateTokens,
    clang_tokenize,
    clang_disposeTokens,
)
from src.libclang.common import _CXStringStorage
from src.libclang.cursor import Cursor
from src.libclang.source_range import SourceRange
from src.libclang.source_location import SourceLocation
from std.memory import UnsafePointer


@fieldwise_init
struct Token(Copyable, Movable, Writable):
    """A single token, borrowing storage from its `TokenGroup`."""

    var _tu: CXTranslationUnit
    var _raw: UnsafePointer[CXToken, MutExternalOrigin]
    var _spelling: String
    var _kind: CXTokenKind

    def _cache_from_ffi(mut self) raises:
        self._kind = clang_getTokenKind(self._raw)
        var cs = _CXStringStorage()
        clang_getTokenSpelling(cs.ptr_for_out(), self._tu, self._raw)
        self._spelling = cs.take()

    def write_to(self, mut writer: Some[Writer]):
        writer.write(
            "Token(", Int(c_uint(self._kind)), ": ", self._spelling, ")"
        )

    def kind(mut self) raises -> CXTokenKind:
        return self._kind

    def spelling(mut self) raises -> String:
        return self._spelling

    def location(mut self) raises -> SourceLocation:
        raise Error(
            "Token.location is currently unstable; keep using raw FFI probes",
        )

    def extent(mut self) raises -> SourceRange:
        raise Error(
            "Token.extent is currently unstable; keep using raw FFI probes",
        )

    def cursor(mut self) raises -> Cursor:
        var out = Cursor(tu=self._tu)
        clang_annotateTokens(self._tu, self._raw, c_uint(1), out._ptr())
        out._cache_spelling()
        return out^


struct TokenGroup(Movable, Writable, Sized):
    """Owns the buffer returned by `clang_tokenize`."""

    var _tu: CXTranslationUnit
    var _tokens: Optional[UnsafePointer[CXToken, MutExternalOrigin]]
    var _count: c_uint
    var _index: Int

    def __init__(
        out self,
        tu: CXTranslationUnit,
        extent: SourceRange,
    ) raises:
        self._tu = tu
        self._index = 0
        var token_storage = InlineArray[
            Optional[UnsafePointer[CXToken, MutExternalOrigin]], 1
        ](fill=Optional[UnsafePointer[CXToken, MutExternalOrigin]]())
        var count_storage = InlineArray[c_uint, 1](fill=c_uint(0))
        var e = extent.copy()
        clang_tokenize(
            tu,
            e._ptr(),
            Optional[UnsafePointer[
                Optional[UnsafePointer[CXToken, MutExternalOrigin]],
                MutExternalOrigin,
            ]](
                rebind[UnsafePointer[
                    Optional[UnsafePointer[CXToken, MutExternalOrigin]],
                    MutExternalOrigin,
                ]](token_storage.unsafe_ptr())
            ),
            rebind[UnsafePointer[c_uint, MutExternalOrigin]](
                count_storage.unsafe_ptr()
            ),
        )
        self._tokens = token_storage[0]
        self._count = count_storage[0]

    def __del__(deinit self):
        if self._tokens:
            clang_disposeTokens(self._tu, self._tokens.value(), self._count)

    def __len__(self) -> Int:
        return Int(self._count)

    def write_to(self, mut writer: Some[Writer]):
        writer.write("TokenGroup(count=", Int(self._count), ")")

    def __getitem__(self, i: Int) raises -> Token:
        if i < 0 or i >= Int(self._count):
            raise Error("TokenGroup index out of range")
        var tok = Token(
            _tu=self._tu,
            _raw=self._tokens.value() + i,
            _spelling=String(),
            _kind=CXTokenKind(c_uint(0)),
        )
        tok._cache_from_ffi()
        return tok^

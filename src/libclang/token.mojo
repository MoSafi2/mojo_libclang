"""`Token` and `TokenGroup` — tokenization output.

`TokenGroup` owns the buffer returned by `clang_tokenize` and disposes it
in `__del__`. Each `Token` is a borrowed pointer into that buffer plus
the originating `CXTranslationUnit` so it can issue follow-up queries.
"""
from src.libclang_raw import (
    CXToken,
    CXSourceRange,
    CXTranslationUnit,
    CXTokenKind,
    c_uint,
    clang_getTokenKind_ref,
    clang_getTokenSpelling_ref,
    clang_getTokenLocation_ref,
    clang_getTokenExtent_ref,
    clang_tokenize_ref,
    clang_annotateTokens,
    clang_disposeTokens,
)
from src.libclang.common import take_cxstring
from src.libclang.cursor import Cursor
from src.libclang.source_location import SourceLocation
from src.libclang.source_range import SourceRange
from std.memory import UnsafePointer


@fieldwise_init
struct Token(Copyable, Movable):
    """A single token, borrowing storage from its `TokenGroup`."""

    var _tu: CXTranslationUnit
    var _raw: UnsafePointer[CXToken, MutExternalOrigin]

    def kind(mut self) raises -> CXTokenKind:
        return clang_getTokenKind_ref(self._raw)

    def spelling(mut self) raises -> String:
        return take_cxstring(clang_getTokenSpelling_ref(self._tu, self._raw))

    def location(mut self) raises -> SourceLocation:
        var out = SourceLocation(tu=self._tu)
        clang_getTokenLocation_ref(out._ptr(), self._tu, self._raw)
        return out^

    def extent(mut self) raises -> SourceRange:
        var out = SourceRange(tu=self._tu)
        clang_getTokenExtent_ref(out._ptr(), self._tu, self._raw)
        return out^

    def cursor(mut self) raises -> Cursor:
        # `clang_annotateTokens` fills a cursor buffer. Annotating a single
        # token writes exactly one cursor at `out._ptr()`.
        var out = Cursor(tu=self._tu)
        clang_annotateTokens(self._tu, self._raw, c_uint(1), out._ptr())
        return out^


struct TokenGroup(Movable):
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
        # `clang_tokenize_ref` takes a `**CXToken` and a `*c_uint`. Use
        # caller-owned `InlineArray[_, 1]` storage so the pointers stay
        # stable for the FFI call.
        var token_storage = InlineArray[
            Optional[UnsafePointer[CXToken, MutExternalOrigin]], 1
        ](fill=Optional[UnsafePointer[CXToken, MutExternalOrigin]]())
        var count_storage = InlineArray[c_uint, 1](fill=c_uint(0))
        var e = extent.copy()
        clang_tokenize_ref(
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
            try:
                clang_disposeTokens(self._tu, self._tokens.value(), self._count)
            except:
                pass

    def __len__(self) -> Int:
        return Int(self._count)

    def __getitem__(self, i: Int) raises -> Token:
        if i < 0 or i >= Int(self._count):
            raise Error("TokenGroup index out of range")
        return Token(_tu=self._tu, _raw=self._tokens.value() + i)

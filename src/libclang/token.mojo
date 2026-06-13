"""`Token` and `TokenGroup` — tokenization output."""
from src.libclang_raw import (
    CXToken,
    CXTokenKind,
    CXSourceLocation,
    CXSourceRange,
    CXTranslationUnit,
    c_uint,
    clang_getTokenKind_ref,
    clang_getTokenSpelling_ref,
    clang_getTokenLocation_ref,
    clang_getTokenExtent_ref,
    clang_tokenize_ref,
    clang_disposeTokens,
)
from src.libclang.common import take_cxstring
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
        clang_getTokenExtent_into(out._ptr(), self._tu, self._raw)
        return out^


@fieldwise_init
struct TokenGroup(Movable):
    """Owns the buffer returned by `clang_tokenize`."""

    var _tu: CXTranslationUnit
    var _tokens: Optional[UnsafePointer[CXToken, MutExternalOrigin]]
    var _count: c_uint
    var _index: Int

    def __init__(
        out self,
        tu: CXTranslationUnit,
        range: SourceRange,
    ) raises:
        self._tu = tu
        self._tokens = Optional[UnsafePointer[CXToken, MutExternalOrigin]]()
        self._count = c_uint(0)
        self._index = 0
        var token_ptr = Optional[UnsafePointer[CXToken, MutExternalOrigin]]()
        var count_storage = InlineArray[c_uint, 1](fill=c_uint(0))
        # `clang_tokenize_ref` takes a `**CXToken` and `*c_uint`. We have
        # `Optional[UnsafePointer[...]]`; reinterpret as a pointer to that
        # Optional's storage and pass.
        var tokens_addr = UnsafePointer[Optional[UnsafePointer[CXToken, MutExternalOrigin]]](
            to=token_ptr,
        )
        var token_ptr_arg = rebind[
            UnsafePointer[
                Optional[UnsafePointer[CXToken, MutExternalOrigin]],
                MutExternalOrigin,
            ]
        ](rebind[UnsafePointer[UnsafePointer[CXToken, MutExternalOrigin], MutExternalOrigin]](
            tokens_addr,
        ))
        var r = range.copy()
        clang_tokenize_ref(
            tu,
            r._ptr(),
            token_ptr_arg,
            rebind[UnsafePointer[c_uint, MutExternalOrigin]](
                count_storage.unsafe_ptr(),
            ),
        )
        self._tokens = token_ptr
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

    def __iter__(mut self) -> Self:
        self._index = 0
        return self^

    def __next__(mut self) raises -> Token:
        if self._index >= Int(self._count):
            raise StopIteration()
        var item = self[self._index]
        self._index += 1
        return item^


# Local shim: libclang_raw exposes `clang_getTokenExtent_ref` but the
# convention here is the `_into` suffix for out-param APIs that target
# caller-owned storage. Wrap the existing shim call with a clearer name.
def clang_getTokenExtent_into(
    out_range: UnsafePointer[CXSourceRange, MutExternalOrigin],
    tu: CXTranslationUnit,
    token: UnsafePointer[CXToken, MutExternalOrigin],
) raises:
    clang_getTokenExtent_ref(result=out_range, tu=tu, token=token)

"""`Token` and `TokenGroup` — tokenization output.

`TokenGroup` owns the buffer returned by `clang_tokenize` and disposes it in
`__del__`.

Returned `Token` values do not borrow pointers into that buffer. Each `Token`
owns a copied `CXToken` value in `InlineArray[CXToken, 1]`, plus an
`ArcPointer[TranslationUnitState]` keepalive reference to the originating
translation unit.

The working surface here is token kind, spelling, and cursor annotation.
Token location/extent queries remain disabled until their wrappers are stable.

Typical usage:

```mojo
from clang.cindex import TranslationUnit

def main() raises:
    var tu = TranslationUnit.from_source("test/fixtures/test_fixture.c")
    for token in tu.cursor().tokens():
        print(token.kind(), token.spelling())
```
"""

from clang._ffi import (
    CXToken,
    CXTokenKind,
    CXSourceLocation,
    CXSourceRange,
    c_uint,
    clang_getTokenKind,
    clang_getTokenSpelling,
    clang_getTokenLocation,
    clang_getTokenExtent,
    clang_annotateTokens,
    clang_tokenize,
    clang_disposeTokens,
    CXTranslationUnit,
)

from clang.enums import TokenKind
from clang.common import _CXStringStorage
from clang.state import TranslationUnitState
from clang.cursor import Cursor
from clang.source_range import SourceRange
from clang.source_location import SourceLocation

from std.iter import Iterable, Iterator, StopIteration
from std.memory import ArcPointer, UnsafePointer


@fieldwise_init
struct Token(Copyable, Movable, Writable):
    """A single token copied out of a `TokenGroup`.

    The token keeps its owning translation unit alive through
    `ArcPointer[TranslationUnitState]`.

    Example:

    ```mojo
    var token = cursor.tokens()[0]
    print(token.kind(), token.spelling())
    ```
    """

    var _tu: ArcPointer[TranslationUnitState]
    var _generation: Int
    var _raw: InlineArray[CXToken, 1]
    var _spelling: String
    var _kind: TokenKind

    def __init__(
        out self,
        tu: TranslationUnit,
        raw: CXToken,
    ) raises:
        """Create a token wrapper from a copied raw token tied to `tu`."""
        self._tu = tu._shared_state()
        self._generation = self._tu[].generation
        self._raw = InlineArray[CXToken, 1](fill=raw)
        self._spelling = String()
        self._kind = TokenKind(c_uint(0))
        self._cache_from_ffi()

    def __init__(
        out self,
        tu: ArcPointer[TranslationUnitState],
        raw: CXToken,
    ) raises:
        """Create a token wrapper from a copied raw token."""
        self._tu = tu
        self._generation = tu[].generation
        self._raw = InlineArray[CXToken, 1](fill=raw)
        self._spelling = String()
        self._kind = TokenKind(c_uint(0))
        self._cache_from_ffi()

    def __init__(
        out self,
        tu: ArcPointer[TranslationUnitState],
        raw: CXToken,
        _unchecked: Bool,
    ):
        """Internal non-raising constructor used by iterators.

        The caller must ensure the TU is alive and at the expected generation.
        Spelling and kind are cached immediately using the raw TU handle.
        """
        self._tu = tu
        self._generation = tu[].generation
        self._raw = InlineArray[CXToken, 1](fill=raw)
        self._spelling = String()
        self._kind = TokenKind(c_uint(0))
        self._cache_from_ffi_unchecked()

    def _check_valid(self) raises:
        if not self._tu[].alive:
            raise Error("Token used after TranslationUnit disposal")

        if self._generation != self._tu[].generation:
            raise Error("Token used after TranslationUnit.reparse()")

    def _tu_raw(self) raises -> CXTranslationUnit:
        self._check_valid()
        return self._tu[].raw()

    def _ptr(ref self) -> UnsafePointer[CXToken, MutUntrackedOrigin]:
        return rebind[UnsafePointer[CXToken, MutUntrackedOrigin]](
            self._raw.unsafe_ptr(),
        )

    def _cache_from_ffi(mut self) raises:
        self._check_valid()
        self._cache_from_ffi_unchecked()

    def _cache_from_ffi_unchecked(mut self):
        """Cache spelling/kind without validity checks.

        Uses the raw TU handle directly. The caller is responsible for
        guaranteeing the TU is alive.
        """
        self._kind = clang_getTokenKind(self._ptr())

        var cs = _CXStringStorage()
        clang_getTokenSpelling(
            cs.ptr_for_out(),
            self._tu[]._raw_unchecked(),
            self._ptr(),
        )
        self._spelling = cs._take_unchecked()

    def write_to(self, mut writer: Some[Writer]):
        writer.write(
            "Token(",
            Int(self._kind.as_c_uint()),
            ": ",
            self._spelling,
            ")",
        )

    def kind(ref self) raises -> TokenKind:
        """Return the cached token kind."""
        self._check_valid()
        return self._kind

    def spelling(ref self) raises -> String:
        """Return the cached token spelling."""
        self._check_valid()
        return self._spelling

    def location(ref self) raises -> SourceLocation:
        """Return the spelling location of this token."""
        self._check_valid()

        var out = SourceLocation(tu=self._tu)
        clang_getTokenLocation(
            out._ptr(),
            self._tu_raw(),
            self._ptr(),
        )
        out.refresh()
        return out^

    def extent(ref self) raises -> SourceRange:
        """Return the source extent covered by this token."""
        self._check_valid()

        var out = SourceRange(tu=self._tu)
        clang_getTokenExtent(
            out._ptr(),
            self._tu_raw(),
            self._ptr(),
        )
        return out^

    def cursor(ref self) raises -> Cursor:
        """Return the cursor annotation associated with this token."""
        self._check_valid()

        var out = Cursor(tu=self._tu)

        clang_annotateTokens(
            self._tu_raw(),
            self._ptr(),
            c_uint(1),
            out._ptr(),
        )

        return out^


struct TokenGroupIterator[mut: Bool, //, origin: Origin[mut=mut]](
    Iterator, Movable
):
    """Iterator over tokens in a `TokenGroup`."""

    comptime Element = Token

    var _tu: ArcPointer[TranslationUnitState]
    var _generation: Int
    var _tokens: Optional[UnsafePointer[CXToken, MutUntrackedOrigin]]
    var _count: c_uint
    var _index: Int

    def __init__(out self, ref group: TokenGroup):
        self._tu = group._tu
        self._generation = group._generation
        self._tokens = group._tokens
        self._count = group._count
        self._index = 0

    def __next__(mut self) raises StopIteration -> Token:
        if not self._tu[].alive or self._generation != self._tu[].generation:
            raise StopIteration()

        if self._index >= Int(self._count):
            raise StopIteration()

        var raw = (self._tokens.value() + self._index)[].copy()
        self._index += 1
        return Token(tu=self._tu, raw=raw, _unchecked=True)


struct TokenGroup(Iterable, Movable, Sized, Writable):
    """Owns the buffer returned by `clang_tokenize`.

    The group keeps the translation unit alive while the token buffer exists.
    Returned `Token` values copy individual `CXToken` values, so they do not
    dangle when the group is destroyed.

    Example:

    ```mojo
    var tokens = cursor.tokens()
    print(len(tokens))
    ```
    """

    comptime IteratorType[
        iterable_mut: Bool, //, iterable_origin: Origin[mut=iterable_mut]
    ]: Iterator = TokenGroupIterator[mut=iterable_mut, origin=iterable_origin]

    var _tu: ArcPointer[TranslationUnitState]
    var _generation: Int
    var _tokens: Optional[UnsafePointer[CXToken, MutUntrackedOrigin]]
    var _count: c_uint

    def __init__(
        out self,
        tu: TranslationUnit,
        extent: SourceRange,
    ) raises:
        """Tokenize `extent` in `tu` and take ownership of the token buffer."""
        self._tu = tu._shared_state()
        self._generation = self._tu[].generation
        self._tokens = None
        self._count = c_uint(0)

        self._check_valid()

        var e = extent.copy()
        e._check_valid()

        if e._generation != self._generation:
            raise Error(
                (
                    "TokenGroup: SourceRange has different TranslationUnit"
                    " generation"
                ),
            )

        if e._tu[].raw() != self._tu[].raw():
            raise Error(
                (
                    "TokenGroup: SourceRange belongs to a different"
                    " TranslationUnit"
                ),
            )

        var token_storage = InlineArray[
            Optional[UnsafePointer[CXToken, MutUntrackedOrigin]], 1
        ](fill=Optional[UnsafePointer[CXToken, MutUntrackedOrigin]]())

        var count_storage = InlineArray[c_uint, 1](fill=c_uint(0))

        clang_tokenize(
            self._tu_raw(),
            e._ptr(),
            Optional[
                UnsafePointer[
                    Optional[UnsafePointer[CXToken, MutUntrackedOrigin]],
                    MutUntrackedOrigin,
                ]
            ](
                rebind[
                    UnsafePointer[
                        Optional[UnsafePointer[CXToken, MutUntrackedOrigin]],
                        MutUntrackedOrigin,
                    ]
                ](token_storage.unsafe_ptr())
            ),
            rebind[UnsafePointer[c_uint, MutUntrackedOrigin]](
                count_storage.unsafe_ptr(),
            ),
        )

        self._tokens = token_storage[0]
        self._count = count_storage[0]

    def __init__(
        out self,
        tu: ArcPointer[TranslationUnitState],
        extent: SourceRange,
    ) raises:
        """Tokenize `extent` in a shared translation-unit state."""
        self._tu = tu
        self._generation = tu[].generation
        self._tokens = None
        self._count = c_uint(0)

        self._check_valid()

        var e = extent.copy()
        e._check_valid()

        if e._generation != self._generation:
            raise Error(
                (
                    "TokenGroup: SourceRange has different TranslationUnit"
                    " generation"
                ),
            )

        if e._tu[].raw() != self._tu[].raw():
            raise Error(
                (
                    "TokenGroup: SourceRange belongs to a different"
                    " TranslationUnit"
                ),
            )

        var token_storage = InlineArray[
            Optional[UnsafePointer[CXToken, MutUntrackedOrigin]], 1
        ](fill=Optional[UnsafePointer[CXToken, MutUntrackedOrigin]]())

        var count_storage = InlineArray[c_uint, 1](fill=c_uint(0))

        clang_tokenize(
            self._tu_raw(),
            e._ptr(),
            Optional[
                UnsafePointer[
                    Optional[UnsafePointer[CXToken, MutUntrackedOrigin]],
                    MutUntrackedOrigin,
                ]
            ](
                rebind[
                    UnsafePointer[
                        Optional[UnsafePointer[CXToken, MutUntrackedOrigin]],
                        MutUntrackedOrigin,
                    ]
                ](token_storage.unsafe_ptr())
            ),
            rebind[UnsafePointer[c_uint, MutUntrackedOrigin]](
                count_storage.unsafe_ptr(),
            ),
        )

        self._tokens = token_storage[0]
        self._count = count_storage[0]

    def _check_valid(self) raises:
        if not self._tu[].alive:
            raise Error("TokenGroup used after TranslationUnit disposal")

        if self._generation != self._tu[].generation:
            raise Error("TokenGroup used after TranslationUnit.reparse()")

    def _tu_raw(self) raises -> CXTranslationUnit:
        self._check_valid()
        return self._tu[].raw()

    def __del__(deinit self):
        if self._tokens:
            try:
                clang_disposeTokens(
                    self._tu[].raw(),
                    self._tokens.value(),
                    self._count,
                )
            except:
                pass

    def __len__(self) -> Int:
        """Return the number of tokens in this group."""
        return Int(self._count)

    def write_to(self, mut writer: Some[Writer]):
        writer.write("TokenGroup(count=", Int(self._count), ")")

    def __getitem__(self, i: Int) raises -> Token:
        """Return token `i`."""
        self._check_valid()

        if i < 0 or i >= Int(self._count):
            raise Error("TokenGroup index out of range")

        if not self._tokens:
            raise Error("TokenGroup has no token buffer")

        var raw = (self._tokens.value() + i)[].copy()
        return Token(tu=self._tu, raw=raw)

    def __iter__(ref self) -> Self.IteratorType[origin_of(self)]:
        return TokenGroupIterator[origin_of(self)](self)

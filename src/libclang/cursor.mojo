"""High-level `Cursor` wrapper.

A `Cursor` is a copied `CXCursor` value plus an ARC keepalive reference to the
owning `TranslationUnitState`.

Important:
- `Cursor` does not own libclang AST memory.
- `Cursor` keeps the owning TranslationUnit alive through ArcPointer.
- `Cursor` becomes stale after TranslationUnit.reparse() if generation changes.
- Every FFI call passes `CXCursor *` to the shim, never `CXCursor` by value.
"""

from src._ffi import (
    CXCursor,
    CXCursorKind,
    CXTranslationUnit,
    CXType,
    CXSourceLocation,
    CXSourceRange,
    CXFile,
    clang_getNullCursor,
    clang_equalCursors,
    clang_Cursor_isNull,
    clang_hashCursor,
    clang_getCursorKind,
    clang_getCursorSpelling,
    clang_getCursorDisplayName,
    clang_getCursorUSR,
    clang_getCursorType,
    clang_getCursorResultType,
    clang_getCursorLocation,
    clang_getCursorExtent,
    clang_getCursorSemanticParent,
    clang_getCursorLexicalParent,
    clang_getCursorReferenced,
    clang_getCursorDefinition,
    clang_getCanonicalCursor,
    clang_Cursor_getTranslationUnit,
    clang_isCursorDefinition,
    clang_isDeclaration,
    clang_isReference,
    clang_isExpression,
    clang_isStatement,
    clang_isAttribute,
    c_uint,
    c_int,
)

from src.libclang.common import _CXStringStorage

from src.libclang.translation_unit import (
    TranslationUnitState,
)

from std.collections import InlineArray
from std.memory import ArcPointer, UnsafePointer, ImmutOpaquePointer


struct Cursor(Copyable, Movable, Writable):
    """A high-level wrapper around `CXCursor`.

    The raw `CXCursor` is copied by value into `_raw`.
    The owning `CXTranslationUnit` is kept alive by `_tu`.
    """

    var _tu: ArcPointer[TranslationUnitState]
    var _generation: Int
    var _raw: InlineArray[CXCursor, 1]

    def __init__(
        out self,
        tu: ArcPointer[TranslationUnitState],
    ) raises:
        """Create a null cursor tied to a translation unit."""
        self._tu = tu
        self._generation = tu[].generation
        self._raw = InlineArray[CXCursor, 1](
            fill=_zero_cursor(),
        )

        clang_getNullCursor(self._ptr())

    def __init__(
        out self,
        tu: ArcPointer[TranslationUnitState],
        raw: CXCursor,
    ):
        """Create a cursor from a copied raw `CXCursor` value."""
        self._tu = tu
        self._generation = tu[].generation
        self._raw = InlineArray[CXCursor, 1](fill=raw)

    def _check_valid(self) raises:
        """Reject use after TU disposal or in-place reparse."""
        if self._generation != self._tu[].generation:
            raise Error("Cursor is stale due to TranslationUnit reparse")

    def _ptr(mut self) -> UnsafePointer[CXCursor, MutExternalOrigin]:
        """Mutable pointer to raw cursor storage for shim calls."""
        return rebind[UnsafePointer[CXCursor, MutExternalOrigin]](
            self._raw.unsafe_ptr(),
        )

    def _const_ptr(self) -> UnsafePointer[CXCursor, ImmutExternalOrigin]:
        """Immutable pointer to raw cursor storage.

        Use this if your shim signatures distinguish const input pointers.
        If your generated `_ffi.mojo` currently expects MutExternalOrigin for
        all pointers, keep using `_ptr()`.
        """
        return rebind[UnsafePointer[CXCursor, ImmutExternalOrigin]](
            self._raw.unsafe_ptr(),
        )

    def raw_value(self) raises -> CXCursor:
        """Return a copied raw cursor value.

        This does not transfer ownership of anything. It is mostly useful for
        tests or low-level adapters.
        """
        self._check_valid()
        return self._raw[0].copy()

    def translation_unit(self) raises -> CXTranslationUnit:
        """Return the borrowed raw TU handle after validity checks."""
        self._check_valid()
        return self._tu[].raw()

    def write_to(mut self, mut writer: Some[Writer]):
        try:
            writer.write(
                "Cursor(kind=", self.kind(), ", spelling=", self.spelling(), ")"
            )
        except:
            writer.write("Cursor(<invalid>)")

    # -----------------------------------------------------------------------
    # Basic cursor properties
    # -----------------------------------------------------------------------

    def is_null(mut self) raises -> Bool:
        self._check_valid()
        return Bool(clang_Cursor_isNull(self._ptr()))

    def kind(mut self) raises -> CXCursorKind:
        self._check_valid()
        return clang_getCursorKind(self._ptr())

    def hash(mut self) raises -> c_uint:
        self._check_valid()
        return clang_hashCursor(self._ptr())

    def spelling(mut self) raises -> String:
        self._check_valid()
        var cs = _CXStringStorage()
        clang_getCursorSpelling(cs.ptr_for_out(), self._ptr())
        return cs.take()

    def display_name(mut self) raises -> String:
        self._check_valid()
        var cs = _CXStringStorage()
        clang_getCursorDisplayName(cs.ptr_for_out(), self._ptr())
        return cs.take()

    def usr(mut self) raises -> Optional[String]:
        self._check_valid()
        var cs = _CXStringStorage()
        clang_getCursorUSR(cs.ptr_for_out(), self._ptr())
        var value = cs.take()
        if not value:
            return None
        return Optional[String](value)

    # -----------------------------------------------------------------------
    # Classification
    # -----------------------------------------------------------------------

    def is_definition(mut self) raises -> Bool:
        self._check_valid()
        return Bool(clang_isCursorDefinition(self._ptr()))

    def is_declaration(mut self) raises -> Bool:
        self._check_valid()
        return Bool(clang_isDeclaration(self._raw[0].kind))

    def is_reference(mut self) raises -> Bool:
        self._check_valid()
        return Bool(clang_isReference(self._raw[0].kind))

    def is_expression(mut self) raises -> Bool:
        self._check_valid()
        return Bool(clang_isExpression(self._raw[0].kind))

    def is_statement(mut self) raises -> Bool:
        self._check_valid()
        return Bool(clang_isStatement(self._raw[0].kind))

    def is_attribute(mut self) raises -> Bool:
        self._check_valid()
        return Bool(clang_isAttribute(self._raw[0].kind))

    # -----------------------------------------------------------------------
    # Cursor relations
    # -----------------------------------------------------------------------

    def semantic_parent(mut self) raises -> Optional[Self]:
        self._check_valid()

        var out = Self(self._tu)
        clang_getCursorSemanticParent(out._ptr(), self._ptr())

        if Bool(clang_Cursor_isNull(out._ptr())):
            return None

        return Optional[Self](out^)

    def lexical_parent(mut self) raises -> Optional[Self]:
        self._check_valid()

        var out = Self(self._tu)
        clang_getCursorLexicalParent(out._ptr(), self._ptr())

        if Bool(clang_Cursor_isNull(out._ptr())):
            return None

        return Optional[Self](out^)

    def referenced(mut self) raises -> Optional[Self]:
        self._check_valid()

        var out = Self(self._tu)
        clang_getCursorReferenced(out._ptr(), self._ptr())

        if Bool(clang_Cursor_isNull(out._ptr())):
            return None

        return Optional[Self](out^)

    def definition(mut self) raises -> Optional[Self]:
        self._check_valid()

        var out = Self(self._tu)
        clang_getCursorDefinition(out._ptr(), self._ptr())

        if Bool(clang_Cursor_isNull(out._ptr())):
            return None

        return Optional[Self](out^)

    def canonical(mut self) raises -> Self:
        self._check_valid()

        var out = Self(self._tu)
        clang_getCanonicalCursor(out._ptr(), self._ptr())
        return out^

    def equals(mut self, mut other: Self) raises -> Bool:
        self._check_valid()
        other._check_valid()

        # Optional: require same TranslationUnit generation.
        if self._generation != other._generation:
            return False

        return Bool(clang_equalCursors(self._ptr(), other._ptr()))

    # -----------------------------------------------------------------------
    # Types and source locations
    # -----------------------------------------------------------------------

    def type(mut self) raises -> Type:
        """Return the semantic type of this cursor.

        Local import avoids a module cycle:
            cursor.mojo -> type_.mojo -> cursor.mojo
        """
        from src.libclang.type_ import Type

        self._check_valid()

        var out = Type(self._tu)
        clang_getCursorType(out._ptr(), self._ptr())
        return out^

    def result_type(mut self) raises -> Type:
        from src.libclang.type_ import Type

        self._check_valid()

        var out = Type(self._tu)
        clang_getCursorResultType(out._ptr(), self._ptr())
        return out^

    def location(mut self) raises -> SourceLocation:
        from src.libclang.source_location import SourceLocation

        self._check_valid()

        var out = SourceLocation(self._tu)
        clang_getCursorLocation(out._ptr(), self._ptr())
        return out^

    def extent(mut self) raises -> SourceRange:
        from src.libclang.source_range import SourceRange

        self._check_valid()

        var out = SourceRange(self._tu)
        clang_getCursorExtent(out._ptr(), self._ptr())
        return out^


def _zero_cursor() -> CXCursor:
    """Return a zero-initialized `CXCursor` value.

    This is only used as initial storage before a shim function writes the real
    cursor value.
    """
    return CXCursor(
        kind=CXCursorKind(c_uint(0)),
        xdata=c_int(0),
        data=InlineArray[Optional[ImmutOpaquePointer[ImmutExternalOrigin]], 3](
            fill=None
        ),
    )

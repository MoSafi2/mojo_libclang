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
    CXClientData,
    clang_visitChildren,
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

    @staticmethod
    def null(tu: ArcPointer[TranslationUnitState]) raises -> Self:
        return Self(tu=tu)

    def __eq__(mut self, mut other: Self) raises -> Bool:
        if self._generation != other._generation:
            return False
        return Bool(clang_equalCursors(self._ptr(), other._ptr()))

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

    def children(mut self) raises -> List[Cursor]:
        """Return immediate child cursors."""

        self._check_valid()
        return collect_children(self.copy())

    def get_children(mut self) raises -> List[Cursor]:
        """Alias for `children()`."""
        return self.children()

    def walk_preorder(mut self) raises -> List[Cursor]:
        """Return this cursor and all descendants in preorder."""

        self._check_valid()
        return walk_preorder(self.copy())

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
        out.refresh()
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


comptime MAX_CHILDREN = 4096


@fieldwise_init
struct _Collector(Movable):
    var buffer: UnsafePointer[CXCursor, MutAnyOrigin]
    var count: Int
    var capacity: Int
    var truncated: Bool


def _visit_trampoline(
    cursor: Optional[UnsafePointer[CXCursor, MutExternalOrigin]],
    parent: Optional[UnsafePointer[CXCursor, MutExternalOrigin]],
    client_data: CXClientData,
) abi("C") -> CXChildVisitResult:
    if not cursor:
        return CXChildVisit_Continue

    var opaque = client_data.value()
    var collector = rebind[UnsafePointer[_Collector, MutAnyOrigin]](
        rebind[UnsafePointer[UInt8, MutAnyOrigin]](
            rebind[UnsafePointer[UInt8, MutExternalOrigin]](opaque),
        ),
    )

    if collector[].count >= collector[].capacity:
        collector[].truncated = True
        return CXChildVisit_Continue

    # Copy the CXCursor value itself. Do not memcpy a guessed byte count.
    collector[].buffer[collector[].count] = cursor.value()[].copy()
    collector[].count += 1

    _ = parent
    return CXChildVisit_Continue


def collect_children(parent: Cursor) raises -> List[Cursor]:
    """Collect the immediate children of `parent`.

    ```
    The returned cursors keep the same translation-unit state as `parent`.
    """
    var p = parent.copy()
    p._check_valid()

    var buffer = alloc[CXCursor](MAX_CHILDREN)
    var collector_box = alloc[_Collector](1)

    collector_box[] = _Collector(
        buffer=buffer,
        count=0,
        capacity=MAX_CHILDREN,
        truncated=False,
    )

    var client_data = CXClientData(
        rebind[MutOpaquePointer[MutExternalOrigin]](
            rebind[UnsafePointer[UInt8, MutExternalOrigin]](
                rebind[UnsafePointer[UInt8, MutAnyOrigin]](collector_box),
            ),
        ),
    )

    _ = clang_visitChildren(
        p._ptr(),
        _visit_trampoline,
        client_data,
    )

    # Catch a reparse that happened during or immediately after traversal.
    p._check_valid()

    if collector_box[].truncated:
        collector_box.free()
        buffer.free()
        raise Error(
            "collect_children: child count exceeded MAX_CHILDREN="
            + String(MAX_CHILDREN),
        )

    var out = List[Cursor]()

    for i in range(collector_box[].count):
        var child = Cursor(
            tu=p._tu,
            raw=buffer[i],
        )
        out.append(child^)

    collector_box.free()
    buffer.free()

    return out^


def walk_preorder(root: Cursor) raises -> List[Cursor]:
    """Return cursors in preorder: root, then descendants."""
    var out = List[Cursor]()

    var r = root.copy()
    r._check_valid()
    out.append(r.copy())

    var children = collect_children(r)

    for i in range(Int(children.__len__())):
        var child = children[i].copy()
        var descendants = walk_preorder(child)

        for j in range(Int(descendants.__len__())):
            out.append(descendants[j].copy())

    return out^

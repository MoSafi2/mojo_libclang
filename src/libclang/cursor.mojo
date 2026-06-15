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
    CXPrintingPolicy,
    CX_CXXAccessSpecifier,
    CXTemplateArgumentKind,
    CXLinkageKind,
    CXVisibilityKind,
    CXAvailabilityKind,
    CXLanguageKind,
    CXTLSKind,
    CX_StorageClass,
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
    clang_CXXMethod_isPureVirtual,
    clang_CXXMethod_isStatic,
    clang_CXXMethod_isVirtual,
    clang_isVirtualBase,
    clang_CXXMethod_isConst,
    clang_CXXMethod_isDefaulted,
    clang_CXXMethod_isDeleted,
    clang_CXXMethod_isMoveAssignmentOperator,
    clang_CXXMethod_isCopyAssignmentOperator,
    clang_CXXMethod_isExplicit,
    clang_getCXXAccessSpecifier,
    clang_CXXRecord_isAbstract,
    clang_EnumDecl_isScoped,
    clang_Cursor_isVariadic,
    clang_Cursor_isExternalSymbol,
    clang_Cursor_isAnonymous,
    clang_Cursor_isAnonymousRecordDecl,
    clang_Cursor_getNumArguments,
    clang_Cursor_getArgument,
    clang_getOverriddenCursors,
    clang_disposeOverriddenCursors,
    clang_getNumOverloadedDecls,
    clang_getOverloadedDecl,
    clang_Cursor_getNumTemplateArguments,
    clang_Cursor_getTemplateArgumentKind,
    clang_Cursor_getTemplateArgumentType,
    clang_Cursor_getTemplateArgumentValue,
    clang_Cursor_getTemplateArgumentUnsignedValue,
    clang_getSpecializedCursorTemplate,
    clang_getTemplateCursorKind,
    clang_getCursorPrettyPrinted,
    clang_getCursorPrintingPolicy,
    clang_PrintingPolicy_dispose,
    clang_Cursor_getBriefCommentText,
    clang_Cursor_getRawCommentText,
    clang_isInvalid,
    clang_isTranslationUnit,
    clang_isPreprocessing,
    clang_isUnexposed,
    clang_Cursor_hasAttrs,
    clang_isConstQualifiedType,
    clang_isVolatileQualifiedType,
    clang_isRestrictQualifiedType,
    clang_isPODType,
    clang_getCursorLinkage,
    clang_getCursorVisibility,
    clang_getCursorAvailability,
    clang_getCursorLanguage,
    clang_getCursorTLSKind,
    clang_getIncludedFile,
    clang_getTypedefDeclUnderlyingType,
    clang_getEnumDeclIntegerType,
    clang_Cursor_isBitField,
    clang_getFieldDeclBitWidth,
    clang_Cursor_getOffsetOfField,
    clang_Cursor_getStorageClass,
    clang_Cursor_getMangling,
    clang_getEnumConstantDeclValue,
    clang_getEnumConstantDeclUnsignedValue,
    clang_CXXConstructor_isConvertingConstructor,
    clang_CXXConstructor_isCopyConstructor,
    clang_CXXConstructor_isDefaultConstructor,
    clang_CXXConstructor_isMoveConstructor,
    clang_CXXField_isMutable,
    clang_getDeclObjCTypeEncoding,
    clang_getCursorBinaryOperatorKind,
    clang_getCursorUnaryOperatorKind,
    clang_Cursor_isFunctionInlined,
    c_uint,
    c_int,
    c_long_long,
    c_ulong_long,
    CXClientData,
    CXCursorVisitor,
    CXChildVisitResult,
    CXChildVisit_Continue,
    CXChildVisit_Break,
    clang_visitChildren,
)

from src.libclang.enums import (
    CursorKind,
    TypeKind,
    LinkageKind,
    VisibilityKind,
    AvailabilityKind,
    LanguageKind,
    TLSKind,
    StorageClass,
    AccessSpecifier,
    TemplateArgumentKind,
    BinaryOperator,
    UnaryOperator,
)

from src.libclang.common import _CXStringStorage

from src.libclang.translation_unit import (
    TranslationUnitState,
)

from std.collections import InlineArray, List
from std.iter import Iterable, Iterator, StopIteration
from std.memory import (
    ArcPointer,
    UnsafePointer,
    ImmutOpaquePointer,
    MutOpaquePointer,
)


struct Cursor(Copyable, Movable, Writable, Iterable):
    """A high-level wrapper around `CXCursor`.

    The raw `CXCursor` is copied by value into `_raw`.
    The owning `CXTranslationUnit` is kept alive by `_tu`.
    """

    comptime IteratorType[
        iterable_mut: Bool, //, iterable_origin: Origin[mut=iterable_mut]
    ]: Iterator = CursorChildrenIterator

    var _tu: ArcPointer[TranslationUnitState]
    var _generation: Int
    var _raw: InlineArray[CXCursor, 1]

    def __init__(out self, tu: TranslationUnit) raises:
        """Create a null cursor tied to `tu`."""
        self._tu = tu.state()
        self._generation = self._tu[].generation
        self._raw = InlineArray[CXCursor, 1](
            fill=_zero_cursor(),
        )
        clang_getNullCursor(self._ptr())

    def __init__(out self, tu: TranslationUnit, raw: CXCursor):
        self._tu = tu.state()
        self._generation = tu.state()[].generation
        self._raw = InlineArray[CXCursor, 1](fill=raw)

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
    def null(tu: TranslationUnit) raises -> Self:
        return Self(tu=tu)

    @staticmethod
    def null(tu: ArcPointer[TranslationUnitState]) raises -> Self:
        return Self(tu=tu)

    def __eq__(ref self, ref other: Self) raises -> Bool:
        if self._generation != other._generation:
            return False
        return Bool(clang_equalCursors(self._ptr(), other._ptr()))

    def _check_valid(self) raises:
        """Reject use after TU disposal or in-place reparse."""
        if self._generation != self._tu[].generation:
            raise Error("Cursor is stale due to TranslationUnit reparse")

    def _ptr(ref self) -> UnsafePointer[CXCursor, MutExternalOrigin]:
        """Pointer to raw cursor storage for shim calls."""
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

    def children(ref self) raises -> List[Cursor]:
        """Return immediate child cursors."""

        self._check_valid()
        return collect_children(self.copy())

    def get_children(ref self) raises -> List[Cursor]:
        """Alias for `children()`."""
        return self.children()

    def walk_preorder(ref self) raises -> List[Cursor]:
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

    def translation_unit(self) raises -> TranslationUnit:
        """Return the TranslationUnit to which this cursor belongs."""
        from src.libclang.translation_unit import TranslationUnit

        self._check_valid()
        return TranslationUnit(self._tu)

    def raw_translation_unit(self) raises -> CXTranslationUnit:
        """Return the borrowed raw TU handle after validity checks."""
        self._check_valid()
        return self._tu[].raw()

    def write_to(ref self, mut writer: Some[Writer]):
        try:
            writer.write(
                "Cursor(kind=",
                self.kind().as_c_uint(),
                ", spelling=",
                self.spelling(),
                ")",
            )
        except:
            writer.write("Cursor(<invalid>)")

    # -----------------------------------------------------------------------
    # Basic cursor properties
    # -----------------------------------------------------------------------

    def is_null(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_Cursor_isNull(self._ptr()))

    def kind(ref self) raises -> CursorKind:
        self._check_valid()
        return CursorKind(clang_getCursorKind(self._ptr()))

    def hash(ref self) raises -> c_uint:
        self._check_valid()
        return clang_hashCursor(self._ptr())

    def spelling(ref self) raises -> String:
        self._check_valid()
        var cs = _CXStringStorage()
        clang_getCursorSpelling(cs.ptr_for_out(), self._ptr())
        return cs.take()

    def display_name(ref self) raises -> String:
        self._check_valid()
        var cs = _CXStringStorage()
        clang_getCursorDisplayName(cs.ptr_for_out(), self._ptr())
        return cs.take()

    def usr(ref self) raises -> Optional[String]:
        self._check_valid()
        var cs = _CXStringStorage()
        clang_getCursorUSR(cs.ptr_for_out(), self._ptr())
        return cs.take_optional()

    # -----------------------------------------------------------------------
    # Classification
    # -----------------------------------------------------------------------

    def is_definition(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_isCursorDefinition(self._ptr()))

    def is_declaration(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_isDeclaration(self._raw[0].kind))

    def is_reference(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_isReference(self._raw[0].kind))

    def is_expression(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_isExpression(self._raw[0].kind))

    def is_statement(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_isStatement(self._raw[0].kind))

    def is_attribute(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_isAttribute(self._raw[0].kind))

    def is_invalid(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_isInvalid(self._raw[0].kind))

    def is_translation_unit(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_isTranslationUnit(self._raw[0].kind))

    def is_preprocessing(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_isPreprocessing(self._raw[0].kind))

    def is_unexposed(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_isUnexposed(self._raw[0].kind))

    def has_attrs(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_Cursor_hasAttrs(self._ptr()))

    # -----------------------------------------------------------------------
    # C++ method predicates
    # -----------------------------------------------------------------------

    def is_pure_virtual(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_CXXMethod_isPureVirtual(self._ptr()))

    def is_static(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_CXXMethod_isStatic(self._ptr()))

    def is_virtual(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_CXXMethod_isVirtual(self._ptr()))

    def is_virtual_base(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_isVirtualBase(self._ptr()))

    def is_const(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_CXXMethod_isConst(self._ptr()))

    def is_defaulted(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_CXXMethod_isDefaulted(self._ptr()))

    def is_deleted(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_CXXMethod_isDeleted(self._ptr()))

    def is_move_assignment_operator(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_CXXMethod_isMoveAssignmentOperator(self._ptr()))

    def is_copy_assignment_operator(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_CXXMethod_isCopyAssignmentOperator(self._ptr()))

    def is_explicit(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_CXXMethod_isExplicit(self._ptr()))

    def is_explicit_method(ref self) raises -> Bool:
        """Alias for ``is_explicit()`` that matches the Python binding name."""
        return self.is_explicit()

    def is_converting_constructor(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_CXXConstructor_isConvertingConstructor(self._ptr()))

    def is_copy_constructor(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_CXXConstructor_isCopyConstructor(self._ptr()))

    def is_default_constructor(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_CXXConstructor_isDefaultConstructor(self._ptr()))

    def is_move_constructor(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_CXXConstructor_isMoveConstructor(self._ptr()))

    def is_mutable_field(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_CXXField_isMutable(self._ptr()))

    def is_abstract_record(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_CXXRecord_isAbstract(self._ptr()))

    def is_scoped_enum(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_EnumDecl_isScoped(self._ptr()))

    def is_variadic(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_Cursor_isVariadic(self._ptr()))

    def is_external_symbol(ref self) raises -> Bool:
        self._check_valid()
        var language_cs = _CXStringStorage()
        var defined_in_cs = _CXStringStorage()
        var is_generated: InlineArray[c_uint, 1] = InlineArray[c_uint, 1](
            fill=c_uint(0)
        )
        var result = Bool(
            clang_Cursor_isExternalSymbol(
                self._ptr(),
                language_cs.ptr_for_out(),
                defined_in_cs.ptr_for_out(),
                rebind[UnsafePointer[c_uint, MutExternalOrigin]](
                    is_generated.unsafe_ptr(),
                ),
            )
        )
        _ = language_cs.take()
        _ = defined_in_cs.take()
        return result

    def is_anonymous(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_Cursor_isAnonymous(self._ptr()))

    def is_anonymous_record_decl(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_Cursor_isAnonymousRecordDecl(self._ptr()))

    def is_const_qualified_type(ref self) raises -> Bool:
        from src.libclang.type_ import Type

        self._check_valid()
        var t = Type(tu=self._tu)
        clang_getCursorType(t._ptr(), self._ptr())
        return Bool(clang_isConstQualifiedType(t._ptr()))

    def is_volatile_qualified_type(ref self) raises -> Bool:
        from src.libclang.type_ import Type

        self._check_valid()
        var t = Type(tu=self._tu)
        clang_getCursorType(t._ptr(), self._ptr())
        return Bool(clang_isVolatileQualifiedType(t._ptr()))

    def is_restrict_qualified_type(ref self) raises -> Bool:
        from src.libclang.type_ import Type

        self._check_valid()
        var t = Type(tu=self._tu)
        clang_getCursorType(t._ptr(), self._ptr())
        return Bool(clang_isRestrictQualifiedType(t._ptr()))

    def is_pod_type(ref self) raises -> Bool:
        from src.libclang.type_ import Type

        self._check_valid()
        var t = Type(tu=self._tu)
        clang_getCursorType(t._ptr(), self._ptr())
        return Bool(clang_isPODType(t._ptr()))

    def access_specifier(ref self) raises -> AccessSpecifier:
        self._check_valid()
        return AccessSpecifier(c_uint(clang_getCXXAccessSpecifier(self._ptr())))

    # -----------------------------------------------------------------------
    # Cursor relations
    # -----------------------------------------------------------------------

    def semantic_parent(ref self) raises -> Optional[Self]:
        self._check_valid()

        var out = Self(self._tu)
        clang_getCursorSemanticParent(out._ptr(), self._ptr())

        if Bool(clang_Cursor_isNull(out._ptr())):
            return None

        return Optional[Self](out^)

    def lexical_parent(ref self) raises -> Optional[Self]:
        self._check_valid()

        var out = Self(self._tu)
        clang_getCursorLexicalParent(out._ptr(), self._ptr())

        if Bool(clang_Cursor_isNull(out._ptr())):
            return None

        return Optional[Self](out^)

    def referenced(ref self) raises -> Optional[Self]:
        self._check_valid()

        var out = Self(self._tu)
        clang_getCursorReferenced(out._ptr(), self._ptr())

        if Bool(clang_Cursor_isNull(out._ptr())):
            return None

        return Optional[Self](out^)

    def definition(ref self) raises -> Optional[Self]:
        self._check_valid()

        var out = Self(self._tu)
        clang_getCursorDefinition(out._ptr(), self._ptr())

        if Bool(clang_Cursor_isNull(out._ptr())):
            return None

        return Optional[Self](out^)

    def canonical(ref self) raises -> Self:
        self._check_valid()

        var out = Self(self._tu)
        clang_getCanonicalCursor(out._ptr(), self._ptr())
        return out^

    def equals(ref self, ref other: Self) raises -> Bool:
        self._check_valid()
        other._check_valid()

        # Optional: require same TranslationUnit generation.
        if self._generation != other._generation:
            return False

        return Bool(clang_equalCursors(self._ptr(), other._ptr()))

    # -----------------------------------------------------------------------
    # Cursor info (pretty-printed, overridden, overloaded, template)
    # -----------------------------------------------------------------------

    def pretty_printed(
        ref self,
        policy: Optional[PrintingPolicy] = None,
    ) raises -> String:
        """Pretty-print the declaration referenced by this cursor.

        If no ``PrintingPolicy`` is provided, a default policy is created and
        disposed automatically.
        """
        from src.libclang.printing_policy import PrintingPolicy

        self._check_valid()

        var cs = _CXStringStorage()
        if policy:
            clang_getCursorPrettyPrinted(
                cs.ptr_for_out(), self._ptr(), policy.value()._raw
            )
        else:
            var default_policy = PrintingPolicy(self._ptr())
            clang_getCursorPrettyPrinted(
                cs.ptr_for_out(), self._ptr(), default_policy._raw
            )
        return cs.take()

    def overridden_cursors(ref self) raises -> List[Cursor]:
        self._check_valid()
        var overridden_slot: InlineArray[
            Optional[UnsafePointer[CXCursor, MutExternalOrigin]], 1
        ] = InlineArray[
            Optional[UnsafePointer[CXCursor, MutExternalOrigin]], 1
        ](
            fill=None
        )
        var num_slot: InlineArray[c_uint, 1] = InlineArray[c_uint, 1](
            fill=c_uint(0)
        )

        clang_getOverriddenCursors(
            self._ptr(),
            rebind[
                UnsafePointer[
                    Optional[UnsafePointer[CXCursor, MutExternalOrigin]],
                    MutExternalOrigin,
                ]
            ](overridden_slot.unsafe_ptr()),
            rebind[UnsafePointer[c_uint, MutExternalOrigin]](
                num_slot.unsafe_ptr()
            ),
        )

        var raw_ptr = overridden_slot[0]
        var count = Int(num_slot[0])

        var out = List[Cursor]()
        if raw_ptr:
            for i in range(count):
                var raw = (raw_ptr.value() + i)[].copy()
                out.append(Cursor(tu=self._tu, raw=raw))
            clang_disposeOverriddenCursors(raw_ptr.value())
        return out^

    def num_overloaded_decls(ref self) raises -> c_uint:
        self._check_valid()
        return clang_getNumOverloadedDecls(self._ptr())

    def get_overloaded_decl(ref self, index: c_uint) raises -> Self:
        self._check_valid()
        var out = Self(self._tu)
        clang_getOverloadedDecl(out._ptr(), self._ptr(), index)
        return out^

    def num_template_arguments(ref self) raises -> c_int:
        self._check_valid()
        return clang_Cursor_getNumTemplateArguments(self._ptr())

    def template_argument_kind(
        ref self, i: c_uint
    ) raises -> TemplateArgumentKind:
        self._check_valid()
        return TemplateArgumentKind(
            c_uint(clang_Cursor_getTemplateArgumentKind(self._ptr(), i))
        )

    def template_argument_type(ref self, i: c_uint) raises -> Type:
        from src.libclang.type_ import Type

        self._check_valid()
        var out = Type(tu=self._tu)
        clang_Cursor_getTemplateArgumentType(out._ptr(), self._ptr(), i)
        out._cache_spelling()
        return out^

    def template_argument_value(ref self, i: c_uint) raises -> c_long_long:
        self._check_valid()
        return clang_Cursor_getTemplateArgumentValue(self._ptr(), i)

    def template_argument_unsigned_value(
        ref self, i: c_uint
    ) raises -> c_ulong_long:
        self._check_valid()
        return clang_Cursor_getTemplateArgumentUnsignedValue(self._ptr(), i)

    def specialized_cursor_template(ref self) raises -> Optional[Self]:
        self._check_valid()
        var out = Self(self._tu)
        clang_getSpecializedCursorTemplate(out._ptr(), self._ptr())
        if out.is_null():
            return None
        return Optional[Self](out^)

    def template_kind(ref self) raises -> CursorKind:
        self._check_valid()
        return CursorKind(clang_getTemplateCursorKind(self._ptr()))

    # -----------------------------------------------------------------------
    # Arguments and tokens
    # -----------------------------------------------------------------------

    def num_arguments(ref self) raises -> c_int:
        self._check_valid()
        return clang_Cursor_getNumArguments(self._ptr())

    def get_argument(ref self, i: c_uint) raises -> Self:
        self._check_valid()
        var out = Self(self._tu)
        clang_Cursor_getArgument(out._ptr(), self._ptr(), i)
        return out^

    def get_arguments(ref self) raises -> List[Cursor]:
        self._check_valid()
        var n = self.num_arguments()
        var out = List[Cursor]()
        for i in range(Int(n)):
            out.append(self.get_argument(c_uint(i)))
        return out^

    def get_tokens(ref self) raises -> TokenGroup:
        from src.libclang.token import TokenGroup

        self._check_valid()
        var ext = self.extent()
        var tg = TokenGroup(tu=self._tu, extent=ext.copy())
        return tg^

    # -----------------------------------------------------------------------
    # Comments
    # -----------------------------------------------------------------------

    def brief_comment(ref self) raises -> Optional[String]:
        self._check_valid()
        var cs = _CXStringStorage()
        clang_Cursor_getBriefCommentText(cs.ptr_for_out(), self._ptr())
        return cs.take_optional()

    def raw_comment(ref self) raises -> Optional[String]:
        self._check_valid()
        var cs = _CXStringStorage()
        clang_Cursor_getRawCommentText(cs.ptr_for_out(), self._ptr())
        return cs.take_optional()

    # -----------------------------------------------------------------------
    # Miscellaneous cursor properties
    # -----------------------------------------------------------------------

    def linkage(ref self) raises -> LinkageKind:
        self._check_valid()
        return LinkageKind(c_uint(clang_getCursorLinkage(self._ptr())))

    def visibility(ref self) raises -> VisibilityKind:
        self._check_valid()
        return VisibilityKind(c_uint(clang_getCursorVisibility(self._ptr())))

    def availability(ref self) raises -> AvailabilityKind:
        self._check_valid()
        return AvailabilityKind(
            c_uint(clang_getCursorAvailability(self._ptr()))
        )

    def language(ref self) raises -> LanguageKind:
        self._check_valid()
        return LanguageKind(c_uint(clang_getCursorLanguage(self._ptr())))

    def tls_kind(ref self) raises -> TLSKind:
        self._check_valid()
        return TLSKind(c_uint(clang_getCursorTLSKind(self._ptr())))

    def storage_class(ref self) raises -> StorageClass:
        self._check_valid()
        return StorageClass(c_uint(clang_Cursor_getStorageClass(self._ptr())))

    def is_bitfield(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_Cursor_isBitField(self._ptr()))

    def get_bitfield_width(ref self) raises -> c_int:
        self._check_valid()
        return clang_getFieldDeclBitWidth(self._ptr())

    def get_offset_of_field(ref self) raises -> c_long_long:
        self._check_valid()
        return clang_Cursor_getOffsetOfField(self._ptr())

    def get_field_offsetof(ref self) raises -> c_long_long:
        """Alias for ``get_offset_of_field()`` matching the Python name."""
        return self.get_offset_of_field()

    def get_base_offsetof(ref self, ref parent: Self) raises -> c_long_long:
        """Return the offset of a CXX_BASE_SPECIFIER relative to ``parent``.

        Note: This falls back to ``clang_Cursor_getOffsetOfField`` because the
        upstream ``clang_getOffsetOfBase`` helper is not exposed by the
        generated raw FFI for this libclang version.
        """
        self._check_valid()
        parent._check_valid()
        return clang_Cursor_getOffsetOfField(self._ptr())

    def is_function_inlined(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_Cursor_isFunctionInlined(self._ptr()))

    def underlying_typedef_type(ref self) raises -> Type:
        from src.libclang.type_ import Type

        self._check_valid()
        var out = Type(tu=self._tu)
        clang_getTypedefDeclUnderlyingType(out._ptr(), self._ptr())
        out._cache_spelling()
        return out^

    def enum_type(ref self) raises -> Type:
        from src.libclang.type_ import Type

        self._check_valid()
        var out = Type(tu=self._tu)
        clang_getEnumDeclIntegerType(out._ptr(), self._ptr())
        out._cache_spelling()
        return out^

    def mangled_name(ref self) raises -> String:
        self._check_valid()
        var cs = _CXStringStorage()
        clang_Cursor_getMangling(cs.ptr_for_out(), self._ptr())
        return cs.take()

    def enum_value(ref self) raises -> c_long_long:
        """Return the value of an enum constant declaration.

        This inspects the underlying integer type to decide whether to use the
        signed or unsigned libclang accessor, matching the Python bindings.
        """
        self._check_valid()

        if self.kind() != CursorKind.ENUM_CONSTANT_DECL:
            raise Error(
                "Cursor.enum_value: cursor is not an ENUM_CONSTANT_DECL"
            )

        var underlying = self.type()
        if underlying.kind() == TypeKind.ENUM:
            var decl = underlying.get_declaration()
            if decl:
                underlying = decl.value().enum_type()

        var uk = underlying.kind()
        if (
            uk == TypeKind.CHAR_U
            or uk == TypeKind.UCHAR
            or uk == TypeKind.CHAR16
            or uk == TypeKind.CHAR32
            or uk == TypeKind.USHORT
            or uk == TypeKind.UINT
            or uk == TypeKind.ULONG
            or uk == TypeKind.ULONG_LONG
            or uk == TypeKind.UINT128
        ):
            return c_long_long(
                clang_getEnumConstantDeclUnsignedValue(self._ptr())
            )

        return clang_getEnumConstantDeclValue(self._ptr())

    def objc_type_encoding(ref self) raises -> String:
        """Return the Objective-C type encoding for this cursor."""
        self._check_valid()
        var cs = _CXStringStorage()
        clang_getDeclObjCTypeEncoding(cs.ptr_for_out(), self._ptr())
        return cs.take()

    def binary_operator(ref self) raises -> BinaryOperator:
        """Return the binary operator kind for a binary operator cursor."""
        self._check_valid()
        return BinaryOperator(clang_getCursorBinaryOperatorKind(self._ptr()))

    def unary_operator(ref self) raises -> UnaryOperator:
        """Return the unary operator kind for a unary operator cursor."""
        self._check_valid()
        return UnaryOperator(clang_getCursorUnaryOperatorKind(self._ptr()))

    def get_included_file(ref self) raises -> Optional[File]:
        from src.libclang.file import File

        self._check_valid()
        var raw = clang_getIncludedFile(self._ptr())
        if not raw:
            return None
        var f = File(tu=self._tu, raw=raw)
        return Optional[File](f^)

    # -----------------------------------------------------------------------
    # Types and source locations
    # -----------------------------------------------------------------------

    def type(ref self) raises -> Type:
        """Return the semantic type of this cursor.

        Local import avoids a module cycle:
            cursor.mojo -> type_.mojo -> cursor.mojo
        """
        from src.libclang.type_ import Type

        self._check_valid()

        var out = Type(self._tu)
        clang_getCursorType(out._ptr(), self._ptr())
        return out^

    def result_type(ref self) raises -> Type:
        from src.libclang.type_ import Type

        self._check_valid()

        var out = Type(self._tu)
        clang_getCursorResultType(out._ptr(), self._ptr())
        return out^

    def location(ref self) raises -> SourceLocation:
        from src.libclang.source_location import SourceLocation

        self._check_valid()

        var out = SourceLocation(self._tu)
        clang_getCursorLocation(out._ptr(), self._ptr())
        out.refresh()
        return out^

    def extent(ref self) raises -> SourceRange:
        from src.libclang.source_range import SourceRange

        self._check_valid()

        var out = SourceRange(self._tu)
        clang_getCursorExtent(out._ptr(), self._ptr())
        return out^

    def __iter__(ref self) -> Self.IteratorType[origin_of(self)]:
        """Yield immediate child cursors.

        Usage:
            for c in root:
                print(c.spelling())
        """
        return CursorChildrenIterator(self)


struct CursorChildrenIterator(Movable, Iterator):
    """Iterator over immediate children of a `Cursor`."""

    comptime Element = Cursor

    var _tu: ArcPointer[TranslationUnitState]
    var _generation: Int
    var _parent_raw: InlineArray[CXCursor, 1]
    var _children: List[Cursor]
    var _index: Int
    var _buffered: Bool

    def __init__(out self, ref cursor: Cursor):
        self._tu = cursor._tu
        self._generation = cursor._generation
        self._parent_raw = InlineArray[CXCursor, 1](fill=cursor._raw[0].copy())
        self._children = List[Cursor]()
        self._index = 0
        self._buffered = False

    def _ensure_buffered(mut self) raises StopIteration:
        if self._buffered:
            return
        if not self._tu[].alive or self._generation != self._tu[].generation:
            raise StopIteration()
        var parent = Cursor(tu=self._tu, raw=self._parent_raw[0].copy())
        self._children = _collect_children_unchecked(parent)
        self._buffered = True

    def __next__(mut self) raises StopIteration -> Cursor:
        self._ensure_buffered()
        if self._index >= self._children.__len__():
            raise StopIteration()
        var result = self._children[self._index].copy()
        self._index += 1
        return result^


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
            t"collect_children: child count exceeded MAX_CHILDREN={MAX_CHILDREN}",
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


def _collect_children_unchecked(parent: Cursor) -> List[Cursor]:
    """Collect immediate children without raising.

    Used by `CursorChildrenIterator.__next__`, which may only raise
    `StopIteration`. The caller must ensure `parent` is valid. If the child
    count exceeds `MAX_CHILDREN`, the result is silently truncated.
    """
    var p = parent.copy()

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

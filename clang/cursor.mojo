"""High-level `Cursor` wrapper.

A `Cursor` is a copied `CXCursor` value plus an ARC keepalive reference to the
owning `TranslationUnitState`.

Important:
- `Cursor` does not own libclang AST memory.
- `Cursor` keeps the owning TranslationUnit alive through ArcPointer.
- `Cursor` becomes stale after TranslationUnit.reparse() if generation changes.
- Every FFI call passes `CXCursor *` to the shim, never `CXCursor` by value.

Typical usage:

```mojo
from clang.cindex import TranslationUnit

def main() raises:
    var tu = TranslationUnit.from_source("test/fixtures/test_fixture.c")
    var cursor = tu.cursor()
    print(cursor.kind())
    print(cursor.children())
```
"""

from clang._ffi import (
    CXCursor,
    CXCursorKind,
    CXCursorSet,
    CXEvalResult,
    CXTranslationUnit,
    CXType,
    CXString,
    CXStringSet,
    CXSourceLocation,
    CXSourceRange,
    CXFile,
    CXPrintingPolicy,
    CXPlatformAvailability,
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
    clang_isInvalidDeclaration,
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
    clang_getCursorPlatformAvailability,
    clang_Cursor_getVarDeclInitializer,
    clang_Cursor_hasVarDeclGlobalStorage,
    clang_Cursor_hasVarDeclExternalStorage,
    clang_Cursor_isMacroFunctionLike,
    clang_Cursor_isMacroBuiltin,
    clang_Cursor_isInlineNamespace,
    clang_Cursor_getSpellingNameRange,
    clang_Cursor_getCommentRange,
    clang_Cursor_getModule,
    clang_getCursorReferenceNameRange,
    clang_getCursorExceptionSpecificationType,
    clang_Cursor_Evaluate,
    clang_EvalResult_dispose,
    clang_EvalResult_getAsDouble,
    clang_EvalResult_getAsInt,
    clang_EvalResult_getAsLongLong,
    clang_EvalResult_getAsStr,
    clang_EvalResult_getAsUnsigned,
    clang_EvalResult_getKind,
    clang_EvalResult_isUnsignedInt,
    clang_createCXCursorSet,
    clang_disposeCXCursorSet,
    clang_CXCursorSet_contains,
    clang_CXCursorSet_insert,
    clang_Cursor_isBitField,
    clang_getFieldDeclBitWidth,
    clang_Cursor_getOffsetOfField,
    clang_Cursor_getStorageClass,
    clang_Cursor_getMangling,
    clang_Cursor_getCXXManglings,
    clang_Cursor_getObjCManglings,
    clang_getEnumConstantDeclValue,
    clang_getEnumConstantDeclUnsignedValue,
    clang_CXXConstructor_isConvertingConstructor,
    clang_CXXConstructor_isCopyConstructor,
    clang_CXXConstructor_isDefaultConstructor,
    clang_CXXConstructor_isMoveConstructor,
    clang_CXXField_isMutable,
    clang_getDeclObjCTypeEncoding,
    clang_getIBOutletCollectionType,
    clang_Cursor_getObjCSelectorIndex,
    clang_Cursor_isDynamicCall,
    clang_Cursor_getReceiverType,
    clang_Cursor_getObjCPropertyAttributes,
    clang_Cursor_getObjCPropertyGetterName,
    clang_Cursor_getObjCPropertySetterName,
    clang_Cursor_getObjCDeclQualifiers,
    clang_Cursor_isObjCOptional,
    clang_getBinaryOperatorKindSpelling,
    clang_getCursorBinaryOperatorKind,
    clang_getCursorUnaryOperatorKind,
    clang_Cursor_isFunctionInlined,
    clang_disposeStringSet,
    c_char,
    c_double,
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

from clang.enums import (
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

from clang.common import (
    PlatformAvailability,
    _CXStringStorage,
    _copy_platform_availabilities,
    _dispose_platform_availabilities,
    _take_cxstring,
)
from clang.module import Module, wrap_module

from clang.translation_unit import (
    TranslationUnitState,
)

from std.collections import InlineArray, List
from std.iter import Iterable, Iterator, StopIteration
from std.memory import (
    ArcPointer,
    UnsafePointer,
    alloc,
    ImmutOpaquePointer,
    MutOpaquePointer,
)


struct EvalResult(Movable, Writable):
    """Owning wrapper around a `CXEvalResult` returned by cursor evaluation."""

    var _raw: CXEvalResult

    def __init__(out self, raw: CXEvalResult) raises:
        """Take ownership of a non-null raw evaluation result."""
        if not raw:
            raise Error("EvalResult: libclang returned null")
        self._raw = raw

    def __del__(deinit self):
        if self._raw:
            clang_EvalResult_dispose(self._raw)

    def kind(ref self) -> Int:
        """Return the raw `CXEvalResultKind` integer."""
        return Int(clang_EvalResult_getKind(self._raw))

    def as_int(ref self) -> Int:
        """Return the evaluated value as a signed int."""
        return Int(clang_EvalResult_getAsInt(self._raw))

    def as_long_long(ref self) -> Int:
        """Return the evaluated value as a signed long long."""
        return Int(clang_EvalResult_getAsLongLong(self._raw))

    def is_unsigned_int(ref self) -> Bool:
        """Return true if the evaluated integer is unsigned."""
        return Bool(clang_EvalResult_isUnsignedInt(self._raw))

    def as_unsigned(ref self) -> Int:
        """Return the evaluated value as an unsigned integer."""
        return Int(clang_EvalResult_getAsUnsigned(self._raw))

    def as_double(ref self) -> Float64:
        """Return the evaluated value as a double."""
        return Float64(clang_EvalResult_getAsDouble(self._raw))

    def as_string(ref self) -> Optional[String]:
        """Return the evaluated value as a string, if available."""
        var ptr = clang_EvalResult_getAsStr(self._raw)
        if not ptr:
            return None
        return Optional[String](String(unsafe_from_utf8_ptr=ptr.value()))

    def write_to(self, mut writer: Some[Writer]):
        writer.write("EvalResult(kind=", Int(self.kind()), ")")


struct CursorSet(Movable, Writable):
    """Owning set of cursors for identity-based membership checks."""

    var _raw: CXCursorSet

    def __init__(out self) raises:
        """Create an empty cursor set."""
        self._raw = clang_createCXCursorSet()
        if not self._raw:
            raise Error("CursorSet: clang_createCXCursorSet returned null")

    def __del__(deinit self):
        if self._raw:
            clang_disposeCXCursorSet(self._raw)

    def contains(ref self, ref cursor: Cursor) raises -> Bool:
        """Return true if `cursor` is already in the set."""
        cursor._check_valid()
        return Bool(clang_CXCursorSet_contains(self._raw, cursor._ptr()))

    def insert(ref self, ref cursor: Cursor) raises -> Bool:
        """Insert `cursor`; return true when it was not already present."""
        cursor._check_valid()
        return Bool(clang_CXCursorSet_insert(self._raw, cursor._ptr()))

    def write_to(self, mut writer: Some[Writer]):
        writer.write("CursorSet()")


struct Cursor(Copyable, Iterable, Movable, Writable):
    """A high-level wrapper around `CXCursor`.

    The raw `CXCursor` is copied by value into `_raw`.
    The owning `CXTranslationUnit` is kept alive by `_tu`.

    Example:

    ```mojo
    var root = tu.cursor()
    for child in root:
        print(child.kind(), child.spelling())
    ```
    """

    comptime IteratorType[
        iterable_mut: Bool, //, iterable_origin: Origin[mut=iterable_mut]
    ]: Iterator = CursorChildrenIterator

    var _tu: ArcPointer[TranslationUnitState]
    var _generation: Int
    var _raw: InlineArray[CXCursor, 1]

    def __init__(out self, tu: TranslationUnit) raises:
        """Create a null cursor tied to `tu`."""
        self._tu = tu._shared_state()
        self._generation = self._tu[].generation
        self._raw = InlineArray[CXCursor, 1](
            fill=_zero_cursor(),
        )
        clang_getNullCursor(self._ptr())

    def __init__(out self, tu: TranslationUnit, raw: CXCursor):
        self._tu = tu._shared_state()
        self._generation = tu._shared_state()[].generation
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

    def __ne__(ref self, ref other: Self) raises -> Bool:
        return not self.__eq__(other)

    def _check_valid(self) raises:
        """Reject use after TU disposal or in-place reparse."""
        if self._generation != self._tu[].generation:
            raise Error("Cursor is stale due to TranslationUnit reparse")

    def _ptr(ref self) -> UnsafePointer[CXCursor, MutUntrackedOrigin]:
        """Pointer to raw cursor storage for shim calls."""
        return rebind[UnsafePointer[CXCursor, MutUntrackedOrigin]](
            self._raw.unsafe_ptr(),
        )

    def _const_ptr(self) -> UnsafePointer[CXCursor, ImmutUntrackedOrigin]:
        """Immutable pointer to raw cursor storage.

        Use this if your shim signatures distinguish const input pointers.
        If your generated `_ffi.mojo` currently expects MutUntrackedOrigin for
        all pointers, keep using `_ptr()`.
        """
        return rebind[UnsafePointer[CXCursor, ImmutUntrackedOrigin]](
            self._raw.unsafe_ptr(),
        )

    def children(ref self) raises -> List[Cursor]:
        """Return immediate child cursors."""

        self._check_valid()
        return collect_children(self.copy())

    def walk_preorder(ref self) raises -> List[Cursor]:
        """Return this cursor and all descendants in preorder."""

        self._check_valid()
        return walk_preorder(self.copy())

    def _raw_value(self) raises -> CXCursor:
        """Return a copied raw cursor value.

        This does not transfer ownership of anything. It is mostly useful for
        tests or low-level adapters.
        """
        self._check_valid()
        return self._raw[0].copy()

    def translation_unit(self) raises -> TranslationUnit:
        """Return the TranslationUnit to which this cursor belongs."""
        from clang.translation_unit import TranslationUnit

        self._check_valid()
        return TranslationUnit(self._tu)

    def _raw_translation_unit(self) raises -> CXTranslationUnit:
        """Return the borrowed raw TU handle after validity checks."""
        self._check_valid()
        return self._tu[].raw()

    def write_to(self, mut writer: Some[Writer]):
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
        """Return true if this cursor is libclang's null cursor."""
        self._check_valid()
        return Bool(clang_Cursor_isNull(self._ptr()))

    def kind(ref self) raises -> CursorKind:
        """Return the libclang cursor kind."""
        self._check_valid()
        return CursorKind(clang_getCursorKind(self._ptr()))

    def hash(ref self) raises -> Int:
        """Return libclang's stable hash for this cursor."""
        self._check_valid()
        return Int(clang_hashCursor(self._ptr()))

    def spelling(ref self) raises -> String:
        """Return the cursor spelling."""
        self._check_valid()
        var cs = _CXStringStorage()
        clang_getCursorSpelling(cs.ptr_for_out(), self._ptr())
        return cs.take()

    def display_name(ref self) raises -> String:
        """Return the display name for this cursor."""
        self._check_valid()
        var cs = _CXStringStorage()
        clang_getCursorDisplayName(cs.ptr_for_out(), self._ptr())
        return cs.take()

    def usr(ref self) raises -> Optional[String]:
        """Return the unified symbol resolution string for this cursor, if any."""
        self._check_valid()
        var cs = _CXStringStorage()
        clang_getCursorUSR(cs.ptr_for_out(), self._ptr())
        return cs.take_optional()

    # -----------------------------------------------------------------------
    # Classification
    # -----------------------------------------------------------------------

    def is_definition(ref self) raises -> Bool:
        """Return true if this cursor is a definition."""
        self._check_valid()
        return Bool(clang_isCursorDefinition(self._ptr()))

    def is_declaration(ref self) raises -> Bool:
        """Return true if this cursor kind is a declaration."""
        self._check_valid()
        return Bool(clang_isDeclaration(self._raw[0].kind))

    def is_reference(ref self) raises -> Bool:
        """Return true if this cursor kind is a reference."""
        self._check_valid()
        return Bool(clang_isReference(self._raw[0].kind))

    def is_expression(ref self) raises -> Bool:
        """Return true if this cursor kind is an expression."""
        self._check_valid()
        return Bool(clang_isExpression(self._raw[0].kind))

    def is_statement(ref self) raises -> Bool:
        """Return true if this cursor kind is a statement."""
        self._check_valid()
        return Bool(clang_isStatement(self._raw[0].kind))

    def is_attribute(ref self) raises -> Bool:
        """Return true if this cursor kind is an attribute."""
        self._check_valid()
        return Bool(clang_isAttribute(self._raw[0].kind))

    def is_invalid(ref self) raises -> Bool:
        """Return true if this cursor kind is invalid."""
        self._check_valid()
        return Bool(clang_isInvalid(self._raw[0].kind))

    def is_invalid_declaration(ref self) raises -> Bool:
        """Return true if libclang marks this declaration invalid."""
        self._check_valid()
        return Bool(clang_isInvalidDeclaration(self._ptr()))

    def is_translation_unit(ref self) raises -> Bool:
        """Return true if this is the translation-unit cursor."""
        self._check_valid()
        return Bool(clang_isTranslationUnit(self._raw[0].kind))

    def is_preprocessing(ref self) raises -> Bool:
        """Return true if this cursor belongs to preprocessing entities."""
        self._check_valid()
        return Bool(clang_isPreprocessing(self._raw[0].kind))

    def is_unexposed(ref self) raises -> Bool:
        """Return true if libclang exposes this as an unexposed cursor kind."""
        self._check_valid()
        return Bool(clang_isUnexposed(self._raw[0].kind))

    def has_attrs(ref self) raises -> Bool:
        """Return true if this cursor has attributes."""
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
                rebind[UnsafePointer[c_uint, MutUntrackedOrigin]](
                    is_generated.unsafe_ptr(),
                ),
            )
        )
        _ = language_cs.take()
        _ = defined_in_cs.take()
        return result

    def has_var_decl_global_storage(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_Cursor_hasVarDeclGlobalStorage(self._ptr()))

    def has_var_decl_external_storage(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_Cursor_hasVarDeclExternalStorage(self._ptr()))

    def is_anonymous(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_Cursor_isAnonymous(self._ptr()))

    def is_anonymous_record_decl(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_Cursor_isAnonymousRecordDecl(self._ptr()))

    def is_macro_function_like(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_Cursor_isMacroFunctionLike(self._ptr()))

    def is_macro_builtin(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_Cursor_isMacroBuiltin(self._ptr()))

    def is_inline_namespace(ref self) raises -> Bool:
        self._check_valid()
        return Bool(clang_Cursor_isInlineNamespace(self._ptr()))

    def is_const_qualified_type(ref self) raises -> Bool:
        from clang.type_ import Type

        self._check_valid()
        var t = Type(tu=self._tu)
        clang_getCursorType(t._ptr(), self._ptr())
        return Bool(clang_isConstQualifiedType(t._ptr()))

    def is_volatile_qualified_type(ref self) raises -> Bool:
        from clang.type_ import Type

        self._check_valid()
        var t = Type(tu=self._tu)
        clang_getCursorType(t._ptr(), self._ptr())
        return Bool(clang_isVolatileQualifiedType(t._ptr()))

    def is_restrict_qualified_type(ref self) raises -> Bool:
        from clang.type_ import Type

        self._check_valid()
        var t = Type(tu=self._tu)
        clang_getCursorType(t._ptr(), self._ptr())
        return Bool(clang_isRestrictQualifiedType(t._ptr()))

    def is_pod_type(ref self) raises -> Bool:
        from clang.type_ import Type

        self._check_valid()
        var t = Type(tu=self._tu)
        clang_getCursorType(t._ptr(), self._ptr())
        return Bool(clang_isPODType(t._ptr()))

    def access_specifier(ref self) raises -> AccessSpecifier:
        """Return the C++ access specifier for this cursor."""
        self._check_valid()
        return AccessSpecifier(c_uint(clang_getCXXAccessSpecifier(self._ptr())))

    # -----------------------------------------------------------------------
    # Cursor relations
    # -----------------------------------------------------------------------

    def semantic_parent(ref self) raises -> Optional[Self]:
        """Return the semantic parent cursor, if any."""
        self._check_valid()

        var out = Self(self._tu)
        clang_getCursorSemanticParent(out._ptr(), self._ptr())

        if Bool(clang_Cursor_isNull(out._ptr())):
            return None

        return Optional[Self](out^)

    def lexical_parent(ref self) raises -> Optional[Self]:
        """Return the lexical parent cursor, if any."""
        self._check_valid()

        var out = Self(self._tu)
        clang_getCursorLexicalParent(out._ptr(), self._ptr())

        if Bool(clang_Cursor_isNull(out._ptr())):
            return None

        return Optional[Self](out^)

    def referenced(ref self) raises -> Optional[Self]:
        """Return the referenced cursor, if any."""
        self._check_valid()

        var out = Self(self._tu)
        clang_getCursorReferenced(out._ptr(), self._ptr())

        if Bool(clang_Cursor_isNull(out._ptr())):
            return None

        return Optional[Self](out^)

    def definition(ref self) raises -> Optional[Self]:
        """Return the definition cursor, if any."""
        self._check_valid()

        var out = Self(self._tu)
        clang_getCursorDefinition(out._ptr(), self._ptr())

        if Bool(clang_Cursor_isNull(out._ptr())):
            return None

        return Optional[Self](out^)

    def var_decl_initializer(ref self) raises -> Optional[Self]:
        """Return the initializer cursor for a variable declaration, if any."""
        self._check_valid()
        var out = Self(self._tu)
        clang_Cursor_getVarDeclInitializer(out._ptr(), self._ptr())
        if out.is_null():
            return None
        return Optional[Self](out^)

    def canonical(ref self) raises -> Self:
        """Return the canonical cursor for this entity."""
        self._check_valid()

        var out = Self(self._tu)
        clang_getCanonicalCursor(out._ptr(), self._ptr())
        return out^

    def equals(ref self, ref other: Self) raises -> Bool:
        """Return true if `other` identifies the same libclang cursor."""
        self._check_valid()
        other._check_valid()

        # Optional: require same TranslationUnit generation.
        if self._generation != other._generation:
            return False

        return Bool(clang_equalCursors(self._ptr(), other._ptr()))

    # -----------------------------------------------------------------------
    # Cursor info (pretty-printed, overridden, overloaded, template)
    # -----------------------------------------------------------------------

    def overridden_cursors(ref self) raises -> List[Cursor]:
        """Return overridden method cursors for this cursor."""
        self._check_valid()
        var overridden_slot: InlineArray[
            Optional[UnsafePointer[CXCursor, MutUntrackedOrigin]], 1
        ] = InlineArray[
            Optional[UnsafePointer[CXCursor, MutUntrackedOrigin]], 1
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
                    Optional[UnsafePointer[CXCursor, MutUntrackedOrigin]],
                    MutUntrackedOrigin,
                ]
            ](overridden_slot.unsafe_ptr()),
            rebind[UnsafePointer[c_uint, MutUntrackedOrigin]](
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

    def num_overloaded_decls(ref self) raises -> Int:
        """Return the number of overloaded declarations referenced here."""
        self._check_valid()
        return Int(clang_getNumOverloadedDecls(self._ptr()))

    def overloaded_decl(ref self, index: Int) raises -> Self:
        """Return overloaded declaration `index`."""
        self._check_valid()
        if index < 0:
            raise Error("Cursor.overloaded_decl: index out of range")
        var out = Self(self._tu)
        clang_getOverloadedDecl(out._ptr(), self._ptr(), c_uint(index))
        return out^

    def num_template_arguments(ref self) raises -> Int:
        """Return the number of template arguments available on this cursor."""
        self._check_valid()
        return Int(clang_Cursor_getNumTemplateArguments(self._ptr()))

    def template_argument_kind(
        ref self, i: Int
    ) raises -> TemplateArgumentKind:
        """Return the template-argument kind for argument `i`."""
        self._check_valid()
        if i < 0:
            raise Error("Cursor.template_argument_kind: index out of range")
        return TemplateArgumentKind(
            c_uint(clang_Cursor_getTemplateArgumentKind(self._ptr(), c_uint(i)))
        )

    def template_argument_type(ref self, i: Int) raises -> Type:
        """Return template type argument `i`."""
        from clang.type_ import Type

        self._check_valid()
        if i < 0:
            raise Error("Cursor.template_argument_type: index out of range")
        var out = Type(tu=self._tu)
        clang_Cursor_getTemplateArgumentType(
            out._ptr(), self._ptr(), c_uint(i)
        )
        out._cache_spelling()
        return out^

    def template_argument_value(ref self, i: Int) raises -> Int:
        """Return the signed value of non-type template argument `i`."""
        self._check_valid()
        if i < 0:
            raise Error("Cursor.template_argument_value: index out of range")
        return Int(clang_Cursor_getTemplateArgumentValue(self._ptr(), c_uint(i)))

    def template_argument_unsigned_value(
        ref self, i: Int
    ) raises -> Int:
        """Return the unsigned value of non-type template argument `i`."""
        self._check_valid()
        if i < 0:
            raise Error(
                "Cursor.template_argument_unsigned_value: index out of range"
            )
        return Int(
            clang_Cursor_getTemplateArgumentUnsignedValue(self._ptr(), c_uint(i))
        )

    def specialized_cursor_template(ref self) raises -> Optional[Self]:
        """Return the specialized template cursor, if any."""
        self._check_valid()
        var out = Self(self._tu)
        clang_getSpecializedCursorTemplate(out._ptr(), self._ptr())
        if out.is_null():
            return None
        return Optional[Self](out^)

    def template_kind(ref self) raises -> CursorKind:
        """Return the cursor kind for the underlying template declaration."""
        self._check_valid()
        return CursorKind(clang_getTemplateCursorKind(self._ptr()))

    # -----------------------------------------------------------------------
    # Arguments and tokens
    # -----------------------------------------------------------------------

    def num_arguments(ref self) raises -> Int:
        """Return the number of arguments on a callable cursor."""
        self._check_valid()
        return Int(clang_Cursor_getNumArguments(self._ptr()))

    def argument(ref self, i: Int) raises -> Self:
        """Return argument cursor `i`."""
        self._check_valid()
        if i < 0:
            raise Error("Cursor.argument: index out of range")
        var out = Self(self._tu)
        clang_Cursor_getArgument(out._ptr(), self._ptr(), c_uint(i))
        return out^

    def arguments(ref self) raises -> List[Cursor]:
        """Return all argument cursors."""
        self._check_valid()
        var n = self.num_arguments()
        var out = List[Cursor]()
        for i in range(n):
            out.append(self.argument(i))
        return out^

    def tokens(ref self) raises -> TokenGroup:
        """Tokenize this cursor's source extent."""
        from clang.token import TokenGroup

        self._check_valid()
        var ext = self.extent()
        var tg = TokenGroup(tu=self._tu, extent=ext.copy())
        return tg^

    # -----------------------------------------------------------------------
    # Comments
    # -----------------------------------------------------------------------

    def brief_comment(ref self) raises -> Optional[String]:
        """Return the brief documentation comment text, if any."""
        self._check_valid()
        var cs = _CXStringStorage()
        clang_Cursor_getBriefCommentText(cs.ptr_for_out(), self._ptr())
        return cs.take_optional()

    def raw_comment(ref self) raises -> Optional[String]:
        """Return the raw documentation comment text, if any."""
        self._check_valid()
        var cs = _CXStringStorage()
        clang_Cursor_getRawCommentText(cs.ptr_for_out(), self._ptr())
        return cs.take_optional()

    def comment_range(ref self) raises -> SourceRange:
        """Return the source range covering the documentation comment."""
        from clang.source_range import SourceRange

        self._check_valid()
        var out = SourceRange(self._tu)
        clang_Cursor_getCommentRange(out._ptr(), self._ptr())
        return out^

    def spelling_name_range(
        ref self,
        piece_index: c_uint = c_uint(0),
        options: c_uint = c_uint(0),
    ) raises -> SourceRange:
        """Return the source range for a spelling-name piece."""
        from clang.source_range import SourceRange

        self._check_valid()
        var out = SourceRange(self._tu)
        clang_Cursor_getSpellingNameRange(
            out._ptr(),
            self._ptr(),
            piece_index,
            options,
        )
        return out^

    def reference_name_range(
        ref self,
        name_flags: c_uint = c_uint(0),
        piece_index: c_uint = c_uint(0),
    ) raises -> SourceRange:
        """Return the source range for a reference-name piece."""
        from clang.source_range import SourceRange

        self._check_valid()
        var out = SourceRange(self._tu)
        clang_getCursorReferenceNameRange(
            out._ptr(),
            self._ptr(),
            name_flags,
            piece_index,
        )
        return out^

    # -----------------------------------------------------------------------
    # Miscellaneous cursor properties
    # -----------------------------------------------------------------------

    def linkage(ref self) raises -> LinkageKind:
        """Return the linkage kind for this cursor."""
        self._check_valid()
        return LinkageKind(c_uint(clang_getCursorLinkage(self._ptr())))

    def visibility(ref self) raises -> VisibilityKind:
        """Return the visibility kind for this cursor."""
        self._check_valid()
        return VisibilityKind(c_uint(clang_getCursorVisibility(self._ptr())))

    def availability(ref self) raises -> AvailabilityKind:
        """Return the availability kind for this cursor."""
        self._check_valid()
        return AvailabilityKind(
            c_uint(clang_getCursorAvailability(self._ptr()))
        )

    def language(ref self) raises -> LanguageKind:
        """Return the source language kind for this cursor."""
        self._check_valid()
        return LanguageKind(c_uint(clang_getCursorLanguage(self._ptr())))

    def tls_kind(ref self) raises -> TLSKind:
        """Return the TLS kind for this cursor."""
        self._check_valid()
        return TLSKind(c_uint(clang_getCursorTLSKind(self._ptr())))

    def storage_class(ref self) raises -> StorageClass:
        """Return the storage class for this cursor."""
        self._check_valid()
        return StorageClass(c_uint(clang_Cursor_getStorageClass(self._ptr())))

    def cursor_exception_specification_kind(
        ref self,
    ) raises -> ExceptionSpecificationKind:
        """Return the exception-specification kind for this cursor."""
        self._check_valid()
        return ExceptionSpecificationKind(
            c_uint(clang_getCursorExceptionSpecificationType(self._ptr()))
        )

    def is_bitfield(ref self) raises -> Bool:
        """Return true if this field declaration is a bit-field."""
        self._check_valid()
        return Bool(clang_Cursor_isBitField(self._ptr()))

    def bitfield_width(ref self) raises -> Int:
        """Return the bit width of a bit-field declaration."""
        self._check_valid()
        return Int(clang_getFieldDeclBitWidth(self._ptr()))

    def offset_of_field(ref self) raises -> Int:
        """Return the bit offset of a field within its parent record."""
        self._check_valid()
        return Int(clang_Cursor_getOffsetOfField(self._ptr()))

    def is_function_inlined(ref self) raises -> Bool:
        """Return true if libclang marks this function as inlined."""
        self._check_valid()
        return Bool(clang_Cursor_isFunctionInlined(self._ptr()))

    def underlying_typedef_type(ref self) raises -> Type:
        """Return the underlying type of a typedef declaration."""
        from clang.type_ import Type

        self._check_valid()
        var out = Type(tu=self._tu)
        clang_getTypedefDeclUnderlyingType(out._ptr(), self._ptr())
        out._cache_spelling()
        return out^

    def enum_type(ref self) raises -> Type:
        """Return the integer type used by an enum declaration."""
        from clang.type_ import Type

        self._check_valid()
        var out = Type(tu=self._tu)
        clang_getEnumDeclIntegerType(out._ptr(), self._ptr())
        out._cache_spelling()
        return out^

    def mangled_name(ref self) raises -> String:
        """Return the primary mangled name for this cursor."""
        self._check_valid()
        var cs = _CXStringStorage()
        clang_Cursor_getMangling(cs.ptr_for_out(), self._ptr())
        return cs.take()

    def cxx_manglings(ref self) raises -> List[String]:
        """Return all C++ manglings for this cursor."""
        self._check_valid()
        return _string_list_from_cxstringset(
            clang_Cursor_getCXXManglings(self._ptr())
        )

    def objc_manglings(ref self) raises -> List[String]:
        """Return all Objective-C manglings for this cursor."""
        self._check_valid()
        return _string_list_from_cxstringset(
            clang_Cursor_getObjCManglings(self._ptr())
        )

    def enum_value(ref self) raises -> Int:
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
            var decl = underlying.declaration()
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
            return Int(clang_getEnumConstantDeclUnsignedValue(self._ptr()))

        return Int(clang_getEnumConstantDeclValue(self._ptr()))

    def objc_type_encoding(ref self) raises -> String:
        """Return the Objective-C type encoding for this cursor."""
        self._check_valid()
        var cs = _CXStringStorage()
        clang_getDeclObjCTypeEncoding(cs.ptr_for_out(), self._ptr())
        return cs.take()

    def iboutlet_collection_type(ref self) raises -> Optional[Type]:
        """Return the IBOutlet collection element type, if any."""
        from clang.type_ import Type

        self._check_valid()
        var out = Type(tu=self._tu)
        clang_getIBOutletCollectionType(out._ptr(), self._ptr())
        if out.kind() == TypeKind.INVALID:
            return None
        out._cache_spelling()
        return Optional[Type](out^)

    def objc_selector_index(ref self) raises -> Int:
        """Return the selector index for an Objective-C method piece."""
        self._check_valid()
        return Int(clang_Cursor_getObjCSelectorIndex(self._ptr()))

    def is_dynamic_call(ref self) raises -> Bool:
        """Return true if this Objective-C call is dynamically dispatched."""
        self._check_valid()
        return Bool(clang_Cursor_isDynamicCall(self._ptr()))

    def receiver_type(ref self) raises -> Optional[Type]:
        """Return the receiver type for an Objective-C message expression, if any."""
        from clang.type_ import Type

        self._check_valid()
        var out = Type(tu=self._tu)
        clang_Cursor_getReceiverType(out._ptr(), self._ptr())
        if out.kind() == TypeKind.INVALID:
            return None
        out._cache_spelling()
        return Optional[Type](out^)

    def objc_property_attributes(
        ref self,
        reserved: Int = 0,
    ) raises -> Int:
        """Return Objective-C property attribute flags."""
        self._check_valid()
        if reserved < 0:
            raise Error("Cursor.objc_property_attributes: reserved must be >= 0")
        return Int(
            clang_Cursor_getObjCPropertyAttributes(self._ptr(), c_uint(reserved))
        )

    def objc_property_getter_name(ref self) raises -> String:
        """Return the getter name for an Objective-C property."""
        self._check_valid()
        var cs = _CXStringStorage()
        clang_Cursor_getObjCPropertyGetterName(cs.ptr_for_out(), self._ptr())
        return cs.take()

    def objc_property_setter_name(ref self) raises -> String:
        """Return the setter name for an Objective-C property."""
        self._check_valid()
        var cs = _CXStringStorage()
        clang_Cursor_getObjCPropertySetterName(cs.ptr_for_out(), self._ptr())
        return cs.take()

    def objc_decl_qualifiers(ref self) raises -> Int:
        """Return Objective-C declaration qualifier flags."""
        self._check_valid()
        return Int(clang_Cursor_getObjCDeclQualifiers(self._ptr()))

    def is_objc_optional(ref self) raises -> Bool:
        """Return true if this Objective-C declaration is optional."""
        self._check_valid()
        return Bool(clang_Cursor_isObjCOptional(self._ptr()))

    def binary_opcode(ref self) raises -> BinaryOperator:
        """Alias for `binary_operator()`."""
        return self.binary_operator()

    def binary_opcode_spelling(ref self) raises -> String:
        """Return the spelling of this cursor's binary operator kind."""
        self._check_valid()
        var cs = _CXStringStorage()
        clang_getBinaryOperatorKindSpelling(
            cs.ptr_for_out(),
            c_uint(self.binary_opcode().as_c_uint()),
        )
        return cs.take()

    def binary_operator(ref self) raises -> BinaryOperator:
        """Return the binary operator kind for a binary operator cursor."""
        self._check_valid()
        return BinaryOperator(clang_getCursorBinaryOperatorKind(self._ptr()))

    def unary_operator(ref self) raises -> UnaryOperator:
        """Return the unary operator kind for a unary operator cursor."""
        self._check_valid()
        return UnaryOperator(clang_getCursorUnaryOperatorKind(self._ptr()))

    def gcc_assembly_input_constraint(ref self, index: Int) raises -> String:
        """Return the GCC inline-assembly input constraint at `index`."""
        if index < 0:
            raise Error("Cursor.gcc_assembly_input_constraint: index out of range")
        return _gcc_assembly_operand(
            self._tu, self._ptr(), c_uint(index), True
        ).constraint

    def gcc_assembly_input_expr(
        ref self, index: Int
    ) raises -> Optional[Self]:
        """Return the GCC inline-assembly input expression at `index`."""
        if index < 0:
            raise Error("Cursor.gcc_assembly_input_expr: index out of range")
        return _gcc_assembly_operand(
            self._tu, self._ptr(), c_uint(index), True
        ).expr.copy()

    def gcc_assembly_output_constraint(
        ref self, index: Int
    ) raises -> String:
        """Return the GCC inline-assembly output constraint at `index`."""
        if index < 0:
            raise Error("Cursor.gcc_assembly_output_constraint: index out of range")
        return _gcc_assembly_operand(
            self._tu, self._ptr(), c_uint(index), False
        ).constraint

    def gcc_assembly_output_expr(
        ref self, index: Int
    ) raises -> Optional[Self]:
        """Return the GCC inline-assembly output expression at `index`."""
        if index < 0:
            raise Error("Cursor.gcc_assembly_output_expr: index out of range")
        return _gcc_assembly_operand(
            self._tu, self._ptr(), c_uint(index), False
        ).expr.copy()

    def included_file(ref self) raises -> Optional[File]:
        """Return the included file for an inclusion directive cursor, if any."""
        from clang.file import File

        self._check_valid()
        var raw = clang_getIncludedFile(self._ptr())
        if not raw:
            return None
        var f = File(tu=self._tu, raw=raw)
        return Optional[File](f^)

    def module(ref self) raises -> Optional[Module]:
        """Return the module associated with this cursor, if any."""
        self._check_valid()
        return wrap_module(self._tu, clang_Cursor_getModule(self._ptr()))

    def evaluate(ref self) raises -> Optional[EvalResult]:
        """Evaluate this cursor as a constant expression, if possible."""
        self._check_valid()
        var raw = clang_Cursor_Evaluate(self._ptr())
        if not raw:
            return None
        return Optional[EvalResult](EvalResult(raw))

    def platform_availability(ref self) raises -> List[PlatformAvailability]:
        """Return platform availability records for this cursor."""
        self._check_valid()
        var always_deprecated = c_int(0)
        var always_unavailable = c_int(0)
        var dep_ptr = UnsafePointer[c_int, MutAnyOrigin](to=always_deprecated)
        var unavail_ptr = UnsafePointer[c_int, MutAnyOrigin](
            to=always_unavailable
        )
        var dep_message = _CXStringStorage()
        var unavail_message = _CXStringStorage()
        var avail = alloc[CXPlatformAvailability](8)
        var count = clang_getCursorPlatformAvailability(
            self._ptr(),
            rebind[UnsafePointer[c_int, MutUntrackedOrigin]](dep_ptr),
            dep_message.ptr_for_out(),
            rebind[UnsafePointer[c_int, MutUntrackedOrigin]](unavail_ptr),
            unavail_message.ptr_for_out(),
            rebind[UnsafePointer[CXPlatformAvailability, MutUntrackedOrigin]](
                avail
            ),
            c_int(8),
        )
        var avail_ptr = rebind[
            UnsafePointer[CXPlatformAvailability, MutUntrackedOrigin]
        ](avail)
        var copied = _copy_platform_availabilities(avail_ptr, Int(count))
        _dispose_platform_availabilities(avail_ptr, Int(count))
        avail.free()
        return copied^

    # -----------------------------------------------------------------------
    # Types and source locations
    # -----------------------------------------------------------------------

    def type(ref self) raises -> Type:
        """Return the semantic type of this cursor.

        Local import avoids a module cycle:
            cursor.mojo -> type_.mojo -> cursor.mojo
        """
        from clang.type_ import Type

        self._check_valid()

        var out = Type(self._tu)
        clang_getCursorType(out._ptr(), self._ptr())
        return out^

    def result_type(ref self) raises -> Type:
        """Return the result type for a callable cursor."""
        from clang.type_ import Type

        self._check_valid()

        var out = Type(self._tu)
        clang_getCursorResultType(out._ptr(), self._ptr())
        return out^

    def location(ref self) raises -> SourceLocation:
        """Return the primary source location of this cursor."""
        from clang.source_location import SourceLocation

        self._check_valid()

        var out = SourceLocation(self._tu)
        clang_getCursorLocation(out._ptr(), self._ptr())
        out.refresh()
        return out^

    def extent(ref self) raises -> SourceRange:
        """Return the full source extent of this cursor."""
        from clang.source_range import SourceRange

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


struct CursorChildrenIterator(Iterator, Movable):
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


@fieldwise_init
struct _GCCAssemblyOperandInfo(Movable):
    var constraint: String
    var expr: Optional[Cursor]


def _take_cxstring_value(raw: CXString) raises -> String:
    var slot = alloc[CXString](1)
    slot[] = CXString(data=raw.data, private_flags=raw.private_flags)
    var ptr = rebind[UnsafePointer[CXString, MutUntrackedOrigin]](slot)
    var out = _take_cxstring(ptr)
    slot.free()
    return out


def _string_list_from_cxstringset(
    raw: Optional[UnsafePointer[CXStringSet, MutUntrackedOrigin]],
) raises -> List[String]:
    var out = List[String]()
    if not raw:
        return out^

    var strings = raw.value()[].Strings
    var count = Int(raw.value()[].Count)
    if strings:
        for i in range(count):
            out.append(_take_cxstring_value((strings.value() + i)[]))
    clang_disposeStringSet(raw)
    return out^


def _gcc_assembly_operand(
    tu: ArcPointer[TranslationUnitState],
    cursor: UnsafePointer[CXCursor, MutUntrackedOrigin],
    index: c_uint,
    is_input: Bool,
) raises -> _GCCAssemblyOperandInfo:
    _ = tu
    _ = cursor
    _ = index
    _ = is_input
    return _GCCAssemblyOperandInfo(
        constraint=String(),
        expr=Optional[Cursor](None),
    )


def _zero_cursor() -> CXCursor:
    """Return a zero-initialized `CXCursor` value.

    This is only used as initial storage before a shim function writes the real
    cursor value.
    """
    return CXCursor(
        kind=CXCursorKind(c_uint(0)),
        xdata=c_int(0),
        data=InlineArray[Optional[ImmutOpaquePointer[ImmutUntrackedOrigin]], 3](
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
    cursor: Optional[UnsafePointer[CXCursor, MutUntrackedOrigin]],
    parent: Optional[UnsafePointer[CXCursor, MutUntrackedOrigin]],
    client_data: CXClientData,
) abi("C") -> CXChildVisitResult:
    if not cursor:
        return CXChildVisit_Continue

    var opaque = client_data.value()
    var collector = rebind[UnsafePointer[_Collector, MutAnyOrigin]](
        rebind[UnsafePointer[UInt8, MutAnyOrigin]](
            rebind[UnsafePointer[UInt8, MutUntrackedOrigin]](opaque),
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
        rebind[MutOpaquePointer[MutUntrackedOrigin]](
            rebind[UnsafePointer[UInt8, MutUntrackedOrigin]](
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
            (
                t"collect_children: child count exceeded"
                t" MAX_CHILDREN={MAX_CHILDREN}"
            ),
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
        rebind[MutOpaquePointer[MutUntrackedOrigin]](
            rebind[UnsafePointer[UInt8, MutUntrackedOrigin]](
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

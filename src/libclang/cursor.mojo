"""`Cursor` — a wrapper around `CXCursor`.

Stored as `InlineArray[CXCursor, 1]` plus a borrowed `CXTranslationUnit` so
the null cursor / parent / definition / type queries can be issued through the
shim pointer-only path.
"""
from src._ffi import (
    CXCursor,
    CXCursorKind,
    CXTranslationUnit,
    CXType,
    CXFile,
    CXLinkageKind,
    CXAvailabilityKind,
    CXLanguageKind,
    CXTLSKind,
    CX_CXXAccessSpecifier,
    CX_StorageClass,
    CXVisibilityKind,
    CXRefQualifierKind,
    CXTemplateArgumentKind,
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
    clang_getCursorLinkage,
    clang_getCursorVisibility,
    clang_getCursorAvailability,
    clang_getCursorLanguage,
    clang_getCursorTLSKind,
    clang_Cursor_hasAttrs,
    clang_Cursor_isBitField,
    clang_Cursor_isAnonymous,
    clang_Cursor_isAnonymousRecordDecl,
    clang_getFieldDeclBitWidth,
    clang_Cursor_getNumArguments,
    clang_Cursor_getArgument,
    clang_Cursor_getNumTemplateArguments,
    clang_Cursor_getTemplateArgumentKind,
    clang_Cursor_getTemplateArgumentType,
    clang_Cursor_getTemplateArgumentValue,
    clang_Cursor_getTemplateArgumentUnsignedValue,
    clang_Cursor_getOffsetOfField,
    clang_getIncludedFile,
    clang_getEnumDeclIntegerType,
    clang_getEnumConstantDeclValue,
    clang_getEnumConstantDeclUnsignedValue,
    clang_getTypedefDeclUnderlyingType,
    clang_getSpecializedCursorTemplate,
    clang_getOverloadedDecl,
    clang_Cursor_getRawCommentText,
    clang_Cursor_getBriefCommentText,
    clang_Cursor_getMangling,
    clang_Cursor_getStorageClass,
    clang_getCXXAccessSpecifier,
    clang_CXXMethod_isStatic,
    clang_CXXMethod_isVirtual,
    clang_CXXMethod_isConst,
    clang_CXXMethod_isDefaulted,
    clang_CXXMethod_isDeleted,
    clang_CXXMethod_isPureVirtual,
    clang_CXXConstructor_isConvertingConstructor,
    clang_CXXConstructor_isCopyConstructor,
    clang_CXXConstructor_isMoveConstructor,
    clang_CXXConstructor_isDefaultConstructor,
    clang_CXXRecord_isAbstract,
    clang_EnumDecl_isScoped,
    clang_isCursorDefinition,
    clang_visitChildren,
    clang_isDeclaration,
    clang_isReference,
    clang_isExpression,
    clang_isStatement,
    clang_isAttribute,
    clang_isInvalid,
    clang_CXCursorSet_contains,
    CXCursorSet,
    c_uint,
    c_int,
    c_long_long,
    c_ulong_long,
)
from src.libclang.common import _CXStringStorage
from std.memory import UnsafePointer, ImmutOpaquePointer


@fieldwise_init
struct Cursor(Copyable, Movable):
    """A `CXCursor` borrowed from a `TranslationUnit`."""

    var _tu: CXTranslationUnit
    var _raw: InlineArray[CXCursor, 1]

    def __init__(out self, tu: CXTranslationUnit) raises:
        self._tu = tu
        self._raw = InlineArray[CXCursor, 1](
            fill=CXCursor(
                kind=CXCursorKind(c_uint(0)),
                xdata=c_int(0),
                data=InlineArray[
                    Optional[ImmutOpaquePointer[ImmutExternalOrigin]], 3
                ](fill=None),
            ),
        )
        clang_getNullCursor(self._ptr())

    def _ptr(mut self) -> UnsafePointer[CXCursor, MutExternalOrigin]:
        return rebind[UnsafePointer[CXCursor, MutExternalOrigin]](
            self._raw.unsafe_ptr(),
        )

    @staticmethod
    def null(tu: CXTranslationUnit) raises -> Self:
        return Self(tu=tu)

    def kind(mut self) raises -> CXCursorKind:
        return clang_getCursorKind(self._ptr())

    def spelling(mut self) raises -> String:
        var cs = _CXStringStorage()
        clang_getCursorSpelling(cs.ptr(), self._ptr())
        return cs.take()

    def display_name(mut self) raises -> String:
        var cs = _CXStringStorage()
        clang_getCursorDisplayName(cs.ptr(), self._ptr())
        return cs.take()

    def usr(mut self) raises -> Optional[String]:
        var cs = _CXStringStorage()
        clang_getCursorUSR(cs.ptr(), self._ptr())
        var raw = cs.take()
        if not raw:
            return None
        return Optional[String](raw)

    def type(mut self) raises -> Type:
        from src.libclang.type_ import Type as RealType
        var out = RealType(tu=self._tu)
        clang_getCursorType(out._ptr(), self._ptr())
        return out^

    def result_type(mut self) raises -> Type:
        from src.libclang.type_ import Type as RealType
        var out = RealType(tu=self._tu)
        clang_getCursorResultType(out._ptr(), self._ptr())
        return out^

    def location(mut self) raises -> SourceLocation:
        from src.libclang.source_location import SourceLocation as RealLoc
        var out = RealLoc(tu=self._tu)
        clang_getCursorLocation(out._ptr(), self._ptr())
        return out^

    def extent(mut self) raises -> SourceRange:
        from src.libclang.source_range import SourceRange as RealRange
        var out = RealRange(tu=self._tu)
        clang_getCursorExtent(out._ptr(), self._ptr())
        return out^

    def translation_unit(mut self) -> CXTranslationUnit:
        return self._tu

    def _make_cursor(mut self) raises -> Cursor:
        var out = Cursor(tu=self._tu)
        return out^

    def semantic_parent(mut self) raises -> Optional[Cursor]:
        var out = self._make_cursor()
        clang_getCursorSemanticParent(out._ptr(), self._ptr())
        if Bool(clang_Cursor_isNull(out._ptr())):
            return None
        return Optional[Cursor](out^)

    def lexical_parent(mut self) raises -> Optional[Cursor]:
        var out = self._make_cursor()
        clang_getCursorLexicalParent(out._ptr(), self._ptr())
        if Bool(clang_Cursor_isNull(out._ptr())):
            return None
        return Optional[Cursor](out^)

    def referenced(mut self) raises -> Optional[Cursor]:
        var out = self._make_cursor()
        clang_getCursorReferenced(out._ptr(), self._ptr())
        if Bool(clang_Cursor_isNull(out._ptr())):
            return None
        return Optional[Cursor](out^)

    def definition(mut self) raises -> Optional[Cursor]:
        var out = self._make_cursor()
        clang_getCursorDefinition(out._ptr(), self._ptr())
        if Bool(clang_Cursor_isNull(out._ptr())):
            return None
        return Optional[Cursor](out^)

    def canonical(mut self) raises -> Cursor:
        var out = self._make_cursor()
        clang_getCanonicalCursor(out._ptr(), self._ptr())
        return out^

    def hash(mut self) raises -> c_uint:
        return clang_hashCursor(self._ptr())

    def is_null(mut self) raises -> Bool:
        return Bool(clang_Cursor_isNull(self._ptr()))

    def is_definition(mut self) raises -> Bool:
        return Bool(clang_isCursorDefinition(self._ptr()))

    def is_declaration(mut self) raises -> Bool:
        return Bool(clang_isDeclaration(self._raw[0].kind))

    def is_reference(mut self) raises -> Bool:
        return Bool(clang_isReference(self._raw[0].kind))

    def is_expression(mut self) raises -> Bool:
        return Bool(clang_isExpression(self._raw[0].kind))

    def is_statement(mut self) raises -> Bool:
        return Bool(clang_isStatement(self._raw[0].kind))

    def is_attribute(mut self) raises -> Bool:
        return Bool(clang_isAttribute(self._raw[0].kind))

    def is_invalid(mut self) raises -> Bool:
        return Bool(clang_isInvalid(self._raw[0].kind))

    def has_attrs(mut self) raises -> Bool:
        return Bool(clang_Cursor_hasAttrs(self._ptr()))

    def is_bitfield(mut self) raises -> Bool:
        return Bool(clang_Cursor_isBitField(self._ptr()))

    def is_anonymous(mut self) raises -> Bool:
        return Bool(clang_Cursor_isAnonymous(self._ptr()))

    def is_anonymous_record_decl(mut self) raises -> Bool:
        return Bool(clang_Cursor_isAnonymousRecordDecl(self._ptr()))

    def get_bitfield_width(mut self) raises -> c_int:
        return clang_getFieldDeclBitWidth(self._ptr())

    def get_field_offsetof(mut self) raises -> c_long_long:
        return clang_Cursor_getOffsetOfField(self._ptr())

    def get_included_file(mut self) raises -> Optional[File]:
        from src.libclang.file import File as RealFile
        var handle = clang_getIncludedFile(self._ptr())
        if not handle:
            return None
        return Optional[File](RealFile(_tu=self._tu, _raw=handle))

    def enum_type(mut self) raises -> Type:
        from src.libclang.type_ import Type as RealType
        var out = RealType(tu=self._tu)
        clang_getEnumDeclIntegerType(out._ptr(), self._ptr())
        return out^

    def enum_value(mut self) raises -> c_long_long:
        return clang_getEnumConstantDeclValue(self._ptr())

    def enum_unsigned_value(mut self) raises -> c_ulong_long:
        return clang_getEnumConstantDeclUnsignedValue(self._ptr())

    def underlying_typedef_type(mut self) raises -> Type:
        from src.libclang.type_ import Type as RealType
        var out = RealType(tu=self._tu)
        clang_getTypedefDeclUnderlyingType(out._ptr(), self._ptr())
        return out^

    def raw_comment(mut self) raises -> String:
        var cs = _CXStringStorage()
        clang_Cursor_getRawCommentText(cs.ptr(), self._ptr())
        return cs.take()

    def brief_comment(mut self) raises -> String:
        var cs = _CXStringStorage()
        clang_Cursor_getBriefCommentText(cs.ptr(), self._ptr())
        return cs.take()

    def mangled_name(mut self) raises -> String:
        var cs = _CXStringStorage()
        clang_Cursor_getMangling(cs.ptr(), self._ptr())
        return cs.take()

    def storage_class(mut self) raises -> CX_StorageClass:
        return clang_Cursor_getStorageClass(self._ptr())

    def access_specifier(mut self) raises -> CX_CXXAccessSpecifier:
        return clang_getCXXAccessSpecifier(self._ptr())

    def availability(mut self) raises -> CXAvailabilityKind:
        return clang_getCursorAvailability(self._ptr())

    def linkage(mut self) raises -> CXLinkageKind:
        return clang_getCursorLinkage(self._ptr())

    def visibility(mut self) raises -> CXVisibilityKind:
        return clang_getCursorVisibility(self._ptr())

    def language(mut self) raises -> CXLanguageKind:
        return clang_getCursorLanguage(self._ptr())

    def tls_kind(mut self) raises -> CXTLSKind:
        return clang_getCursorTLSKind(self._ptr())

    def is_static_method(mut self) raises -> Bool:
        return Bool(clang_CXXMethod_isStatic(self._ptr()))

    def is_virtual_method(mut self) raises -> Bool:
        return Bool(clang_CXXMethod_isVirtual(self._ptr()))

    def is_const_method(mut self) raises -> Bool:
        return Bool(clang_CXXMethod_isConst(self._ptr()))

    def is_copy_constructor(mut self) raises -> Bool:
        return Bool(clang_CXXConstructor_isCopyConstructor(self._ptr()))

    def is_move_constructor(mut self) raises -> Bool:
        return Bool(clang_CXXConstructor_isMoveConstructor(self._ptr()))

    def is_default_constructor(mut self) raises -> Bool:
        return Bool(clang_CXXConstructor_isDefaultConstructor(self._ptr()))

    def is_converting_constructor(mut self) raises -> Bool:
        return Bool(
            clang_CXXConstructor_isConvertingConstructor(self._ptr()),
        )

    def is_default_method(mut self) raises -> Bool:
        return Bool(clang_CXXMethod_isDefaulted(self._ptr()))

    def is_deleted_method(mut self) raises -> Bool:
        return Bool(clang_CXXMethod_isDeleted(self._ptr()))

    def is_pure_virtual_method(mut self) raises -> Bool:
        return Bool(clang_CXXMethod_isPureVirtual(self._ptr()))

    def is_abstract_record(mut self) raises -> Bool:
        return Bool(clang_CXXRecord_isAbstract(self._ptr()))

    def is_scoped_enum(mut self) raises -> Bool:
        return Bool(clang_EnumDecl_isScoped(self._ptr()))

    def num_arguments(mut self) raises -> c_int:
        return clang_Cursor_getNumArguments(self._ptr())

    def get_argument(mut self, i: c_uint) raises -> Cursor:
        var out = self._make_cursor()
        clang_Cursor_getArgument(out._ptr(), self._ptr(), i)
        return out^

    def get_arguments(mut self) raises -> List[Cursor]:
        var n = self.num_arguments()
        var out = List[Cursor]()
        for i in range(c_uint(n)):
            out.append(self.get_argument(c_uint(i)))
        return out^

    def get_num_template_arguments(mut self) raises -> c_int:
        return clang_Cursor_getNumTemplateArguments(self._ptr())

    def get_template_argument_kind(
        mut self, i: c_uint
    ) raises -> CXTemplateArgumentKind:
        return clang_Cursor_getTemplateArgumentKind(self._ptr(), i)

    def get_template_argument_type(mut self, i: c_uint) raises -> Type:
        from src.libclang.type_ import Type as RealType
        var out = RealType(tu=self._tu)
        clang_Cursor_getTemplateArgumentType(out._ptr(), self._ptr(), i)
        return out^

    def get_template_argument_value(mut self, i: c_uint) raises -> c_long_long:
        return clang_Cursor_getTemplateArgumentValue(self._ptr(), i)

    def get_template_argument_unsigned_value(
        mut self, i: c_uint
    ) raises -> c_ulong_long:
        return clang_Cursor_getTemplateArgumentUnsignedValue(self._ptr(), i)

    def get_children(mut self) raises -> List[Cursor]:
        from src.libclang.cursor_children import collect_children
        return collect_children(self)

    def walk_preorder(mut self) raises -> List[Cursor]:
        from src.libclang.cursor_children import walk_preorder
        return walk_preorder(self)

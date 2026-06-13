"""`Cursor` — a wrapper around `CXCursor`.

Stored as `InlineArray[CXCursor, 1]` plus a borrowed `CXTranslationUnit` so
null cursor / parent / definition / type queries can be issued through the
shim pointer-only path.
"""
from src.libclang_raw import (
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
    clang_getNullCursor_ref,
    clang_equalCursors_ref,
    clang_Cursor_isNull_ref,
    clang_hashCursor_ref,
    clang_getCursorKind_ref,
    clang_getCursorSpelling_ref,
    clang_getCursorDisplayName_ref,
    clang_getCursorUSR_ref,
    clang_getCursorType_into,
    clang_getCursorResultType_into,
    clang_getCursorLocation_into,
    clang_getCursorExtent_into,
    clang_getCursorSemanticParent_into,
    clang_getCursorLexicalParent_into,
    clang_getCursorReferenced_into,
    clang_getCursorDefinition_into,
    clang_getCanonicalCursor_into,
    clang_Cursor_getTranslationUnit_ref,
    clang_getCursorLinkage_ref,
    clang_getCursorVisibility_ref,
    clang_getCursorAvailability_ref,
    clang_getCursorLanguage_ref,
    clang_getCursorTLSKind_ref,
    clang_Cursor_hasAttrs_ref,
    clang_Cursor_isBitField_ref,
    clang_Cursor_isAnonymous_ref,
    clang_Cursor_isAnonymousRecordDecl_ref,
    clang_getFieldDeclBitWidth_ref,
    clang_Cursor_getNumArguments_ref,
    clang_Cursor_getArgument_into,
    clang_Cursor_getNumTemplateArguments_ref,
    clang_Cursor_getTemplateArgumentKind_ref,
    clang_Cursor_getTemplateArgumentType_into,
    clang_Cursor_getTemplateArgumentValue_ref,
    clang_Cursor_getTemplateArgumentUnsignedValue_ref,
    clang_Cursor_getOffsetOfField_ref,
    clang_getIncludedFile_ref,
    clang_getEnumDeclIntegerType_into,
    clang_getEnumConstantDeclValue_ref,
    clang_getEnumConstantDeclUnsignedValue_ref,
    clang_getTypedefDeclUnderlyingType_into,
    clang_getSpecializedCursorTemplate_into,
    clang_getOverloadedDecl_into,
    clang_Cursor_getRawCommentText_ref,
    clang_Cursor_getBriefCommentText_ref,
    clang_Cursor_getMangling_ref,
    clang_Cursor_getStorageClass_ref,
    clang_getCXXAccessSpecifier_ref,
    clang_CXXMethod_isStatic_ref,
    clang_CXXMethod_isVirtual_ref,
    clang_CXXMethod_isConst_ref,
    clang_CXXMethod_isDefaulted_ref,
    clang_CXXMethod_isDeleted_ref,
    clang_CXXMethod_isPureVirtual_ref,
    clang_CXXConstructor_isConvertingConstructor_ref,
    clang_CXXConstructor_isCopyConstructor_ref,
    clang_CXXConstructor_isMoveConstructor_ref,
    clang_CXXConstructor_isDefaultConstructor_ref,
    clang_CXXRecord_isAbstract_ref,
    clang_EnumDecl_isScoped_ref,
    clang_isCursorDefinition_ref,
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
from src.libclang.common import take_cxstring
from std.memory import UnsafePointer
from std.ffi import c_char


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
                data0=None,
                data1=None,
                data2=None,
            ),
        )
        clang_getNullCursor_ref(self._ptr())

    def _ptr(mut self) -> UnsafePointer[CXCursor, MutExternalOrigin]:
        return rebind[UnsafePointer[CXCursor, MutExternalOrigin]](
            self._raw.unsafe_ptr(),
        )

    @staticmethod
    def null(tu: CXTranslationUnit) -> Self:
        return Self(tu=tu)

    def kind(mut self) raises -> CXCursorKind:
        return clang_getCursorKind_ref(self._ptr())

    def spelling(mut self) raises -> String:
        return take_cxstring(clang_getCursorSpelling_ref(self._ptr()))

    def display_name(mut self) raises -> String:
        return take_cxstring(clang_getCursorDisplayName_ref(self._ptr()))

    def usr(mut self) raises -> Optional[String]:
        var raw = take_cxstring(clang_getCursorUSR_ref(self._ptr()))
        if not raw:
            return None
        return Optional[String](raw)

    def type(mut self) raises -> Type:
        from src.libclang.type_ import Type as RealType
        var out = RealType(tu=self._tu)
        clang_getCursorType_into(out._ptr(), self._ptr())
        return out^

    def result_type(mut self) raises -> Type:
        from src.libclang.type_ import Type as RealType
        var out = RealType(tu=self._tu)
        clang_getCursorResultType_into(out._ptr(), self._ptr())
        return out^

    def location(mut self) raises -> SourceLocation:
        from src.libclang.source_location import SourceLocation as RealLoc
        var out = RealLoc(tu=self._tu)
        clang_getCursorLocation_into(out._ptr(), self._ptr())
        return out^

    def extent(mut self) raises -> SourceRange:
        from src.libclang.source_range import SourceRange as RealRange
        var out = RealRange(tu=self._tu)
        clang_getCursorExtent_into(out._ptr(), self._ptr())
        return out^

    def translation_unit(mut self) -> CXTranslationUnit:
        return self._tu

    def _make_cursor(mut self) raises -> Cursor:
        var out = Cursor(tu=self._tu)
        return out^

    def semantic_parent(mut self) raises -> Optional[Cursor]:
        var out = self._make_cursor()
        clang_getCursorSemanticParent_into(out._ptr(), self._ptr())
        if Bool(clang_Cursor_isNull_ref(out._ptr())):
            return None
        return Optional[Cursor](out^)

    def lexical_parent(mut self) raises -> Optional[Cursor]:
        var out = self._make_cursor()
        clang_getCursorLexicalParent_into(out._ptr(), self._ptr())
        if Bool(clang_Cursor_isNull_ref(out._ptr())):
            return None
        return Optional[Cursor](out^)

    def referenced(mut self) raises -> Optional[Cursor]:
        var out = self._make_cursor()
        clang_getCursorReferenced_into(out._ptr(), self._ptr())
        if Bool(clang_Cursor_isNull_ref(out._ptr())):
            return None
        return Optional[Cursor](out^)

    def definition(mut self) raises -> Optional[Cursor]:
        var out = self._make_cursor()
        clang_getCursorDefinition_into(out._ptr(), self._ptr())
        if Bool(clang_Cursor_isNull_ref(out._ptr())):
            return None
        return Optional[Cursor](out^)

    def canonical(mut self) raises -> Cursor:
        var out = self._make_cursor()
        clang_getCanonicalCursor_into(out._ptr(), self._ptr())
        return out^

    def hash(mut self) raises -> c_uint:
        return clang_hashCursor_ref(self._ptr())

    def is_null(mut self) raises -> Bool:
        return Bool(clang_Cursor_isNull_ref(self._ptr()))

    def is_definition(mut self) raises -> Bool:
        return Bool(clang_isCursorDefinition_ref(self._ptr()))

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
        return Bool(clang_Cursor_hasAttrs_ref(self._ptr()))

    def is_bitfield(mut self) raises -> Bool:
        return Bool(clang_Cursor_isBitField_ref(self._ptr()))

    def is_anonymous(mut self) raises -> Bool:
        return Bool(clang_Cursor_isAnonymous_ref(self._ptr()))

    def is_anonymous_record_decl(mut self) raises -> Bool:
        return Bool(clang_Cursor_isAnonymousRecordDecl_ref(self._ptr()))

    def get_bitfield_width(mut self) raises -> c_int:
        return clang_getFieldDeclBitWidth_ref(self._ptr())

    def get_field_offsetof(mut self) raises -> c_long_long:
        return clang_Cursor_getOffsetOfField_ref(self._ptr())

    def get_included_file(mut self) raises -> Optional[File]:
        from src.libclang.file import File as RealFile
        var handle = clang_getIncludedFile_ref(self._ptr())
        if not handle:
            return None
        return Optional[File](RealFile(_tu=self._tu, _raw=handle))

    def enum_type(mut self) raises -> Type:
        from src.libclang.type_ import Type as RealType
        var out = RealType(tu=self._tu)
        clang_getEnumDeclIntegerType_into(out._ptr(), self._ptr())
        return out^

    def enum_value(mut self) raises -> c_long_long:
        return clang_getEnumConstantDeclValue_ref(self._ptr())

    def enum_unsigned_value(mut self) raises -> c_ulong_long:
        return clang_getEnumConstantDeclUnsignedValue_ref(self._ptr())

    def underlying_typedef_type(mut self) raises -> Type:
        from src.libclang.type_ import Type as RealType
        var out = RealType(tu=self._tu)
        clang_getTypedefDeclUnderlyingType_into(out._ptr(), self._ptr())
        return out^

    def raw_comment(mut self) raises -> String:
        return take_cxstring(clang_Cursor_getRawCommentText_ref(self._ptr()))

    def brief_comment(mut self) raises -> String:
        return take_cxstring(clang_Cursor_getBriefCommentText_ref(self._ptr()))

    def mangled_name(mut self) raises -> String:
        return take_cxstring(clang_Cursor_getMangling_ref(self._ptr()))

    def storage_class(mut self) raises -> CX_StorageClass:
        return clang_Cursor_getStorageClass_ref(self._ptr())

    def access_specifier(mut self) raises -> CX_CXXAccessSpecifier:
        return clang_getCXXAccessSpecifier_ref(self._ptr())

    def availability(mut self) raises -> CXAvailabilityKind:
        return clang_getCursorAvailability_ref(self._ptr())

    def linkage(mut self) raises -> CXLinkageKind:
        return clang_getCursorLinkage_ref(self._ptr())

    def visibility(mut self) raises -> CXVisibilityKind:
        return clang_getCursorVisibility_ref(self._ptr())

    def language(mut self) raises -> CXLanguageKind:
        return clang_getCursorLanguage_ref(self._ptr())

    def tls_kind(mut self) raises -> CXTLSKind:
        return clang_getCursorTLSKind_ref(self._ptr())

    def is_static_method(mut self) raises -> Bool:
        return Bool(clang_CXXMethod_isStatic_ref(self._ptr()))

    def is_virtual_method(mut self) raises -> Bool:
        return Bool(clang_CXXMethod_isVirtual_ref(self._ptr()))

    def is_const_method(mut self) raises -> Bool:
        return Bool(clang_CXXMethod_isConst_ref(self._ptr()))

    def is_copy_constructor(mut self) raises -> Bool:
        return Bool(clang_CXXConstructor_isCopyConstructor_ref(self._ptr()))

    def is_move_constructor(mut self) raises -> Bool:
        return Bool(clang_CXXConstructor_isMoveConstructor_ref(self._ptr()))

    def is_default_constructor(mut self) raises -> Bool:
        return Bool(clang_CXXConstructor_isDefaultConstructor_ref(self._ptr()))

    def is_converting_constructor(mut self) raises -> Bool:
        return Bool(clang_CXXConstructor_isConvertingConstructor_ref(self._ptr()))

    def is_default_method(mut self) raises -> Bool:
        return Bool(clang_CXXMethod_isDefaulted_ref(self._ptr()))

    def is_deleted_method(mut self) raises -> Bool:
        return Bool(clang_CXXMethod_isDeleted_ref(self._ptr()))

    def is_pure_virtual_method(mut self) raises -> Bool:
        return Bool(clang_CXXMethod_isPureVirtual_ref(self._ptr()))

    def is_abstract_record(mut self) raises -> Bool:
        return Bool(clang_CXXRecord_isAbstract_ref(self._ptr()))

    def is_scoped_enum(mut self) raises -> Bool:
        return Bool(clang_EnumDecl_isScoped_ref(self._ptr()))

    def num_arguments(mut self) raises -> c_int:
        return clang_Cursor_getNumArguments_ref(self._ptr())

    def get_argument(mut self, i: c_uint) raises -> Cursor:
        var out = self._make_cursor()
        clang_Cursor_getArgument_into(out._ptr(), self._ptr(), i)
        return out^

    def get_arguments(mut self) raises -> List[Cursor]:
        var n = self.num_arguments()
        var out = List[Cursor]()
        for i in range(c_uint(n)):
            out.append(self.get_argument(c_uint(i)))
        return out^

    def get_num_template_arguments(mut self) raises -> c_int:
        return clang_Cursor_getNumTemplateArguments_ref(self._ptr())

    def get_template_argument_kind(mut self, i: c_uint) raises -> CXTemplateArgumentKind:
        return clang_Cursor_getTemplateArgumentKind_ref(self._ptr(), i)

    def get_template_argument_type(mut self, i: c_uint) raises -> Type:
        from src.libclang.type_ import Type as RealType
        var out = RealType(tu=self._tu)
        clang_Cursor_getTemplateArgumentType_into(out._ptr(), self._ptr(), i)
        return out^

    def get_template_argument_value(mut self, i: c_uint) raises -> c_long_long:
        return clang_Cursor_getTemplateArgumentValue_ref(self._ptr(), i)

    def get_template_argument_unsigned_value(mut self, i: c_uint) raises -> c_ulong_long:
        return clang_Cursor_getTemplateArgumentUnsignedValue_ref(self._ptr(), i)

    def get_children(mut self) raises -> List[Cursor]:
        from src.libclang.cursor_children import collect_children
        return collect_children(self)

    def walk_preorder(mut self) raises -> List[Cursor]:
        from src.libclang.cursor_children import walk_preorder
        return walk_preorder(self)

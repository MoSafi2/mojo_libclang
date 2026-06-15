"""High-level enum wrappers for libclang.

Each enum tag in the raw binding is exposed as a small ``Copyable,
ImplicitlyCopyable, Movable, Equatable`` struct that:

- Wraps a single ``c_uint`` (or ``Int``) value matching the C ABI.
- Exposes a ``comptime`` constant for every documented case so callers can
  write ``kind == CursorKind.TRANSLATION_UNIT``.
- Converts implicitly from ``c_uint`` so existing call sites that return raw
  values keep working without manual wrapping.
- Exposes ``as_c_uint()`` (or ``as_int()``) to recover the raw value for FFI
  calls.

The wrapper structs are pure value types. They do **not** own libclang
resources and are safe to copy freely.
"""

from std import reflection
from src._ffi import (
    c_int,
    c_uint,
    CXCursorKind,
    CXTypeKind,
    CXTokenKind,
    CXLinkageKind,
    CXAvailabilityKind,
    CX_CXXAccessSpecifier,
    CX_StorageClass,
    CXTLSKind,
    CXLanguageKind,
    CXRefQualifierKind,
    CXTemplateArgumentKind,
    CXCallingConv,
    CXChildVisitResult,
    CXDiagnosticSeverity,
    CXCursor_FirstInvalid,
    CXCursor_TranslationUnit,
    CXCursor_FunctionDecl,
    CXCursor_StructDecl,
    CXCursor_UnionDecl,
    CXCursor_ClassDecl,
    CXCursor_EnumDecl,
    CXCursor_FieldDecl,
    CXCursor_EnumConstantDecl,
    CXCursor_VarDecl,
    CXCursor_ParmDecl,
    CXCursor_TypedefDecl,
    CXCursor_CXXMethod,
    CXCursor_Constructor,
    CXCursor_Destructor,
    CXCursor_ConversionFunction,
    CXCursor_Namespace,
    CXCursor_TypeAliasDecl,
    CXCursor_UnexposedDecl,
    CXType_Invalid,
    CXType_Void,
    CXType_Bool,
    CXType_Char_U,
    CXType_UChar,
    CXType_Char16,
    CXType_Char32,
    CXType_UShort,
    CXType_UInt,
    CXType_ULong,
    CXType_ULongLong,
    CXType_UInt128,
    CXType_Char_S,
    CXType_SChar,
    CXType_WChar,
    CXType_Short,
    CXType_Int,
    CXType_Long,
    CXType_LongLong,
    CXType_Int128,
    CXType_Float,
    CXType_Double,
    CXType_LongDouble,
    CXType_Float16,
    CXType_Float128,
    CXType_Pointer,
    CXType_Record,
    CXType_Enum,
    CXType_Typedef,
    CXType_FunctionProto,
    CXType_ConstantArray,
    CXType_IncompleteArray,
    CXType_LValueReference,
    CXType_RValueReference,
    CXType_MemberPointer,
    CXType_Auto,
    CXType_Elaborated,
    CXType_Dependent,
    CXType_ObjCObjectPointer,
    CXType_BFloat16,
    CXDiagnostic_Ignored,
    CXDiagnostic_Note,
    CXDiagnostic_Warning,
    CXDiagnostic_Error,
    CXDiagnostic_Fatal,
    CXChildVisit_Break,
    CXChildVisit_Continue,
    CXChildVisit_Recurse,
    CXErrorCode,
    CXError_Success,
    CXError_Failure,
    CXError_Crashed,
    CXError_InvalidArguments,
    CXError_ASTReadError,
    CXSaveError,
    CXSaveError_None,
    CXSaveError_Unknown,
    CXSaveError_TranslationErrors,
    CXSaveError_InvalidTU,
    CXTranslationUnit_Flags,
    CXTranslationUnit_None,
    CXTranslationUnit_DetailedPreprocessingRecord,
    CXTranslationUnit_Incomplete,
    CXTranslationUnit_PrecompiledPreamble,
    CXTranslationUnit_CacheCompletionResults,
    CXTranslationUnit_ForSerialization,
    CXTranslationUnit_CXXChainedPCH,
    CXTranslationUnit_SkipFunctionBodies,
    CXTranslationUnit_IncludeBriefCommentsInCodeCompletion,
    CXTranslationUnit_CreatePreambleOnFirstParse,
    CXTranslationUnit_KeepGoing,
    CXTranslationUnit_SingleFileParse,
    CXTranslationUnit_LimitSkipFunctionBodiesToPreamble,
    CXTranslationUnit_IncludeAttributedTypes,
    CXTranslationUnit_VisitImplicitAttributes,
    CXTranslationUnit_IgnoreNonErrorsFromIncludedFiles,
    CXTranslationUnit_RetainExcludedConditionalBlocks,
    CXDiagnosticDisplayOptions,
    CXDiagnostic_DisplaySourceLocation,
    CXDiagnostic_DisplayColumn,
    CXDiagnostic_DisplaySourceRanges,
    CXDiagnostic_DisplayOption,
    CXDiagnostic_DisplayCategoryId,
    CXDiagnostic_DisplayCategoryName,
    CXTypeLayoutError,
    CXTypeLayoutError_Invalid,
    CXTypeLayoutError_Incomplete,
    CXTypeLayoutError_Dependent,
    CXTypeLayoutError_NotConstantSize,
    CXTypeLayoutError_InvalidFieldName,
    CXTypeLayoutError_Undeduced,
    CXVisibilityKind,
    CXVisibility_Invalid,
    CXVisibility_Hidden,
    CXVisibility_Protected,
    CXVisibility_Default,
    CXCursor_ExceptionSpecificationKind,
    CXCursor_ExceptionSpecificationKind_None,
    CXCursor_ExceptionSpecificationKind_DynamicNone,
    CXCursor_ExceptionSpecificationKind_Dynamic,
    CXCursor_ExceptionSpecificationKind_MSAny,
    CXCursor_ExceptionSpecificationKind_BasicNoexcept,
    CXCursor_ExceptionSpecificationKind_ComputedNoexcept,
    CXCursor_ExceptionSpecificationKind_Unevaluated,
    CXCursor_ExceptionSpecificationKind_Uninstantiated,
    CXCursor_ExceptionSpecificationKind_Unparsed,
    CXCursor_ExceptionSpecificationKind_NoThrow,
    CXCodeComplete_Flags,
    CXCodeComplete_IncludeMacros,
    CXCodeComplete_IncludeCodePatterns,
    CXCodeComplete_IncludeBriefComments,
    CXCodeComplete_SkipPreamble,
    CXCodeComplete_IncludeCompletionsWithFixIts,
    CXBinaryOperatorKind,
    CXBinaryOperator_Invalid,
    CXBinaryOperator_PtrMemD,
    CXBinaryOperator_PtrMemI,
    CXBinaryOperator_Mul,
    CXBinaryOperator_Div,
    CXBinaryOperator_Rem,
    CXBinaryOperator_Add,
    CXBinaryOperator_Sub,
    CXBinaryOperator_Shl,
    CXBinaryOperator_Shr,
    CXBinaryOperator_Cmp,
    CXBinaryOperator_LT,
    CXBinaryOperator_GT,
    CXBinaryOperator_LE,
    CXBinaryOperator_GE,
    CXBinaryOperator_EQ,
    CXBinaryOperator_NE,
    CXBinaryOperator_And,
    CXBinaryOperator_Xor,
    CXBinaryOperator_Or,
    CXBinaryOperator_LAnd,
    CXBinaryOperator_LOr,
    CXBinaryOperator_Assign,
    CXBinaryOperator_MulAssign,
    CXBinaryOperator_DivAssign,
    CXBinaryOperator_RemAssign,
    CXBinaryOperator_AddAssign,
    CXBinaryOperator_SubAssign,
    CXBinaryOperator_ShlAssign,
    CXBinaryOperator_ShrAssign,
    CXBinaryOperator_AndAssign,
    CXBinaryOperator_XorAssign,
    CXBinaryOperator_OrAssign,
    CXBinaryOperator_Comma,
    CXUnaryOperatorKind,
    CXUnaryOperator_Invalid,
    CXUnaryOperator_PostInc,
    CXUnaryOperator_PostDec,
    CXUnaryOperator_PreInc,
    CXUnaryOperator_PreDec,
    CXUnaryOperator_AddrOf,
    CXUnaryOperator_Deref,
    CXUnaryOperator_Plus,
    CXUnaryOperator_Minus,
    CXUnaryOperator_Not,
    CXUnaryOperator_LNot,
    CXUnaryOperator_Real,
    CXUnaryOperator_Imag,
    CXUnaryOperator_Extension,
    CXUnaryOperator_Coawait,
    CXCompletionChunkKind,
    CXCompletionChunk_Optional,
    CXCompletionChunk_TypedText,
    CXCompletionChunk_Text,
    CXCompletionChunk_Placeholder,
    CXCompletionChunk_Informative,
    CXCompletionChunk_CurrentParameter,
    CXCompletionChunk_LeftParen,
    CXCompletionChunk_RightParen,
    CXCompletionChunk_LeftBracket,
    CXCompletionChunk_RightBracket,
    CXCompletionChunk_LeftBrace,
    CXCompletionChunk_RightBrace,
    CXCompletionChunk_LeftAngle,
    CXCompletionChunk_RightAngle,
    CXCompletionChunk_Comma,
    CXCompletionChunk_ResultType,
    CXCompletionChunk_Colon,
    CXCompletionChunk_SemiColon,
    CXCompletionChunk_Equal,
    CXCompletionChunk_HorizontalSpace,
    CXCompletionChunk_VerticalSpace,
    CXCompilationDatabase_Error,
    CXCompilationDatabase_NoError,
    CXCompilationDatabase_CanNotLoadDatabase,
    CXPrintingPolicyProperty,
    CXPrintingPolicy_Indentation,
    CXPrintingPolicy_SuppressSpecifiers,
    CXPrintingPolicy_SuppressTagKeyword,
    CXPrintingPolicy_IncludeTagDefinition,
    CXPrintingPolicy_SuppressScope,
    CXPrintingPolicy_SuppressUnwrittenScope,
    CXPrintingPolicy_SuppressInitializers,
    CXPrintingPolicy_ConstantArraySizeAsWritten,
    CXPrintingPolicy_AnonymousTagLocations,
    CXPrintingPolicy_SuppressStrongLifetime,
    CXPrintingPolicy_SuppressLifetimeQualifiers,
    CXPrintingPolicy_SuppressTemplateArgsInCXXConstructors,
    CXPrintingPolicy_Bool,
    CXPrintingPolicy_Restrict,
    CXPrintingPolicy_Alignof,
    CXPrintingPolicy_UnderscoreAlignof,
    CXPrintingPolicy_UseVoidForZeroParams,
    CXPrintingPolicy_TerseOutput,
    CXPrintingPolicy_PolishForDeclaration,
    CXPrintingPolicy_Half,
    CXPrintingPolicy_MSWChar,
    CXPrintingPolicy_IncludeNewlines,
    CXPrintingPolicy_MSVCFormatting,
    CXPrintingPolicy_ConstantsAsWritten,
    CXPrintingPolicy_SuppressImplicitBase,
    CXPrintingPolicy_FullyQualifiedName,
    CXPrintingPolicy_LastProperty,
)


# ---------------------------------------------------------------------------
# CursorKind
# ---------------------------------------------------------------------------


def _is_cursor_kind_decl(value: c_uint) -> Bool:
    return value >= c_uint(1) and value <= c_uint(39)


def _is_cursor_kind_ref(value: c_uint) -> Bool:
    return value >= c_uint(40) and value <= c_uint(50)


def _is_cursor_kind_invalid(value: c_uint) -> Bool:
    return value >= c_uint(70) and value <= c_uint(73)


def _is_cursor_kind_expr(value: c_uint) -> Bool:
    return value >= c_uint(100) and value <= c_uint(155)


def _is_cursor_kind_stmt(value: c_uint) -> Bool:
    return value >= c_uint(200) and value <= c_uint(306)


def _is_cursor_kind_attr(value: c_uint) -> Bool:
    return value >= c_uint(400) and value <= c_uint(441)


def _is_cursor_kind_preprocessing(value: c_uint) -> Bool:
    return value >= c_uint(500) and value <= c_uint(503)


def _is_cursor_kind_extra_decl(value: c_uint) -> Bool:
    return value >= c_uint(600) and value <= c_uint(604)


struct CursorKind(Equatable, ImplicitlyCopyable, Writable):
    """High-level wrapper around ``CXCursorKind``.

    The wrapped ``c_uint`` matches the C ABI so the value can be passed
    straight back into libclang FFI calls.
    """

    var _value: c_uint

    @implicit
    def __init__(out self, value: c_uint):
        self._value = value

    def as_c_uint(self) -> c_uint:
        return self._value

    def is_declaration(self) -> Bool:
        return _is_cursor_kind_decl(self._value)

    def is_reference(self) -> Bool:
        return _is_cursor_kind_ref(self._value)

    def is_invalid(self) -> Bool:
        return _is_cursor_kind_invalid(self._value)

    def is_expression(self) -> Bool:
        return _is_cursor_kind_expr(self._value)

    def is_statement(self) -> Bool:
        return _is_cursor_kind_stmt(self._value)

    def is_attribute(self) -> Bool:
        return _is_cursor_kind_attr(self._value)

    def is_preprocessing(self) -> Bool:
        return _is_cursor_kind_preprocessing(self._value)

    def is_extra_declaration(self) -> Bool:
        return _is_cursor_kind_extra_decl(self._value)

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    # Group boundaries
    comptime OVERLOAD_CANDIDATE = Self(c_uint(700))

    # Declaration kinds
    comptime UNEXPOSED_DECL = Self(CXCursor_UnexposedDecl)
    comptime STRUCT_DECL = Self(CXCursor_StructDecl)
    comptime UNION_DECL = Self(CXCursor_UnionDecl)
    comptime CLASS_DECL = Self(CXCursor_ClassDecl)
    comptime ENUM_DECL = Self(CXCursor_EnumDecl)
    comptime FIELD_DECL = Self(CXCursor_FieldDecl)
    comptime ENUM_CONSTANT_DECL = Self(CXCursor_EnumConstantDecl)
    comptime FUNCTION_DECL = Self(CXCursor_FunctionDecl)
    comptime VAR_DECL = Self(CXCursor_VarDecl)
    comptime PARM_DECL = Self(CXCursor_ParmDecl)
    comptime OBJC_INTERFACE_DECL = Self(c_uint(11))
    comptime OBJC_CATEGORY_DECL = Self(c_uint(12))
    comptime OBJC_PROTOCOL_DECL = Self(c_uint(13))
    comptime OBJC_PROPERTY_DECL = Self(c_uint(14))
    comptime OBJC_IVAR_DECL = Self(c_uint(15))
    comptime OBJC_INSTANCE_METHOD_DECL = Self(c_uint(16))
    comptime OBJC_CLASS_METHOD_DECL = Self(c_uint(17))
    comptime OBJC_IMPLEMENTATION_DECL = Self(c_uint(18))
    comptime OBJC_CATEGORY_IMPL_DECL = Self(c_uint(19))
    comptime TYPEDEF_DECL = Self(CXCursor_TypedefDecl)
    comptime CXX_METHOD = Self(CXCursor_CXXMethod)
    comptime NAMESPACE = Self(CXCursor_Namespace)
    comptime LINKAGE_SPEC = Self(c_uint(23))
    comptime CONSTRUCTOR = Self(CXCursor_Constructor)
    comptime DESTRUCTOR = Self(CXCursor_Destructor)
    comptime CONVERSION_FUNCTION = Self(CXCursor_ConversionFunction)
    comptime TEMPLATE_TYPE_PARAMETER = Self(c_uint(27))
    comptime NON_TYPE_TEMPLATE_PARAMETER = Self(c_uint(28))
    comptime TEMPLATE_TEMPLATE_PARAMETER = Self(c_uint(29))
    comptime FUNCTION_TEMPLATE = Self(c_uint(30))
    comptime CLASS_TEMPLATE = Self(c_uint(31))
    comptime CLASS_TEMPLATE_PARTIAL_SPECIALIZATION = Self(c_uint(32))
    comptime NAMESPACE_ALIAS = Self(c_uint(33))
    comptime USING_DIRECTIVE = Self(c_uint(34))
    comptime USING_DECLARATION = Self(c_uint(35))
    comptime TYPE_ALIAS_DECL = Self(CXCursor_TypeAliasDecl)
    comptime OBJC_SYNTHESIZE_DECL = Self(c_uint(37))
    comptime OBJC_DYNAMIC_DECL = Self(c_uint(38))
    comptime CXX_ACCESS_SPECIFIER = Self(c_uint(39))

    # Reference kinds
    comptime OBJC_SUPER_CLASS_REF = Self(c_uint(40))
    comptime OBJC_PROTOCOL_REF = Self(c_uint(41))
    comptime OBJC_CLASS_REF = Self(c_uint(42))
    comptime TYPE_REF = Self(c_uint(43))
    comptime CXX_BASE_SPECIFIER = Self(c_uint(44))
    comptime TEMPLATE_REF = Self(c_uint(45))
    comptime NAMESPACE_REF = Self(c_uint(46))
    comptime MEMBER_REF = Self(c_uint(47))
    comptime LABEL_REF = Self(c_uint(48))
    comptime OVERLOADED_DECL_REF = Self(c_uint(49))
    comptime VARIABLE_REF = Self(c_uint(50))

    # Invalid kinds
    comptime INVALID_FILE = Self(c_uint(70))
    comptime NO_DECL_FOUND = Self(c_uint(71))
    comptime NOT_IMPLEMENTED = Self(c_uint(72))
    comptime INVALID_CODE = Self(c_uint(73))

    # Expression kinds
    comptime UNEXPOSED_EXPR = Self(c_uint(100))
    comptime DECL_REF_EXPR = Self(c_uint(101))
    comptime MEMBER_REF_EXPR = Self(c_uint(102))
    comptime CALL_EXPR = Self(c_uint(103))
    comptime OBJC_MESSAGE_EXPR = Self(c_uint(104))
    comptime BLOCK_EXPR = Self(c_uint(105))
    comptime INTEGER_LITERAL = Self(c_uint(106))
    comptime FLOATING_LITERAL = Self(c_uint(107))
    comptime IMAGINARY_LITERAL = Self(c_uint(108))
    comptime STRING_LITERAL = Self(c_uint(109))
    comptime CHARACTER_LITERAL = Self(c_uint(110))
    comptime PAREN_EXPR = Self(c_uint(111))
    comptime UNARY_OPERATOR = Self(c_uint(112))
    comptime ARRAY_SUBSCRIPT_EXPR = Self(c_uint(113))
    comptime BINARY_OPERATOR = Self(c_uint(114))
    comptime COMPOUND_ASSIGN_OPERATOR = Self(c_uint(115))
    comptime CONDITIONAL_OPERATOR = Self(c_uint(116))
    comptime C_STYLE_CAST_EXPR = Self(c_uint(117))
    comptime COMPOUND_LITERAL_EXPR = Self(c_uint(118))
    comptime INIT_LIST_EXPR = Self(c_uint(119))
    comptime ADDR_LABEL_EXPR = Self(c_uint(120))
    comptime STMT_EXPR = Self(c_uint(121))
    comptime GENERIC_SELECTION_EXPR = Self(c_uint(122))
    comptime GNU_NULL_EXPR = Self(c_uint(123))
    comptime CXX_STATIC_CAST_EXPR = Self(c_uint(124))
    comptime CXX_DYNAMIC_CAST_EXPR = Self(c_uint(125))
    comptime CXX_REINTERPRET_CAST_EXPR = Self(c_uint(126))
    comptime CXX_CONST_CAST_EXPR = Self(c_uint(127))
    comptime CXX_FUNCTIONAL_CAST_EXPR = Self(c_uint(128))
    comptime CXX_TYPEID_EXPR = Self(c_uint(129))
    comptime CXX_BOOL_LITERAL_EXPR = Self(c_uint(130))
    comptime CXX_NULL_PTR_LITERAL_EXPR = Self(c_uint(131))
    comptime CXX_THIS_EXPR = Self(c_uint(132))
    comptime CXX_THROW_EXPR = Self(c_uint(133))
    comptime CXX_NEW_EXPR = Self(c_uint(134))
    comptime CXX_DELETE_EXPR = Self(c_uint(135))
    comptime UNARY_EXPR = Self(c_uint(136))
    comptime OBJC_STRING_LITERAL = Self(c_uint(137))
    comptime OBJC_ENCODE_EXPR = Self(c_uint(138))
    comptime OBJC_SELECTOR_EXPR = Self(c_uint(139))
    comptime OBJC_PROTOCOL_EXPR = Self(c_uint(140))
    comptime OBJC_BRIDGED_CAST_EXPR = Self(c_uint(141))
    comptime PACK_EXPANSION_EXPR = Self(c_uint(142))
    comptime SIZE_OF_PACK_EXPR = Self(c_uint(143))
    comptime LAMBDA_EXPR = Self(c_uint(144))
    comptime OBJC_BOOL_LITERAL_EXPR = Self(c_uint(145))
    comptime OBJC_SELF_EXPR = Self(c_uint(146))
    comptime FIXED_POINT_LITERAL = Self(c_uint(149))
    comptime CXX_ADDRSPACE_CAST_EXPR = Self(c_uint(152))
    comptime CONCEPT_SPECIALIZATION_EXPR = Self(c_uint(153))
    comptime REQUIRES_EXPR = Self(c_uint(154))
    comptime CXX_PAREN_LIST_INIT_EXPR = Self(c_uint(155))

    # Statement kinds
    comptime UNEXPOSED_STMT = Self(c_uint(200))
    comptime LABEL_STMT = Self(c_uint(201))
    comptime COMPOUND_STMT = Self(c_uint(202))
    comptime CASE_STMT = Self(c_uint(203))
    comptime DEFAULT_STMT = Self(c_uint(204))
    comptime IF_STMT = Self(c_uint(205))
    comptime SWITCH_STMT = Self(c_uint(206))
    comptime WHILE_STMT = Self(c_uint(207))
    comptime DO_STMT = Self(c_uint(208))
    comptime FOR_STMT = Self(c_uint(209))
    comptime GOTO_STMT = Self(c_uint(210))
    comptime INDIRECT_GOTO_STMT = Self(c_uint(211))
    comptime CONTINUE_STMT = Self(c_uint(212))
    comptime BREAK_STMT = Self(c_uint(213))
    comptime RETURN_STMT = Self(c_uint(214))
    comptime GCC_ASM_STMT = Self(c_uint(215))
    comptime OBJC_AT_TRY_STMT = Self(c_uint(216))
    comptime OBJC_AT_CATCH_STMT = Self(c_uint(217))
    comptime OBJC_AT_FINALLY_STMT = Self(c_uint(218))
    comptime OBJC_AT_THROW_STMT = Self(c_uint(219))
    comptime OBJC_AT_SYNCHRONIZED_STMT = Self(c_uint(220))
    comptime OBJC_AUTORELEASE_POOL_STMT = Self(c_uint(221))
    comptime OBJC_FOR_COLLECTION_STMT = Self(c_uint(222))
    comptime CXX_CATCH_STMT = Self(c_uint(223))
    comptime CXX_TRY_STMT = Self(c_uint(224))
    comptime CXX_FOR_RANGE_STMT = Self(c_uint(225))
    comptime SEH_TRY_STMT = Self(c_uint(226))
    comptime SEH_EXCEPT_STMT = Self(c_uint(227))
    comptime SEH_FINALLY_STMT = Self(c_uint(228))
    comptime MS_ASM_STMT = Self(c_uint(229))
    comptime NULL_STMT = Self(c_uint(230))
    comptime DECL_STMT = Self(c_uint(231))

    # Root
    comptime TRANSLATION_UNIT = Self(CXCursor_TranslationUnit)

    # Attribute kinds
    comptime UNEXPOSED_ATTR = Self(c_uint(400))
    comptime IBACTION_ATTR = Self(c_uint(401))
    comptime IBOUTLET_ATTR = Self(c_uint(402))
    comptime IBOUTLET_COLLECTION_ATTR = Self(c_uint(403))
    comptime CXX_FINAL_ATTR = Self(c_uint(404))
    comptime CXX_OVERRIDE_ATTR = Self(c_uint(405))
    comptime ANNOTATE_ATTR = Self(c_uint(406))
    comptime ASM_LABEL_ATTR = Self(c_uint(407))
    comptime PACKED_ATTR = Self(c_uint(408))
    comptime PURE_ATTR = Self(c_uint(409))
    comptime CONST_ATTR = Self(c_uint(410))
    comptime NO_DUPLICATE_ATTR = Self(c_uint(411))
    comptime CUDA_CONSTANT_ATTR = Self(c_uint(412))
    comptime CUDA_DEVICE_ATTR = Self(c_uint(413))
    comptime CUDA_GLOBAL_ATTR = Self(c_uint(414))
    comptime CUDA_HOST_ATTR = Self(c_uint(415))
    comptime CUDA_SHARED_ATTR = Self(c_uint(416))
    comptime VISIBILITY_ATTR = Self(c_uint(417))
    comptime DLL_EXPORT = Self(c_uint(418))
    comptime DLL_IMPORT = Self(c_uint(419))
    comptime NS_RETURNS_RETAINED = Self(c_uint(420))
    comptime NS_RETURNS_NOT_RETAINED = Self(c_uint(421))
    comptime NS_RETURNS_AUTORELEASED = Self(c_uint(422))
    comptime NS_CONSUMES_SELF = Self(c_uint(423))
    comptime NS_CONSUMED = Self(c_uint(424))
    comptime OBJC_EXCEPTION = Self(c_uint(425))
    comptime OBJC_NSOBJECT = Self(c_uint(426))
    comptime OBJC_INDEPENDENT_CLASS = Self(c_uint(427))
    comptime OBJC_PRECISE_LIFETIME = Self(c_uint(428))
    comptime OBJC_RETURNS_INNER_POINTER = Self(c_uint(429))
    comptime OBJC_REQUIRES_SUPER = Self(c_uint(430))
    comptime OBJC_ROOT_CLASS = Self(c_uint(431))
    comptime OBJC_SUBCLASSING_RESTRICTED = Self(c_uint(432))
    comptime OBJC_EXPLICIT_PROTOCOL_IMPL = Self(c_uint(433))
    comptime OBJC_DESIGNATED_INITIALIZER = Self(c_uint(434))
    comptime OBJC_RUNTIME_VISIBLE = Self(c_uint(435))
    comptime OBJC_BOXABLE = Self(c_uint(436))
    comptime FLAG_ENUM = Self(c_uint(437))
    comptime CONVERGENT_ATTR = Self(c_uint(438))
    comptime WARN_UNUSED_ATTR = Self(c_uint(439))
    comptime WARN_UNUSED_RESULT_ATTR = Self(c_uint(440))
    comptime ALIGNED_ATTR = Self(c_uint(441))

    # Preprocessing kinds
    comptime PREPROCESSING_DIRECTIVE = Self(c_uint(500))
    comptime MACRO_DEFINITION = Self(c_uint(501))
    comptime MACRO_EXPANSION = Self(c_uint(502))
    comptime INCLUSION_DIRECTIVE = Self(c_uint(503))

    # Extra declaration kinds
    comptime MODULE_IMPORT_DECL = Self(c_uint(600))
    comptime TYPE_ALIAS_TEMPLATE_DECL = Self(c_uint(601))
    comptime STATIC_ASSERT = Self(c_uint(602))
    comptime FRIEND_DECL = Self(c_uint(603))
    comptime CONCEPT_DECL = Self(c_uint(604))


# ---------------------------------------------------------------------------
# TypeKind
# ---------------------------------------------------------------------------


struct TypeKind(Equatable, ImplicitlyCopyable, Writable):
    """High-level wrapper around ``CXTypeKind``."""

    var _value: c_uint

    @implicit
    def __init__(out self, value: c_uint):
        self._value = value

    def as_c_uint(self) -> c_uint:
        return self._value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    comptime INVALID = Self(c_uint(0))
    comptime UNEXPOSED = Self(c_uint(1))
    comptime VOID = Self(c_uint(2))
    comptime BOOL = Self(c_uint(3))
    comptime CHAR_U = Self(c_uint(4))
    comptime UCHAR = Self(c_uint(5))
    comptime CHAR16 = Self(c_uint(6))
    comptime CHAR32 = Self(c_uint(7))
    comptime USHORT = Self(c_uint(8))
    comptime UINT = Self(c_uint(9))
    comptime ULONG = Self(c_uint(10))
    comptime ULONG_LONG = Self(c_uint(11))
    comptime UINT128 = Self(c_uint(12))
    comptime CHAR_S = Self(c_uint(13))
    comptime SCHAR = Self(c_uint(14))
    comptime WCHAR = Self(c_uint(15))
    comptime SHORT = Self(c_uint(16))
    comptime INT = Self(c_uint(17))
    comptime LONG = Self(c_uint(18))
    comptime LONG_LONG = Self(c_uint(19))
    comptime INT128 = Self(c_uint(20))
    comptime FLOAT = Self(c_uint(21))
    comptime DOUBLE = Self(c_uint(22))
    comptime LONG_DOUBLE = Self(c_uint(23))
    comptime NULLPTR = Self(c_uint(24))
    comptime OVERLOAD = Self(c_uint(25))
    comptime DEPENDENT = Self(c_uint(26))
    comptime OBJC_ID = Self(c_uint(27))
    comptime OBJC_CLASS = Self(c_uint(28))
    comptime OBJC_SEL = Self(c_uint(29))
    comptime FLOAT128 = Self(c_uint(30))
    comptime HALF = Self(c_uint(31))
    comptime FLOAT16 = Self(c_uint(32))
    comptime BFLOAT16 = Self(c_uint(39))
    comptime IBM128 = Self(c_uint(40))
    comptime FIRST_BUILTIN = Self(c_uint(2))
    comptime LAST_BUILTIN = Self(c_uint(40))
    comptime COMPLEX = Self(c_uint(100))
    comptime POINTER = Self(c_uint(101))
    comptime BLOCK_POINTER = Self(c_uint(102))
    comptime LVALUE_REFERENCE = Self(c_uint(103))
    comptime RVALUE_REFERENCE = Self(c_uint(104))
    comptime RECORD = Self(c_uint(105))
    comptime ENUM = Self(c_uint(106))
    comptime TYPEDEF = Self(c_uint(107))
    comptime OBJC_INTERFACE = Self(c_uint(108))
    comptime OBJC_OBJECT_POINTER = Self(c_uint(109))
    comptime FUNCTION_NO_PROTO = Self(c_uint(110))
    comptime FUNCTION_PROTO = Self(c_uint(111))
    comptime CONSTANT_ARRAY = Self(c_uint(112))
    comptime VECTOR = Self(c_uint(113))
    comptime INCOMPLETE_ARRAY = Self(c_uint(114))
    comptime VARIABLE_ARRAY = Self(c_uint(115))
    comptime DEPENDENT_SIZED_ARRAY = Self(c_uint(116))
    comptime MEMBER_POINTER = Self(c_uint(117))
    comptime AUTO = Self(c_uint(118))
    comptime ELABORATED = Self(c_uint(119))
    comptime PIPE = Self(c_uint(120))
    comptime OBJC_OBJECT = Self(c_uint(161))
    comptime OBJC_TYPE_PARAM = Self(c_uint(162))
    comptime ATTRIBUTED = Self(c_uint(163))
    comptime EXT_VECTOR = Self(c_uint(176))
    comptime ATOMIC = Self(c_uint(177))
    comptime BTF_TAG_ATTRIBUTED = Self(c_uint(178))


# ---------------------------------------------------------------------------
# TokenKind
# ---------------------------------------------------------------------------


struct TokenKind(Equatable, ImplicitlyCopyable, Writable):
    """High-level wrapper around ``CXTokenKind``."""

    var _value: c_uint

    @implicit
    def __init__(out self, value: c_uint):
        self._value = value

    def as_c_uint(self) -> c_uint:
        return self._value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    comptime PUNCTUATION = Self(c_uint(0))
    comptime KEYWORD = Self(c_uint(1))
    comptime IDENTIFIER = Self(c_uint(2))
    comptime LITERAL = Self(c_uint(3))
    comptime COMMENT = Self(c_uint(4))


# ---------------------------------------------------------------------------
# LinkageKind
# ---------------------------------------------------------------------------


struct LinkageKind(Equatable, ImplicitlyCopyable, Writable):
    """High-level wrapper around ``CXLinkageKind``."""

    var _value: c_uint

    @implicit
    def __init__(out self, value: c_uint):
        self._value = value

    def as_c_uint(self) -> c_uint:
        return self._value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    comptime INVALID = Self(c_uint(0))
    comptime NO_LINKAGE = Self(c_uint(1))
    comptime INTERNAL = Self(c_uint(2))
    comptime UNIQUE_EXTERNAL = Self(c_uint(3))
    comptime EXTERNAL = Self(c_uint(4))


# ---------------------------------------------------------------------------
# AvailabilityKind
# ---------------------------------------------------------------------------


struct AvailabilityKind(Equatable, ImplicitlyCopyable, Writable):
    """High-level wrapper around ``CXAvailabilityKind``."""

    var _value: c_uint

    @implicit
    def __init__(out self, value: c_uint):
        self._value = value

    def as_c_uint(self) -> c_uint:
        return self._value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    comptime AVAILABLE = Self(c_uint(0))
    comptime DEPRECATED = Self(c_uint(1))
    comptime NOT_AVAILABLE = Self(c_uint(2))
    comptime NOT_ACCESSIBLE = Self(c_uint(3))


# ---------------------------------------------------------------------------
# AccessSpecifier
# ---------------------------------------------------------------------------


struct AccessSpecifier(Equatable, ImplicitlyCopyable, Writable):
    """High-level wrapper around ``CX_CXXAccessSpecifier``."""

    var _value: c_uint

    @implicit
    def __init__(out self, value: c_uint):
        self._value = value

    def as_c_uint(self) -> c_uint:
        return self._value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    comptime INVALID = Self(c_uint(0))
    comptime PUBLIC = Self(c_uint(1))
    comptime PROTECTED = Self(c_uint(2))
    comptime PRIVATE = Self(c_uint(3))


# ---------------------------------------------------------------------------
# StorageClass
# ---------------------------------------------------------------------------


struct StorageClass(Equatable, ImplicitlyCopyable, Writable):
    """High-level wrapper around ``CX_StorageClass``."""

    var _value: c_uint

    @implicit
    def __init__(out self, value: c_uint):
        self._value = value

    def as_c_uint(self) -> c_uint:
        return self._value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    comptime INVALID = Self(c_uint(0))
    comptime NONE = Self(c_uint(1))
    comptime EXTERN = Self(c_uint(2))
    comptime STATIC = Self(c_uint(3))
    comptime PRIVATE_EXTERN = Self(c_uint(4))
    comptime OPENCL_WORK_GROUP_LOCAL = Self(c_uint(5))
    comptime AUTO = Self(c_uint(6))
    comptime REGISTER = Self(c_uint(7))


# ---------------------------------------------------------------------------
# TLSKind
# ---------------------------------------------------------------------------


struct TLSKind(Equatable, ImplicitlyCopyable, Writable):
    """High-level wrapper around ``CXTLSKind``."""

    var _value: c_uint

    @implicit
    def __init__(out self, value: c_uint):
        self._value = value

    def as_c_uint(self) -> c_uint:
        return self._value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    comptime NONE = Self(c_uint(0))
    comptime DYNAMIC = Self(c_uint(1))
    comptime STATIC = Self(c_uint(2))


# ---------------------------------------------------------------------------
# LanguageKind
# ---------------------------------------------------------------------------


struct LanguageKind(Equatable, ImplicitlyCopyable, Writable):
    """High-level wrapper around ``CXLanguageKind``."""

    var _value: c_uint

    @implicit
    def __init__(out self, value: c_uint):
        self._value = value

    def as_c_uint(self) -> c_uint:
        return self._value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    comptime INVALID = Self(c_uint(0))
    comptime C = Self(c_uint(1))
    comptime OBJC = Self(c_uint(2))
    comptime C_PLUS_PLUS = Self(c_uint(3))


# ---------------------------------------------------------------------------
# RefQualifierKind
# ---------------------------------------------------------------------------


struct RefQualifierKind(Equatable, ImplicitlyCopyable, Writable):
    """High-level wrapper around ``CXRefQualifierKind``."""

    var _value: c_uint

    @implicit
    def __init__(out self, value: c_uint):
        self._value = value

    def as_c_uint(self) -> c_uint:
        return self._value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    comptime NONE = Self(c_uint(0))
    comptime LVALUE = Self(c_uint(1))
    comptime RVALUE = Self(c_uint(2))


# ---------------------------------------------------------------------------
# TemplateArgumentKind
# ---------------------------------------------------------------------------


struct TemplateArgumentKind(Equatable, ImplicitlyCopyable, Writable):
    """High-level wrapper around ``CXTemplateArgumentKind``."""

    var _value: c_uint

    @implicit
    def __init__(out self, value: c_uint):
        self._value = value

    def as_c_uint(self) -> c_uint:
        return self._value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    comptime NULL = Self(c_uint(0))
    comptime TYPE = Self(c_uint(1))
    comptime DECLARATION = Self(c_uint(2))
    comptime NULLPTR = Self(c_uint(3))
    comptime INTEGRAL = Self(c_uint(4))
    comptime TEMPLATE = Self(c_uint(5))
    comptime TEMPLATE_EXPANSION = Self(c_uint(6))
    comptime EXPRESSION = Self(c_uint(7))
    comptime PACK = Self(c_uint(8))
    comptime INVALID = Self(c_uint(9))


# ---------------------------------------------------------------------------
# CallingConv
# ---------------------------------------------------------------------------


struct CallingConv(Equatable, ImplicitlyCopyable, Writable):
    """High-level wrapper around ``CXCallingConv``."""

    var _value: c_uint

    @implicit
    def __init__(out self, value: c_uint):
        self._value = value

    def as_c_uint(self) -> c_uint:
        return self._value

    def name(self) -> String:
        """Return the Python-libclang-compatible name of this convention."""
        if self._value == c_uint(0):
            return "DEFAULT"
        if self._value == c_uint(1):
            return "C"
        if self._value == c_uint(2):
            return "X86_STDCALL"
        if self._value == c_uint(3):
            return "X86_FASTCALL"
        if self._value == c_uint(4):
            return "X86_THISCALL"
        if self._value == c_uint(5):
            return "X86_PASCAL"
        if self._value == c_uint(6):
            return "AAPCS"
        if self._value == c_uint(7):
            return "AAPCS_VFP"
        if self._value == c_uint(8):
            return "X86_REG_CALL"
        if self._value == c_uint(9):
            return "INTEL_OCL_BICC"
        if self._value == c_uint(10):
            return "WIN64"
        if self._value == c_uint(11):
            return "X86_64_SYS_V"
        if self._value == c_uint(12):
            return "X86_VECTOR_CALL"
        if self._value == c_uint(13):
            return "SWIFT"
        if self._value == c_uint(14):
            return "PRESERVE_MOST"
        if self._value == c_uint(15):
            return "PRESERVE_ALL"
        if self._value == c_uint(16):
            return "AARCH64_VECTOR_CALL"
        if self._value == c_uint(17):
            return "SWIFT_ASYNC"
        if self._value == c_uint(18):
            return "AARCH64_SVE_PCS"
        if self._value == c_uint(19):
            return "M68K_RTD"
        if self._value == c_uint(100):
            return "INVALID"
        if self._value == c_uint(200):
            return "UNEXPOSED"
        return String(t"UNKNOWN({Int(self._value)})")

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    comptime DEFAULT = Self(c_uint(0))
    comptime C = Self(c_uint(1))
    comptime X86_STD_CALL = Self(c_uint(2))
    comptime X86_FAST_CALL = Self(c_uint(3))
    comptime X86_THIS_CALL = Self(c_uint(4))
    comptime X86_PASCAL = Self(c_uint(5))
    comptime AAPCS = Self(c_uint(6))
    comptime AAPCS_VFP = Self(c_uint(7))
    comptime X86_REG_CALL = Self(c_uint(8))
    comptime INTEL_OCL_BICC = Self(c_uint(9))
    comptime WIN64 = Self(c_uint(10))
    comptime X86_64_WIN64 = Self(c_uint(10))
    comptime X86_64_SYS_V = Self(c_uint(11))
    comptime X86_VECTOR_CALL = Self(c_uint(12))
    comptime SWIFT = Self(c_uint(13))
    comptime PRESERVE_MOST = Self(c_uint(14))
    comptime PRESERVE_ALL = Self(c_uint(15))
    comptime AARCH64_VECTOR_CALL = Self(c_uint(16))
    comptime SWIFT_ASYNC = Self(c_uint(17))
    comptime AARCH64_SVE_PCS = Self(c_uint(18))
    comptime M68K_RTD = Self(c_uint(19))
    comptime INVALID = Self(c_uint(100))
    comptime UNEXPOSED = Self(c_uint(200))


# ---------------------------------------------------------------------------
# ChildVisitResult
# ---------------------------------------------------------------------------


struct ChildVisitResult(Equatable, ImplicitlyCopyable, Writable):
    """High-level wrapper around ``CXChildVisitResult``."""

    var _value: c_uint

    @implicit
    def __init__(out self, value: c_uint):
        self._value = value

    def as_c_uint(self) -> c_uint:
        return self._value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    comptime BREAK = Self(CXChildVisit_Break)
    comptime CONTINUE = Self(CXChildVisit_Continue)
    comptime RECURSE = Self(CXChildVisit_Recurse)


# ---------------------------------------------------------------------------
# DiagnosticSeverity
# ---------------------------------------------------------------------------


struct DiagnosticSeverity(Equatable, ImplicitlyCopyable, Writable):
    """High-level wrapper around ``CXDiagnosticSeverity``."""

    var _value: c_uint

    @implicit
    def __init__(out self, value: c_uint):
        self._value = value

    def as_c_uint(self) -> c_uint:
        return self._value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    comptime IGNORED = Self(CXDiagnostic_Ignored)
    comptime NOTE = Self(CXDiagnostic_Note)
    comptime WARNING = Self(CXDiagnostic_Warning)
    comptime ERROR = Self(CXDiagnostic_Error)
    comptime FATAL = Self(CXDiagnostic_Fatal)


# ---------------------------------------------------------------------------
# ErrorCode
# ---------------------------------------------------------------------------


struct ErrorCode(Equatable, ImplicitlyCopyable, Writable):
    """Return code from ``clang_parseTranslationUnit2`` etc."""

    var _value: c_uint

    @implicit
    def __init__(out self, value: c_uint):
        self._value = value

    def as_c_uint(self) -> c_uint:
        return self._value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    comptime SUCCESS = Self(CXError_Success)
    comptime FAILURE = Self(CXError_Failure)
    comptime CRASHED = Self(CXError_Crashed)
    comptime INVALID_ARGUMENTS = Self(CXError_InvalidArguments)
    comptime AST_READ_ERROR = Self(CXError_ASTReadError)


# ---------------------------------------------------------------------------
# SaveError
# ---------------------------------------------------------------------------


struct SaveError(Equatable, ImplicitlyCopyable, Writable):
    """Return code from ``clang_saveTranslationUnit``."""

    var _value: c_uint

    @implicit
    def __init__(out self, value: c_uint):
        self._value = value

    def as_c_uint(self) -> c_uint:
        return self._value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    comptime NONE = Self(CXSaveError_None)
    comptime UNKNOWN = Self(CXSaveError_Unknown)
    comptime TRANSLATION_ERRORS = Self(CXSaveError_TranslationErrors)
    comptime INVALID_TU = Self(CXSaveError_InvalidTU)


# ---------------------------------------------------------------------------
# TranslationUnitFlags  (bit flags)
# ---------------------------------------------------------------------------


struct TranslationUnitFlags(Equatable, ImplicitlyCopyable, Writable):
    """Bit flags for ``TranslationUnit`` creation / reparse options.

    Supports ``contains()`` and ``|`` for composing options.
    """

    var _value: c_uint

    @implicit
    def __init__(out self, value: c_uint):
        self._value = value

    def as_c_uint(self) -> c_uint:
        return self._value

    def contains(self, flag: Self) -> Bool:
        return (self._value & flag._value) != c_uint(0)

    def __or__(self, other: Self) -> Self:
        return Self(self._value | other._value)

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    comptime NONE = Self(CXTranslationUnit_None)
    comptime DETAILED_PREPROCESSING_RECORD = Self(
        CXTranslationUnit_DetailedPreprocessingRecord,
    )
    comptime INCOMPLETE = Self(CXTranslationUnit_Incomplete)
    comptime PRECOMPILED_PREAMBLE = Self(CXTranslationUnit_PrecompiledPreamble)
    comptime CACHE_COMPLETION_RESULTS = Self(
        CXTranslationUnit_CacheCompletionResults
    )
    comptime FOR_SERIALIZATION = Self(CXTranslationUnit_ForSerialization)
    comptime CXX_CHAINED_PCH = Self(CXTranslationUnit_CXXChainedPCH)
    comptime SKIP_FUNCTION_BODIES = Self(CXTranslationUnit_SkipFunctionBodies)
    comptime INCLUDE_BRIEF_COMMENTS_IN_CODE_COMPLETION = Self(
        CXTranslationUnit_IncludeBriefCommentsInCodeCompletion,
    )
    comptime CREATE_PREAMBLE_ON_FIRST_PARSE = Self(
        CXTranslationUnit_CreatePreambleOnFirstParse,
    )
    comptime KEEP_GOING = Self(CXTranslationUnit_KeepGoing)
    comptime SINGLE_FILE_PARSE = Self(CXTranslationUnit_SingleFileParse)
    comptime LIMIT_SKIP_FUNCTION_BODIES_TO_PREAMBLE = Self(
        CXTranslationUnit_LimitSkipFunctionBodiesToPreamble,
    )
    comptime INCLUDE_ATTRIBUTED_TYPES = Self(
        CXTranslationUnit_IncludeAttributedTypes
    )
    comptime VISIT_IMPLICIT_ATTRIBUTES = Self(
        CXTranslationUnit_VisitImplicitAttributes
    )
    comptime IGNORE_NON_ERRORS_FROM_INCLUDED_FILES = Self(
        CXTranslationUnit_IgnoreNonErrorsFromIncludedFiles,
    )
    comptime RETAIN_EXCLUDED_CONDITIONAL_BLOCKS = Self(
        CXTranslationUnit_RetainExcludedConditionalBlocks,
    )


# ---------------------------------------------------------------------------
# DiagnosticDisplayOptions  (bit flags)
# ---------------------------------------------------------------------------


struct DiagnosticDisplayOptions(Equatable, ImplicitlyCopyable, Writable):
    """Bit flags for ``clang_formatDiagnostic`` options."""

    var _value: c_uint

    @implicit
    def __init__(out self, value: c_uint):
        self._value = value

    def as_c_uint(self) -> c_uint:
        return self._value

    def contains(self, flag: Self) -> Bool:
        return (self._value & flag._value) != c_uint(0)

    def __or__(self, other: Self) -> Self:
        return Self(self._value | other._value)

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    comptime DEFAULT = Self(c_uint(0))
    comptime SOURCE_LOCATION = Self(CXDiagnostic_DisplaySourceLocation)
    comptime COLUMN = Self(CXDiagnostic_DisplayColumn)
    comptime SOURCE_RANGES = Self(CXDiagnostic_DisplaySourceRanges)
    comptime OPTION = Self(CXDiagnostic_DisplayOption)
    comptime CATEGORY_ID = Self(CXDiagnostic_DisplayCategoryId)
    comptime CATEGORY_NAME = Self(CXDiagnostic_DisplayCategoryName)


# ---------------------------------------------------------------------------
# TypeLayoutError  (signed — layout APIs return negative error codes)
# ---------------------------------------------------------------------------


struct TypeLayoutError(Equatable, ImplicitlyCopyable, Writable):
    """Signed error code from ``clang_Type_getSizeOf`` etc."""

    var _value: Int

    @implicit
    def __init__(out self, value: Int):
        self._value = value

    def as_int(self) -> Int:
        return self._value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    comptime INVALID = Self(Int(CXTypeLayoutError_Invalid))
    comptime INCOMPLETE = Self(Int(CXTypeLayoutError_Incomplete))
    comptime DEPENDENT = Self(Int(CXTypeLayoutError_Dependent))
    comptime NOT_CONSTANT_SIZE = Self(Int(CXTypeLayoutError_NotConstantSize))
    comptime INVALID_FIELD_NAME = Self(Int(CXTypeLayoutError_InvalidFieldName))
    comptime UNDEDUCED = Self(Int(CXTypeLayoutError_Undeduced))


# ---------------------------------------------------------------------------
# VisibilityKind
# ---------------------------------------------------------------------------


struct VisibilityKind(Equatable, ImplicitlyCopyable, Writable):
    """Visibility of a cursor/declaration."""

    var _value: c_uint

    @implicit
    def __init__(out self, value: c_uint):
        self._value = value

    def as_c_uint(self) -> c_uint:
        return self._value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    comptime INVALID = Self(CXVisibility_Invalid)
    comptime HIDDEN = Self(CXVisibility_Hidden)
    comptime PROTECTED = Self(CXVisibility_Protected)
    comptime DEFAULT = Self(CXVisibility_Default)


# ---------------------------------------------------------------------------
# ExceptionSpecificationKind
# ---------------------------------------------------------------------------


struct ExceptionSpecificationKind(Equatable, ImplicitlyCopyable, Writable):
    """Exception specification kind on a function type."""

    var _value: c_uint

    @implicit
    def __init__(out self, value: c_uint):
        self._value = value

    def as_c_uint(self) -> c_uint:
        return self._value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    comptime NONE = Self(CXCursor_ExceptionSpecificationKind_None)
    comptime DYNAMIC_NONE = Self(
        CXCursor_ExceptionSpecificationKind_DynamicNone
    )
    comptime DYNAMIC = Self(CXCursor_ExceptionSpecificationKind_Dynamic)
    comptime MS_ANY = Self(CXCursor_ExceptionSpecificationKind_MSAny)
    comptime BASIC_NOEXCEPT = Self(
        CXCursor_ExceptionSpecificationKind_BasicNoexcept
    )
    comptime COMPUTED_NOEXCEPT = Self(
        CXCursor_ExceptionSpecificationKind_ComputedNoexcept,
    )
    comptime UNEVALUATED = Self(CXCursor_ExceptionSpecificationKind_Unevaluated)
    comptime UNINSTANTIATED = Self(
        CXCursor_ExceptionSpecificationKind_Uninstantiated
    )
    comptime UNPARSED = Self(CXCursor_ExceptionSpecificationKind_Unparsed)
    comptime NO_THROW = Self(CXCursor_ExceptionSpecificationKind_NoThrow)


# ---------------------------------------------------------------------------
# CodeCompleteFlags  (bit flags)
# ---------------------------------------------------------------------------


struct CodeCompleteFlags(Equatable, ImplicitlyCopyable, Writable):
    """Bit flags for code-completion options."""

    var _value: c_uint

    @implicit
    def __init__(out self, value: c_uint):
        self._value = value

    def as_c_uint(self) -> c_uint:
        return self._value

    def contains(self, flag: Self) -> Bool:
        return (self._value & flag._value) != c_uint(0)

    def __or__(self, other: Self) -> Self:
        return Self(self._value | other._value)

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    comptime INCLUDE_MACROS = Self(CXCodeComplete_IncludeMacros)
    comptime INCLUDE_CODE_PATTERNS = Self(CXCodeComplete_IncludeCodePatterns)
    comptime INCLUDE_BRIEF_COMMENTS = Self(CXCodeComplete_IncludeBriefComments)
    comptime SKIP_PREAMBLE = Self(CXCodeComplete_SkipPreamble)
    comptime INCLUDE_COMPLETIONS_WITH_FIX_ITS = Self(
        CXCodeComplete_IncludeCompletionsWithFixIts,
    )


# ---------------------------------------------------------------------------
# BinaryOperator
# ---------------------------------------------------------------------------


struct BinaryOperator(Equatable, ImplicitlyCopyable, Writable):
    """High-level wrapper around ``CXBinaryOperatorKind``."""

    var _value: c_uint

    @implicit
    def __init__(out self, value: c_uint):
        self._value = value

    def as_c_uint(self) -> c_uint:
        return self._value

    def is_invalid(self) -> Bool:
        return self._value == c_uint(0)

    def is_assignment(self) -> Bool:
        var v = self._value
        return v >= CXBinaryOperator_Assign and v < CXBinaryOperator_Comma

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    def __bool__(self) -> Bool:
        return self._value != c_uint(0)

    comptime INVALID = Self(CXBinaryOperator_Invalid)
    comptime PTR_MEM_D = Self(CXBinaryOperator_PtrMemD)
    comptime PTR_MEM_I = Self(CXBinaryOperator_PtrMemI)
    comptime MUL = Self(CXBinaryOperator_Mul)
    comptime DIV = Self(CXBinaryOperator_Div)
    comptime REM = Self(CXBinaryOperator_Rem)
    comptime ADD = Self(CXBinaryOperator_Add)
    comptime SUB = Self(CXBinaryOperator_Sub)
    comptime SHL = Self(CXBinaryOperator_Shl)
    comptime SHR = Self(CXBinaryOperator_Shr)
    comptime CMP = Self(CXBinaryOperator_Cmp)
    comptime LT = Self(CXBinaryOperator_LT)
    comptime GT = Self(CXBinaryOperator_GT)
    comptime LE = Self(CXBinaryOperator_LE)
    comptime GE = Self(CXBinaryOperator_GE)
    comptime EQ = Self(CXBinaryOperator_EQ)
    comptime NE = Self(CXBinaryOperator_NE)
    comptime AND = Self(CXBinaryOperator_And)
    comptime XOR = Self(CXBinaryOperator_Xor)
    comptime OR = Self(CXBinaryOperator_Or)
    comptime LAND = Self(CXBinaryOperator_LAnd)
    comptime LOR = Self(CXBinaryOperator_LOr)
    comptime ASSIGN = Self(CXBinaryOperator_Assign)
    comptime MUL_ASSIGN = Self(CXBinaryOperator_MulAssign)
    comptime DIV_ASSIGN = Self(CXBinaryOperator_DivAssign)
    comptime REM_ASSIGN = Self(CXBinaryOperator_RemAssign)
    comptime ADD_ASSIGN = Self(CXBinaryOperator_AddAssign)
    comptime SUB_ASSIGN = Self(CXBinaryOperator_SubAssign)
    comptime SHL_ASSIGN = Self(CXBinaryOperator_ShlAssign)
    comptime SHR_ASSIGN = Self(CXBinaryOperator_ShrAssign)
    comptime AND_ASSIGN = Self(CXBinaryOperator_AndAssign)
    comptime XOR_ASSIGN = Self(CXBinaryOperator_XorAssign)
    comptime OR_ASSIGN = Self(CXBinaryOperator_OrAssign)
    comptime COMMA = Self(CXBinaryOperator_Comma)


# ---------------------------------------------------------------------------
# UnaryOperator
# ---------------------------------------------------------------------------


struct UnaryOperator(Equatable, ImplicitlyCopyable, Writable):
    """High-level wrapper around ``CXUnaryOperatorKind``."""

    var _value: c_uint

    @implicit
    def __init__(out self, value: c_uint):
        self._value = value

    def as_c_uint(self) -> c_uint:
        return self._value

    def is_invalid(self) -> Bool:
        return self._value == c_uint(0)

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    def __bool__(self) -> Bool:
        return self._value != c_uint(0)

    comptime INVALID = Self(CXUnaryOperator_Invalid)
    comptime POST_INC = Self(CXUnaryOperator_PostInc)
    comptime POST_DEC = Self(CXUnaryOperator_PostDec)
    comptime PRE_INC = Self(CXUnaryOperator_PreInc)
    comptime PRE_DEC = Self(CXUnaryOperator_PreDec)
    comptime ADDR_OF = Self(CXUnaryOperator_AddrOf)
    comptime DEREF = Self(CXUnaryOperator_Deref)
    comptime PLUS = Self(CXUnaryOperator_Plus)
    comptime MINUS = Self(CXUnaryOperator_Minus)
    comptime NOT = Self(CXUnaryOperator_Not)
    comptime LNOT = Self(CXUnaryOperator_LNot)
    comptime REAL = Self(CXUnaryOperator_Real)
    comptime IMAG = Self(CXUnaryOperator_Imag)
    comptime EXTENSION = Self(CXUnaryOperator_Extension)
    comptime COAWAIT = Self(CXUnaryOperator_Coawait)


# ---------------------------------------------------------------------------
# CompletionChunkKind
# ---------------------------------------------------------------------------


struct CompletionChunkKind(Equatable, ImplicitlyCopyable, Writable):
    """High-level wrapper around ``CXCompletionChunkKind``."""

    var _value: c_uint

    @implicit
    def __init__(out self, value: c_uint):
        self._value = value

    def as_c_uint(self) -> c_uint:
        return self._value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    def __bool__(self) -> Bool:
        return True

    comptime OPTIONAL = Self(CXCompletionChunk_Optional)
    comptime TYPED_TEXT = Self(CXCompletionChunk_TypedText)
    comptime TEXT = Self(CXCompletionChunk_Text)
    comptime PLACEHOLDER = Self(CXCompletionChunk_Placeholder)
    comptime INFORMATIVE = Self(CXCompletionChunk_Informative)
    comptime CURRENT_PARAMETER = Self(CXCompletionChunk_CurrentParameter)
    comptime LEFT_PAREN = Self(CXCompletionChunk_LeftParen)
    comptime RIGHT_PAREN = Self(CXCompletionChunk_RightParen)
    comptime LEFT_BRACKET = Self(CXCompletionChunk_LeftBracket)
    comptime RIGHT_BRACKET = Self(CXCompletionChunk_RightBracket)
    comptime LEFT_BRACE = Self(CXCompletionChunk_LeftBrace)
    comptime RIGHT_BRACE = Self(CXCompletionChunk_RightBrace)
    comptime LEFT_ANGLE = Self(CXCompletionChunk_LeftAngle)
    comptime RIGHT_ANGLE = Self(CXCompletionChunk_RightAngle)
    comptime COMMA = Self(CXCompletionChunk_Comma)
    comptime RESULT_TYPE = Self(CXCompletionChunk_ResultType)
    comptime COLON = Self(CXCompletionChunk_Colon)
    comptime SEMI_COLON = Self(CXCompletionChunk_SemiColon)
    comptime EQUAL = Self(CXCompletionChunk_Equal)
    comptime HORIZONTAL_SPACE = Self(CXCompletionChunk_HorizontalSpace)
    comptime VERTICAL_SPACE = Self(CXCompletionChunk_VerticalSpace)


# ---------------------------------------------------------------------------
# CompilationDatabaseError
# ---------------------------------------------------------------------------


struct CompilationDatabaseErrorCode(Equatable, ImplicitlyCopyable, Writable):
    """High-level wrapper around ``CXCompilationDatabase_Error``."""

    var _value: c_uint

    @implicit
    def __init__(out self, value: c_uint):
        self._value = value

    def as_c_uint(self) -> c_uint:
        return self._value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    comptime NO_ERROR = Self(CXCompilationDatabase_NoError)
    comptime CANNOT_LOAD_DATABASE = Self(
        CXCompilationDatabase_CanNotLoadDatabase
    )


# ---------------------------------------------------------------------------
# PrintingPolicyProperty
# ---------------------------------------------------------------------------


struct PrintingPolicyProperty(Equatable, ImplicitlyCopyable, Writable):
    """High-level wrapper around ``CXPrintingPolicyProperty``."""

    var _value: c_uint

    @implicit
    def __init__(out self, value: c_uint):
        self._value = value

    def as_c_uint(self) -> c_uint:
        return self._value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    comptime INDENTATION = Self(CXPrintingPolicy_Indentation)
    comptime SUPPRESS_SPECIFIERS = Self(CXPrintingPolicy_SuppressSpecifiers)
    comptime SUPPRESS_TAG_KEYWORD = Self(CXPrintingPolicy_SuppressTagKeyword)
    comptime INCLUDE_TAG_DEFINITION = Self(
        CXPrintingPolicy_IncludeTagDefinition
    )
    comptime SUPPRESS_SCOPE = Self(CXPrintingPolicy_SuppressScope)
    comptime SUPPRESS_UNWRITTEN_SCOPE = Self(
        CXPrintingPolicy_SuppressUnwrittenScope
    )
    comptime SUPPRESS_INITIALIZERS = Self(CXPrintingPolicy_SuppressInitializers)
    comptime CONSTANT_ARRAY_SIZE_AS_WRITTEN = Self(
        CXPrintingPolicy_ConstantArraySizeAsWritten
    )
    comptime ANONYMOUS_TAG_LOCATIONS = Self(
        CXPrintingPolicy_AnonymousTagLocations
    )
    comptime SUPPRESS_STRONG_LIFETIME = Self(
        CXPrintingPolicy_SuppressStrongLifetime
    )
    comptime SUPPRESS_LIFETIME_QUALIFIERS = Self(
        CXPrintingPolicy_SuppressLifetimeQualifiers
    )
    comptime SUPPRESS_TEMPLATE_ARGS_IN_CXX_CONSTRUCTORS = Self(
        CXPrintingPolicy_SuppressTemplateArgsInCXXConstructors
    )
    comptime BOOL = Self(CXPrintingPolicy_Bool)
    comptime RESTRICT = Self(CXPrintingPolicy_Restrict)
    comptime ALIGNOF = Self(CXPrintingPolicy_Alignof)
    comptime UNDERSCORE_ALIGNOF = Self(CXPrintingPolicy_UnderscoreAlignof)
    comptime USE_VOID_FOR_ZERO_PARAMS = Self(
        CXPrintingPolicy_UseVoidForZeroParams
    )
    comptime TERSE_OUTPUT = Self(CXPrintingPolicy_TerseOutput)
    comptime POLISH_FOR_DECLARATION = Self(
        CXPrintingPolicy_PolishForDeclaration
    )
    comptime HALF = Self(CXPrintingPolicy_Half)
    comptime MSW_CHAR = Self(CXPrintingPolicy_MSWChar)
    comptime INCLUDE_NEWLINES = Self(CXPrintingPolicy_IncludeNewlines)
    comptime MSVC_FORMATTING = Self(CXPrintingPolicy_MSVCFormatting)
    comptime CONSTANTS_AS_WRITTEN = Self(CXPrintingPolicy_ConstantsAsWritten)
    comptime SUPPRESS_IMPLICIT_BASE = Self(
        CXPrintingPolicy_SuppressImplicitBase
    )
    comptime FULLY_QUALIFIED_NAME = Self(CXPrintingPolicy_FullyQualifiedName)
    comptime LAST_PROPERTY = Self(CXPrintingPolicy_LastProperty)

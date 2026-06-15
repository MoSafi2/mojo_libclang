"""High-level enum wrappers for libclang.

Each enum tag in the raw binding is exposed as a small ``Copyable,
ImplicitlyCopyable, Movable, Equatable`` struct that:

- Wraps a single ``c_uint`` value matching the C ABI.
- Exposes a ``comptime`` constant for every documented case so callers can
  write ``kind == CursorKind.TRANSLATION_UNIT``.
- Converts implicitly from ``c_uint`` (and therefore from the raw ``CX*``
  alias, which is a ``comptime`` alias for ``c_uint``) so existing call
  sites that return raw values keep working without manual wrapping.
- Exposes ``as_c_uint()`` to recover the raw integer for FFI calls.

The wrapper structs are pure value types. They do **not** own libclang
resources and are safe to copy freely.

The raw ``c_uint`` aliases (e.g. ``CXCursorKind``) and the raw
``CX*_Foo`` constant aliases (e.g. ``CXCursor_TranslationUnit``) are
re-exported from this module for backward compatibility with code that
prefers the raw naming.
"""

from src._ffi import (
    # Underlying C types
    c_uint,
    # Raw enum type aliases (comptime = c_uint)
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
    # Raw constants: cursor kinds (group boundaries and common cases)
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
    # Raw constants: type kinds (common cases)
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
    # Raw constants: diagnostic severity
    CXDiagnostic_Ignored,
    CXDiagnostic_Note,
    CXDiagnostic_Warning,
    CXDiagnostic_Error,
    CXDiagnostic_Fatal,
    # Raw constants: traversal results
    CXChildVisit_Break,
    CXChildVisit_Continue,
    CXChildVisit_Recurse,
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


struct CursorKind(Copyable, ImplicitlyCopyable, Movable, Equatable):
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
    comptime FIRST_DECL = Self(c_uint(1))
    comptime LAST_DECL = Self(c_uint(39))
    comptime FIRST_REF = Self(c_uint(40))
    comptime LAST_REF = Self(c_uint(50))
    comptime FIRST_INVALID = Self(c_uint(70))
    comptime LAST_INVALID = Self(c_uint(73))
    comptime FIRST_EXPR = Self(c_uint(100))
    comptime LAST_EXPR = Self(c_uint(155))
    comptime FIRST_STMT = Self(c_uint(200))
    comptime LAST_STMT = Self(c_uint(306))
    comptime FIRST_ATTR = Self(c_uint(400))
    comptime LAST_ATTR = Self(c_uint(441))
    comptime FIRST_PREPROCESSING = Self(c_uint(500))
    comptime LAST_PREPROCESSING = Self(c_uint(503))
    comptime FIRST_EXTRA_DECL = Self(c_uint(600))
    comptime LAST_EXTRA_DECL = Self(c_uint(604))
    comptime OVERLOAD_CANDIDATE = Self(c_uint(700))

    # Declaration kinds
    comptime UNEXPOSED_DECL = Self(c_uint(1))
    comptime STRUCT_DECL = Self(c_uint(2))
    comptime UNION_DECL = Self(c_uint(3))
    comptime CLASS_DECL = Self(c_uint(4))
    comptime ENUM_DECL = Self(c_uint(5))
    comptime FIELD_DECL = Self(c_uint(6))
    comptime ENUM_CONSTANT_DECL = Self(c_uint(7))
    comptime FUNCTION_DECL = Self(c_uint(8))
    comptime VAR_DECL = Self(c_uint(9))
    comptime PARM_DECL = Self(c_uint(10))
    comptime OBJC_INTERFACE_DECL = Self(c_uint(11))
    comptime OBJC_CATEGORY_DECL = Self(c_uint(12))
    comptime OBJC_PROTOCOL_DECL = Self(c_uint(13))
    comptime OBJC_PROPERTY_DECL = Self(c_uint(14))
    comptime OBJC_IVAR_DECL = Self(c_uint(15))
    comptime OBJC_INSTANCE_METHOD_DECL = Self(c_uint(16))
    comptime OBJC_CLASS_METHOD_DECL = Self(c_uint(17))
    comptime OBJC_IMPLEMENTATION_DECL = Self(c_uint(18))
    comptime OBJC_CATEGORY_IMPL_DECL = Self(c_uint(19))
    comptime TYPEDEF_DECL = Self(c_uint(20))
    comptime CXX_METHOD = Self(c_uint(21))
    comptime NAMESPACE = Self(c_uint(22))
    comptime LINKAGE_SPEC = Self(c_uint(23))
    comptime CONSTRUCTOR = Self(c_uint(24))
    comptime DESTRUCTOR = Self(c_uint(25))
    comptime CONVERSION_FUNCTION = Self(c_uint(26))
    comptime TEMPLATE_TYPE_PARAMETER = Self(c_uint(27))
    comptime NON_TYPE_TEMPLATE_PARAMETER = Self(c_uint(28))
    comptime TEMPLATE_TEMPLATE_PARAMETER = Self(c_uint(29))
    comptime FUNCTION_TEMPLATE = Self(c_uint(30))
    comptime CLASS_TEMPLATE = Self(c_uint(31))
    comptime CLASS_TEMPLATE_PARTIAL_SPECIALIZATION = Self(c_uint(32))
    comptime NAMESPACE_ALIAS = Self(c_uint(33))
    comptime USING_DIRECTIVE = Self(c_uint(34))
    comptime USING_DECLARATION = Self(c_uint(35))
    comptime TYPE_ALIAS_DECL = Self(c_uint(36))
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
    comptime TRANSLATION_UNIT = Self(c_uint(350))

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


struct TypeKind(Copyable, ImplicitlyCopyable, Movable, Equatable):
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


struct TokenKind(Copyable, ImplicitlyCopyable, Movable, Equatable):
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


struct LinkageKind(Copyable, ImplicitlyCopyable, Movable, Equatable):
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


struct AvailabilityKind(Copyable, ImplicitlyCopyable, Movable, Equatable):
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


struct AccessSpecifier(Copyable, ImplicitlyCopyable, Movable, Equatable):
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


struct StorageClass(Copyable, ImplicitlyCopyable, Movable, Equatable):
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


struct TLSKind(Copyable, ImplicitlyCopyable, Movable, Equatable):
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


struct LanguageKind(Copyable, ImplicitlyCopyable, Movable, Equatable):
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


struct RefQualifierKind(Copyable, ImplicitlyCopyable, Movable, Equatable):
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


struct TemplateArgumentKind(Copyable, ImplicitlyCopyable, Movable, Equatable):
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


struct CallingConv(Copyable, ImplicitlyCopyable, Movable, Equatable):
    """High-level wrapper around ``CXCallingConv``."""

    var _value: c_uint

    @implicit
    def __init__(out self, value: c_uint):
        self._value = value

    def as_c_uint(self) -> c_uint:
        return self._value

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


struct ChildVisitResult(Copyable, ImplicitlyCopyable, Movable, Equatable):
    """High-level wrapper around ``CXChildVisitResult``."""

    var _value: c_uint

    @implicit
    def __init__(out self, value: c_uint):
        self._value = value

    def as_c_uint(self) -> c_uint:
        return self._value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    comptime BREAK = Self(c_uint(0))
    comptime CONTINUE = Self(c_uint(1))
    comptime RECURSE = Self(c_uint(2))


# ---------------------------------------------------------------------------
# DiagnosticSeverity
# ---------------------------------------------------------------------------


struct DiagnosticSeverity(Copyable, ImplicitlyCopyable, Movable, Equatable):
    """High-level wrapper around ``CXDiagnosticSeverity``."""

    var _value: c_uint

    @implicit
    def __init__(out self, value: c_uint):
        self._value = value

    def as_c_uint(self) -> c_uint:
        return self._value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    comptime IGNORED = Self(c_uint(0))
    comptime NOTE = Self(c_uint(1))
    comptime WARNING = Self(c_uint(2))
    comptime ERROR = Self(c_uint(3))
    comptime FATAL = Self(c_uint(4))

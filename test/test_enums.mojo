"""Smoke test for `src/libclang/enums.mojo`."""
from std.ffi import c_uint
from std.testing import TestSuite
from src.libclang.enums import (
    CursorKind,
    TypeKind,
    TypeNullabilityKind,
    TokenKind,
    LinkageKind,
    AvailabilityKind,
    AccessSpecifier,
    StorageClass,
    TLSKind,
    LanguageKind,
    RefQualifierKind,
    TemplateArgumentKind,
    CallingConv,
    Choice,
    GlobalOptFlags,
    ChildVisitResult,
    VisitorResult,
    DiagnosticSeverity,
    ErrorCode,
    Result,
    SaveError,
    TranslationUnitFlags,
    DiagnosticDisplayOptions,
    TypeLayoutError,
    VisibilityKind,
    ExceptionSpecificationKind,
    CodeCompleteFlags,
)


def _check(cond: Bool, message: String) raises:
    if not cond:
        raise Error(message)


def test_cursor_kind_constants() raises:
    _check(
        CursorKind.TRANSLATION_UNIT.as_c_uint() == c_uint(350),
        "CursorKind.TRANSLATION_UNIT mismatch",
    )
    _check(
        CursorKind.FUNCTION_DECL.as_c_uint() == c_uint(8),
        "CursorKind.FUNCTION_DECL mismatch",
    )
    _check(
        CursorKind.STRUCT_DECL.as_c_uint() == c_uint(2),
        "CursorKind.STRUCT_DECL mismatch",
    )


def test_cursor_kind_groups() raises:
    _check(
        CursorKind.STRUCT_DECL.is_declaration(),
        "STRUCT_DECL should be a declaration",
    )
    _check(
        CursorKind.TYPE_REF.is_reference(),
        "TYPE_REF should be a reference",
    )
    _check(
        CursorKind.INVALID_FILE.is_invalid(),
        "INVALID_FILE should be invalid",
    )
    _check(
        CursorKind.CALL_EXPR.is_expression(),
        "CALL_EXPR should be an expression",
    )
    _check(
        CursorKind.COMPOUND_STMT.is_statement(),
        "COMPOUND_STMT should be a statement",
    )
    _check(
        CursorKind.WARN_UNUSED_ATTR.is_attribute(),
        "WARN_UNUSED_ATTR should be an attribute",
    )
    _check(
        CursorKind.MACRO_DEFINITION.is_preprocessing(),
        "MACRO_DEFINITION should be preprocessing",
    )
    _check(
        CursorKind.MODULE_IMPORT_DECL.is_extra_declaration(),
        "MODULE_IMPORT_DECL should be an extra declaration",
    )


def test_implicit_conversion_from_c_uint() raises:
    var kind: CursorKind = c_uint(350)
    _check(
        kind == CursorKind.TRANSLATION_UNIT,
        "implicit conversion CursorKind comparison failed",
    )


def test_compare_c_uint_with_struct() raises:
    _check(
        CursorKind.TRANSLATION_UNIT == c_uint(350),
        "struct == c_uint failed",
    )
    _check(
        CursorKind.TRANSLATION_UNIT
        == CursorKind.TRANSLATION_UNIT.as_c_uint(),
        "struct == struct.as_c_uint() failed",
    )


def test_type_kind_constants() raises:
    _check(TypeKind.VOID.as_c_uint() == c_uint(2), "TypeKind.VOID")
    _check(TypeKind.POINTER.as_c_uint() == c_uint(101), "TypeKind.POINTER")
    _check(TypeKind.RECORD.as_c_uint() == c_uint(105), "TypeKind.RECORD")
    _check(TypeKind.AUTO.as_c_uint() == c_uint(118), "TypeKind.AUTO")
    _check(TypeKind.BFLOAT16.as_c_uint() == c_uint(39), "TypeKind.BFLOAT16")
    _check(TypeKind.HLSL_RESOURCE.as_c_uint() == c_uint(179), "TypeKind.HLSL_RESOURCE")
    _check(
        TypeKind.PREDEFINED_SUGAR.as_c_uint() == c_uint(182),
        "TypeKind.PREDEFINED_SUGAR",
    )


def test_kind_spellings() raises:
    _check(
        CursorKind.TRANSLATION_UNIT.spelling().byte_length() > 0,
        "CursorKind spelling should be non-empty",
    )
    _check(TypeKind.VOID.spelling() == String("void"), "TypeKind.VOID spelling")


def test_type_nullability_kind_constants() raises:
    _check(
        TypeNullabilityKind.NON_NULL.as_c_uint() == c_uint(0),
        "TypeNullabilityKind.NON_NULL",
    )
    _check(
        TypeNullabilityKind.NULLABLE_RESULT.as_c_uint() == c_uint(4),
        "TypeNullabilityKind.NULLABLE_RESULT",
    )


def test_token_kind_constants() raises:
    _check(TokenKind.KEYWORD.as_c_uint() == c_uint(1), "TokenKind.KEYWORD")
    _check(TokenKind.LITERAL.as_c_uint() == c_uint(3), "TokenKind.LITERAL")
    _check(TokenKind.COMMENT.as_c_uint() == c_uint(4), "TokenKind.COMMENT")


def test_linkage_kind_constants() raises:
    _check(LinkageKind.EXTERNAL.as_c_uint() == c_uint(4), "LinkageKind.EXTERNAL")
    _check(LinkageKind.INTERNAL.as_c_uint() == c_uint(2), "LinkageKind.INTERNAL")


def test_availability_kind_constants() raises:
    _check(
        AvailabilityKind.AVAILABLE.as_c_uint() == c_uint(0),
        "AvailabilityKind.AVAILABLE",
    )
    _check(
        AvailabilityKind.DEPRECATED.as_c_uint() == c_uint(1),
        "AvailabilityKind.DEPRECATED",
    )


def test_access_specifier_constants() raises:
    _check(AccessSpecifier.PUBLIC.as_c_uint() == c_uint(1), "AccessSpecifier.PUBLIC")
    _check(AccessSpecifier.PRIVATE.as_c_uint() == c_uint(3), "AccessSpecifier.PRIVATE")


def test_storage_class_constants() raises:
    _check(StorageClass.STATIC.as_c_uint() == c_uint(3), "StorageClass.STATIC")
    _check(StorageClass.EXTERN.as_c_uint() == c_uint(2), "StorageClass.EXTERN")


def test_tls_kind_constants() raises:
    _check(TLSKind.DYNAMIC.as_c_uint() == c_uint(1), "TLSKind.DYNAMIC")
    _check(TLSKind.STATIC.as_c_uint() == c_uint(2), "TLSKind.STATIC")


def test_language_kind_constants() raises:
    _check(LanguageKind.C.as_c_uint() == c_uint(1), "LanguageKind.C")
    _check(
        LanguageKind.C_PLUS_PLUS.as_c_uint() == c_uint(3),
        "LanguageKind.C_PLUS_PLUS",
    )


def test_ref_qualifier_constants() raises:
    _check(RefQualifierKind.LVALUE.as_c_uint() == c_uint(1), "RefQualifierKind.LVALUE")
    _check(RefQualifierKind.RVALUE.as_c_uint() == c_uint(2), "RefQualifierKind.RVALUE")


def test_template_argument_kind_constants() raises:
    _check(
        TemplateArgumentKind.TYPE.as_c_uint() == c_uint(1),
        "TemplateArgumentKind.TYPE",
    )
    _check(
        TemplateArgumentKind.INTEGRAL.as_c_uint() == c_uint(4),
        "TemplateArgumentKind.INTEGRAL",
    )


def test_calling_conv_constants() raises:
    _check(CallingConv.DEFAULT.as_c_uint() == c_uint(0), "CallingConv.DEFAULT")
    _check(
        CallingConv.X86_64_SYS_V.as_c_uint() == c_uint(11),
        "CallingConv.X86_64_SYS_V",
    )
    _check(CallingConv.SWIFT.as_c_uint() == c_uint(13), "CallingConv.SWIFT")


def test_choice_constants() raises:
    _check(Choice.DEFAULT.as_c_uint() == c_uint(0), "Choice.DEFAULT")
    _check(Choice.ENABLED.as_c_uint() == c_uint(1), "Choice.ENABLED")
    _check(Choice.DISABLED.as_c_uint() == c_uint(2), "Choice.DISABLED")


def test_global_opt_flags() raises:
    var combined = (
        GlobalOptFlags.THREAD_BACKGROUND_PRIORITY_FOR_INDEXING
        | GlobalOptFlags.THREAD_BACKGROUND_PRIORITY_FOR_EDITING
    )
    _check(
        combined.contains(GlobalOptFlags.THREAD_BACKGROUND_PRIORITY_FOR_INDEXING),
        "combined contains indexing flag",
    )
    _check(
        combined.contains(GlobalOptFlags.THREAD_BACKGROUND_PRIORITY_FOR_EDITING),
        "combined contains editing flag",
    )


def test_child_visit_result_constants() raises:
    _check(ChildVisitResult.BREAK.as_c_uint() == c_uint(0), "ChildVisitResult.BREAK")
    _check(
        ChildVisitResult.CONTINUE.as_c_uint() == c_uint(1),
        "ChildVisitResult.CONTINUE",
    )
    _check(ChildVisitResult.RECURSE.as_c_uint() == c_uint(2), "ChildVisitResult.RECURSE")


def test_visitor_result_constants() raises:
    _check(VisitorResult.BREAK.as_c_uint() == c_uint(0), "VisitorResult.BREAK")
    _check(
        VisitorResult.CONTINUE.as_c_uint() == c_uint(1),
        "VisitorResult.CONTINUE",
    )


def test_diagnostic_severity_constants() raises:
    _check(
        DiagnosticSeverity.WARNING.as_c_uint() == c_uint(2),
        "DiagnosticSeverity.WARNING",
    )
    _check(
        DiagnosticSeverity.FATAL.as_c_uint() == c_uint(4),
        "DiagnosticSeverity.FATAL",
    )


def test_error_code_constants() raises:
    _check(ErrorCode.SUCCESS.as_c_uint() == c_uint(0), "ErrorCode.SUCCESS")
    _check(ErrorCode.FAILURE.as_c_uint() == c_uint(1), "ErrorCode.FAILURE")
    _check(ErrorCode.CRASHED.as_c_uint() == c_uint(2), "ErrorCode.CRASHED")
    _check(
        ErrorCode.INVALID_ARGUMENTS.as_c_uint() == c_uint(3),
        "ErrorCode.INVALID_ARGUMENTS",
    )
    _check(
        ErrorCode.AST_READ_ERROR.as_c_uint() == c_uint(4),
        "ErrorCode.AST_READ_ERROR",
    )


def test_result_constants() raises:
    _check(Result.SUCCESS.as_c_uint() == c_uint(0), "Result.SUCCESS")
    _check(Result.INVALID.as_c_uint() == c_uint(1), "Result.INVALID")
    _check(Result.VISIT_BREAK.as_c_uint() == c_uint(2), "Result.VISIT_BREAK")


def test_save_error_constants() raises:
    _check(SaveError.NONE.as_c_uint() == c_uint(0), "SaveError.NONE")
    _check(SaveError.UNKNOWN.as_c_uint() == c_uint(1), "SaveError.UNKNOWN")
    _check(
        SaveError.TRANSLATION_ERRORS.as_c_uint() == c_uint(2),
        "SaveError.TRANSLATION_ERRORS",
    )
    _check(
        SaveError.INVALID_TU.as_c_uint() == c_uint(3),
        "SaveError.INVALID_TU",
    )


def test_translation_unit_flags() raises:
    _check(
        TranslationUnitFlags.NONE.as_c_uint() == c_uint(0),
        "TranslationUnitFlags.NONE",
    )
    _check(
        TranslationUnitFlags.DETAILED_PREPROCESSING_RECORD.as_c_uint()
        == c_uint(1),
        "TranslationUnitFlags.DETAILED_PREPROCESSING_RECORD",
    )
    _check(
        TranslationUnitFlags.KEEP_GOING.as_c_uint() == c_uint(512),
        "TranslationUnitFlags.KEEP_GOING",
    )
    var combined = (
        TranslationUnitFlags.DETAILED_PREPROCESSING_RECORD
        | TranslationUnitFlags.KEEP_GOING
    )
    _check(
        combined.contains(TranslationUnitFlags.DETAILED_PREPROCESSING_RECORD),
        "combined contains DETAILED_PREPROCESSING_RECORD",
    )
    _check(
        combined.contains(TranslationUnitFlags.KEEP_GOING),
        "combined contains KEEP_GOING",
    )


def test_diagnostic_display_options() raises:
    _check(
        DiagnosticDisplayOptions.SOURCE_LOCATION.as_c_uint() == c_uint(1),
        "DiagnosticDisplayOptions.SOURCE_LOCATION",
    )
    _check(
        DiagnosticDisplayOptions.OPTION.as_c_uint() == c_uint(8),
        "DiagnosticDisplayOptions.OPTION",
    )
    var opts = (
        DiagnosticDisplayOptions.SOURCE_LOCATION
        | DiagnosticDisplayOptions.OPTION
    )
    _check(
        opts.contains(DiagnosticDisplayOptions.SOURCE_LOCATION),
        "opts contains SOURCE_LOCATION",
    )
    _check(
        opts.contains(DiagnosticDisplayOptions.OPTION),
        "opts contains OPTION",
    )


def test_type_layout_error_constants() raises:
    _check(TypeLayoutError.INVALID.as_int() == -1, "TypeLayoutError.INVALID")
    _check(
        TypeLayoutError.INCOMPLETE.as_int() == -2,
        "TypeLayoutError.INCOMPLETE",
    )
    _check(
        TypeLayoutError.NOT_CONSTANT_SIZE.as_int() == -4,
        "TypeLayoutError.NOT_CONSTANT_SIZE",
    )


def test_visibility_kind_constants() raises:
    _check(
        VisibilityKind.DEFAULT.as_c_uint() == c_uint(3),
        "VisibilityKind.DEFAULT",
    )
    _check(
        VisibilityKind.HIDDEN.as_c_uint() == c_uint(1),
        "VisibilityKind.HIDDEN",
    )


def test_exception_specification_kind_constants() raises:
    _check(
        ExceptionSpecificationKind.NONE.as_c_uint() == c_uint(0),
        "ExceptionSpecificationKind.NONE",
    )
    _check(
        ExceptionSpecificationKind.BASIC_NOEXCEPT.as_c_uint() == c_uint(4),
        "ExceptionSpecificationKind.BASIC_NOEXCEPT",
    )
    _check(
        ExceptionSpecificationKind.NO_THROW.as_c_uint() == c_uint(9),
        "ExceptionSpecificationKind.NO_THROW",
    )


def test_code_complete_flags() raises:
    _check(
        CodeCompleteFlags.INCLUDE_MACROS.as_c_uint() == c_uint(1),
        "CodeCompleteFlags.INCLUDE_MACROS",
    )
    _check(
        CodeCompleteFlags.INCLUDE_CODE_PATTERNS.as_c_uint() == c_uint(2),
        "CodeCompleteFlags.INCLUDE_CODE_PATTERNS",
    )
    var combined = (
        CodeCompleteFlags.INCLUDE_MACROS
        | CodeCompleteFlags.INCLUDE_CODE_PATTERNS
    )
    _check(
        combined.contains(CodeCompleteFlags.INCLUDE_MACROS),
        "combined contains INCLUDE_MACROS",
    )
    _check(
        combined.contains(CodeCompleteFlags.INCLUDE_CODE_PATTERNS),
        "combined contains INCLUDE_CODE_PATTERNS",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

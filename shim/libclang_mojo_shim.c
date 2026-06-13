#include <clang-c/Index.h>
#include <clang-c/Rewrite.h>

/* Typedef aliases for untagged enums so we can use them as bare type names. */
typedef enum CXCursorKind CXCursorKind;
typedef enum CXAvailabilityKind CXAvailabilityKind;
typedef enum CXTypeKind CXTypeKind;

#if defined(_WIN32)
#define MOJO_SHIM_EXPORT __declspec(dllexport)
#else
#define MOJO_SHIM_EXPORT __attribute__((visibility("default")))
#endif

MOJO_SHIM_EXPORT void mojo_clang_getNullLocation(CXSourceLocation *out) {
    *out = clang_getNullLocation();
}

MOJO_SHIM_EXPORT unsigned mojo_clang_equalLocations(
    CXSourceLocation *loc1,
    CXSourceLocation *loc2
) {
    return clang_equalLocations(*loc1, *loc2);
}

MOJO_SHIM_EXPORT int mojo_clang_Location_isInSystemHeader(CXSourceLocation *location) {
    return clang_Location_isInSystemHeader(*location);
}

MOJO_SHIM_EXPORT int mojo_clang_Location_isFromMainFile(CXSourceLocation *location) {
    return clang_Location_isFromMainFile(*location);
}

MOJO_SHIM_EXPORT void mojo_clang_getNullRange(CXSourceRange *out) {
    *out = clang_getNullRange();
}

MOJO_SHIM_EXPORT void mojo_clang_getRange(
    CXSourceRange *out,
    CXSourceLocation *begin,
    CXSourceLocation *end
) {
    *out = clang_getRange(*begin, *end);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_equalRanges(
    CXSourceRange *range1,
    CXSourceRange *range2
) {
    return clang_equalRanges(*range1, *range2);
}

MOJO_SHIM_EXPORT int mojo_clang_Range_isNull(CXSourceRange *range) {
    return clang_Range_isNull(*range);
}

MOJO_SHIM_EXPORT CXCursorKind mojo_clang_getCursorKind_ref(CXCursor *cursor) {
    return clang_getCursorKind(*cursor);
}

MOJO_SHIM_EXPORT CXString mojo_clang_getCursorSpelling_ref(CXCursor *cursor) {
    return clang_getCursorSpelling(*cursor);
}

MOJO_SHIM_EXPORT int mojo_clang_Cursor_isNull_ref(CXCursor *cursor) {
    return clang_Cursor_isNull(*cursor);
}

MOJO_SHIM_EXPORT CXString mojo_clang_getTokenSpelling_ref(
    CXTranslationUnit tu,
    CXToken *token
) {
    return clang_getTokenSpelling(tu, *token);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_getTokenKind_ref(CXToken *token) {
    return clang_getTokenKind(*token);
}

MOJO_SHIM_EXPORT void mojo_clang_getExpansionLocation(
    CXSourceLocation *location,
    CXFile *file,
    unsigned *line,
    unsigned *column,
    unsigned *offset
) {
    clang_getExpansionLocation(*location, file, line, column, offset);
}

MOJO_SHIM_EXPORT void mojo_clang_getPresumedLocation(
    CXSourceLocation *location,
    CXString *filename,
    unsigned *line,
    unsigned *column
) {
    clang_getPresumedLocation(*location, filename, line, column);
}

MOJO_SHIM_EXPORT void mojo_clang_getInstantiationLocation(
    CXSourceLocation *location,
    CXFile *file,
    unsigned *line,
    unsigned *column,
    unsigned *offset
) {
    clang_getInstantiationLocation(*location, file, line, column, offset);
}

MOJO_SHIM_EXPORT void mojo_clang_getSpellingLocation(
    CXSourceLocation *location,
    CXFile *file,
    unsigned *line,
    unsigned *column,
    unsigned *offset
) {
    clang_getSpellingLocation(*location, file, line, column, offset);
}

MOJO_SHIM_EXPORT void mojo_clang_getFileLocation(
    CXSourceLocation *location,
    CXFile *file,
    unsigned *line,
    unsigned *column,
    unsigned *offset
) {
    clang_getFileLocation(*location, file, line, column, offset);
}

MOJO_SHIM_EXPORT void mojo_clang_getRangeStart(
    CXSourceLocation *out,
    CXSourceRange *range
) {
    *out = clang_getRangeStart(*range);
}

MOJO_SHIM_EXPORT void mojo_clang_getRangeEnd(
    CXSourceLocation *out,
    CXSourceRange *range
) {
    *out = clang_getRangeEnd(*range);
}

MOJO_SHIM_EXPORT void mojo_clang_getDiagnosticLocation(
    CXSourceLocation *out,
    CXDiagnostic diagnostic
) {
    *out = clang_getDiagnosticLocation(diagnostic);
}

MOJO_SHIM_EXPORT void mojo_clang_getDiagnosticRange(
    CXSourceRange *out,
    CXDiagnostic diagnostic,
    unsigned index
) {
    *out = clang_getDiagnosticRange(diagnostic, index);
}

MOJO_SHIM_EXPORT void mojo_clang_getDiagnosticFixIt_into(
    CXSourceRange *out,
    CXDiagnostic diagnostic,
    unsigned index
) {
    /* Discard the returned CXString; only the range is required. */
    CXString ignored = clang_getDiagnosticFixIt(diagnostic, index, out);
    clang_disposeString(ignored);
}

MOJO_SHIM_EXPORT CXString mojo_clang_getDiagnosticFixIt_text(
    CXDiagnostic diagnostic,
    unsigned index
) {
    /* Caller still needs to fetch the range with mojo_clang_getDiagnosticFixIt_into. */
    return clang_getDiagnosticFixIt(diagnostic, index, NULL);
}

MOJO_SHIM_EXPORT void mojo_clang_getLocation(
    CXSourceLocation *out,
    CXTranslationUnit tu,
    CXFile file,
    unsigned line,
    unsigned column
) {
    *out = clang_getLocation(tu, file, line, column);
}

MOJO_SHIM_EXPORT void mojo_clang_getLocationForOffset(
    CXSourceLocation *out,
    CXTranslationUnit tu,
    CXFile file,
    unsigned offset
) {
    *out = clang_getLocationForOffset(tu, file, offset);
}

MOJO_SHIM_EXPORT void mojo_clang_getNullCursor(CXCursor *out) {
    *out = clang_getNullCursor();
}

MOJO_SHIM_EXPORT void mojo_clang_getTranslationUnitCursor(
    CXCursor *out,
    CXTranslationUnit tu
) {
    *out = clang_getTranslationUnitCursor(tu);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_equalCursors(CXCursor *left, CXCursor *right) {
    return clang_equalCursors(*left, *right);
}

MOJO_SHIM_EXPORT int mojo_clang_Cursor_isNull(CXCursor *cursor) {
    return clang_Cursor_isNull(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_hashCursor(CXCursor *cursor) {
    return clang_hashCursor(*cursor);
}

MOJO_SHIM_EXPORT CXCursorKind mojo_clang_getCursorKind(CXCursor *cursor) {
    return clang_getCursorKind(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_getCursorLinkage(CXCursor *cursor) {
    return clang_getCursorLinkage(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_getCursorVisibility(CXCursor *cursor) {
    return clang_getCursorVisibility(*cursor);
}

MOJO_SHIM_EXPORT CXAvailabilityKind mojo_clang_getCursorAvailability(CXCursor *cursor) {
    return clang_getCursorAvailability(*cursor);
}

MOJO_SHIM_EXPORT void mojo_clang_Cursor_getVarDeclInitializer(
    CXCursor *out,
    CXCursor *cursor
) {
    *out = clang_Cursor_getVarDeclInitializer(*cursor);
}

MOJO_SHIM_EXPORT int mojo_clang_Cursor_hasVarDeclGlobalStorage(CXCursor *cursor) {
    return clang_Cursor_hasVarDeclGlobalStorage(*cursor);
}

MOJO_SHIM_EXPORT int mojo_clang_Cursor_hasVarDeclExternalStorage(CXCursor *cursor) {
    return clang_Cursor_hasVarDeclExternalStorage(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_getCursorLanguage(CXCursor *cursor) {
    return clang_getCursorLanguage(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_getCursorTLSKind(CXCursor *cursor) {
    return clang_getCursorTLSKind(*cursor);
}

MOJO_SHIM_EXPORT CXTranslationUnit mojo_clang_Cursor_getTranslationUnit(CXCursor *cursor) {
    return clang_Cursor_getTranslationUnit(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_CXCursorSet_contains(void *cset, CXCursor *cursor) {
    return clang_CXCursorSet_contains(cset, *cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_CXCursorSet_insert(void *cset, CXCursor *cursor) {
    return clang_CXCursorSet_insert(cset, *cursor);
}

MOJO_SHIM_EXPORT void mojo_clang_getCursorSemanticParent(
    CXCursor *out,
    CXCursor *cursor
) {
    *out = clang_getCursorSemanticParent(*cursor);
}

MOJO_SHIM_EXPORT void mojo_clang_getCursorLexicalParent(
    CXCursor *out,
    CXCursor *cursor
) {
    *out = clang_getCursorLexicalParent(*cursor);
}

MOJO_SHIM_EXPORT void mojo_clang_getOverriddenCursors(
    CXCursor *cursor,
    CXCursor **overridden,
    unsigned *num_overridden
) {
    clang_getOverriddenCursors(*cursor, overridden, num_overridden);
}

MOJO_SHIM_EXPORT CXFile mojo_clang_getIncludedFile(CXCursor *cursor) {
    return clang_getIncludedFile(*cursor);
}

MOJO_SHIM_EXPORT void mojo_clang_getCursor(
    CXCursor *out,
    CXTranslationUnit tu,
    CXSourceLocation *location
) {
    *out = clang_getCursor(tu, *location);
}

MOJO_SHIM_EXPORT void mojo_clang_getCursorLocation(
    CXSourceLocation *out,
    CXCursor *cursor
) {
    *out = clang_getCursorLocation(*cursor);
}

MOJO_SHIM_EXPORT void mojo_clang_getCursorExtent(
    CXSourceRange *out,
    CXCursor *cursor
) {
    *out = clang_getCursorExtent(*cursor);
}

MOJO_SHIM_EXPORT void mojo_clang_getCursorType(CXType *out, CXCursor *cursor) {
    *out = clang_getCursorType(*cursor);
}

MOJO_SHIM_EXPORT CXString mojo_clang_getTypeSpelling(CXType *type) {
    return clang_getTypeSpelling(*type);
}

MOJO_SHIM_EXPORT void mojo_clang_getTypedefDeclUnderlyingType(
    CXType *out,
    CXCursor *cursor
) {
    *out = clang_getTypedefDeclUnderlyingType(*cursor);
}

MOJO_SHIM_EXPORT void mojo_clang_getEnumDeclIntegerType(
    CXType *out,
    CXCursor *cursor
) {
    *out = clang_getEnumDeclIntegerType(*cursor);
}

MOJO_SHIM_EXPORT CXString mojo_clang_getCursorUSR(CXCursor *cursor) {
    return clang_getCursorUSR(*cursor);
}

MOJO_SHIM_EXPORT CXString mojo_clang_getCursorSpelling(CXCursor *cursor) {
    return clang_getCursorSpelling(*cursor);
}

MOJO_SHIM_EXPORT void mojo_clang_getCursorReferenced(
    CXCursor *out,
    CXCursor *cursor
) {
    *out = clang_getCursorReferenced(*cursor);
}

MOJO_SHIM_EXPORT void mojo_clang_getCursorDefinition(
    CXCursor *out,
    CXCursor *cursor
) {
    *out = clang_getCursorDefinition(*cursor);
}

MOJO_SHIM_EXPORT void mojo_clang_getCanonicalCursor(
    CXCursor *out,
    CXCursor *cursor
) {
    *out = clang_getCanonicalCursor(*cursor);
}

MOJO_SHIM_EXPORT CXToken *mojo_clang_getToken(
    CXTranslationUnit tu,
    CXSourceLocation *location
) {
    return clang_getToken(tu, *location);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_getTokenKind(CXToken *token) {
    return clang_getTokenKind(*token);
}

MOJO_SHIM_EXPORT CXString mojo_clang_getTokenSpelling(
    CXTranslationUnit tu,
    CXToken *token
) {
    return clang_getTokenSpelling(tu, *token);
}

MOJO_SHIM_EXPORT void mojo_clang_getTokenLocation(
    CXSourceLocation *out,
    CXTranslationUnit tu,
    CXToken *token
) {
    *out = clang_getTokenLocation(tu, *token);
}

MOJO_SHIM_EXPORT void mojo_clang_getTokenExtent(
    CXSourceRange *out,
    CXTranslationUnit tu,
    CXToken *token
) {
    *out = clang_getTokenExtent(tu, *token);
}

MOJO_SHIM_EXPORT void mojo_clang_tokenize(
    CXTranslationUnit tu,
    CXSourceRange *range,
    CXToken **tokens,
    unsigned *num_tokens
) {
    clang_tokenize(tu, *range, tokens, num_tokens);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_equalTypes(CXType *left, CXType *right) {
    return clang_equalTypes(*left, *right);
}

MOJO_SHIM_EXPORT void mojo_clang_annotateTokens(
    CXTranslationUnit tu,
    CXToken *tokens,
    unsigned num_tokens,
    CXCursor *cursors
) {
    clang_annotateTokens(tu, tokens, num_tokens, cursors);
}

/* ===== CXType query functions (scalar returns) ===== */

MOJO_SHIM_EXPORT unsigned mojo_clang_isConstQualifiedType(CXType *type) {
    return clang_isConstQualifiedType(*type);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_isVolatileQualifiedType(CXType *type) {
    return clang_isVolatileQualifiedType(*type);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_isRestrictQualifiedType(CXType *type) {
    return clang_isRestrictQualifiedType(*type);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_getAddressSpace(CXType *type) {
    return clang_getAddressSpace(*type);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_isFunctionTypeVariadic(CXType *type) {
    return clang_isFunctionTypeVariadic(*type);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_isPODType(CXType *type) {
    return clang_isPODType(*type);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_Type_isTransparentTagTypedef(CXType *type) {
    return clang_Type_isTransparentTagTypedef(*type);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_getFunctionTypeCallingConv(CXType *type) {
    return clang_getFunctionTypeCallingConv(*type);
}

MOJO_SHIM_EXPORT int mojo_clang_getExceptionSpecificationType(CXType *type) {
    return clang_getExceptionSpecificationType(*type);
}

MOJO_SHIM_EXPORT int mojo_clang_getNumArgTypes(CXType *type) {
    return clang_getNumArgTypes(*type);
}

MOJO_SHIM_EXPORT int mojo_clang_Type_getNumTemplateArguments(CXType *type) {
    return clang_Type_getNumTemplateArguments(*type);
}

MOJO_SHIM_EXPORT long long mojo_clang_Type_getAlignOf(CXType *type) {
    return clang_Type_getAlignOf(*type);
}

MOJO_SHIM_EXPORT long long mojo_clang_Type_getSizeOf(CXType *type) {
    return clang_Type_getSizeOf(*type);
}

MOJO_SHIM_EXPORT long long mojo_clang_Type_getOffsetOf(CXType *type, const char *fieldname) {
    return clang_Type_getOffsetOf(*type, fieldname);
}

MOJO_SHIM_EXPORT long long mojo_clang_getArraySize(CXType *type) {
    return clang_getArraySize(*type);
}

MOJO_SHIM_EXPORT long long mojo_clang_getNumElements(CXType *type) {
    return clang_getNumElements(*type);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_Type_getNumObjCProtocolRefs(CXType *type) {
    return clang_Type_getNumObjCProtocolRefs(*type);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_Type_getNumObjCTypeArgs(CXType *type) {
    return clang_Type_getNumObjCTypeArgs(*type);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_Type_getNullability(CXType *type) {
    return clang_Type_getNullability(*type);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_Type_getCXXRefQualifier(CXType *type) {
    return clang_Type_getCXXRefQualifier(*type);
}

/* ===== CXType string/opaque returns ===== */

MOJO_SHIM_EXPORT CXString mojo_clang_getTypedefName(CXType *type) {
    return clang_getTypedefName(*type);
}

MOJO_SHIM_EXPORT CXString mojo_clang_Type_getObjCEncoding(CXType *type) {
    return clang_Type_getObjCEncoding(*type);
}

/* ===== CXType -> CXType (struct returns via out-param) ===== */

MOJO_SHIM_EXPORT void mojo_clang_getCanonicalType(CXType *out, CXType *type) {
    *out = clang_getCanonicalType(*type);
}

MOJO_SHIM_EXPORT void mojo_clang_getPointeeType(CXType *out, CXType *type) {
    *out = clang_getPointeeType(*type);
}

MOJO_SHIM_EXPORT void mojo_clang_getUnqualifiedType(CXType *out, CXType *type) {
    *out = clang_getUnqualifiedType(*type);
}

MOJO_SHIM_EXPORT void mojo_clang_getNonReferenceType(CXType *out, CXType *type) {
    *out = clang_getNonReferenceType(*type);
}

MOJO_SHIM_EXPORT void mojo_clang_getResultType(CXType *out, CXType *type) {
    *out = clang_getResultType(*type);
}

MOJO_SHIM_EXPORT void mojo_clang_getElementType(CXType *out, CXType *type) {
    *out = clang_getElementType(*type);
}

MOJO_SHIM_EXPORT void mojo_clang_getArrayElementType(CXType *out, CXType *type) {
    *out = clang_getArrayElementType(*type);
}

MOJO_SHIM_EXPORT void mojo_clang_Type_getNamedType(CXType *out, CXType *type) {
    *out = clang_Type_getNamedType(*type);
}

MOJO_SHIM_EXPORT void mojo_clang_Type_getClassType(CXType *out, CXType *type) {
    *out = clang_Type_getClassType(*type);
}

MOJO_SHIM_EXPORT void mojo_clang_Type_getModifiedType(CXType *out, CXType *type) {
    *out = clang_Type_getModifiedType(*type);
}

MOJO_SHIM_EXPORT void mojo_clang_Type_getValueType(CXType *out, CXType *type) {
    *out = clang_Type_getValueType(*type);
}

MOJO_SHIM_EXPORT void mojo_clang_Type_getObjCObjectBaseType(CXType *out, CXType *type) {
    *out = clang_Type_getObjCObjectBaseType(*type);
}

MOJO_SHIM_EXPORT void mojo_clang_getArgType(CXType *out, CXType *type, unsigned i) {
    *out = clang_getArgType(*type, i);
}

MOJO_SHIM_EXPORT void mojo_clang_Type_getObjCTypeArg(CXType *out, CXType *type, unsigned i) {
    *out = clang_Type_getObjCTypeArg(*type, i);
}

MOJO_SHIM_EXPORT void mojo_clang_Type_getTemplateArgumentAsType(CXType *out, CXType *type, unsigned i) {
    *out = clang_Type_getTemplateArgumentAsType(*type, i);
}

/* ===== CXType -> CXCursor (struct returns) ===== */

MOJO_SHIM_EXPORT void mojo_clang_getTypeDeclaration(CXCursor *out, CXType *type) {
    *out = clang_getTypeDeclaration(*type);
}

MOJO_SHIM_EXPORT void mojo_clang_Type_getObjCProtocolDecl(CXCursor *out, CXType *type, unsigned i) {
    *out = clang_Type_getObjCProtocolDecl(*type, i);
}

/* ===== CXCursor query functions (scalar returns) ===== */

MOJO_SHIM_EXPORT unsigned mojo_clang_Cursor_hasAttrs(CXCursor *cursor) {
    return clang_Cursor_hasAttrs(*cursor);
}

MOJO_SHIM_EXPORT long long mojo_clang_getEnumConstantDeclValue(CXCursor *cursor) {
    return clang_getEnumConstantDeclValue(*cursor);
}

MOJO_SHIM_EXPORT unsigned long long mojo_clang_getEnumConstantDeclUnsignedValue(CXCursor *cursor) {
    return clang_getEnumConstantDeclUnsignedValue(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_Cursor_isBitField(CXCursor *cursor) {
    return clang_Cursor_isBitField(*cursor);
}

MOJO_SHIM_EXPORT int mojo_clang_getFieldDeclBitWidth(CXCursor *cursor) {
    return clang_getFieldDeclBitWidth(*cursor);
}

MOJO_SHIM_EXPORT int mojo_clang_Cursor_getNumArguments(CXCursor *cursor) {
    return clang_Cursor_getNumArguments(*cursor);
}

MOJO_SHIM_EXPORT int mojo_clang_Cursor_getNumTemplateArguments(CXCursor *cursor) {
    return clang_Cursor_getNumTemplateArguments(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_Cursor_isMacroFunctionLike(CXCursor *cursor) {
    return clang_Cursor_isMacroFunctionLike(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_Cursor_isMacroBuiltin(CXCursor *cursor) {
    return clang_Cursor_isMacroBuiltin(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_Cursor_isFunctionInlined(CXCursor *cursor) {
    return clang_Cursor_isFunctionInlined(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_Cursor_isAnonymous(CXCursor *cursor) {
    return clang_Cursor_isAnonymous(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_Cursor_isAnonymousRecordDecl(CXCursor *cursor) {
    return clang_Cursor_isAnonymousRecordDecl(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_Cursor_isInlineNamespace(CXCursor *cursor) {
    return clang_Cursor_isInlineNamespace(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_isVirtualBase(CXCursor *cursor) {
    return clang_isVirtualBase(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_getCXXAccessSpecifier(CXCursor *cursor) {
    return clang_getCXXAccessSpecifier(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_Cursor_getStorageClass(CXCursor *cursor) {
    return clang_Cursor_getStorageClass(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_getNumOverloadedDecls(CXCursor *cursor) {
    return clang_getNumOverloadedDecls(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_isCursorDefinition(CXCursor *cursor) {
    return clang_isCursorDefinition(*cursor);
}

MOJO_SHIM_EXPORT int mojo_clang_Cursor_getObjCSelectorIndex(CXCursor *cursor) {
    return clang_Cursor_getObjCSelectorIndex(*cursor);
}

MOJO_SHIM_EXPORT int mojo_clang_Cursor_isDynamicCall(CXCursor *cursor) {
    return clang_Cursor_isDynamicCall(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_Cursor_getObjCPropertyAttributes(CXCursor *cursor, unsigned reserved) {
    return clang_Cursor_getObjCPropertyAttributes(*cursor, reserved);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_Cursor_getObjCDeclQualifiers(CXCursor *cursor) {
    return clang_Cursor_getObjCDeclQualifiers(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_Cursor_isObjCOptional(CXCursor *cursor) {
    return clang_Cursor_isObjCOptional(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_Cursor_isVariadic(CXCursor *cursor) {
    return clang_Cursor_isVariadic(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_getTemplateCursorKind(CXCursor *cursor) {
    return clang_getTemplateCursorKind(*cursor);
}

MOJO_SHIM_EXPORT long long mojo_clang_Cursor_getOffsetOfField(CXCursor *cursor) {
    return clang_Cursor_getOffsetOfField(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_getCursorBinaryOperatorKind(CXCursor *cursor) {
    return clang_getCursorBinaryOperatorKind(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_getCursorUnaryOperatorKind(CXCursor *cursor) {
    return clang_getCursorUnaryOperatorKind(*cursor);
}

MOJO_SHIM_EXPORT int mojo_clang_getCursorExceptionSpecificationType(CXCursor *cursor) {
    return clang_getCursorExceptionSpecificationType(*cursor);
}

/* ===== CXX special member function queries ===== */

MOJO_SHIM_EXPORT unsigned mojo_clang_CXXConstructor_isConvertingConstructor(CXCursor *cursor) {
    return clang_CXXConstructor_isConvertingConstructor(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_CXXConstructor_isCopyConstructor(CXCursor *cursor) {
    return clang_CXXConstructor_isCopyConstructor(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_CXXConstructor_isDefaultConstructor(CXCursor *cursor) {
    return clang_CXXConstructor_isDefaultConstructor(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_CXXConstructor_isMoveConstructor(CXCursor *cursor) {
    return clang_CXXConstructor_isMoveConstructor(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_CXXField_isMutable(CXCursor *cursor) {
    return clang_CXXField_isMutable(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_CXXMethod_isDefaulted(CXCursor *cursor) {
    return clang_CXXMethod_isDefaulted(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_CXXMethod_isDeleted(CXCursor *cursor) {
    return clang_CXXMethod_isDeleted(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_CXXMethod_isPureVirtual(CXCursor *cursor) {
    return clang_CXXMethod_isPureVirtual(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_CXXMethod_isStatic(CXCursor *cursor) {
    return clang_CXXMethod_isStatic(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_CXXMethod_isVirtual(CXCursor *cursor) {
    return clang_CXXMethod_isVirtual(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_CXXMethod_isCopyAssignmentOperator(CXCursor *cursor) {
    return clang_CXXMethod_isCopyAssignmentOperator(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_CXXMethod_isMoveAssignmentOperator(CXCursor *cursor) {
    return clang_CXXMethod_isMoveAssignmentOperator(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_CXXMethod_isExplicit(CXCursor *cursor) {
    return clang_CXXMethod_isExplicit(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_CXXRecord_isAbstract(CXCursor *cursor) {
    return clang_CXXRecord_isAbstract(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_EnumDecl_isScoped(CXCursor *cursor) {
    return clang_EnumDecl_isScoped(*cursor);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_CXXMethod_isConst(CXCursor *cursor) {
    return clang_CXXMethod_isConst(*cursor);
}

/* ===== CXCursor -> CXString / opaque returns ===== */

MOJO_SHIM_EXPORT CXString mojo_clang_getCursorDisplayName(CXCursor *cursor) {
    return clang_getCursorDisplayName(*cursor);
}

MOJO_SHIM_EXPORT CXString mojo_clang_Cursor_getObjCPropertyGetterName(CXCursor *cursor) {
    return clang_Cursor_getObjCPropertyGetterName(*cursor);
}

MOJO_SHIM_EXPORT CXString mojo_clang_Cursor_getObjCPropertySetterName(CXCursor *cursor) {
    return clang_Cursor_getObjCPropertySetterName(*cursor);
}

MOJO_SHIM_EXPORT CXString mojo_clang_Cursor_getRawCommentText(CXCursor *cursor) {
    return clang_Cursor_getRawCommentText(*cursor);
}

MOJO_SHIM_EXPORT CXString mojo_clang_Cursor_getBriefCommentText(CXCursor *cursor) {
    return clang_Cursor_getBriefCommentText(*cursor);
}

MOJO_SHIM_EXPORT CXString mojo_clang_Cursor_getMangling(CXCursor *cursor) {
    return clang_Cursor_getMangling(*cursor);
}

MOJO_SHIM_EXPORT CXString mojo_clang_getDeclObjCTypeEncoding(CXCursor *cursor) {
    return clang_getDeclObjCTypeEncoding(*cursor);
}

MOJO_SHIM_EXPORT CXString mojo_clang_getCursorPrettyPrinted(CXCursor *cursor, CXPrintingPolicy policy) {
    return clang_getCursorPrettyPrinted(*cursor, policy);
}

MOJO_SHIM_EXPORT CXPrintingPolicy mojo_clang_getCursorPrintingPolicy(CXCursor *cursor) {
    return clang_getCursorPrintingPolicy(*cursor);
}

MOJO_SHIM_EXPORT CXCompletionString mojo_clang_getCursorCompletionString(CXCursor *cursor) {
    return clang_getCursorCompletionString(*cursor);
}

/* ===== CXCursor -> CXSourceRange (struct returns via out-param) ===== */

MOJO_SHIM_EXPORT void mojo_clang_Cursor_getSpellingNameRange(CXSourceRange *out, CXCursor *cursor, unsigned pieceIndex, unsigned options) {
    *out = clang_Cursor_getSpellingNameRange(*cursor, pieceIndex, options);
}

MOJO_SHIM_EXPORT void mojo_clang_Cursor_getCommentRange(CXSourceRange *out, CXCursor *cursor) {
    *out = clang_Cursor_getCommentRange(*cursor);
}

MOJO_SHIM_EXPORT void mojo_clang_getCursorReferenceNameRange(CXSourceRange *out, CXCursor *cursor, unsigned nameFlags, unsigned pieceIndex) {
    *out = clang_getCursorReferenceNameRange(*cursor, nameFlags, pieceIndex);
}

/* ===== CXCursor -> CXType (struct returns via out-param) ===== */

MOJO_SHIM_EXPORT void mojo_clang_getCursorResultType(CXType *out, CXCursor *cursor) {
    *out = clang_getCursorResultType(*cursor);
}

MOJO_SHIM_EXPORT void mojo_clang_Cursor_getReceiverType(CXType *out, CXCursor *cursor) {
    *out = clang_Cursor_getReceiverType(*cursor);
}

MOJO_SHIM_EXPORT void mojo_clang_getIBOutletCollectionType(CXType *out, CXCursor *cursor) {
    *out = clang_getIBOutletCollectionType(*cursor);
}

MOJO_SHIM_EXPORT void mojo_clang_Cursor_getTemplateArgumentType(CXType *out, CXCursor *cursor, unsigned i) {
    *out = clang_Cursor_getTemplateArgumentType(*cursor, i);
}

/* ===== CXCursor -> CXCursor (struct returns via out-param) ===== */

MOJO_SHIM_EXPORT void mojo_clang_Cursor_getArgument(CXCursor *out, CXCursor *cursor, unsigned i) {
    *out = clang_Cursor_getArgument(*cursor, i);
}

MOJO_SHIM_EXPORT void mojo_clang_getOverloadedDecl(CXCursor *out, CXCursor *cursor, unsigned index) {
    *out = clang_getOverloadedDecl(*cursor, index);
}

MOJO_SHIM_EXPORT void mojo_clang_getSpecializedCursorTemplate(CXCursor *out, CXCursor *cursor) {
    *out = clang_getSpecializedCursorTemplate(*cursor);
}

/* ===== CXCursor template arg value queries ===== */

MOJO_SHIM_EXPORT unsigned mojo_clang_Cursor_getTemplateArgumentKind(CXCursor *cursor, unsigned i) {
    return clang_Cursor_getTemplateArgumentKind(*cursor, i);
}

MOJO_SHIM_EXPORT long long mojo_clang_Cursor_getTemplateArgumentValue(CXCursor *cursor, unsigned i) {
    return clang_Cursor_getTemplateArgumentValue(*cursor, i);
}

MOJO_SHIM_EXPORT unsigned long long mojo_clang_Cursor_getTemplateArgumentUnsignedValue(CXCursor *cursor, unsigned i) {
    return clang_Cursor_getTemplateArgumentUnsignedValue(*cursor, i);
}

/* ===== CXCursor external symbol query ===== */

MOJO_SHIM_EXPORT unsigned mojo_clang_Cursor_isExternalSymbol(CXCursor *cursor, CXString *language, CXString *definedIn, unsigned *isGenerated) {
    return clang_Cursor_isExternalSymbol(*cursor, language, definedIn, isGenerated);
}

/* ===== CXCursor definition spelling and extent ===== */

MOJO_SHIM_EXPORT void mojo_clang_getDefinitionSpellingAndExtent(CXCursor *cursor, const char **startBuf, const char **endBuf, unsigned *startLine, unsigned *startColumn, unsigned *endLine, unsigned *endColumn) {
    clang_getDefinitionSpellingAndExtent(*cursor, startBuf, endBuf, startLine, startColumn, endLine, endColumn);
}

/* ===== CXType field visitor trampoline ===== */

/* Mojo callback type: takes pointer to CXCursor and user data */
typedef unsigned (*mojo_field_visitor_fn)(CXCursor *, void *);

static unsigned field_visit_trampoline(CXCursor cursor, CXClientData data) {
    struct {
        mojo_field_visitor_fn fn;
        void *user_data;
    } *ctx = (void*)data;
    return ctx->fn(&cursor, ctx->user_data);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_Type_visitFields(CXType *type, mojo_field_visitor_fn visitor, void *user_data) {
    /* Allocate context on the stack */
    struct { mojo_field_visitor_fn fn; void *user_data; } ctx;
    ctx.fn = visitor;
    ctx.user_data = user_data;
    return clang_Type_visitFields(*type, field_visit_trampoline, &ctx);
}

/* ===== CXCursor child visitor trampoline ===== */

/* Mojo callback type: takes pointers to CXCursor cursors and user data */
typedef unsigned (*mojo_cursor_visitor_fn)(CXCursor *, CXCursor *, void *);

static unsigned cursor_visit_trampoline(CXCursor cursor, CXCursor parent, CXClientData data) {
    struct {
        mojo_cursor_visitor_fn fn;
        void *user_data;
    } *ctx = (void*)data;
    return ctx->fn(&cursor, &parent, ctx->user_data);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_visitChildren(CXCursor *parent, mojo_cursor_visitor_fn visitor, void *user_data) {
    struct { mojo_cursor_visitor_fn fn; void *user_data; } ctx;
    ctx.fn = visitor;
    ctx.user_data = user_data;
    return clang_visitChildren(*parent, cursor_visit_trampoline, &ctx);
}

/* Direct callback-passing variants for raw bindings (no trampoline).
   These wrap the by-value struct input but pass the C callback through unchanged. */
MOJO_SHIM_EXPORT unsigned mojo_clang_visitChildren_direct(CXCursor *parent, CXCursorVisitor visitor, CXClientData client_data) {
    return clang_visitChildren(*parent, visitor, client_data);
}

MOJO_SHIM_EXPORT unsigned mojo_clang_Type_visitFields_direct(CXType *type, CXFieldVisitor visitor, CXClientData client_data) {
    return clang_Type_visitFields(*type, visitor, client_data);
}

/* ===== Rewriter functions (by-value CXSourceLocation/CXSourceRange) ===== */

MOJO_SHIM_EXPORT void mojo_clang_CXRewriter_insertTextBefore(CXRewriter rew, CXSourceLocation *loc, const char *insert) {
    clang_CXRewriter_insertTextBefore(rew, *loc, insert);
}

MOJO_SHIM_EXPORT void mojo_clang_CXRewriter_replaceText(CXRewriter rew, CXSourceRange *range, const char *replacement) {
    clang_CXRewriter_replaceText(rew, *range, replacement);
}

MOJO_SHIM_EXPORT void mojo_clang_CXRewriter_removeText(CXRewriter rew, CXSourceRange *range) {
    clang_CXRewriter_removeText(rew, *range);
}

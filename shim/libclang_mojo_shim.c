typedef void *CXFile;
typedef void *CXDiagnostic;
typedef void *CXTranslationUnit;
typedef unsigned CXCursorKind;
typedef unsigned CXAvailabilityKind;
typedef unsigned CXTypeKind;

typedef struct {
    const void *data;
    unsigned private_flags;
} CXString;

typedef struct {
    const void *ptr_data[2];
    unsigned int_data;
} CXSourceLocation;

typedef struct {
    const void *ptr_data[2];
    unsigned begin_int_data;
    unsigned end_int_data;
} CXSourceRange;

typedef struct {
    CXCursorKind kind;
    int xdata;
    const void *data[3];
} CXCursor;

typedef struct {
    CXTypeKind kind;
    void *data[2];
} CXType;

extern unsigned clang_equalTypes(CXType, CXType);

typedef struct {
    unsigned int_data[4];
    void *ptr_data;
} CXToken;

extern CXSourceLocation clang_getNullLocation(void);
extern unsigned clang_equalLocations(CXSourceLocation, CXSourceLocation);
extern int clang_Location_isInSystemHeader(CXSourceLocation);
extern int clang_Location_isFromMainFile(CXSourceLocation);
extern CXSourceRange clang_getNullRange(void);
extern CXSourceRange clang_getRange(CXSourceLocation, CXSourceLocation);
extern unsigned clang_equalRanges(CXSourceRange, CXSourceRange);
extern int clang_Range_isNull(CXSourceRange);
extern void clang_getExpansionLocation(CXSourceLocation, CXFile *, unsigned *, unsigned *, unsigned *);
extern void clang_getPresumedLocation(CXSourceLocation, CXString *, unsigned *, unsigned *);
extern void clang_getInstantiationLocation(CXSourceLocation, CXFile *, unsigned *, unsigned *, unsigned *);
extern void clang_getSpellingLocation(CXSourceLocation, CXFile *, unsigned *, unsigned *, unsigned *);
extern void clang_getFileLocation(CXSourceLocation, CXFile *, unsigned *, unsigned *, unsigned *);
extern CXSourceLocation clang_getRangeStart(CXSourceRange);
extern CXSourceLocation clang_getRangeEnd(CXSourceRange);
extern CXSourceLocation clang_getDiagnosticLocation(CXDiagnostic);
extern CXSourceRange clang_getDiagnosticRange(CXDiagnostic, unsigned);
extern CXSourceLocation clang_getLocation(CXTranslationUnit, CXFile, unsigned, unsigned);
extern CXSourceLocation clang_getLocationForOffset(CXTranslationUnit, CXFile, unsigned);
extern CXCursor clang_getNullCursor(void);
extern CXCursor clang_getTranslationUnitCursor(CXTranslationUnit);
extern unsigned clang_equalCursors(CXCursor, CXCursor);
extern int clang_Cursor_isNull(CXCursor);
extern unsigned clang_hashCursor(CXCursor);
extern CXCursorKind clang_getCursorKind(CXCursor);
extern unsigned clang_getCursorLinkage(CXCursor);
extern unsigned clang_getCursorVisibility(CXCursor);
extern CXAvailabilityKind clang_getCursorAvailability(CXCursor);
extern CXCursor clang_Cursor_getVarDeclInitializer(CXCursor);
extern int clang_Cursor_hasVarDeclGlobalStorage(CXCursor);
extern int clang_Cursor_hasVarDeclExternalStorage(CXCursor);
extern unsigned clang_getCursorLanguage(CXCursor);
extern unsigned clang_getCursorTLSKind(CXCursor);
extern CXTranslationUnit clang_Cursor_getTranslationUnit(CXCursor);
extern unsigned clang_CXCursorSet_contains(void *, CXCursor);
extern unsigned clang_CXCursorSet_insert(void *, CXCursor);
extern CXCursor clang_getCursorSemanticParent(CXCursor);
extern CXCursor clang_getCursorLexicalParent(CXCursor);
extern void clang_getOverriddenCursors(CXCursor, CXCursor **, unsigned *);
extern CXFile clang_getIncludedFile(CXCursor);
extern CXCursor clang_getCursor(CXTranslationUnit, CXSourceLocation);
extern CXSourceLocation clang_getCursorLocation(CXCursor);
extern CXSourceRange clang_getCursorExtent(CXCursor);
extern CXType clang_getCursorType(CXCursor);
extern CXString clang_getTypeSpelling(CXType);
extern CXType clang_getTypedefDeclUnderlyingType(CXCursor);
extern CXType clang_getEnumDeclIntegerType(CXCursor);
extern CXString clang_getCursorUSR(CXCursor);
extern CXString clang_getCursorSpelling(CXCursor);
extern CXCursor clang_getCursorReferenced(CXCursor);
extern CXCursor clang_getCursorDefinition(CXCursor);
extern CXCursor clang_getCanonicalCursor(CXCursor);
extern CXToken *clang_getToken(CXTranslationUnit, CXSourceLocation);
extern unsigned clang_getTokenKind(CXToken);
extern CXString clang_getTokenSpelling(CXTranslationUnit, CXToken);
extern CXSourceLocation clang_getTokenLocation(CXTranslationUnit, CXToken);
extern CXSourceRange clang_getTokenExtent(CXTranslationUnit, CXToken);
extern void clang_tokenize(CXTranslationUnit, CXSourceRange, CXToken **, unsigned *);
extern void clang_annotateTokens(CXTranslationUnit, CXToken *, unsigned, CXCursor *);

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

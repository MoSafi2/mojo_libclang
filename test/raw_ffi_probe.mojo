from src.libclang_raw import (
    clang_File_isEqual,
    clang_File_tryGetRealPathName,
    clang_createIndex,
    clang_Cursor_getArgument,
    clang_Cursor_getNumArguments,
    clang_Cursor_getNumTemplateArguments,
    clang_Cursor_getStorageClass,
    clang_Cursor_hasAttrs,
    clang_Cursor_isAnonymous,
    clang_Cursor_isAnonymousRecordDecl,
    clang_Cursor_isBitField,
    clang_Cursor_isVariadic,
    clang_CXXConstructor_isDefaultConstructor,
    clang_CXXMethod_isConst,
    clang_CXXMethod_isStatic,
    clang_CXXMethod_isVirtual,
    clang_CXXRecord_isAbstract,
    clang_defaultEditingTranslationUnitOptions,
    clang_defaultSaveOptions,
    clang_disposeDiagnostic,
    clang_disposeIndex,
    clang_disposeString,
    clang_disposeTokens,
    clang_disposeTranslationUnit,
    clang_EnumDecl_isScoped,
    clang_equalCursors,
    clang_equalCursors_ref,
    clang_equalLocations,
    clang_equalLocations_ref,
    clang_equalRanges,
    clang_equalRanges_ref,
    clang_equalTypes,
    clang_equalTypes_ref,
    clang_getAddressSpace,
    clang_getArgType,
    clang_getArrayElementType,
    clang_getArraySize,
    clang_getCanonicalCursor,
    clang_getCanonicalType,
    clang_getClangVersion,
    clang_getCString,
    clang_getCursor,
    clang_getCursor_ref,
    clang_getCursorAvailability,
    clang_getCursorDefinition,
    clang_getCursorDisplayName,
    clang_getCursorExceptionSpecificationType,
    clang_getCursorExtent,
    clang_getCursorKind,
    clang_getCursorKind_ref,
    clang_getCursorKindSpelling,
    clang_getCursorLexicalParent,
    clang_getCursorReferenced,
    clang_getCursorResultType,
    clang_getCursorSemanticParent,
    clang_getCursorSpelling,
    clang_getCursorSpelling_ref,
    clang_getCursorType,
    clang_getCursorType_ref,
    clang_getCursorUSR,
    clang_getCXXAccessSpecifier,
    clang_getDiagnostic,
    clang_getDiagnosticSpelling,
    clang_getElementType,
    clang_getEnumConstantDeclValue,
    clang_getExceptionSpecificationType,
    clang_getFieldDeclBitWidth,
    clang_getFile,
    clang_getFileLocation,
    clang_getFileName,
    clang_getFileTime,
    clang_getFunctionTypeCallingConv,
    clang_getLocation,
    clang_getLocation_into,
    clang_getNonReferenceType,
    clang_getNullCursor,
    clang_getNullCursor_ref,
    clang_getNullLocation,
    clang_getNullLocation_ref,
    clang_getNullRange,
    clang_getNullRange_into,
    clang_getNumArgTypes,
    clang_getNumDiagnostics,
    clang_getNumElements,
    clang_getNumOverloadedDecls,
    clang_getOverloadedDecl,
    clang_getPointeeType,
    clang_getRange,
    clang_getRange_into,
    clang_getResultType,
    clang_getSpecializedCursorTemplate,
    clang_getSpellingLocation,
    clang_getSpellingLocation_ref,
    clang_getTemplateCursorKind,
    clang_getToken,
    clang_getToken_ref,
    clang_getTokenKind,
    clang_getTokenKind_ref,
    clang_getTokenExtent,
    clang_getTokenExtent_ref,
    clang_getTokenLocation,
    clang_getTokenLocation_ref,
    clang_getTokenSpelling,
    clang_getTokenSpelling_ref,
    clang_getTranslationUnitCursor,
    clang_getTranslationUnitCursor_ref,
    clang_getTranslationUnitSpelling,
    clang_getTypeDeclaration,
    clang_getTypedefName,
    clang_getTypeSpelling,
    clang_getTypeSpelling_ref,
    clang_getUnqualifiedType,
    clang_isConstQualifiedType,
    clang_isCursorDefinition,
    clang_isDeclaration,
    clang_isExpression,
    clang_isFunctionTypeVariadic,
    clang_isInvalid,
    clang_isPODType,
    clang_isRestrictQualifiedType,
    clang_isStatement,
    clang_isVirtualBase,
    clang_isVolatileQualifiedType,
    clang_parseTranslationUnit,
    clang_Range_isNull,
    clang_Range_isNull_ref,
    clang_tokenize,
    clang_tokenize_ref,
    clang_Type_getAlignOf,
    clang_Type_getNumTemplateArguments,
    clang_Type_getSizeOf,
    clang_visitChildren,
    CXCursor,
    CXCursorKind,
    CXCursor_EnumConstantDecl,
    CXCursor_FirstInvalid,
    CXCursor_FunctionDecl,
    CXCursor_TranslationUnit,
    CXCursor_VarDecl,
    CXFile,
    CXIndex,
    CXSourceLocation,
    CXSourceRange,
    CXString,
    CXToken,
    CXTranslationUnit,
    CXTranslationUnit_None,
    CXType,
    CXType_Invalid,
    CXTypeKind,
    CXUnsavedFile,
    CXChildVisitResult,
    CXChildVisit_Continue,
    CXClientData,
)
from std.ffi import c_char, c_int, c_uint, c_ulong
from std.memory import UnsafePointer


comptime EXPECT_WORKING = "working"
comptime EXPECT_UNKNOWN = "unknown"
comptime EXPECT_KNOWN_BROKEN = "known-broken"


def _check(condition: Bool, message: String) raises:
    if not condition:
        raise Error(message)


def _as_c_string(text: String) -> UnsafePointer[c_char, ImmutExternalOrigin]:
    return rebind[UnsafePointer[c_char, ImmutExternalOrigin]](text.unsafe_ptr())


def _cx_string_pointer_note(cx_string: CXString) raises -> String:
    var c_string = clang_getCString(cx_string)
    if not c_string:
        clang_disposeString(cx_string)
        raise Error("libclang returned a null C string")
    var value = String(unsafe_from_utf8_ptr=c_string.value())
    clang_disposeString(cx_string)
    return value


def _parse_file(index: CXIndex, path_storage: String) raises -> CXTranslationUnit:
    var tu = clang_parseTranslationUnit(
        index,
        _as_c_string(path_storage),
        None,
        0,
        None,
        0,
        CXTranslationUnit_None,
    )
    if not tu:
        raise Error("clang_parseTranslationUnit returned null")
    return tu


def _probe_version_string() raises -> String:
    var text = _cx_string_pointer_note(clang_getClangVersion())
    _check(text.byte_length() > 0, "clang version string was empty")
    _check(text.byte_length() < 200, "clang version string suspiciously long")
    return "clang version: " + text


def _probe_default_options() raises -> String:
    var edit_options = clang_defaultEditingTranslationUnitOptions()
    _check(edit_options != 0, "clang_defaultEditingTranslationUnitOptions returned zero")
    return "edit-options=" + String(edit_options)


def _probe_null_struct_returns() raises -> String:
    var location = clang_getNullLocation()
    var cursor = clang_getNullCursor()
    var range_storage = InlineArray[CXSourceRange, 1](fill=clang_getNullRange())
    clang_getNullRange_into(rebind[UnsafePointer[CXSourceRange, MutExternalOrigin]](range_storage.unsafe_ptr()))

    _check(Bool(clang_Range_isNull_ref(rebind[UnsafePointer[CXSourceRange, MutExternalOrigin]](range_storage.unsafe_ptr()))), "clang_getNullRange did not produce a null range")
    _ = location
    _ = cursor
    return "null location, range, and cursor returned"


def _probe_null_cursor_metadata() raises -> String:
    var cursor = clang_getNullCursor()
    var kind = clang_getCursorKind(cursor)
    _check(kind == CXCursor_FirstInvalid, "null cursor kind was not CXCursor_FirstInvalid")
    _check(Bool(clang_isInvalid(kind)), "null cursor kind was not classified as invalid")
    var kind_name = _cx_string_pointer_note(clang_getCursorKindSpelling(kind))
    _check(kind_name.byte_length() > 0, "null cursor kind spelling was empty")
    return "kind=" + String(kind) + ", spelling=" + kind_name


def _probe_parse_file_and_tu_cursor() raises -> String:
    var index = clang_createIndex(0, 0)
    if not index:
        raise Error("clang_createIndex returned null")

    var path = String("test/raw_ffi_probe_fixture.c\00")
    var tu = _parse_file(index, path)

    try:
        _check(clang_getNumDiagnostics(tu) == 0, "expected zero diagnostics for valid fixture")

        var file = clang_getFile(tu, _as_c_string(path))
        if not file:
            raise Error("clang_getFile returned null")

        var file_name = _cx_string_pointer_note(clang_getFileName(file))
        var file_real_path = _cx_string_pointer_note(clang_File_tryGetRealPathName(file))
        var file_time = clang_getFileTime(file)
        _check(Bool(clang_File_isEqual(file, file)), "clang_File_isEqual(file, file) returned false")
        var cursor = clang_getTranslationUnitCursor(tu)
        var tu_spelling = _cx_string_pointer_note(clang_getTranslationUnitSpelling(tu))
        var save_options = clang_defaultSaveOptions(tu)

        _ = cursor
        return (
            "tu-spelling=" + tu_spelling
            + ", file=" + file_name
            + ", real-path=" + file_real_path
            + ", file-time=" + String(file_time)
            + ", save-options=" + String(save_options)
        )
    finally:
        clang_disposeTranslationUnit(tu)
        clang_disposeIndex(index)


def _probe_cursor_lookup_and_spelling() raises -> String:
    var index = clang_createIndex(0, 0)
    if not index:
        raise Error("clang_createIndex returned null")

    var path = String("test/raw_ffi_probe_fixture.c\00")
    var tu = _parse_file(index, path)

    try:
        var file = clang_getFile(tu, _as_c_string(path))
        if not file:
            raise Error("clang_getFile returned null")

        var location_storage = InlineArray[CXSourceLocation, 1](fill=clang_getNullLocation())
        clang_getLocation_into(
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](location_storage.unsafe_ptr()),
            tu, file, 1, 5,
        )

        var cursor_storage = InlineArray[CXCursor, 1](fill=clang_getNullCursor())
        clang_getCursor_ref(
            rebind[UnsafePointer[CXCursor, MutExternalOrigin]](cursor_storage.unsafe_ptr()),
            tu,
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](location_storage.unsafe_ptr()),
        )

        var kind = clang_getCursorKind_ref(rebind[UnsafePointer[CXCursor, MutExternalOrigin]](cursor_storage.unsafe_ptr()))
        _check(not Bool(clang_isInvalid(kind)), "cursor from clang_getCursor_ref had an invalid kind")

        var spelling = _cx_string_pointer_note(clang_getCursorSpelling_ref(rebind[UnsafePointer[CXCursor, MutExternalOrigin]](cursor_storage.unsafe_ptr())))
        _check(spelling.byte_length() > 0, "cursor spelling was empty")
        return "kind=" + String(kind) + ", spelling=" + spelling
    finally:
        clang_disposeTranslationUnit(tu)
        clang_disposeIndex(index)


def _probe_location_round_trip() raises -> String:
    var index = clang_createIndex(0, 0)
    if not index:
        raise Error("clang_createIndex returned null")

    var path = String("test/raw_ffi_probe_fixture.c\00")
    var tu = _parse_file(index, path)

    try:
        var file = clang_getFile(tu, _as_c_string(path))
        if not file:
            raise Error("clang_getFile returned null")

        var location_storage = InlineArray[CXSourceLocation, 1](fill=clang_getNullLocation())
        var spelling_file = InlineArray[CXFile, 1](fill=None)
        var spelling_line = InlineArray[c_uint, 1](fill=c_uint(0))
        var spelling_column = InlineArray[c_uint, 1](fill=c_uint(0))
        var spelling_offset = InlineArray[c_uint, 1](fill=c_uint(0))

        clang_getLocation_into(
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](location_storage.unsafe_ptr()),
            tu,
            file,
            1,
            5,
        )
        clang_getSpellingLocation_ref(
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](location_storage.unsafe_ptr()),
            rebind[UnsafePointer[CXFile, MutExternalOrigin]](spelling_file.unsafe_ptr()),
            rebind[UnsafePointer[c_uint, MutExternalOrigin]](spelling_line.unsafe_ptr()),
            rebind[UnsafePointer[c_uint, MutExternalOrigin]](spelling_column.unsafe_ptr()),
            rebind[UnsafePointer[c_uint, MutExternalOrigin]](spelling_offset.unsafe_ptr()),
        )

        _check(spelling_line[0] == 1, "spelling line mismatch")
        _check(spelling_column[0] == 5, "spelling column mismatch")
        _check(Bool(clang_File_isEqual(file, spelling_file[0])), "spelling file mismatch")
        return "line=" + String(spelling_line[0]) + ", column=" + String(spelling_column[0])
    finally:
        clang_disposeTranslationUnit(tu)
        clang_disposeIndex(index)


def _probe_tu_cursor_metadata() raises -> String:
    var index = clang_createIndex(0, 0)
    if not index:
        raise Error("clang_createIndex returned null")

    var path = String("test/raw_ffi_probe_fixture.c\00")
    var tu = _parse_file(index, path)

    try:
        var cursor = clang_getTranslationUnitCursor(tu)
        var kind = clang_getCursorKind(cursor)
        _check(kind == CXCursor_TranslationUnit, "TU cursor kind was not CXCursor_TranslationUnit")
        var kind_name = _cx_string_pointer_note(clang_getCursorKindSpelling(kind))
        _check(kind_name.byte_length() > 0, "TU cursor kind spelling was empty")

        var semantic_parent = clang_getCursorSemanticParent(cursor)
        var lexical_parent = clang_getCursorLexicalParent(cursor)
        _check(clang_getCursorKind(semantic_parent) == CXCursor_TranslationUnit, "TU cursor semantic parent kind was not CXCursor_TranslationUnit")
        _check(clang_getCursorKind(lexical_parent) == CXCursor_TranslationUnit, "TU cursor lexical parent kind was not CXCursor_TranslationUnit")

        var definition = clang_getCursorDefinition(cursor)
        _ = definition

        var referenced = clang_getCursorReferenced(cursor)
        var availability = clang_getCursorAvailability(cursor)
        _ = referenced
        return "kind=" + String(kind) + ", kind-spelling=" + kind_name + ", availability=" + String(availability)
    finally:
        clang_disposeTranslationUnit(tu)
        clang_disposeIndex(index)


def _probe_tu_cursor_type_surface() raises -> String:
    var index = clang_createIndex(0, 0)
    if not index:
        raise Error("clang_createIndex returned null")

    var path = String("test/raw_ffi_probe_fixture.c\00")
    var tu = _parse_file(index, path)

    try:
        var file = clang_getFile(tu, _as_c_string(path))
        if not file:
            raise Error("clang_getFile returned null")

        var location_storage = InlineArray[CXSourceLocation, 1](fill=clang_getNullLocation())
        clang_getLocation_into(
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](location_storage.unsafe_ptr()),
            tu, file, 1, 5,
        )

        var cursor_storage = InlineArray[CXCursor, 1](fill=clang_getNullCursor())
        clang_getCursor_ref(
            rebind[UnsafePointer[CXCursor, MutExternalOrigin]](cursor_storage.unsafe_ptr()),
            tu,
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](location_storage.unsafe_ptr()),
        )

        var kind = clang_getCursorKind_ref(rebind[UnsafePointer[CXCursor, MutExternalOrigin]](cursor_storage.unsafe_ptr()))
        _check(kind == CXCursor_FunctionDecl, "expected cursor at line 1 col 5 to be FunctionDecl, got " + String(kind))

        var type_storage = InlineArray[CXType, 1](fill=CXType(kind=CXTypeKind(c_uint(0)), data0=None, data1=None))
        clang_getCursorType_ref(
            result=rebind[UnsafePointer[CXType, MutExternalOrigin]](type_storage.unsafe_ptr()),
            cursor=rebind[UnsafePointer[CXCursor, MutExternalOrigin]](cursor_storage.unsafe_ptr()),
        )

        var type_kind = type_storage[0].kind
        _check(type_kind != CXType_Invalid, "function cursor type was CXType_Invalid")

        var type_spelling = _cx_string_pointer_note(clang_getTypeSpelling_ref(rebind[UnsafePointer[CXType, MutExternalOrigin]](type_storage.unsafe_ptr())))
        _check(type_spelling.byte_length() > 0, "function type spelling was empty")

        return "cursor-kind=" + String(kind) + ", type-kind=" + String(type_kind) + ", type-spelling=" + type_spelling
    finally:
        clang_disposeTranslationUnit(tu)
        clang_disposeIndex(index)


def _probe_pointer_only_cursor_and_tokens() raises -> String:
    var index = clang_createIndex(0, 0)
    if not index:
        raise Error("clang_createIndex returned null")

    var path = String("test/raw_ffi_probe_fixture.c\00")
    var tu = _parse_file(index, path)

    try:
        var file = clang_getFile(tu, _as_c_string(path))
        if not file:
            raise Error("clang_getFile returned null")

        var start_location = InlineArray[CXSourceLocation, 1](fill=clang_getNullLocation())
        var end_location = InlineArray[CXSourceLocation, 1](fill=clang_getNullLocation())
        var cursor_storage = InlineArray[CXCursor, 1](fill=clang_getNullCursor())
        var range_storage = InlineArray[CXSourceRange, 1](fill=clang_getNullRange())
        var token_storage = InlineArray[Optional[UnsafePointer[CXToken, MutExternalOrigin]], 1](fill=None)
        var token_count = InlineArray[c_uint, 1](fill=c_uint(0))

        clang_getLocation_into(
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](start_location.unsafe_ptr()),
            tu,
            file,
            1,
            5,
        )
        clang_getCursor_ref(
            rebind[UnsafePointer[CXCursor, MutExternalOrigin]](cursor_storage.unsafe_ptr()),
            tu,
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](start_location.unsafe_ptr()),
        )

        var kind = clang_getCursorKind_ref(rebind[UnsafePointer[CXCursor, MutExternalOrigin]](cursor_storage.unsafe_ptr()))
        _check(not Bool(clang_isInvalid(kind)), "pointer-only cursor lookup produced an invalid kind")

        clang_getLocation_into(
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](end_location.unsafe_ptr()),
            tu,
            file,
            1,
            23,
        )
        clang_getRange_into(
            rebind[UnsafePointer[CXSourceRange, MutExternalOrigin]](range_storage.unsafe_ptr()),
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](start_location.unsafe_ptr()),
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](end_location.unsafe_ptr()),
        )
        clang_tokenize_ref(
            tu,
            rebind[UnsafePointer[CXSourceRange, MutExternalOrigin]](range_storage.unsafe_ptr()),
            rebind[UnsafePointer[Optional[UnsafePointer[CXToken, MutExternalOrigin]], MutExternalOrigin]](token_storage.unsafe_ptr()),
            rebind[UnsafePointer[c_uint, MutExternalOrigin]](token_count.unsafe_ptr()),
        )
        _check(token_count[0] > 0, "pointer-only tokenize returned zero tokens")
        if not token_storage[0]:
            raise Error("pointer-only tokenize returned a null token buffer")
        try:
            var first = _cx_string_pointer_note(clang_getTokenSpelling_ref(tu, token_storage[0].value()))
            return "kind=" + String(kind) + ", tokens=" + String(token_count[0]) + ", first=" + first
        finally:
            clang_disposeTokens(tu, token_storage[0].value(), token_count[0])
    finally:
        clang_disposeTranslationUnit(tu)
        clang_disposeIndex(index)


def _probe_diagnostics() raises -> String:
    var index = clang_createIndex(0, 0)
    if not index:
        raise Error("clang_createIndex returned null")

    var path = String("test/raw_ffi_probe_invalid.c\00")
    var tu = _parse_file(index, path)

    try:
        var count = clang_getNumDiagnostics(tu)
        _check(count > 0, "expected at least one diagnostic for invalid fixture")

        var diagnostic = clang_getDiagnostic(tu, 0)
        if not diagnostic:
            raise Error("clang_getDiagnostic returned null for index 0")
        try:
            var spelling = _cx_string_pointer_note(clang_getDiagnosticSpelling(diagnostic))
            return "diagnostics=" + String(count) + ", first spelling pointer=" + spelling
        finally:
            clang_disposeDiagnostic(diagnostic)
    finally:
        clang_disposeTranslationUnit(tu)
        clang_disposeIndex(index)


def _probe_single_token_surface() raises -> String:
    var index = clang_createIndex(0, 0)
    if not index:
        raise Error("clang_createIndex returned null")

    var path = String("test/raw_ffi_probe_fixture.c\00")
    var tu = _parse_file(index, path)

    try:
        var file = clang_getFile(tu, _as_c_string(path))
        if not file:
            raise Error("clang_getFile returned null")

        var location_storage = InlineArray[CXSourceLocation, 1](fill=clang_getNullLocation())
        clang_getLocation_into(
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](location_storage.unsafe_ptr()),
            tu, file, 1, 1,
        )

        var token = clang_getToken_ref(tu, rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](location_storage.unsafe_ptr()))
        if not token:
            raise Error("clang_getToken_ref returned null")

        var token_ptr = token.value()
        var token_kind = clang_getTokenKind_ref(rebind[UnsafePointer[CXToken, MutExternalOrigin]](token_ptr))
        var spelling = _cx_string_pointer_note(clang_getTokenSpelling_ref(tu, rebind[UnsafePointer[CXToken, MutExternalOrigin]](token_ptr)))

        var location_out = InlineArray[CXSourceLocation, 1](fill=clang_getNullLocation())
        clang_getTokenLocation_ref(
            result=rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](location_out.unsafe_ptr()),
            tu=tu,
            token=rebind[UnsafePointer[CXToken, MutExternalOrigin]](token_ptr),
        )

        var extent_out = InlineArray[CXSourceRange, 1](fill=clang_getNullRange())
        clang_getTokenExtent_ref(
            result=rebind[UnsafePointer[CXSourceRange, MutExternalOrigin]](extent_out.unsafe_ptr()),
            tu=tu,
            token=rebind[UnsafePointer[CXToken, MutExternalOrigin]](token_ptr),
        )

        _check(not Bool(clang_Range_isNull_ref(rebind[UnsafePointer[CXSourceRange, MutExternalOrigin]](extent_out.unsafe_ptr()))), "token extent came back as a null range")
        return "kind=" + String(token_kind) + ", spelling=" + spelling
    finally:
        clang_disposeTranslationUnit(tu)
        clang_disposeIndex(index)


def _probe_unsaved_parse() raises -> String:
    var index = clang_createIndex(0, 0)
    if not index:
        raise Error("clang_createIndex returned null")

    var filename = String("test/raw_ffi_probe_fixture.c")
    var content = String("int x = 42;")

    var unsaved = alloc[CXUnsavedFile](1)
    unsaved[].Filename = rebind[UnsafePointer[c_char, ImmutExternalOrigin]](filename.unsafe_ptr())
    unsaved[].Contents = rebind[UnsafePointer[c_char, ImmutExternalOrigin]](content.unsafe_ptr())
    unsaved[].Length = c_ulong(content.byte_length())

    var tu = clang_parseTranslationUnit(
        index,
        rebind[UnsafePointer[c_char, ImmutExternalOrigin]](filename.unsafe_ptr()),
        None,
        0,
        rebind[UnsafePointer[CXUnsavedFile, MutExternalOrigin]](unsaved),
        1,
        CXTranslationUnit_None,
    )

    if not tu:
        raise Error("clang_parseTranslationUnit returned null with unsaved file")

    try:
        var cursor = clang_getTranslationUnitCursor(tu)
        var kind = clang_getCursorKind(cursor)
        _check(kind == CXCursor_TranslationUnit, "unsaved parse TU cursor was not CXCursor_TranslationUnit")
        var diagnostics = clang_getNumDiagnostics(tu)
        _check(diagnostics == 0, "unsaved parse of valid content produced diagnostics")
        return "diagnostics=" + String(diagnostics)
    finally:
        clang_disposeTranslationUnit(tu)
        clang_disposeIndex(index)


def _visit_child_callback(cursor: CXCursor, parent: CXCursor, client_data: CXClientData) abi("C") -> CXChildVisitResult:
    return CXChildVisit_Continue

def _probe_visit_children() raises -> String:
    var index = clang_createIndex(0, 0)
    if not index:
        raise Error("clang_createIndex returned null")

    var path = String("test/raw_ffi_probe_fixture.c\00")
    var tu = _parse_file(index, path)

    try:
        var tu_cursor = clang_getTranslationUnitCursor(tu)
        var result = clang_visitChildren(tu_cursor, _visit_child_callback, None)
        _check(result == 0, "clang_visitChildren returned non-zero, may indicate error")
        return "result=" + String(result)
    finally:
        clang_disposeTranslationUnit(tu)
        clang_disposeIndex(index)


def _probe_tokenize() raises -> String:
    var index = clang_createIndex(0, 0)
    if not index:
        raise Error("clang_createIndex returned null")

    var path = String("test/raw_ffi_probe_fixture.c\00")
    var tu = _parse_file(index, path)

    try:
        var file = clang_getFile(tu, _as_c_string(path))
        if not file:
            raise Error("clang_getFile returned null")

        var start_storage = InlineArray[CXSourceLocation, 1](fill=clang_getNullLocation())
        var end_storage = InlineArray[CXSourceLocation, 1](fill=clang_getNullLocation())
        clang_getLocation_into(
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](start_storage.unsafe_ptr()),
            tu, file, 1, 1,
        )
        clang_getLocation_into(
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](end_storage.unsafe_ptr()),
            tu, file, 1, 23,
        )

        var range_storage = InlineArray[CXSourceRange, 1](fill=clang_getNullRange())
        clang_getRange_into(
            rebind[UnsafePointer[CXSourceRange, MutExternalOrigin]](range_storage.unsafe_ptr()),
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](start_storage.unsafe_ptr()),
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](end_storage.unsafe_ptr()),
        )

        var token_storage = InlineArray[Optional[UnsafePointer[CXToken, MutExternalOrigin]], 1](fill=None)
        var count_storage = InlineArray[c_uint, 1](fill=c_uint(0))

        clang_tokenize_ref(
            tu,
            rebind[UnsafePointer[CXSourceRange, MutExternalOrigin]](range_storage.unsafe_ptr()),
            rebind[UnsafePointer[Optional[UnsafePointer[CXToken, MutExternalOrigin]], MutExternalOrigin]](token_storage.unsafe_ptr()),
            rebind[UnsafePointer[c_uint, MutExternalOrigin]](count_storage.unsafe_ptr()),
        )

        var token_count = count_storage[0]
        _check(token_count > 0, "clang_tokenize_ref returned zero tokens")
        if not token_storage[0]:
            raise Error("clang_tokenize_ref returned a null token buffer")

        var first_ptr = token_storage[0].value()
        var first_kind = clang_getTokenKind_ref(rebind[UnsafePointer[CXToken, MutExternalOrigin]](first_ptr))
        var first_spelling = _cx_string_pointer_note(clang_getTokenSpelling_ref(tu, rebind[UnsafePointer[CXToken, MutExternalOrigin]](first_ptr)))
        return "count=" + String(token_count) + ", first-kind=" + String(first_kind) + ", first=" + first_spelling
    finally:
        clang_disposeTranslationUnit(tu)
        clang_disposeIndex(index)


def _probe_shim_null_cursor() raises -> String:
    """Tests by-value shimmed functions with null cursors.

    Patch 0005 converted ~111 functions from _bindgen_dl to _bindgen_shim_dl.
    Null cursors (all-zero) exercise the pointer-wrapping path without
    valid data pointers.  Most scalar/enum/struct-return functions work,
    but CXType mapping functions (getCanonicalType, getUnqualifiedType)
    on CXType_Invalid can segfault — the shim wrapper corrupts the
    @register_passable struct's pointer fields.
    """
    var index = clang_createIndex(0, 0)
    if not index:
        raise Error("clang_createIndex returned null")
    var path = String("test/raw_ffi_probe_fixture.c\00")
    var tu = _parse_file(index, path)
    try:
        var null_cursor = clang_getNullCursor()

        # Scalar queries on null cursor
        _check(not Bool(clang_Cursor_hasAttrs(null_cursor)), "hasAttrs on null")
        _check(not Bool(clang_Cursor_isBitField(null_cursor)), "isBitField on null")
        _check(not Bool(clang_Cursor_isAnonymous(null_cursor)), "isAnonymous on null")
        _check(not Bool(clang_Cursor_isVariadic(null_cursor)), "isVariadic on null")
        _check(not Bool(clang_isCursorDefinition(null_cursor)), "isCursorDefinition on null")
        _check(clang_Cursor_getNumArguments(null_cursor) == -1, "null num_args")
        _check(clang_Cursor_getNumTemplateArguments(null_cursor) == -1, "null template_args")
        _check(clang_getFieldDeclBitWidth(null_cursor) == -1, "null bit_width")
        _ = clang_getNumOverloadedDecls(null_cursor)

        # Cursor→CXCursor on null cursor
        var semantic = clang_getCursorSemanticParent(null_cursor)
        _check(clang_getCursorKind(semantic) == CXCursor_FirstInvalid, "null semantic")
        var lexical = clang_getCursorLexicalParent(null_cursor)
        _check(clang_getCursorKind(lexical) == CXCursor_FirstInvalid, "null lexical")
        var referenced = clang_getCursorReferenced(null_cursor)
        _check(clang_getCursorKind(referenced) == CXCursor_FirstInvalid, "null referenced")

        # Cursor→CXType on null cursor: invalid type
        var cursor_type = clang_getCursorType(null_cursor)
        _check(cursor_type.kind == CXType_Invalid, "null cursor type not Invalid")

        # CXX queries on null cursor
        _check(not Bool(clang_CXXMethod_isVirtual(null_cursor)), "isVirtual on null")
        _check(not Bool(clang_CXXMethod_isConst(null_cursor)), "isConst on null")
        _check(not Bool(clang_CXXRecord_isAbstract(null_cursor)), "isAbstract on null")

        return "null-cursor passes"
    finally:
        clang_disposeTranslationUnit(tu)
        clang_disposeIndex(index)


def _probe_shim_nonnull_cursor() raises -> String:
    """Tests by-value shim with non-null TU cursor.

    Functions that only read the `kind` field (offset 0, first 4 bytes)
    work reliably.  Functions that return struct via out-param also work.

    CXCursor→CXString functions (getCursorDisplayName, getCursorUSR) may
    crash or work depending on runtime state — the InlineArray wrapper
    may corrupt the data[0..2] pointer fields of @register_passable CXCursor.
    """
    var index = clang_createIndex(0, 0)
    if not index:
        raise Error("clang_createIndex returned null")
    var path = String("test/raw_ffi_probe_fixture.c\00")
    var tu = _parse_file(index, path)
    try:
        var tu_cursor = clang_getTranslationUnitCursor(tu)

        # Scalar: reads only kind field at offset 0 → works
        var kind = clang_getCursorKind(tu_cursor)
        _check(kind == CXCursor_TranslationUnit, "TU cursor kind mismatch")

        # Struct return via out-param → works
        var semantic = clang_getCursorSemanticParent(tu_cursor)
        _check(clang_getCursorKind(semantic) == CXCursor_TranslationUnit, "TU semantic")

        _check(not Bool(clang_Cursor_hasAttrs(tu_cursor)), "hasAttrs on TU")

        # CXCursor→CXString: may crash if InlineArray corrupts data ptrs
        var display_name = _cx_string_pointer_note(
            clang_getCursorDisplayName(tu_cursor),
        )
        _check(display_name.byte_length() > 0, "TU display name empty")

        return "kind=" + String(kind) + ", display=" + display_name
    finally:
        clang_disposeTranslationUnit(tu)
        clang_disposeIndex(index)


def _probe_equal_types_via_direct_dl() raises -> String:
    var index = clang_createIndex(0, 0)
    if not index:
        raise Error("clang_createIndex returned null")
    var path = String("test/raw_ffi_probe_fixture.c\00")
    var tu = _parse_file(index, path)
    try:
        var file = clang_getFile(tu, _as_c_string(path))
        if not file:
            raise Error("clang_getFile returned null")

        var location_storage = InlineArray[CXSourceLocation, 1](
            fill=CXSourceLocation(ptr_data0=None, ptr_data1=None, int_data=c_uint(0)),
        )
        clang_getLocation_into(
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](location_storage.unsafe_ptr()),
            tu, file, 1, 5,
        )
        var cursor_storage = InlineArray[CXCursor, 1](
            fill=CXCursor(kind=CXCursorKind(c_uint(0)), xdata=c_int(0), data0=None, data1=None, data2=None),
        )
        clang_getCursor_ref(
            rebind[UnsafePointer[CXCursor, MutExternalOrigin]](cursor_storage.unsafe_ptr()),
            tu,
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](location_storage.unsafe_ptr()),
        )
        var type_storage = InlineArray[CXType, 1](fill=CXType(kind=CXType_Invalid, data0=None, data1=None))
        clang_getCursorType_ref(
            result=rebind[UnsafePointer[CXType, MutExternalOrigin]](type_storage.unsafe_ptr()),
            cursor=rebind[UnsafePointer[CXCursor, MutExternalOrigin]](cursor_storage.unsafe_ptr()),
        )

        var equal_self = clang_equalTypes_ref(
            rebind[UnsafePointer[CXType, MutExternalOrigin]](type_storage.unsafe_ptr()),
            rebind[UnsafePointer[CXType, MutExternalOrigin]](type_storage.unsafe_ptr()),
        )
        _check(Bool(equal_self), "clang_equalTypes_ref(self, self) is false")

        var invalid_type_storage = InlineArray[CXType, 1](fill=CXType(kind=CXType_Invalid, data0=None, data1=None))
        var equal_diff = clang_equalTypes_ref(
            rebind[UnsafePointer[CXType, MutExternalOrigin]](type_storage.unsafe_ptr()),
            rebind[UnsafePointer[CXType, MutExternalOrigin]](invalid_type_storage.unsafe_ptr()),
        )
        _check(not Bool(equal_diff), "clang_equalTypes_ref(self, invalid) is true")

        return "self=" + String(equal_self) + ", diff=" + String(equal_diff)
    finally:
        clang_disposeTranslationUnit(tu)
        clang_disposeIndex(index)


def _probe_equal_cursors_via_shim() raises -> String:
    var index = clang_createIndex(0, 0)
    if not index:
        raise Error("clang_createIndex returned null")
    var path = String("test/raw_ffi_probe_fixture.c\00")
    var tu = _parse_file(index, path)
    try:
        var tu_cursor_storage = InlineArray[CXCursor, 1](
            fill=CXCursor(kind=CXCursorKind(c_uint(0)), xdata=c_int(0), data0=None, data1=None, data2=None),
        )
        clang_getTranslationUnitCursor_ref(
            rebind[UnsafePointer[CXCursor, MutExternalOrigin]](tu_cursor_storage.unsafe_ptr()), tu,
        )

        var null_cursor_storage = InlineArray[CXCursor, 1](
            fill=CXCursor(kind=CXCursorKind(c_uint(0)), xdata=c_int(0), data0=None, data1=None, data2=None),
        )
        clang_getNullCursor_ref(
            rebind[UnsafePointer[CXCursor, MutExternalOrigin]](null_cursor_storage.unsafe_ptr()),
        )

        var equal_self = clang_equalCursors_ref(
            rebind[UnsafePointer[CXCursor, MutExternalOrigin]](tu_cursor_storage.unsafe_ptr()),
            rebind[UnsafePointer[CXCursor, MutExternalOrigin]](tu_cursor_storage.unsafe_ptr()),
        )
        _check(Bool(equal_self), "clang_equalCursors_ref(self, self) is false")

        var equal_null = clang_equalCursors_ref(
            rebind[UnsafePointer[CXCursor, MutExternalOrigin]](null_cursor_storage.unsafe_ptr()),
            rebind[UnsafePointer[CXCursor, MutExternalOrigin]](null_cursor_storage.unsafe_ptr()),
        )
        _check(Bool(equal_null), "clang_equalCursors_ref(null, null) is false")

        var equal_diff = clang_equalCursors_ref(
            rebind[UnsafePointer[CXCursor, MutExternalOrigin]](tu_cursor_storage.unsafe_ptr()),
            rebind[UnsafePointer[CXCursor, MutExternalOrigin]](null_cursor_storage.unsafe_ptr()),
        )
        _check(not Bool(equal_diff), "clang_equalCursors_ref(tu, null) is true")

        return "self=" + String(equal_self) + ", null=" + String(equal_null) + ", diff=" + String(equal_diff)
    finally:
        clang_disposeTranslationUnit(tu)
        clang_disposeIndex(index)


def _probe_equal_locations_via_shim() raises -> String:
    var index = clang_createIndex(0, 0)
    if not index:
        raise Error("clang_createIndex returned null")
    var path = String("test/raw_ffi_probe_fixture.c\00")
    var tu = _parse_file(index, path)
    try:
        var file = clang_getFile(tu, _as_c_string(path))
        if not file:
            raise Error("clang_getFile returned null")

        var loc_storage = InlineArray[CXSourceLocation, 1](
            fill=CXSourceLocation(ptr_data0=None, ptr_data1=None, int_data=c_uint(0)),
        )
        clang_getLocation_into(
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](loc_storage.unsafe_ptr()),
            tu, file, 1, 5,
        )

        var null_loc_storage = InlineArray[CXSourceLocation, 1](
            fill=CXSourceLocation(ptr_data0=None, ptr_data1=None, int_data=c_uint(0)),
        )
        clang_getNullLocation_ref(
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](null_loc_storage.unsafe_ptr()),
        )

        var equal_self = clang_equalLocations_ref(
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](loc_storage.unsafe_ptr()),
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](loc_storage.unsafe_ptr()),
        )
        _check(Bool(equal_self), "clang_equalLocations_ref(self, self) is false")

        var equal_null = clang_equalLocations_ref(
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](null_loc_storage.unsafe_ptr()),
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](null_loc_storage.unsafe_ptr()),
        )
        _check(Bool(equal_null), "clang_equalLocations_ref(null, null) is false")

        var equal_diff = clang_equalLocations_ref(
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](loc_storage.unsafe_ptr()),
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](null_loc_storage.unsafe_ptr()),
        )
        _check(not Bool(equal_diff), "clang_equalLocations_ref(loc, null) is true")

        return "self=" + String(equal_self) + ", null=" + String(equal_null) + ", diff=" + String(equal_diff)
    finally:
        clang_disposeTranslationUnit(tu)
        clang_disposeIndex(index)


def _probe_equal_ranges_via_shim() raises -> String:
    var index = clang_createIndex(0, 0)
    if not index:
        raise Error("clang_createIndex returned null")
    var path = String("test/raw_ffi_probe_fixture.c\00")
    var tu = _parse_file(index, path)
    try:
        var null_range_storage = InlineArray[CXSourceRange, 1](
            fill=CXSourceRange(ptr_data0=None, ptr_data1=None, begin_int_data=c_uint(0), end_int_data=c_uint(0)),
        )
        clang_getNullRange_into(
            rebind[UnsafePointer[CXSourceRange, MutExternalOrigin]](null_range_storage.unsafe_ptr()),
        )

        var equal_null = clang_equalRanges_ref(
            rebind[UnsafePointer[CXSourceRange, MutExternalOrigin]](null_range_storage.unsafe_ptr()),
            rebind[UnsafePointer[CXSourceRange, MutExternalOrigin]](null_range_storage.unsafe_ptr()),
        )
        _check(Bool(equal_null), "clang_equalRanges_ref(null, null) is false")

        var file = clang_getFile(tu, _as_c_string(path))
        if not file:
            raise Error("clang_getFile returned null")

        var start_loc = InlineArray[CXSourceLocation, 1](
            fill=CXSourceLocation(ptr_data0=None, ptr_data1=None, int_data=c_uint(0)),
        )
        var end_loc = InlineArray[CXSourceLocation, 1](
            fill=CXSourceLocation(ptr_data0=None, ptr_data1=None, int_data=c_uint(0)),
        )
        clang_getLocation_into(
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](start_loc.unsafe_ptr()),
            tu, file, 1, 1,
        )
        clang_getLocation_into(
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](end_loc.unsafe_ptr()),
            tu, file, 1, 5,
        )

        var range_storage = InlineArray[CXSourceRange, 1](
            fill=CXSourceRange(ptr_data0=None, ptr_data1=None, begin_int_data=c_uint(0), end_int_data=c_uint(0)),
        )
        clang_getRange_into(
            rebind[UnsafePointer[CXSourceRange, MutExternalOrigin]](range_storage.unsafe_ptr()),
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](start_loc.unsafe_ptr()),
            rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](end_loc.unsafe_ptr()),
        )

        var equal_self = clang_equalRanges_ref(
            rebind[UnsafePointer[CXSourceRange, MutExternalOrigin]](range_storage.unsafe_ptr()),
            rebind[UnsafePointer[CXSourceRange, MutExternalOrigin]](range_storage.unsafe_ptr()),
        )
        _check(Bool(equal_self), "clang_equalRanges_ref(range, range) is false")

        var equal_diff = clang_equalRanges_ref(
            rebind[UnsafePointer[CXSourceRange, MutExternalOrigin]](range_storage.unsafe_ptr()),
            rebind[UnsafePointer[CXSourceRange, MutExternalOrigin]](null_range_storage.unsafe_ptr()),
        )
        _check(not Bool(equal_diff), "clang_equalRanges_ref(range, null) is true")

        return "null=" + String(equal_null) + ", self=" + String(equal_self) + ", diff=" + String(equal_diff)
    finally:
        clang_disposeTranslationUnit(tu)
        clang_disposeIndex(index)


def _record_success(mut worked: Int, name: String, expected: String, note: String):
    worked += 1
    print("[worked][" + expected + "] " + name + ": " + note)


def _record_failure(mut failed: Int, mut working_regressions: Int, mut unknown_failed: Int, name: String, expected: String, note: String):
    failed += 1
    if expected == EXPECT_WORKING:
        working_regressions += 1
    elif expected == EXPECT_UNKNOWN:
        unknown_failed += 1
    print("[failed][" + expected + "] " + name + ": " + note)


def main() raises:
    var worked = 0
    var failed = 0
    var unknown_failed = 0
    var working_regressions = 0

    try:
        _record_success(worked, "version-string", EXPECT_WORKING, _probe_version_string())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "version-string", EXPECT_WORKING, String(e))

    try:
        _record_success(worked, "default-options", EXPECT_WORKING, _probe_default_options())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "default-options", EXPECT_WORKING, String(e))

    try:
        _record_success(worked, "null-struct-returns", EXPECT_KNOWN_BROKEN, _probe_null_struct_returns())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "null-struct-returns", EXPECT_KNOWN_BROKEN, String(e))

    try:
        _record_success(worked, "null-cursor-metadata", EXPECT_WORKING, _probe_null_cursor_metadata())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "null-cursor-metadata", EXPECT_WORKING, String(e))

    try:
        _record_success(worked, "parse-file-and-tu-cursor", EXPECT_WORKING, _probe_parse_file_and_tu_cursor())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "parse-file-and-tu-cursor", EXPECT_WORKING, String(e))

    try:
        _record_success(worked, "location-round-trip", EXPECT_WORKING, _probe_location_round_trip())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "location-round-trip", EXPECT_WORKING, String(e))

    try:
        _record_success(worked, "cursor-lookup-and-spelling", EXPECT_WORKING, _probe_cursor_lookup_and_spelling())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "cursor-lookup-and-spelling", EXPECT_WORKING, String(e))

    try:
        _record_success(worked, "tu-cursor-metadata", EXPECT_WORKING, _probe_tu_cursor_metadata())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "tu-cursor-metadata", EXPECT_WORKING, String(e))

    try:
        _record_success(worked, "tu-cursor-type-surface", EXPECT_WORKING, _probe_tu_cursor_type_surface())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "tu-cursor-type-surface", EXPECT_WORKING, String(e))

    try:
        _record_success(worked, "pointer-only-cursor-and-tokens", EXPECT_WORKING, _probe_pointer_only_cursor_and_tokens())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "pointer-only-cursor-and-tokens", EXPECT_WORKING, String(e))

    try:
        _record_success(worked, "diagnostics", EXPECT_WORKING, _probe_diagnostics())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "diagnostics", EXPECT_WORKING, String(e))

    try:
        _record_success(worked, "single-token-surface", EXPECT_WORKING, _probe_single_token_surface())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "single-token-surface", EXPECT_WORKING, String(e))

    try:
        _record_success(worked, "unsaved-parse", EXPECT_WORKING, _probe_unsaved_parse())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "unsaved-parse", EXPECT_WORKING, String(e))

    try:
        _record_success(worked, "visit-children", EXPECT_WORKING, _probe_visit_children())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "visit-children", EXPECT_WORKING, String(e))

    try:
        _record_success(worked, "tokenize", EXPECT_WORKING, _probe_tokenize())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "tokenize", EXPECT_WORKING, String(e))

    try:
        _record_success(worked, "equal-types-via-shim-ref", EXPECT_WORKING, _probe_equal_types_via_direct_dl())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "equal-types-via-shim-ref", EXPECT_WORKING, String(e))

    try:
        _record_success(worked, "equal-cursors-via-shim-ref", EXPECT_WORKING, _probe_equal_cursors_via_shim())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "equal-cursors-via-shim-ref", EXPECT_WORKING, String(e))

    try:
        _record_success(worked, "equal-locations-via-shim-ref", EXPECT_WORKING, _probe_equal_locations_via_shim())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "equal-locations-via-shim-ref", EXPECT_WORKING, String(e))

    try:
        _record_success(worked, "equal-ranges-via-shim-ref", EXPECT_WORKING, _probe_equal_ranges_via_shim())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "equal-ranges-via-shim-ref", EXPECT_WORKING, String(e))

    try:
        _record_success(worked, "shim-null-cursor", EXPECT_WORKING, _probe_shim_null_cursor())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "shim-null-cursor", EXPECT_WORKING, String(e))

    try:
        _record_success(worked, "shim-nonnull-cursor", EXPECT_WORKING, _probe_shim_nonnull_cursor())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "shim-nonnull-cursor", EXPECT_WORKING, String(e))

    print("")
    print("Probe summary:")
    print("  worked: " + String(worked))
    print("  failed: " + String(failed))
    print("  working regressions: " + String(working_regressions))
    print("  unknown failures: " + String(unknown_failed))

    if working_regressions > 0:
        raise Error("raw ffi probe runner found regressions in surfaces marked as working")

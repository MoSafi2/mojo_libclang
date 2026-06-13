from src.libclang_raw import (
    clang_File_isEqual,
    clang_File_tryGetRealPathName,
    clang_defaultEditingTranslationUnitOptions,
    clang_defaultSaveOptions,
    CXCursor,
    CXCursorKind,
    CXCursor_FirstInvalid,
    CXCursor_TranslationUnit,
    CXFile,
    CXIndex,
    CXSourceLocation,
    CXString,
    CXSourceRange,
    CXToken,
    CXTranslationUnit,
    CXTranslationUnit_None,
    CXUnsavedFile,
    clang_Range_isNull,
    clang_Range_isNull_ref,
    clang_createIndex,
    clang_disposeDiagnostic,
    clang_disposeIndex,
    clang_disposeString,
    clang_disposeTokens,
    clang_disposeTranslationUnit,
    clang_getCString,
    clang_getClangVersion,
    clang_getCursor,
    clang_getCursor_ref,
    clang_getCursorAvailability,
    clang_getCursorDefinition,
    clang_getCursorExtent,
    clang_getCursorKind,
    clang_getCursorKind_ref,
    clang_getCursorKindSpelling,
    clang_getCursorLexicalParent,
    clang_getCursorReferenced,
    clang_getCursorSemanticParent,
    clang_getCursorSpelling,
    clang_getCursorSpelling_ref,
    clang_getCursorType,
    clang_getDiagnostic,
    clang_getDiagnosticSpelling,
    clang_getFile,
    clang_getFileLocation,
    clang_getFileName,
    clang_getFileTime,
    clang_getLocation,
    clang_getLocation_into,
    clang_getRange,
    clang_getRange_into,
    clang_getNullCursor,
    clang_getNullLocation,
    clang_getNullRange,
    clang_getNullRange_into,
    clang_getNumDiagnostics,
    clang_getToken,
    clang_getToken_ref,
    clang_getTokenKind,
    clang_getTokenKind_ref,
    clang_getTokenExtent,
    clang_getTokenLocation,
    clang_getTokenSpelling,
    clang_getTokenSpelling_ref,
    clang_getTranslationUnitCursor,
    clang_getTranslationUnitSpelling,
    clang_getTypeSpelling,
    clang_getSpellingLocation,
    clang_getSpellingLocation_ref,
    clang_isDeclaration,
    clang_isExpression,
    clang_isInvalid,
    clang_isStatement,
    clang_parseTranslationUnit,
    clang_tokenize,
    clang_tokenize_ref,
)
from std.ffi import c_char, c_uint, c_ulong
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
    var value = String(c_string.value())
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
        var location = clang_getLocation(tu, file, 1, 5)
        var cursor = clang_getCursor(tu, location)
        var spelling = _cx_string_pointer_note(clang_getCursorSpelling(cursor))
        var kind = clang_getCursorKind(cursor)
        _check(not Bool(clang_isInvalid(kind)), "cursor from clang_getCursor had an invalid kind")
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
    raise Error("risky probe disabled in default runner: clang_getCursorType still crashes on the current cursor lookup path")


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
        var location = clang_getLocation(tu, file, 1, 1)
        var token = clang_getToken(tu, location)
        if not token:
            raise Error("clang_getToken returned null")
        var token_kind = clang_getTokenKind(token.value()[0])
        var spelling = _cx_string_pointer_note(clang_getTokenSpelling(tu, token.value()[0]))
        var token_location = clang_getTokenLocation(tu, token.value()[0])
        var token_extent = clang_getTokenExtent(tu, token.value()[0])
        _check(not Bool(clang_Range_isNull(token_extent)), "token extent came back as a null range")
        _ = token_location
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


def _probe_visit_children() raises -> String:
    raise Error("probe harness gap: need a verified Mojo C-ABI callback definition before clang_visitChildren can be exercised safely")


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

        var start = clang_getLocation(tu, file, 1, 1)
        var end = clang_getLocation(tu, file, 1, 23)
        var range = clang_getRange(start, end)
        var token_storage = InlineArray[Optional[UnsafePointer[CXToken, MutExternalOrigin]], 1](fill=None)
        var count_storage = InlineArray[c_uint, 1](fill=c_uint(0))

        clang_tokenize(
            tu,
            range,
            rebind[UnsafePointer[Optional[UnsafePointer[CXToken, MutExternalOrigin]], MutExternalOrigin]](token_storage.unsafe_ptr()),
            rebind[UnsafePointer[c_uint, MutExternalOrigin]](count_storage.unsafe_ptr()),
        )

        var token_count = count_storage[0]
        _check(token_count > 0, "clang_tokenize returned zero tokens")
        if not token_storage[0]:
            raise Error("clang_tokenize returned a null token buffer")

        try:
            var first = _cx_string_pointer_note(clang_getTokenSpelling(tu, token_storage[0].value()[0]))
            return "tokens=" + String(token_count) + ", first=" + first
        finally:
            clang_disposeTokens(tu, token_storage[0].value(), token_count)
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
        _record_success(worked, "location-round-trip", EXPECT_UNKNOWN, _probe_location_round_trip())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "location-round-trip", EXPECT_UNKNOWN, String(e))

    try:
        _record_success(worked, "cursor-lookup-and-spelling", EXPECT_KNOWN_BROKEN, _probe_cursor_lookup_and_spelling())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "cursor-lookup-and-spelling", EXPECT_KNOWN_BROKEN, String(e))

    try:
        _record_success(worked, "tu-cursor-metadata", EXPECT_WORKING, _probe_tu_cursor_metadata())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "tu-cursor-metadata", EXPECT_WORKING, String(e))

    try:
        _record_success(worked, "tu-cursor-type-surface", EXPECT_UNKNOWN, _probe_tu_cursor_type_surface())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "tu-cursor-type-surface", EXPECT_UNKNOWN, String(e))

    try:
        _record_success(worked, "pointer-only-cursor-and-tokens", EXPECT_WORKING, _probe_pointer_only_cursor_and_tokens())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "pointer-only-cursor-and-tokens", EXPECT_WORKING, String(e))

    try:
        _record_success(worked, "diagnostics", EXPECT_WORKING, _probe_diagnostics())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "diagnostics", EXPECT_WORKING, String(e))

    try:
        _record_success(worked, "single-token-surface", EXPECT_KNOWN_BROKEN, _probe_single_token_surface())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "single-token-surface", EXPECT_KNOWN_BROKEN, String(e))

    try:
        _record_success(worked, "unsaved-parse", EXPECT_WORKING, _probe_unsaved_parse())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "unsaved-parse", EXPECT_WORKING, String(e))

    try:
        _record_success(worked, "visit-children", EXPECT_UNKNOWN, _probe_visit_children())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "visit-children", EXPECT_UNKNOWN, String(e))

    try:
        _record_success(worked, "tokenize", EXPECT_UNKNOWN, _probe_tokenize())
    except e:
        _record_failure(failed, working_regressions, unknown_failed, "tokenize", EXPECT_UNKNOWN, String(e))

    print("")
    print("Probe summary:")
    print("  worked: " + String(worked))
    print("  failed: " + String(failed))
    print("  working regressions: " + String(working_regressions))
    print("  unknown failures: " + String(unknown_failed))

    if working_regressions > 0:
        raise Error("raw ffi probe runner found regressions in surfaces marked as working")

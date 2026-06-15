from src._ffi import (
    CXChildVisitResult,
    CXChildVisit_Continue,
    CXClientData,
    CXCursor,
    CXCursorKind,
    CXCursor_FirstInvalid,
    CXCursor_FunctionDecl,
    CXCursor_TranslationUnit,
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
    clang_Cursor_isNull,
    clang_createIndex,
    clang_defaultEditingTranslationUnitOptions,
    clang_disposeDiagnostic,
    clang_disposeIndex,
    clang_disposeString,
    clang_disposeTokens,
    clang_disposeTranslationUnit,
    clang_equalCursors,
    clang_equalLocations,
    clang_equalRanges,
    clang_equalTypes,
    clang_File_isEqual,
    clang_File_tryGetRealPathName,
    clang_getClangVersion,
    clang_getCString,
    clang_getCursor,
    clang_getCursorKind,
    clang_getCursorKindSpelling,
    clang_getCursorSpelling,
    clang_getCursorType,
    clang_getDiagnostic,
    clang_getDiagnosticSpelling,
    clang_getFile,
    clang_getFileName,
    clang_getFileTime,
    clang_getLocation,
    clang_getNullCursor,
    clang_getNullLocation,
    clang_getNullRange,
    clang_getNumDiagnostics,
    clang_getRange,
    clang_getSpellingLocation,
    clang_getTokenExtent,
    clang_getTokenKind,
    clang_getTokenLocation,
    clang_getTokenSpelling,
    clang_getTranslationUnitCursor,
    clang_getTranslationUnitSpelling,
    clang_getTypeSpelling,
    clang_isInvalid,
    clang_parseTranslationUnit,
    clang_Range_isNull,
    clang_tokenize,
    clang_visitChildren,
    c_char,
    c_int,
    c_uint,
    c_ulong,
)
from std.memory import UnsafePointer
from std.testing import assert_equal, assert_true, TestSuite


def _check(condition: Bool, message: String) raises:
    if not condition:
        raise Error(message)


def _as_c_string(text: String) -> UnsafePointer[c_char, ImmutExternalOrigin]:
    return rebind[UnsafePointer[c_char, ImmutExternalOrigin]](text.unsafe_ptr())


def _cxstring_zero() -> CXString:
    return CXString(data=None, private_flags=c_uint(0))


def _alloc_cxstring() -> UnsafePointer[CXString, MutAnyOrigin]:
    var storage = alloc[CXString](1)
    storage[] = _cxstring_zero()
    return storage


def _cxstring_ptr(
    storage: UnsafePointer[CXString, MutAnyOrigin],
) -> UnsafePointer[CXString, MutExternalOrigin]:
    return rebind[UnsafePointer[CXString, MutExternalOrigin]](storage)


def _take_cxstring(
    ptr: UnsafePointer[CXString, MutExternalOrigin]
) raises -> String:
    var c_string = clang_getCString(ptr)
    if not c_string:
        clang_disposeString(ptr)
        raise Error("libclang returned a null C string")
    var value = String(unsafe_from_utf8_ptr=c_string.value())
    clang_disposeString(ptr)
    return value


def _source_location_zero() -> CXSourceLocation:
    return CXSourceLocation(
        ptr_data=InlineArray[
            Optional[ImmutOpaquePointer[ImmutExternalOrigin]], 2
        ](fill=None),
        int_data=c_uint(0),
    )


def _source_location_ptr(
    mut storage: InlineArray[CXSourceLocation, 1],
) -> UnsafePointer[CXSourceLocation, MutExternalOrigin]:
    return rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](
        storage.unsafe_ptr(),
    )


def _source_range_zero() -> CXSourceRange:
    return CXSourceRange(
        ptr_data=InlineArray[
            Optional[ImmutOpaquePointer[ImmutExternalOrigin]], 2
        ](fill=None),
        begin_int_data=c_uint(0),
        end_int_data=c_uint(0),
    )


def _source_range_ptr(
    mut storage: InlineArray[CXSourceRange, 1],
) -> UnsafePointer[CXSourceRange, MutExternalOrigin]:
    return rebind[UnsafePointer[CXSourceRange, MutExternalOrigin]](
        storage.unsafe_ptr(),
    )


def _cursor_zero() -> CXCursor:
    return CXCursor(
        kind=CXCursorKind(c_uint(0)),
        xdata=c_int(0),
        data=InlineArray[Optional[ImmutOpaquePointer[ImmutExternalOrigin]], 3](
            fill=None
        ),
    )


def _cursor_ptr(
    mut storage: InlineArray[CXCursor, 1],
) -> UnsafePointer[CXCursor, MutExternalOrigin]:
    return rebind[UnsafePointer[CXCursor, MutExternalOrigin]](
        storage.unsafe_ptr()
    )


def _type_zero() -> CXType:
    return CXType(
        kind=CXTypeKind(c_uint(0)),
        data=InlineArray[Optional[MutOpaquePointer[MutExternalOrigin]], 2](
            fill=None
        ),
    )


def _type_ptr(
    mut storage: InlineArray[CXType, 1],
) -> UnsafePointer[CXType, MutExternalOrigin]:
    return rebind[UnsafePointer[CXType, MutExternalOrigin]](
        storage.unsafe_ptr()
    )


def _parse_file(
    index: CXIndex, path_storage: String
) raises -> CXTranslationUnit:
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


def test_version_string() raises:
    var version = _alloc_cxstring()
    clang_getClangVersion(_cxstring_ptr(version))
    var text = _take_cxstring(_cxstring_ptr(version))
    version.free()
    _check(text.byte_length() > 0, "clang version string was empty")



def test_null_aggregates() raises:
    var loc = InlineArray[CXSourceLocation, 1](fill=_source_location_zero())
    var range = InlineArray[CXSourceRange, 1](fill=_source_range_zero())
    var cursor = InlineArray[CXCursor, 1](fill=_cursor_zero())

    clang_getNullLocation(_source_location_ptr(loc))
    clang_getNullRange(_source_range_ptr(range))
    clang_getNullCursor(_cursor_ptr(cursor))

    _check(
        Bool(clang_Range_isNull(_source_range_ptr(range))),
        "null range was not null",
    )
    _check(
        Bool(clang_Cursor_isNull(_cursor_ptr(cursor))),
        "null cursor was not null",
    )
    _check(
        clang_getCursorKind(_cursor_ptr(cursor)) == CXCursor_FirstInvalid,
        "null cursor kind was not CXCursor_FirstInvalid",
    )



def test_parse_file_and_strings() raises:
    var index = clang_createIndex(0, 0)
    if not index:
        raise Error("clang_createIndex returned null")
    var path = String("test/fixtures/raw_ffi_probe_fixture.c\00")
    var tu = _parse_file(index, path)
    try:
        _check(clang_getNumDiagnostics(tu) == 0, "expected zero diagnostics")
        var file = clang_getFile(tu, _as_c_string(path))
        if not file:
            raise Error("clang_getFile returned null")

        var file_name = _alloc_cxstring()
        var real_path = _alloc_cxstring()
        var tu_spelling = _alloc_cxstring()
        clang_getFileName(_cxstring_ptr(file_name), file)
        clang_File_tryGetRealPathName(_cxstring_ptr(real_path), file)
        clang_getTranslationUnitSpelling(_cxstring_ptr(tu_spelling), tu)

        var file_time = clang_getFileTime(file)
        _check(Bool(clang_File_isEqual(file, file)), "file equality failed")
        file_name.free()
        real_path.free()
        tu_spelling.free()
    finally:
        clang_disposeTranslationUnit(tu)
        clang_disposeIndex(index)


def test_cursor_lookup_type_and_spelling() raises:
    var index = clang_createIndex(0, 0)
    if not index:
        raise Error("clang_createIndex returned null")
    var path = String("test/fixtures/raw_ffi_probe_fixture.c\00")
    var tu = _parse_file(index, path)
    try:
        var file = clang_getFile(tu, _as_c_string(path))
        if not file:
            raise Error("clang_getFile returned null")

        var loc = InlineArray[CXSourceLocation, 1](fill=_source_location_zero())
        var cursor = InlineArray[CXCursor, 1](fill=_cursor_zero())
        var typ = InlineArray[CXType, 1](fill=_type_zero())
        var cursor_name = _alloc_cxstring()
        var type_name = _alloc_cxstring()

        clang_getLocation(_source_location_ptr(loc), tu, file, 1, 5)
        clang_getCursor(_cursor_ptr(cursor), tu, _source_location_ptr(loc))
        var kind = clang_getCursorKind(_cursor_ptr(cursor))
        _check(
            kind == CXCursor_FunctionDecl,
            "expected FunctionDecl at line 1 column 5",
        )

        clang_getCursorType(_type_ptr(typ), _cursor_ptr(cursor))
        _check(
            typ[0].kind != CXType_Invalid, "function cursor type was invalid"
        )
        clang_getCursorSpelling(_cxstring_ptr(cursor_name), _cursor_ptr(cursor))
        clang_getTypeSpelling(_cxstring_ptr(type_name), _type_ptr(typ))

        clang_disposeString(_cxstring_ptr(cursor_name))
        clang_disposeString(_cxstring_ptr(type_name))
        cursor_name.free()
        type_name.free()
    finally:
        clang_disposeTranslationUnit(tu)
        clang_disposeIndex(index)


def test_locations_ranges_and_tokens() raises:
    var index = clang_createIndex(0, 0)
    if not index:
        raise Error("clang_createIndex returned null")
    var path = String("test/fixtures/raw_ffi_probe_fixture.c\00")
    var tu = _parse_file(index, path)
    try:
        var file = clang_getFile(tu, _as_c_string(path))
        if not file:
            raise Error("clang_getFile returned null")

        var start = InlineArray[CXSourceLocation, 1](
            fill=_source_location_zero()
        )
        var end = InlineArray[CXSourceLocation, 1](fill=_source_location_zero())
        var range = InlineArray[CXSourceRange, 1](fill=_source_range_zero())
        var spelling_file = InlineArray[CXFile, 1](fill=None)
        var spelling_line = InlineArray[c_uint, 1](fill=c_uint(0))
        var spelling_column = InlineArray[c_uint, 1](fill=c_uint(0))
        var spelling_offset = InlineArray[c_uint, 1](fill=c_uint(0))

        clang_getLocation(_source_location_ptr(start), tu, file, 1, 1)
        clang_getLocation(_source_location_ptr(end), tu, file, 1, 23)
        clang_getRange(
            _source_range_ptr(range),
            _source_location_ptr(start),
            _source_location_ptr(end),
        )
        clang_getSpellingLocation(
            _source_location_ptr(start),
            rebind[UnsafePointer[CXFile, MutExternalOrigin]](
                spelling_file.unsafe_ptr()
            ),
            rebind[UnsafePointer[c_uint, MutExternalOrigin]](
                spelling_line.unsafe_ptr()
            ),
            rebind[UnsafePointer[c_uint, MutExternalOrigin]](
                spelling_column.unsafe_ptr()
            ),
            rebind[UnsafePointer[c_uint, MutExternalOrigin]](
                spelling_offset.unsafe_ptr()
            ),
        )
        _check(spelling_line[0] == 1, "spelling line mismatch")
        _check(spelling_column[0] == 1, "spelling column mismatch")

        var token_storage = InlineArray[
            Optional[UnsafePointer[CXToken, MutExternalOrigin]], 1
        ](fill=None)
        var token_count = InlineArray[c_uint, 1](fill=c_uint(0))
        clang_tokenize(
            tu,
            _source_range_ptr(range),
            rebind[
                UnsafePointer[
                    Optional[UnsafePointer[CXToken, MutExternalOrigin]],
                    MutExternalOrigin,
                ]
            ](
                token_storage.unsafe_ptr(),
            ),
            rebind[UnsafePointer[c_uint, MutExternalOrigin]](
                token_count.unsafe_ptr()
            ),
        )
        _check(token_count[0] > 0, "clang_tokenize returned zero tokens")
        if not token_storage[0]:
            raise Error("clang_tokenize returned null token buffer")

        try:
            var first = token_storage[0].value()
            var token_text = _alloc_cxstring()
            var token_loc = InlineArray[CXSourceLocation, 1](
                fill=_source_location_zero()
            )
            var token_extent = InlineArray[CXSourceRange, 1](
                fill=_source_range_zero()
            )
            var token_kind = clang_getTokenKind(first)
            clang_getTokenSpelling(_cxstring_ptr(token_text), tu, first)
            clang_getTokenLocation(_source_location_ptr(token_loc), tu, first)
            clang_getTokenExtent(_source_range_ptr(token_extent), tu, first)
            _check(
                not Bool(clang_Range_isNull(_source_range_ptr(token_extent))),
                "token extent was null",
            )
            clang_disposeString(_cxstring_ptr(token_text))
            token_text.free()
        finally:
            clang_disposeTokens(tu, token_storage[0].value(), token_count[0])
    finally:
        clang_disposeTranslationUnit(tu)
        clang_disposeIndex(index)


def test_equality() raises:
    var index = clang_createIndex(0, 0)
    if not index:
        raise Error("clang_createIndex returned null")
    var path = String("test/fixtures/raw_ffi_probe_fixture.c\00")
    var tu = _parse_file(index, path)
    try:
        var file = clang_getFile(tu, _as_c_string(path))
        if not file:
            raise Error("clang_getFile returned null")

        var loc = InlineArray[CXSourceLocation, 1](fill=_source_location_zero())
        var null_loc = InlineArray[CXSourceLocation, 1](
            fill=_source_location_zero()
        )
        var range = InlineArray[CXSourceRange, 1](fill=_source_range_zero())
        var null_range = InlineArray[CXSourceRange, 1](
            fill=_source_range_zero()
        )
        var cursor = InlineArray[CXCursor, 1](fill=_cursor_zero())
        var null_cursor = InlineArray[CXCursor, 1](fill=_cursor_zero())
        var typ = InlineArray[CXType, 1](fill=_type_zero())
        var invalid_type = InlineArray[CXType, 1](fill=_type_zero())

        clang_getLocation(_source_location_ptr(loc), tu, file, 1, 5)
        clang_getNullLocation(_source_location_ptr(null_loc))
        clang_getRange(
            _source_range_ptr(range),
            _source_location_ptr(loc),
            _source_location_ptr(loc),
        )
        clang_getNullRange(_source_range_ptr(null_range))
        clang_getCursor(_cursor_ptr(cursor), tu, _source_location_ptr(loc))
        clang_getNullCursor(_cursor_ptr(null_cursor))
        clang_getCursorType(_type_ptr(typ), _cursor_ptr(cursor))

        _check(
            Bool(
                clang_equalLocations(
                    _source_location_ptr(loc), _source_location_ptr(loc)
                )
            ),
            "location self equality failed",
        )
        _check(
            not Bool(
                clang_equalLocations(
                    _source_location_ptr(loc), _source_location_ptr(null_loc)
                )
            ),
            "location/null equality was true",
        )
        _check(
            Bool(
                clang_equalRanges(
                    _source_range_ptr(range), _source_range_ptr(range)
                )
            ),
            "range self equality failed",
        )
        _check(
            not Bool(
                clang_equalRanges(
                    _source_range_ptr(range), _source_range_ptr(null_range)
                )
            ),
            "range/null equality was true",
        )
        _check(
            Bool(clang_equalCursors(_cursor_ptr(cursor), _cursor_ptr(cursor))),
            "cursor self equality failed",
        )
        _check(
            Bool(
                clang_equalCursors(
                    _cursor_ptr(null_cursor), _cursor_ptr(null_cursor)
                )
            ),
            "null cursor equality failed",
        )
        _check(
            not Bool(
                clang_equalCursors(
                    _cursor_ptr(cursor), _cursor_ptr(null_cursor)
                )
            ),
            "cursor/null equality was true",
        )
        _check(
            Bool(clang_equalTypes(_type_ptr(typ), _type_ptr(typ))),
            "type self equality failed",
        )
        _check(
            not Bool(clang_equalTypes(_type_ptr(typ), _type_ptr(invalid_type))),
            "type/invalid equality was true",
        )

    finally:
        clang_disposeTranslationUnit(tu)
        clang_disposeIndex(index)


def test_diagnostics() raises:
    var index = clang_createIndex(0, 0)
    if not index:
        raise Error("clang_createIndex returned null")
    var path = String("test/fixtures/raw_ffi_probe_invalid.c\00")
    var tu = _parse_file(index, path)
    try:
        var count = clang_getNumDiagnostics(tu)
        _check(count > 0, "expected diagnostics for invalid fixture")
        var diagnostic = clang_getDiagnostic(tu, 0)
        if not diagnostic:
            raise Error("clang_getDiagnostic returned null")
        try:
            var spelling = _alloc_cxstring()
            clang_getDiagnosticSpelling(_cxstring_ptr(spelling), diagnostic)
            clang_disposeString(_cxstring_ptr(spelling))
            spelling.free()
        finally:
            clang_disposeDiagnostic(diagnostic)
    finally:
        clang_disposeTranslationUnit(tu)
        clang_disposeIndex(index)


def test_unsaved_parse() raises:
    var index = clang_createIndex(0, 0)
    if not index:
        raise Error("clang_createIndex returned null")

    var filename = String("test/fixtures/raw_ffi_probe_fixture.c\00")
    var content = String("int x = 42;")
    var unsaved = alloc[CXUnsavedFile](1)
    unsaved[].Filename = _as_c_string(filename)
    unsaved[].Contents = _as_c_string(content)
    unsaved[].Length = c_ulong(content.byte_length())

    var tu = clang_parseTranslationUnit(
        index,
        _as_c_string(filename),
        None,
        0,
        rebind[UnsafePointer[CXUnsavedFile, MutExternalOrigin]](unsaved),
        1,
        CXTranslationUnit_None,
    )
    unsaved.free()
    if not tu:
        clang_disposeIndex(index)
        raise Error(
            "clang_parseTranslationUnit returned null with unsaved file"
        )

    try:
        _check(
            clang_getNumDiagnostics(tu) == 0,
            "unsaved parse produced diagnostics",
        )
    finally:
        clang_disposeTranslationUnit(tu)
        clang_disposeIndex(index)


def _visit_child_callback(
    cursor: Optional[UnsafePointer[CXCursor, MutExternalOrigin]],
    parent: Optional[UnsafePointer[CXCursor, MutExternalOrigin]],
    client_data: CXClientData,
) abi("C") -> CXChildVisitResult:
    if not client_data:
        return CXChildVisit_Continue
    var count = rebind[UnsafePointer[c_uint, MutExternalOrigin]](
        client_data.value()
    )
    count[] = count[] + 1
    _ = cursor
    _ = parent
    return CXChildVisit_Continue


def test_visit_children() raises:
    var index = clang_createIndex(0, 0)
    if not index:
        raise Error("clang_createIndex returned null")
    var path = String("test/fixtures/raw_ffi_probe_fixture.c\00")
    var tu = _parse_file(index, path)
    try:
        var tu_cursor = InlineArray[CXCursor, 1](fill=_cursor_zero())
        var count = InlineArray[c_uint, 1](fill=c_uint(0))
        clang_getTranslationUnitCursor(_cursor_ptr(tu_cursor), tu)
        var result = clang_visitChildren(
            _cursor_ptr(tu_cursor),
            _visit_child_callback,
            Optional[UnsafePointer[NoneType, MutExternalOrigin]](
                rebind[UnsafePointer[NoneType, MutExternalOrigin]](
                    rebind[UnsafePointer[c_uint, MutExternalOrigin]](
                        count.unsafe_ptr()
                    ),
                ),
            ),
        )
        _check(result == 0, "clang_visitChildren returned non-zero")
        _check(count[0] > 0, "clang_visitChildren did not visit any children")
    finally:
        clang_disposeTranslationUnit(tu)
        clang_disposeIndex(index)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

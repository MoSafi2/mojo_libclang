/* Test-only C oracle. This library is never installed or distributed. */
#include <clang-c/Index.h>
#include <stddef.h>
#include <string.h>

void oracle_zero_callbacks(IndexerCallbacks *callbacks) {
    memset(callbacks, 0, sizeof(*callbacks));
}

static int markers[3];

CXCursor oracle_cursor(void) {
    CXCursor cursor = {CXCursor_FunctionDecl, -17, {&markers[0], &markers[1], &markers[2]}};
    return cursor;
}

int oracle_check_cursor(CXCursor cursor) {
    return cursor.kind == CXCursor_FunctionDecl && cursor.xdata == -17
        && cursor.data[0] == &markers[0] && cursor.data[1] == &markers[1]
        && cursor.data[2] == &markers[2];
}

CXType oracle_type(CXType value) { value.kind = CXType_Int; return value; }
CXString oracle_string(CXString value) { value.private_flags += 7; return value; }
CXSourceLocation oracle_location(CXSourceLocation value) { value.int_data += 3; return value; }
CXSourceRange oracle_range(CXSourceRange value) { value.end_int_data += 5; return value; }
CXToken oracle_token(CXToken value) { value.int_data[3] += 11; return value; }
CXIdxLoc oracle_idxloc(CXIdxLoc value) { value.int_data += 13; return value; }

int oracle_callback(CXCursor (*callback)(CXCursor, CXSourceRange, void *), void *context) {
    CXSourceRange range = {{&markers[0], &markers[2]}, 19, 37};
    CXCursor result = callback(oracle_cursor(), range, context);
    return oracle_check_cursor(result);
}

size_t oracle_size(unsigned kind) {
    switch (kind) {
    case 0: return sizeof(CXCursor);
    case 1: return sizeof(CXType);
    case 2: return sizeof(CXString);
    case 3: return sizeof(CXSourceLocation);
    case 4: return sizeof(CXSourceRange);
    case 5: return sizeof(CXToken);
    case 6: return sizeof(CXIdxLoc);
    case 7: return offsetof(CXCursor, data[2]);
    case 8: return offsetof(CXSourceLocation, int_data);
    case 9: return offsetof(CXToken, ptr_data);
    default: return 0;
    }
}

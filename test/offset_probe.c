#include <clang-c/Index.h>
#include <stdio.h>

static enum CXChildVisitResult find_pair(
    CXCursor cursor,
    CXCursor parent,
    CXClientData data
) {
    (void)parent;
    if (clang_getCursorKind(cursor) != CXCursor_StructDecl) {
        return CXChildVisit_Continue;
    }
    CXString spelling = clang_getCursorSpelling(cursor);
    const char *text = clang_getCString(spelling);
    if (text && text[0] == 'P' && text[1] == 'a' && text[2] == 'i' && text[3] == 'r' && text[4] == '\0') {
        *(CXCursor *)data = cursor;
        clang_disposeString(spelling);
        return CXChildVisit_Break;
    }
    clang_disposeString(spelling);
    return CXChildVisit_Continue;
}

int main(void) {
    CXIndex index = clang_createIndex(0, 0);
    CXTranslationUnit tu = clang_parseTranslationUnit(
        index,
        "test/type_test_fixture.c",
        NULL,
        0,
        NULL,
        0,
        CXTranslationUnit_None
    );
    if (!tu) {
        fprintf(stderr, "parse failed\n");
        return 1;
    }

    CXCursor root = clang_getTranslationUnitCursor(tu);
    CXCursor pair = clang_getNullCursor();
    clang_visitChildren(root, find_pair, &pair);
    if (clang_Cursor_isNull(pair)) {
        fprintf(stderr, "Pair cursor not found\n");
        return 1;
    }

    CXType pair_type = clang_getCursorType(pair);
    printf("kind=%u size=%lld align=%lld first=%lld second=%lld\n",
           pair_type.kind,
           clang_Type_getSizeOf(pair_type),
           clang_Type_getAlignOf(pair_type),
           clang_Type_getOffsetOf(pair_type, "first"),
           clang_Type_getOffsetOf(pair_type, "second"));

    clang_disposeTranslationUnit(tu);
    clang_disposeIndex(index);
    return 0;
}

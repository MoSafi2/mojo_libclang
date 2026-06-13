from src.libclang_raw import (
    clang_createIndex,
    clang_disposeIndex,
    clang_disposeString,
    clang_getCString,
    clang_getClangVersion,
    clang_getNullCursor,
    clang_getNullLocation,
    clang_getNullRange,
)


def _check(condition: Bool, message: String) raises:
    if not condition:
        raise Error(message)


def test_version_string() raises:
    var version = clang_getClangVersion()
    var c_string = clang_getCString(version)
    if not c_string:
        raise Error("clang_getClangVersion returned a null C string")
    clang_disposeString(version)


def test_index_lifecycle() raises:
    var index = clang_createIndex(0, 0)
    if not index:
        raise Error("clang_createIndex returned null")
    clang_disposeIndex(index)


def test_null_location_and_range() raises:
    var location = clang_getNullLocation()
    _ = location

    var range = clang_getNullRange()
    _ = range


def test_null_cursor() raises:
    var cursor = clang_getNullCursor()
    _ = cursor


def main() raises:
    test_version_string()
    test_index_lifecycle()
    test_null_location_and_range()
    test_null_cursor()
    print("libclang raw binding smoke test passed")

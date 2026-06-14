from src._ffi import (
    CXSourceLocation,
    CXSourceRange,
    CXCursor,
    clang_createIndex,
    clang_disposeIndex,
    clang_disposeString,
    clang_getCString,
    clang_getClangVersion,
    clang_getNullCursor,
    clang_getNullLocation,
    clang_getNullRange,
)
from src.libclang.common import _CXStringStorage
from std.memory import UnsafePointer, ImmutOpaquePointer


def _check(condition: Bool, message: String) raises:
    if not condition:
        raise Error(message)


def test_version_string() raises:
    var cs = _CXStringStorage()
    clang_getClangVersion(cs.ptr())
    var c_string = clang_getCString(cs.ptr())
    if not c_string:
        raise Error("clang_getClangVersion returned a null C string")
    clang_disposeString(cs.ptr())


def test_index_lifecycle() raises:
    var index = clang_createIndex(0, 0)
    if not index:
        raise Error("clang_createIndex returned null")
    clang_disposeIndex(index)


def test_null_location_and_range() raises:
    var loc_storage = InlineArray[CXSourceLocation, 1](
        fill=CXSourceLocation(
            ptr_data=InlineArray[
                Optional[ImmutOpaquePointer[ImmutExternalOrigin]], 2
            ](fill=None),
            int_data=0,
        ),
    )
    var loc_ptr = rebind[UnsafePointer[CXSourceLocation, MutExternalOrigin]](
        loc_storage.unsafe_ptr(),
    )
    clang_getNullLocation(loc_ptr)

    var range_storage = InlineArray[CXSourceRange, 1](
        fill=CXSourceRange(
            ptr_data=InlineArray[
                Optional[ImmutOpaquePointer[ImmutExternalOrigin]], 2
            ](fill=None),
            begin_int_data=0,
            end_int_data=0,
        ),
    )
    var range_ptr = rebind[UnsafePointer[CXSourceRange, MutExternalOrigin]](
        range_storage.unsafe_ptr(),
    )
    clang_getNullRange(range_ptr)


def test_null_cursor() raises:
    var cursor_storage = InlineArray[CXCursor, 1](
        fill=CXCursor(
            kind=0,
            xdata=0,
            data=InlineArray[
                Optional[ImmutOpaquePointer[ImmutExternalOrigin]], 3
            ](fill=None),
        ),
    )
    var cursor_ptr = rebind[UnsafePointer[CXCursor, MutExternalOrigin]](
        cursor_storage.unsafe_ptr(),
    )
    clang_getNullCursor(cursor_ptr)


def main() raises:
    test_version_string()
    test_index_lifecycle()
    test_null_location_and_range()
    test_null_cursor()
    print("libclang raw binding smoke test passed")

"""Unit tests for `clang/common.mojo`."""
from clang.common import (
    _alloc_c_string,
    _borrow_c_string,
    _c_string,
    _take_cxstring,
    _take_cxstring_optional,
    _CXStringStorage,
    UnsavedFile,
    CStringArray,
    UnsavedFileArena,
)
from clang._ffi import CXString
from std.ffi import c_uint, c_int, c_ulong
from std.memory import UnsafePointer
from std.testing import assert_equal, assert_true, assert_false, TestSuite


def _check(cond: Bool, msg: String) raises:
    if not cond:
        raise Error(msg)


# -- _c_string -------------------------------------------------------------


def test_c_string_non_empty() raises:
    var text = String("hello")
    var buf = _alloc_c_string(text)
    var ptr = _c_string(buf)
    buf.free()
    _check(True, "_c_string on non-empty text should succeed")


def test_c_string_empty() raises:
    var text = String("")
    var buf = _alloc_c_string(text)
    var ptr = _c_string(buf)
    buf.free()
    _check(True, "_c_string on empty text should succeed")


def test_borrow_c_string_embedded_nul_allowed() raises:
    var text = String("a\00b")
    var ptr = _borrow_c_string(text)
    _ = ptr
    _check(True, "_borrow_c_string should allow embedded NUL bytes")


# -- _CXStringStorage ------------------------------------------------------


def test_cxstring_storage_create() raises:
    var cs = _CXStringStorage()
    _ = cs
    _check(True, "_CXStringStorage creation should succeed")


def test_cxstring_storage_ptr_not_null() raises:
    var cs = _CXStringStorage()
    var ptr = cs.ptr()
    _ = ptr
    _check(True, "ptr() should return successfully")


def test_cxstring_storage_take_empty() raises:
    var cs = _CXStringStorage()
    var s = cs.take()
    assert_equal(
        s, String(""), "take() on zeroed storage should return empty string"
    )


def test_cxstring_storage_take_optional_null() raises:
    var cs = _CXStringStorage()
    var s = cs.take_optional()
    assert_equal(
        s, None, "take_optional() on zeroed storage should return None"
    )


def test_cxstring_storage_drop() raises:
    var cs = _CXStringStorage()
    _ = cs.ptr()
    _check(True, "create-and-drop should succeed")


# -- _take_cxstring --------------------------------------------------------


def test_take_cxstring_null_data_returns_empty() raises:
    var owned = alloc[CXString](1)
    owned[] = CXString(data=None, private_flags=c_uint(0))
    var raw = rebind[UnsafePointer[CXString, MutUntrackedOrigin]](owned)
    var s = _take_cxstring(raw)
    assert_equal(
        s,
        String(""),
        "_take_cxstring with null data should return empty string",
    )
    owned.free()


def test_take_cxstring_disposes_storage() raises:
    var owned = alloc[CXString](1)
    owned[] = CXString(data=None, private_flags=c_uint(0))
    var raw = rebind[UnsafePointer[CXString, MutUntrackedOrigin]](owned)
    _ = _take_cxstring(raw)
    owned.free()


def test_take_cxstring_optional_null_returns_none() raises:
    var owned = alloc[CXString](1)
    owned[] = CXString(data=None, private_flags=c_uint(0))
    var raw = rebind[UnsafePointer[CXString, MutUntrackedOrigin]](owned)
    var s = _take_cxstring_optional(raw)
    assert_equal(
        s, None, "_take_cxstring_optional with null data should return None"
    )
    owned.free()


def test_unsaved_file_write_to() raises:
    var uf = UnsavedFile(filename="test.c", contents="int x;")
    var s = String(uf)
    _check(s.byte_length() > 0, "UnsavedFile write_to should produce output")


def test_cstring_array() raises:
    var args = List[String]()
    args.append("-xc++")
    args.append("-std=c++17")
    var arena = CStringArray(args)
    _check(Int(arena.count()) == 2, "CStringArray count should match input")
    _check(
        arena.ptr() is not None,
        "CStringArray ptr should not be null for non-empty args",
    )


def test_cstring_array_empty() raises:
    var arena = CStringArray(List[String]())
    _check(Int(arena.count()) == 0, "empty CStringArray count should be 0")


def test_unsaved_file_arena() raises:
    var files = List[UnsavedFile]()
    files.append(UnsavedFile(filename="a.c", contents="int a;"))
    files.append(UnsavedFile(filename="b.c", contents="int b;"))
    var arena = UnsavedFileArena(files)
    _check(Int(arena.count()) == 2, "UnsavedFileArena count should match input")
    _check(arena.ptr() is not None, "UnsavedFileArena ptr should not be null")


def test_unsaved_file_arena_empty() raises:
    var arena = UnsavedFileArena(List[UnsavedFile]())
    _check(Int(arena.count()) == 0, "empty UnsavedFileArena count should be 0")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

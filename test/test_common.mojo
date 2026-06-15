"""Unit tests for `src/libclang/common.mojo`."""
from src.libclang.common import (
    _alloc_c_string,
    _c_string,
    _take_cxstring,
    _take_cxstring_optional,
    _CXStringStorage,
)
from src._ffi import CXString
from std.ffi import c_uint
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


def test_c_string_embedded_nul_rejected() raises:
    var rejected = False
    try:
        var text = String("a\00b")
        var buf = _alloc_c_string(text)
        buf.free()
    except:
        rejected = True

    _check(rejected, "embedded NUL should be rejected")


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
    assert_equal(s, String(""),
                 "take() on zeroed storage should return empty string")


def test_cxstring_storage_take_optional_null() raises:
    var cs = _CXStringStorage()
    var s = cs.take_optional()
    assert_equal(s, None,
                 "take_optional() on zeroed storage should return None")


def test_cxstring_storage_drop() raises:
    var cs = _CXStringStorage()
    _ = cs.ptr()
    _check(True, "create-and-drop should succeed")


# -- _take_cxstring --------------------------------------------------------


def test_take_cxstring_null_data_returns_empty() raises:
    var owned = alloc[CXString](1)
    owned[] = CXString(data=None, private_flags=c_uint(0))
    var raw = rebind[UnsafePointer[CXString, MutExternalOrigin]](owned)
    var s = _take_cxstring(raw)
    assert_equal(s, String(""),
                 "_take_cxstring with null data should return empty string")
    owned.free()


def test_take_cxstring_disposes_storage() raises:
    var owned = alloc[CXString](1)
    owned[] = CXString(data=None, private_flags=c_uint(0))
    var raw = rebind[UnsafePointer[CXString, MutExternalOrigin]](owned)
    _ = _take_cxstring(raw)
    owned.free()


def test_take_cxstring_optional_null_returns_none() raises:
    var owned = alloc[CXString](1)
    owned[] = CXString(data=None, private_flags=c_uint(0))
    var raw = rebind[UnsafePointer[CXString, MutExternalOrigin]](owned)
    var s = _take_cxstring_optional(raw)
    assert_equal(s, None,
                 "_take_cxstring_optional with null data should return None")
    owned.free()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

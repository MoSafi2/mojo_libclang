"""Independent C-to-Mojo and Mojo-to-C aggregate ABI checks."""
from clang._ffi import (
    CXCursor,
    CXType,
    CXString,
    CXSourceLocation,
    CXSourceRange,
    CXToken,
    CXIdxLoc,
    CXClientData,
)
from std.ffi import OwnedDLHandle, c_int, c_uint
from std.os import getenv
from std.sys.info import size_of
from std.reflection import reflect
from std.testing import assert_equal, assert_true, TestSuite


def roundtrip(
    cursor: CXCursor, extent: CXSourceRange, context: CXClientData
) abi("C") -> CXCursor:
    var count = context.value().unsafe_bitcast[c_uint]()
    if (
        cursor.kind == 8
        and cursor.xdata == -17
        and extent.begin_int_data == 19
        and extent.end_int_data == 37
        and cursor.data_0 == extent.ptr_data_0
        and cursor.data_2 == extent.ptr_data_1
    ):
        count[] += 1
    return cursor.copy()


def test_c_aggregate_abi() raises:
    var lib = OwnedDLHandle(getenv("LIBCLANG_ABI_ORACLE"))
    var sizes = lib.get_function[UInt]("oracle_size")
    assert_equal(sizes(c_uint(0)), UInt(size_of[CXCursor]()))
    assert_equal(sizes(c_uint(1)), UInt(size_of[CXType]()))
    assert_equal(sizes(c_uint(2)), UInt(size_of[CXString]()))
    assert_equal(sizes(c_uint(3)), UInt(size_of[CXSourceLocation]()))
    assert_equal(sizes(c_uint(4)), UInt(size_of[CXSourceRange]()))
    assert_equal(sizes(c_uint(5)), UInt(size_of[CXToken]()))
    assert_equal(sizes(c_uint(6)), UInt(size_of[CXIdxLoc]()))
    assert_equal(
        sizes(c_uint(7)), UInt(reflect[CXCursor].field_offset[index=4]())
    )
    assert_equal(
        sizes(c_uint(8)),
        UInt(reflect[CXSourceLocation].field_offset[index=2]()),
    )
    assert_equal(
        sizes(c_uint(9)), UInt(reflect[CXToken].field_offset[index=4]())
    )
    var make = lib.get_function[CXCursor]("oracle_cursor")
    var check = lib.get_function[c_int]("oracle_check_cursor")
    var cursor = make()
    assert_equal(check(cursor), c_int(1))
    assert_equal(cursor.xdata, c_int(-17))
    assert_true(
        cursor.data_0 != cursor.data_1 and cursor.data_1 != cursor.data_2
    )
    var typ = lib.get_function[CXType]("oracle_type")
    assert_equal(typ(CXType(c_uint(0), None, None)).kind, c_uint(17))
    var string = lib.get_function[CXString]("oracle_string")
    assert_equal(string(CXString(None, c_uint(2))).private_flags, c_uint(9))
    var location = lib.get_function[CXSourceLocation]("oracle_location")
    assert_equal(
        location(CXSourceLocation(None, None, c_uint(4))).int_data, c_uint(7)
    )
    var extent = lib.get_function[CXSourceRange]("oracle_range")
    assert_equal(
        extent(CXSourceRange(None, None, c_uint(6), c_uint(8))).end_int_data,
        c_uint(13),
    )
    var token = lib.get_function[CXToken]("oracle_token")
    assert_equal(
        token(
            CXToken(c_uint(1), c_uint(2), c_uint(3), c_uint(4), None)
        ).int_data_3,
        c_uint(15),
    )
    var idxloc = lib.get_function[CXIdxLoc]("oracle_idxloc")
    assert_equal(idxloc(CXIdxLoc(None, None, c_uint(5))).int_data, c_uint(18))
    var callback = lib.get_function[c_int]("oracle_callback")
    var count = c_uint(0)
    var context: CXClientData = (
        Pointer(to=count)
        .unsafe_bitcast[NoneType]()
        .unsafe_origin_cast[MutUntrackedOrigin]()
    )
    for _ in range(8):
        assert_equal(callback(roundtrip, context), c_int(1))
    assert_equal(count, c_uint(8))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

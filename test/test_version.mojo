from clang._ffi import (
    CINDEX_VERSION,
    CINDEX_VERSION_MAJOR,
    CINDEX_VERSION_MINOR,
)
from clang.cindex import version, version_info
from std.testing import assert_equal, TestSuite


def _check(cond: Bool, msg: String = "") raises:
    if not cond:
        raise Error(msg)


def test_version_info() raises:
    var info = version_info()
    assert_equal(info.libclang_mojo_version, "0.1.0")
    assert_equal(info.generated_cindex_version_major, Int(CINDEX_VERSION_MAJOR))
    assert_equal(info.generated_cindex_version_minor, Int(CINDEX_VERSION_MINOR))
    assert_equal(info.generated_cindex_version, Int(CINDEX_VERSION))
    _check(
        info.runtime_clang_version.byte_length() > 0,
        "runtime clang version should be non-empty",
    )
    assert_equal(info.mojo_compiler_constraint, "=1.0.0b2")


def test_version_prints() raises:
    version()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

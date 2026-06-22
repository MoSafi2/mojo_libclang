"""Version reporting for libclang_mojo."""

from clang._ffi import (
    CINDEX_VERSION,
    CINDEX_VERSION_MAJOR,
    CINDEX_VERSION_MINOR,
    clang_getClangVersion,
)
from clang._metadata import LIBCLANG_MOJO_VERSION, MOJO_COMPILER_CONSTRAINT
from clang.common import _CXStringStorage


@fieldwise_init
struct LibclangMojoVersionInfo(Copyable, Movable, Writable):
    """Version information for the Mojo package, generated headers, and runtime."""

    var libclang_mojo_version: String
    var generated_cindex_version_major: Int
    var generated_cindex_version_minor: Int
    var generated_cindex_version: Int
    var runtime_clang_version: String
    var mojo_compiler_constraint: String


def version_info() raises -> LibclangMojoVersionInfo:
    """Return structured version information without printing."""
    var cs = _CXStringStorage()
    clang_getClangVersion(cs.ptr_for_out())
    return LibclangMojoVersionInfo(
        libclang_mojo_version=String(LIBCLANG_MOJO_VERSION),
        generated_cindex_version_major=Int(CINDEX_VERSION_MAJOR),
        generated_cindex_version_minor=Int(CINDEX_VERSION_MINOR),
        generated_cindex_version=Int(CINDEX_VERSION),
        runtime_clang_version=cs.take(),
        mojo_compiler_constraint=String(MOJO_COMPILER_CONSTRAINT),
    )


def version() raises:
    """Print package, generated CINDEX, runtime clang, and Mojo versions."""
    var info = version_info()
    print("libclang_mojo version:", info.libclang_mojo_version)
    print(
        "generated CINDEX version:",
        info.generated_cindex_version_major,
        ".",
        info.generated_cindex_version_minor,
        " (",
        info.generated_cindex_version,
        ")",
        sep="",
    )
    print("runtime clang version:", info.runtime_clang_version)
    print("Mojo compiler constraint:", info.mojo_compiler_constraint)

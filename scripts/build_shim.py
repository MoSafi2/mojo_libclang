#!/usr/bin/env python3
"""Build the native shim without rewriting the checked-in bindings."""

from generate_libclang_bindings import (
    DEFAULT_SHIM_OUT,
    build_shim,
    discover_clang_c_dir,
    discover_libclang_library,
    install_shim_for_loader,
)


if __name__ == "__main__":
    build_shim(
        discover_clang_c_dir().parent, discover_libclang_library(), DEFAULT_SHIM_OUT
    )
    install_shim_for_loader(DEFAULT_SHIM_OUT)

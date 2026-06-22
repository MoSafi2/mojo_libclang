#!/usr/bin/env bash
set -euo pipefail

prefix="${1:-dist/libclang_mojo-prefix}"
mkdir -p "${prefix}/lib" "${prefix}/lib/mojo"

cc_bin="${CC:-cc}"
include_dir="${CONDA_PREFIX:-.pixi/envs/default}/include"
lib_dir="${CONDA_PREFIX:-.pixi/envs/default}/lib"

if [[ "$(uname -s)" == "Darwin" ]]; then
  "${cc_bin}" -dynamiclib \
    -I"${include_dir}" -Ishim \
    -o "${prefix}/lib/libclang_mojo_shim.dylib" \
    shim/libclang_mojo_shim.c \
    -L"${lib_dir}" -lclang \
    -Wl,-rpath,"${lib_dir}"
else
  "${cc_bin}" -shared -fPIC \
    -I"${include_dir}" -Ishim \
    -o "${prefix}/lib/libclang_mojo_shim.so" \
    shim/libclang_mojo_shim.c \
    -L"${lib_dir}" -lclang \
    -Wl,-rpath,"${lib_dir}"
fi

mojo package clang -o "${prefix}/lib/mojo/clang.mojopkg"

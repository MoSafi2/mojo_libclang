#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: run_test.sh <mojo-file>" >&2
  exit 2
fi

file="$1"
root="$(cd "$(dirname "$0")/.." && pwd)"
clang_native="$root/.pixi/envs/default/lib/python3.14/site-packages/clang/native"
build_dir="$root/build"
bin_path="$build_dir/.pixi-test-bin"

python "$root/scripts/generate_libclang_bindings.py"
mojo build -I "$root" -I "$root/src" \
  -Xlinker -L"$build_dir" \
  -Xlinker -lclang_mojo_shim \
  -o "$bin_path" \
  "$file"
env LD_LIBRARY_PATH="$build_dir:$clang_native" "$bin_path"

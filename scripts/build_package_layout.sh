#!/usr/bin/env bash
set -euo pipefail

prefix="${1:-dist/libclang_mojo-prefix}"
mkdir -p "${prefix}/lib/mojo"
if compgen -G "${prefix}/lib/*clang*shim*" >/dev/null; then
  echo "error: stale shim in package prefix; choose a fresh output prefix" >&2
  exit 1
fi
mojo precompile clang -o "${prefix}/lib/mojo/clang.mojoc"

Vendored `clang-c` header snapshot used by `scripts/generate_libclang_bindings.py`.

Purpose:
- make raw binding and shim generation deterministic
- decouple coverage from the system LLVM package installed on the machine

Default behavior:
- the generator prefers `vendor/llvm-project-main-2026-06-16/clang-c`
- `LIBCLANG_HEADERS_DIR` can still override that for explicit experiments

Snapshot source:
- upstream: `llvm-project` `clang/include/clang-c`
- captured from GitHub `refs/heads/main` on `2026-06-16`

Why this exists:
- `/usr/lib/llvm-18/include/clang-c/Index.h` in the local environment was
  missing APIs that exist in the newer upstream header snapshot, so those APIs
  never entered the parsed CIR and could not be regenerated into `_ffi.mojo`
  or the shim.

# Repository Instructions

This repository generates direct Mojo C FFI bindings for LLVM libclang with
`mojo-bindgen`. Prefer Pixi tasks and run shell commands directly.

## Commands

- Generate bindings: `pixi run --locked generate` (alias: `generate-libclang`).
- Check deterministic generation twice: `pixi run --locked check-generated`.
- Full JIT, compiled, and focused -O0 tests: `pixi run --locked test`.
- Run a single ordinary wrapper test: `pixi run --locked run-test <test-file>`.
- The ABI/raw FFI tests need the test-only C oracle and traversal tests need
  generated fixtures; use the full runner.
- Build layout tests: `pixi run --locked build-test test/_ffi_layout_tests.mojo`.
- Build and verify installed layout: `pixi run --locked check-consumer`.
- Build native package: `pixi run --locked -e package build-recipe`.
- Verify binary package: `pixi run --locked -e package check-conda-consumer <package>`.

`clang/_ffi.mojo` is a library module: directly building it without a main
function is expected to fail. The public namespace is `clang.cindex`; do not
re-export all raw `clang_*` functions there.

## Generated files and ABI

`scripts/generate_libclang_bindings.py` generates `clang/_ffi.mojo`,
`clang/_metadata.mojo`, and `test/_ffi_layout_tests.mojo`. Never persist manual
changes to them without updating the deterministic generator.

The generator filters unrelated system-header APIs, then applies the
layout-only normalization in `scripts/direct_abi.py`. Actual libclang function
and callback signatures remain unchanged. Fixed arrays inside by-value records
are flattened into numbered typed fields so Mojo can derive RegisterPassable.
Keep scalar fields scalar and pointer fields typed; never replace pointers with
integer words. Preserve every C size, alignment, and field offset. Keep
bitfield-containing CXIndexOptions opaque. Retain aliases such as time_t when
needed, without bringing back unrelated system-header constants or wrappers.

There is no production C shim. `test/fixtures/abi_oracle.c` is an independent
test oracle, compiled into a temporary directory and never packaged.

The direct loader supports MOJO_BINDGEN_CLANG_LIBRARY_PATH and the generic
MOJO_BINDGEN_LIBRARY_PATH. Keep pointer origins and the cached library owner
alive through calls. Preserve wrapper ownership and reparse invalidation.

## Packaging and Git hygiene

Stable v0.2.0 targets Mojo 1.2.0 and libclang 18. Conda build 1 identifies
its shimless rebuild. Keep the recipe pinned to immutable tested source and
verify its runtime source matches the checkout before publishing.
When amending v0.2.0, replace its packages, manifest, bundle, and checksums and
retarget the existing tag to validated stable source. Keep release notes brief,
focused on package and source installation. The nightly prerelease on master
is a separate track.

Do not delete or revert user changes. When changing bindings, update the
generator and regenerate. Do not commit package outputs, cached environments,
or the test oracle's compiled library.

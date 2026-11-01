# Changelog

## 0.3.0-dev.20261031 - 2026-10-31

Shimless rebuild on 2026-11-01 (conda build 1):

- Remove the native shim and call libclang directly with its C ABI.
- Keep unsaved-file arena buffers alive through parse and reparse by returning an owner-borrowed pointer. Restore empty, large, Unicode, and multiple-file support.
- Remove the 4096-child traversal cap using a shared growable collector; iteration no longer truncates larger parents.
- Store wrapper records inline and consolidate value-based string ownership, removing synthetic pointer accessors and output slots.
- Restore by-value raw function and callback signatures while preserving `clang.cindex`.
- Normalize fixed-array record fields deterministically and verify C layouts and bidirectional aggregate calls.
- Test JIT and compiled executables on all three native platforms; package only the Mojo module and runtime dependencies.
- Replace the existing prerelease assets; build-0 consumers should refresh their manifest and lockfile.

- Pin Mojo nightly 1.3.0.dev2026103105 from the Modular nightly channel.
- Store translation-unit resource usage inline and borrow it with a tracked pointer, removing a heap allocation and redundant ownership flag.
- Keep the stable Mojo 1.2 release at v0.2.0 and codex/mojo-1.2.
- Use conda-compatible package version 0.3.0.dev20261031 for the nightly source release.

## 0.2.0 - 2026-10-31

- Target Mojo 1.2.0 exactly with libclang 18.
- Preserve pointer origins through generated FFI calls, including aggregate inputs, output slots, and borrowed C strings. Correct aggregate input constness and keep large structs behind the C shim.
- Adopt current Pointer, C-string span, explicit unsafe memory operations, and Optional pattern syntax. Share CXString and output-slot helpers.
- Provide locked source builds, external package consumer checks, repeatable binding generation, and native CI on Linux x86-64, Linux ARM64, and macOS ARM64.
- Distribute source releases; compiled Mojo modules must be rebuilt with the exact compiler in each release.

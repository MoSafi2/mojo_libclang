# Changelog

## 0.2.0 - 2026-10-31

- Backport the direct C FFI implementation and inline wrapper storage; remove the production native shim.
- Remove the 4096-child traversal cap across child lists, iteration, and preorder traversal.
- Keep unsaved-file buffers borrowed through parse/reparse calls, including empty, Unicode, and multi-file buffers.
- Validate source and installed packages at normal optimization and with focused -O0 regression checks.
- Target Mojo 1.2.0 exactly with libclang 18.
- Preserve pointer origins through generated FFI calls, including aggregate inputs, output slots, and borrowed C strings. Correct aggregate input constness.
- Adopt current Pointer, C-string span, explicit unsafe memory operations, and Optional pattern syntax. Share CXString and output-slot helpers.
- Provide locked source builds, external package consumer checks, repeatable binding generation, and native CI on Linux x86-64, Linux ARM64, and macOS ARM64.
- Distribute source releases; compiled Mojo modules must be rebuilt with the exact compiler in each release.

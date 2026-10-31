# Changelog

## 0.2.0 - 2026-10-31

- Target Mojo 1.2.0 exactly with libclang 18.
- Preserve pointer origins through generated FFI calls, including aggregate inputs, output slots, and borrowed C strings. Correct aggregate input constness and keep large structs behind the C shim.
- Adopt current Pointer, C-string span, explicit unsafe memory operations, and Optional pattern syntax. Share CXString and output-slot helpers.
- Provide locked source builds, external package consumer checks, repeatable binding generation, and native CI on Linux x86-64, Linux ARM64, and macOS ARM64.
- Distribute source releases; compiled Mojo modules must be rebuilt with the exact compiler in each release.

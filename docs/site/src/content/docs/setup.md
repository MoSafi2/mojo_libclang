---
title: Setup
description: Install the development environment and run local checks.
---

# Setup

Install the Pixi environment:

```bash
pixi install
```

Pixi pins `clangdev` and `libclang` to LLVM 18.x. Headers and the runtime
library come from the Pixi environment.

Run an example or test through the local shim:

```bash
pixi run run-test examples/parse_header_example.mojo
pixi run run-test test/test_translation_unit.mojo
```

For build-only checks:

```bash
pixi run build-test test/test_ffi.mojo
```

Build the documentation site locally:

```bash
pixi run -e docs docs
```

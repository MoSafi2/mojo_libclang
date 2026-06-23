---
title: Setup
description: Install mojo_libclang and run local checks.
---

# Setup

## Fresh System

Install Pixi:

```bash
curl -fsSL https://pixi.sh/install.sh | sh
```

Create a new project:

```bash
pixi init clang-demo
cd clang-demo
pixi workspace channel add conda-forge https://conda.modular.com/max https://repo.prefix.dev/modular-community
pixi add mojo libclang_mojo
```

`libclang_mojo` must be published in one of the configured channels before
Pixi can resolve it. The package installs the Mojo module as `clang` and
depends on the LLVM `libclang` shared library. Users do not need the `clang`
compiler executable or `clangdev` headers unless they are building from source.

Run a Mojo file that imports `clang.cindex`:

```bash
pixi run mojo run -I "$CONDA_PREFIX/lib/mojo" main.mojo
```

## From Source

Install the repository environment:

```bash
git clone https://github.com/MoSafi2/mojo_libclang.git
cd mojo_libclang
pixi install -e dev
```

Run the wrapper tests through the local shim:

```bash
pixi run -e dev run-test test/test_translation_unit.mojo
```

For build-only checks:

```bash
pixi run -e dev build-test test/_ffi_layout_tests.mojo
```

Build the documentation site locally:

```bash
pixi run -e docs docs
```

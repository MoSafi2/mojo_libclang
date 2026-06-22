# Modular Community Recipe Staging

This folder is a staging copy for a future PR to
`modular/modular-community`. Do not publish directly from this repository.

Before opening the PR:

1. Commit the package-ready source changes in this repository.
2. Replace `REPLACE_WITH_RELEASE_COMMIT_SHA` in `recipe.yaml` with that commit.
3. Copy this folder to `recipes/libclang_mojo/` in your fork of
   `modular/modular-community`.

The recipe installs conda package `libclang_mojo`, while the Mojo package name
is `clang`, so users import the public API with:

```mojo
from clang.cindex import Index, UnsavedFile
```

The raw generated ABI module remains internal at `clang._ffi` and should not be
used as the public API.

Platform status:

- `linux-64`, `linux-aarch64`, and `osx-arm64` match the current
  `modular/modular-community` build matrix.
- `osx-64` is not included because `mojo-compiler` is not currently available
  for that platform on the Modular channel.

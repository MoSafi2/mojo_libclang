#!/usr/bin/env python3
"""Verify repeatable generation, including the generator's compiled layout check."""

import argparse
import hashlib
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
OUTPUTS = (
    "clang/_ffi.mojo",
    "clang/_metadata.mojo",
    "test/_ffi_layout_tests.mojo",
    "shim/libclang_mojo_shim.h",
    "shim/libclang_mojo_shim.c",
)


def snapshot() -> dict[str, str]:
    return {
        name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
        for name in OUTPUTS
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--platform-local", action="store_true",
        help="Allow platform-specific C typedef names on the first generation.",
    )
    options = parser.parse_args()
    expected = snapshot()
    for iteration in range(2):
        subprocess.run(
            [sys.executable, "scripts/generate_libclang_bindings.py"],
            cwd=ROOT, check=True,
        )
        actual = snapshot()
        if iteration or not options.platform_local:
            changed = [name for name in OUTPUTS if actual[name] != expected[name]]
            if changed:
                raise SystemExit("Non-reproducible generated files: " + ", ".join(changed))
        expected = actual
    print("Both regeneration checks passed")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Install only the binary package and build/run a production-style consumer."""

import argparse
import os
from pathlib import Path
import subprocess
import tempfile
import tomllib

from conda_channel import write_channel
from check_consumer import SOURCE


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path)
    args = parser.parse_args()
    package = args.package.resolve(strict=True)
    config = tomllib.loads((Path(__file__).resolve().parents[1] / "pixi.toml").read_text())
    version = config["package"]["version"]
    compiler = config["dependencies"]["mojo"]
    modular_channel = next(channel for channel in config["workspace"]["channels"] if channel.startswith("https://conda.modular.com/"))
    env = os.environ.copy()
    outer_prefix = env.get("CONDA_PREFIX")
    if outer_prefix:
        env["PATH"] = os.pathsep.join(part for part in env["PATH"].split(os.pathsep) if not part.startswith(outer_prefix + os.sep))
    for name in (
        "CONDA_PREFIX", "MODULAR_HOME", "PIXI_PROJECT_MANIFEST", "PIXI_PROJECT_ROOT",
        "PIXI_ENVIRONMENT_NAME", "LD_LIBRARY_PATH", "DYLD_LIBRARY_PATH", "MOJO_PKG_PATH",
        "MOJO_BINDGEN_LIBRARY_PATH", "MOJO_BINDGEN_LIBCLANG_MOJO_SHIM_LIBRARY_PATH",
    ):
        env.pop(name, None)
    with tempfile.TemporaryDirectory(prefix="libclang-conda-production-") as temporary:
        root = Path(temporary)
        channel = root / "channel"
        records = write_channel([package], channel)
        platform = records[package.name]["subdir"]
        if records[package.name]["version"] != version:
            raise ValueError("Package version does not match this checkout")
        app = root / "application"
        app.mkdir()
        (app / "pixi.toml").write_text(
            '[workspace]\nname = "clang-production"\n'
            f'channels = ["{channel.as_uri()}", "{modular_channel}", "conda-forge"]\n'
            f'platforms = ["{platform}"]\n\n'
            f'[dependencies]\nlibclang_mojo = "=={version}"\n'
        )
        source = SOURCE.replace(
            '    print("External consumer passed:", info.libclang_mojo_version)',
            f'    assert_equal(info.libclang_mojo_version, "{version}")\n'
            f'    assert_equal(info.mojo_compiler_constraint, "{compiler}")\n'
            '    print("Production conda consumer passed:", info.libclang_mojo_version)',
        )
        (app / "main.mojo").write_text(source)
        for filename in ("api.c", "api.cpp"):
            (app / filename).write_text("int add(int a, int b) { return a + b; }\n")
        (app / "invalid.c").write_text("int broken = ;\n")
        subprocess.run(["pixi", "install"], cwd=app, env=env, check=True)
        subprocess.run(["pixi", "run", "mojo", "build", "main.mojo", "-o", "clang-application"], cwd=app, env=env, check=True)
        subprocess.run(["pixi", "run", "./clang-application"], cwd=app, env=env, check=True)


if __name__ == "__main__":
    main()

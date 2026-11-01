#!/usr/bin/env python3
"""Install only the binary package and build/run a production-style consumer."""

import argparse
import os
from pathlib import Path
import subprocess
import tempfile
import tomllib
import urllib.request
import hashlib
import platform as host_platform

from conda_channel import write_channel, validate_payload
from check_consumer import SOURCE


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path, nargs="?")
    parser.add_argument("--release-manifest", help="Verify the published Pixi manifest and its native package URL")
    args = parser.parse_args()
    if bool(args.package) == bool(args.release_manifest):
        parser.error("Supply either a package file or --release-manifest URL")
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
        "MOJO_BINDGEN_LIBRARY_PATH", "MOJO_BINDGEN_CLANG_LIBRARY_PATH",
    ):
        env.pop(name, None)
    with tempfile.TemporaryDirectory(prefix="libclang-conda-production-") as temporary:
        root = Path(temporary)
        app = root / "application"
        app.mkdir()
        if args.release_manifest:
            with urllib.request.urlopen(args.release_manifest, timeout=60) as response:
                manifest = response.read().decode()
            expected = Path(__file__).resolve().parents[1] / "packaging/consumers/v0.2.0/pixi.toml"
            if tomllib.loads(manifest) != tomllib.loads(expected.read_text()):
                raise ValueError("Published manifest differs from the checked-in release manifest")
            machine = host_platform.machine()
            platform = "osx-arm64" if host_platform.system() == "Darwin" else ("linux-aarch64" if machine in ("aarch64", "arm64") else "linux-64")
            dependency = tomllib.loads(manifest)["target"][platform]["dependencies"]["libclang_mojo"]
            with urllib.request.urlopen(dependency["url"], timeout=60) as response:
                data = response.read()
            if hashlib.sha256(data).hexdigest() != dependency["sha256"]:
                raise ValueError("Published package checksum mismatch")
            package = root / dependency["url"].rsplit("/", 1)[1]
            package.write_bytes(data)
            validate_payload(package)
            (app / "pixi.toml").write_text(manifest)
        else:
            package = args.package.resolve(strict=True)
            channel = root / "channel"
            records = write_channel([package], channel)
            platform = records[package.name]["subdir"]
            if records[package.name]["version"] != version:
                raise ValueError("Package version does not match this checkout")
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
            (app / filename).write_text("struct Point { int x; int y; };\nint add(int a, int b) { return a + b; }\n")
        (app / "invalid.c").write_text("int broken = ;\n")
        (app / "many_children.c").write_text("".join(f"int child_{i};\n" for i in range(5000)))
        subprocess.run(["pixi", "install"], cwd=app, env=env, check=True)
        if list((app / ".pixi/envs/default/lib").glob("*clang*shim*")):
            raise ValueError("Fresh consumer environment contains a native shim")
        subprocess.run(["pixi", "run", "mojo", "build", "main.mojo", "-o", "clang-application"], cwd=app, env=env, check=True)
        subprocess.run(["pixi", "run", "./clang-application"], cwd=app, env=env, check=True)


if __name__ == "__main__":
    main()

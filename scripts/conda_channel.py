#!/usr/bin/env python3
"""Assemble conda release assets and a dependency-resolving channel."""

import argparse
from compression import zstd
import hashlib
import io
import json
from pathlib import Path
import shutil
import tarfile
import zipfile


PLATFORMS = {"linux-64", "linux-aarch64", "osx-arm64"}


def package_record(path: Path) -> dict:
    with zipfile.ZipFile(path) as archive:
        members = [name for name in archive.namelist() if name.startswith("info-") and name.endswith(".tar.zst")]
        if len(members) != 1:
            raise ValueError(f"Expected one metadata archive: {path}")
        with tarfile.open(fileobj=io.BytesIO(zstd.decompress(archive.read(members[0])))) as metadata:
            record = json.load(metadata.extractfile("info/index.json"))
    data = path.read_bytes()
    return record | {
        "size": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
        "md5": hashlib.md5(data, usedforsecurity=False).hexdigest(),
    }


def validate_payload(path: Path) -> None:
    """Reject a production package that still contains the removed native shim."""
    with zipfile.ZipFile(path) as archive:
        members = [name for name in archive.namelist() if name.startswith("pkg-") and name.endswith(".tar.zst")]
        if len(members) != 1:
            raise ValueError(f"Expected one package archive: {path}")
        with tarfile.open(fileobj=io.BytesIO(zstd.decompress(archive.read(members[0])))) as payload:
            names = payload.getnames()
    if "lib/mojo/clang.mojoc" not in names:
        raise ValueError("Compiled clang module missing from package")
    if any("shim" in name.lower() for name in names):
        raise ValueError("Native shim found in package payload")
    record = package_record(path)
    if record["build_number"] != 1:
        raise ValueError("Expected shimless conda build 1")
    if any(dep.startswith("clangdev ") for dep in record["depends"]):
        raise ValueError("Header dependency leaked into runtime requirements")


def write_channel(packages: list[Path], directory: Path) -> dict[str, dict]:
    records = {}
    by_platform = {platform: {} for platform in PLATFORMS | {"noarch"}}
    versions = set()
    for package in packages:
        validate_payload(package)
        record = package_record(package)
        platform = record["subdir"]
        if record["name"] != "libclang_mojo" or platform not in PLATFORMS:
            raise ValueError(f"Unexpected release package: {package}")
        versions.add(record["version"])
        if len(versions) > 1:
            raise ValueError("All release packages must have the same version")
        if package.name in records or by_platform[platform]:
            raise ValueError(f"Duplicate release package/platform: {package}")
        destination = directory / platform / package.name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(package, destination)
        records[package.name] = record
        by_platform[platform][package.name] = record
    for platform, entries in by_platform.items():
        target = directory / platform / "repodata.json"
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps({
            "info": {"subdir": platform}, "repodata_version": 1,
            "packages": {}, "packages.conda": entries, "removed": [],
        }, indent=2) + "\n")
    return records


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("packages", nargs="+", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--tag", help="GitHub release tag; defaults to v plus the package version")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    version = package_record(args.packages[0])["version"]
    channel = args.output / f"libclang_mojo-{version}-channel"
    records = write_channel(args.packages, channel)
    if {record["subdir"] for record in records.values()} != PLATFORMS:
        raise SystemExit("All three native packages are required for publication")
    assets = []
    for package in args.packages:
        destination = args.output / package.name
        shutil.copy2(package, destination)
        assets.append(destination)
    bundle = args.output / f"libclang_mojo-{version}-conda-channel.tar.gz"
    with tarfile.open(bundle, "w:gz") as archive:
        archive.add(channel, arcname=channel.name)
    assets.append(bundle)
    tag = args.tag or "v" + version.replace(".dev", "-dev.")
    manifest = args.output / "pixi.toml"
    lines = [
        '[workspace]', 'name = "clang-app"',
        'channels = ["https://conda.modular.com/max", "conda-forge"]',
        'platforms = ["linux-64", "linux-aarch64", "osx-arm64"]',
        'requires-pixi = ">=0.80.0"',
    ]
    for platform in sorted(PLATFORMS):
        filename, record = next((name, value) for name, value in records.items() if value["subdir"] == platform)
        url = f"https://github.com/MoSafi2/mojo_libclang/releases/download/{tag}/{filename}"
        lines.extend(["", f"[target.{platform}.dependencies]",
                      f'libclang_mojo = {{ url = "{url}", sha256 = "{record["sha256"]}" }}'])
    manifest.write_text("\n".join(lines) + "\n")
    assets.append(manifest)
    (args.output / "SHA256SUMS").write_text("".join(
        f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n"
        for path in sorted(assets)
    ))
    print("Created release packages, channel bundle, Pixi manifest, and SHA256SUMS")


if __name__ == "__main__":
    main()

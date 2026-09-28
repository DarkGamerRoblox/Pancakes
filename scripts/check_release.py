from __future__ import annotations

import re
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_NAME = "darkgamerroblox/pancakes"
MANIFESTS = ("wally.toml", "pesde.toml", "ember.toml")


def load_toml(name: str) -> dict[str, object]:
    with (ROOT / name).open("rb") as file:
        return tomllib.load(file)


def package_info(name: str, data: dict[str, object]) -> tuple[str, str]:
    if name in {"wally.toml", "ember.toml"}:
        package = data["package"]
        assert isinstance(package, dict)
        return str(package["name"]), str(package["version"])

    return str(data["name"]), str(data["version"])


def main() -> int:
    versions: dict[str, str] = {}

    for manifest in MANIFESTS:
        package_name, version = package_info(manifest, load_toml(manifest))
        if package_name != EXPECTED_NAME:
            print(f"{manifest}: expected package name {EXPECTED_NAME!r}, got {package_name!r}")
            return 1
        versions[manifest] = version

    unique_versions = set(versions.values())
    if len(unique_versions) != 1:
        print(f"Manifest versions differ: {versions}")
        return 1

    version = unique_versions.pop()
    source = (ROOT / "src" / "init.luau").read_text(encoding="utf-8")
    match = re.search(r'Pancakes\.Version\s*=\s*"([^"]+)"', source)
    if match is None:
        print("src/init.luau: Pancakes.Version not found")
        return 1

    public_version = ".".join(version.split(".")[:2])
    if match.group(1) != public_version:
        print(f"Public version mismatch: expected {public_version!r}, got {match.group(1)!r}")
        return 1

    required = [
        ROOT / "src" / "Settings.luau",
        ROOT / "default.project.json",
        ROOT / "docs" / "index.html",
        ROOT / "LICENSE",
    ]
    missing = [str(path.relative_to(ROOT)) for path in required if not path.exists()]
    if missing:
        print("Missing required files:", ", ".join(missing))
        return 1

    print(f"Pancakes {version}: manifests, public version, package layout, and docs are in sync.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

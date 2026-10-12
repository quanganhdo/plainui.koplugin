#!/usr/bin/env python3
"""Build the installable plugin ZIP from an explicit set of release files."""

import argparse
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parents[1]
ROOT_FILES = ("_meta.lua", "main.lua", "README.md", "VERSION", "LICENSE")


def release_files():
    files = [ROOT / name for name in ROOT_FILES]
    files += sorted((ROOT / "modules").rglob("*.lua"))
    files += sorted(path for path in (ROOT / "icons").rglob("*") if path.is_file())
    # Full screenshot downloads are review assets; the guide's illustrations
    # remain available offline without duplicating that collection in the ZIP.
    files += sorted(path for path in (ROOT / "docs").rglob("*")
                    if path.is_file() and "full" not in path.relative_to(ROOT / "docs").parts)
    for path in files:
        if not path.is_file():
            raise FileNotFoundError(path)
    return files


def build(output):
    output = output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    files = release_files()
    with ZipFile(output, "w", ZIP_DEFLATED) as archive:
        for path in files:
            archive.write(path, "plainui.koplugin/" + path.relative_to(ROOT).as_posix())
    print(f"Built {output} ({len(files)} files)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    build(parser.parse_args().output)

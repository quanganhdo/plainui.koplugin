#!/usr/bin/env python3
"""Verify runtime dependencies and offline guide assets inside a release ZIP."""

import argparse
from html.parser import HTMLParser
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
PREFIX = "plainui.koplugin/"


class GuideLinks(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
        self.ids = set()

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if "id" in attrs:
            assert attrs["id"] not in self.ids, f"Duplicate guide ID: {attrs['id']}"
            self.ids.add(attrs["id"])
        for name in ("href", "src"):
            if name in attrs:
                self.links.append(attrs[name])


def check(archive_path):
    suites = {path.relative_to(ROOT).as_posix() for path in (ROOT / "tests").glob("*_test.lua")}
    scheduled = set(re.findall(r'tests/[\w]+_test\.lua', (ROOT / "tests/run.lua").read_text()))
    assert scheduled == suites, f"Test runner suite mismatch: {sorted(suites ^ scheduled)}"
    with ZipFile(archive_path) as archive:
        assert archive.testzip() is None, "Corrupt ZIP member"
        names = set(archive.namelist())
        assert all(name.startswith(PREFIX) and ".." not in Path(name).parts for name in names)
        assert not any(part in {".git", ".codegraph", "tests", "scripts", "__pycache__"}
                       for name in names for part in Path(name).parts), "Development files in release"
        expected = {PREFIX + name for name in ("main.lua", "_meta.lua", "VERSION", "README.md", "LICENSE")}
        expected |= {PREFIX + path.relative_to(ROOT).as_posix()
                     for path in (ROOT / "modules").rglob("*.lua")}
        expected |= {PREFIX + path.relative_to(ROOT).as_posix()
                     for path in (ROOT / "icons").rglob("*") if path.is_file()}
        assert expected <= names, f"Missing runtime files: {sorted(expected - names)}"
        for name in expected:
            assert archive.read(name) == (ROOT / name.removeprefix(PREFIX)).read_bytes(), name
        for name in names:
            if name.endswith(".lua"):
                source = archive.read(name).decode()
                for module in re.findall(r'require\s*\(?\s*["\'](modules\.[\w.]+)["\']', source):
                    dependency = PREFIX + module.replace(".", "/") + ".lua"
                    assert dependency in names, f"{name} requires missing {dependency}"
        version = archive.read(PREFIX + "VERSION").decode().strip()
        meta = archive.read(PREFIX + "_meta.lua").decode()
        assert re.search(r'version\s*=\s*["\']' + re.escape(version) + r'["\']', meta), "Version mismatch"
        guide = GuideLinks()
        guide.feed(archive.read(PREFIX + "docs/index.html").decode())
        for link in guide.links:
            parts = urlsplit(link)
            if parts.scheme or parts.netloc:
                continue
            if parts.path:
                assert PREFIX + "docs/" + unquote(parts.path) in names, f"Missing guide asset: {link}"
            elif parts.fragment:
                assert unquote(parts.fragment) in guide.ids, f"Missing guide anchor: {link}"
    print(f"Release verified: complete runtime, matching versions, and offline guide ({len(names)} files)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    check(parser.parse_args().archive)

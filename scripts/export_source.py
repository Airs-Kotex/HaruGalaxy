#!/usr/bin/env python3
"""Export tracked source into a single Windows-friendly project directory."""
from pathlib import Path
import hashlib
import json
import plistlib
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
NAME = "UiharuXPro4MilkyWay"
files = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0")
dist = ROOT / "dist"
dist.mkdir(exist_ok=True)
version = plistlib.loads((ROOT / "Resources/Info.plist").read_bytes())["CFBundleShortVersionString"]
output = dist / f"{NAME}-source-{version}.zip"
with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
    for name in files:
        if name:
            archive.write(ROOT / name, f"{NAME}/{name}")
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    archive.writestr(f"{NAME}/SOURCE_REVISION.json", json.dumps({"source_commit": revision}, indent=2) + "\n")
with zipfile.ZipFile(output) as archive:
    assert archive.testzip() is None
    assert f"{NAME}/README.md" in archive.namelist()
    assert f"{NAME}/scripts/build.py" in archive.namelist()
    assert not any("/.toolchain/" in name or "/.git/" in name for name in archive.namelist())
digest = hashlib.sha256(output.read_bytes()).hexdigest()
(dist / (output.name + ".sha256")).write_text(f"{digest}  {output.name}\n")
print(f"Source archive: {output}\nSHA-256: {digest}")

#!/usr/bin/env python3
"""Compile and run the same portable window model used by the iOS UI."""
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
build = ROOT / "build" / "tests"
build.mkdir(parents=True, exist_ok=True)
cc = os.environ.get("HOST_CC") or shutil.which("cc") or shutil.which("clang")
if not cc:
    raise SystemExit("A host C compiler (cc/clang) is required for Core tests.")
subprocess.run([cc, "-std=c11", "-Wall", "-Wextra", "-Werror", "-pedantic",
                "-fsanitize=undefined", "-I" + str(ROOT / "Sources/Core"),
                str(ROOT / "Sources/Core/MWWindowModel.c"),
                str(ROOT / "Tests/window_model_test.c"), "-lm", "-o", str(build / "window_model_test")], check=True)
subprocess.run([str(build / "window_model_test")], check=True)

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
subprocess.run([cc, "-D_POSIX_C_SOURCE=200809L", "-std=c11", "-Wall", "-Wextra", "-Werror", "-pedantic",
                "-fsanitize=undefined", "-I" + str(ROOT / "Sources/Core"),
                str(ROOT / "Sources/Core/MWLogStore.c"), str(ROOT / "Tests/log_store_test.c"),
                "-o", str(build / "log_store_test")], check=True)
subprocess.run([str(build / "log_store_test")], check=True)
subprocess.run([cc, "-std=c11", "-Wall", "-Wextra", "-Werror", "-pedantic",
                "-fsanitize=undefined", "-I" + str(ROOT / "Sources/Core"),
                str(ROOT / "Sources/Core/MWRuntimeTypes.c"), str(ROOT / "Tests/runtime_types_test.c"),
                "-o", str(build / "runtime_types_test")], check=True)
subprocess.run([str(build / "runtime_types_test")], check=True)
subprocess.run([cc, "-std=c11", "-Wall", "-Wextra", "-Werror", "-pedantic",
                "-fsanitize=undefined", "-I" + str(ROOT / "Sources/Core"),
                str(ROOT / "Sources/Core/MWOverlayStartup.c"), str(ROOT / "Tests/overlay_startup_test.c"),
                "-o", str(build / "overlay_startup_test")], check=True)
subprocess.run([str(build / "overlay_startup_test")], check=True)
subprocess.run([cc, "-std=c11", "-Wall", "-Wextra", "-Werror", "-pedantic",
                "-fsanitize=undefined", "-I" + str(ROOT / "Sources/Core"),
                str(ROOT / "Sources/Core/MWEdgeInteraction.c"), str(ROOT / "Tests/edge_interaction_test.c"),
                "-lm", "-o", str(build / "edge_interaction_test")], check=True)
subprocess.run([str(build / "edge_interaction_test")], check=True)
subprocess.run([cc, "-std=c11", "-Wall", "-Wextra", "-Werror", "-pedantic",
                "-fsanitize=undefined", "-I" + str(ROOT / "Sources/Core"),
                str(ROOT / "Sources/Core/MWSearchHandoff.c"), str(ROOT / "Tests/search_handoff_test.c"),
                "-o", str(build / "search_handoff_test")], check=True)
subprocess.run([str(build / "search_handoff_test")], check=True)
subprocess.run([cc, "-std=c11", "-Wall", "-Wextra", "-Werror", "-pedantic",
                "-fsanitize=undefined", "-I" + str(ROOT / "Sources/Core"),
                str(ROOT / "Sources/Core/MWNativeHandoff.c"), str(ROOT / "Tests/native_handoff_test.c"),
                "-o", str(build / "native_handoff_test")], check=True)
subprocess.run([str(build / "native_handoff_test")], check=True)
subprocess.run([cc, "-std=c11", "-Wall", "-Wextra", "-Werror", "-pedantic",
                "-fsanitize=undefined", "-I" + str(ROOT / "Sources/Core"),
                str(ROOT / "Sources/Core/MWKeyboardFocusState.c"), str(ROOT / "Tests/keyboard_focus_test.c"),
                "-o", str(build / "keyboard_focus_test")], check=True)
subprocess.run([str(build / "keyboard_focus_test")], check=True)
subprocess.run([cc, "-std=c11", "-Wall", "-Wextra", "-Werror", "-pedantic",
                "-fsanitize=undefined", "-I" + str(ROOT / "Sources/Core"),
                str(ROOT / "Sources/Core/MWSceneInputTarget.c"), str(ROOT / "Tests/scene_input_target_test.c"),
                "-o", str(build / "scene_input_target_test")], check=True)
subprocess.run([str(build / "scene_input_target_test")], check=True)
subprocess.run([os.environ.get("PYTHON", "python3"), "-m", "unittest", "discover", "-s", str(ROOT / "Tests"), "-p", "test_*.py", "-v"], check=True)

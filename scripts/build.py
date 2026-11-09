#!/usr/bin/env python3
"""Cross-compile, ad-hoc sign and package the native TrollStore application."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import plistlib
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
NAME = "HaruGalaxy"


def resolve_tool(value, candidates):
    if value:
        found = shutil.which(value)
        if found:
            return found
        raise SystemExit(f"Tool not found: {value}")
    for candidate in candidates:
        found = shutil.which(str(candidate))
        if found:
            return found
    raise SystemExit(f"Required tool missing; tried: {', '.join(map(str, candidates))}")


def run(args):
    subprocess.run([str(a) for a in args], cwd=ROOT, check=True)


def source_provenance():
    if (ROOT / ".git").exists() and shutil.which("git"):
        try:
            commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()
            dirty = bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip())
            return {"source_commit": commit, "source_dirty": dirty, "source_identity": "git"}
        except subprocess.CalledProcessError:
            pass
    metadata = ROOT / "SOURCE_REVISION.json"
    if metadata.is_file():
        try:
            saved = json.loads(metadata.read_text())
            return {"source_commit": saved.get("source_commit"), "source_dirty": None,
                    "source_identity": "archive metadata; local edits are not tracked"}
        except (OSError, ValueError):
            pass
    return {"source_commit": None, "source_dirty": None, "source_identity": "unversioned source"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdk", default=os.environ.get("IOS_SDK"))
    parser.add_argument("--clang", default=os.environ.get("IOS_CLANG"))
    parser.add_argument("--linker", default=os.environ.get("IOS_LD"))
    parser.add_argument("--ldid", default=os.environ.get("LDID"))
    args = parser.parse_args()
    sdk = args.sdk
    if not sdk and platform.system() == "Darwin":
        sdk = subprocess.check_output(["xcrun", "--sdk", "iphoneos", "--show-sdk-path"], text=True).strip()
    sdk = Path(sdk or ROOT / ".toolchain/iPhoneOS16.5.sdk").expanduser().resolve()
    if not (sdk / "System/Library/Frameworks/UIKit.framework/Headers/UIKit.h").exists():
        raise SystemExit(f"iPhoneOS SDK not found at {sdk}. See docs/build-environment.md.")
    compiler = resolve_tool(args.clang, ["clang" if platform.system() == "Darwin" else "clang-14", "clang"])
    linker = resolve_tool(args.linker, ["ld" if platform.system() == "Darwin" else "ld64.lld-14", "ld64.lld"])
    signer = resolve_tool(args.ldid, [ROOT / ".toolchain/ldid", "ldid"])
    info = plistlib.loads((ROOT / "Resources/Info.plist").read_bytes())
    deployment = info["MinimumOSVersion"]
    sdk_settings = sdk / "SDKSettings.plist"
    sdk_version = plistlib.loads(sdk_settings.read_bytes()).get("Version", "16.5") if sdk_settings.exists() else "16.5"
    build = ROOT / "build/ios"
    objects_dir = build / "objects"
    app = build / "Payload" / (NAME + ".app")
    # These are generated directories owned by this script; remove stale inputs.
    for directory in [objects_dir, app]:
        if directory.exists():
            shutil.rmtree(directory)
        directory.mkdir(parents=True)
    sources = sorted((ROOT / "Sources").rglob("*.m")) + sorted((ROOT / "Sources/Core").glob("*.c"))
    sources.append(ROOT / "ThirdParty/CompilerRT/os_version_check.c")
    objects = []
    common = ["-target", f"arm64-apple-ios{deployment}", "-isysroot", str(sdk), "-O2", "-fvisibility=hidden",
              "-Wall", "-Wextra", "-Werror", "-Wno-deprecated-declarations", "-fstack-protector-strong"]
    for source in sources:
        obj = objects_dir / ("_".join(source.relative_to(ROOT).parts) + ".o")
        language_flags = ["-fobjc-arc", "-fblocks", "-fobjc-exceptions"] if source.suffix == ".m" else ["-std=c11"]
        print("Compile", source.relative_to(ROOT), flush=True)
        run([compiler, *common, *language_flags, "-c", source, "-o", obj])
        objects.append(obj)
    executable = app / NAME
    run([linker, "-arch", "arm64", "-platform_version", "ios", deployment, str(sdk_version),
         "-syslibroot", sdk, "-pie", "-o", executable, *objects, "-lSystem", "-lobjc",
         "-framework", "Foundation", "-framework", "UIKit", "-framework", "QuartzCore",
         "-framework", "CoreFoundation", "-framework", "CoreGraphics"])
    executable.chmod(0o755)
    for resource in (ROOT / "Resources").iterdir():
        if resource.name == "entitlements.plist" or resource.suffix == ".svg":
            continue
        if resource.is_file():
            shutil.copy2(resource, app / resource.name)
        elif resource.is_dir() and resource.suffix == ".lproj":
            shutil.copytree(resource, app / resource.name)
    for name in ["LICENSE", "NOTICE.md"]:
        shutil.copy2(ROOT / name, app / name)
    shutil.copy2(ROOT / "ThirdParty/CompilerRT/LICENSE.TXT", app / "CompilerRT-LICENSE.txt")
    run([signer, "-S" + str(ROOT / "Resources/entitlements.plist"), executable])
    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    package = dist / f"{NAME}-{info['CFBundleShortVersionString']}.tipa"
    temporary = package.with_suffix(".tipa.tmp")
    with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(app.rglob("*")):
            if path.is_file():
                archive.write(path, path.relative_to(build))
    temporary.replace(package)
    run([os.environ.get("PYTHON", "python3"), ROOT / "scripts/verify_package.py", package])
    digest = hashlib.sha256(package.read_bytes()).hexdigest()
    (dist / (package.name + ".sha256")).write_text(f"{digest}  {package.name}\n")
    report = {"package": package.name, "sha256": digest, "bytes": package.stat().st_size,
              "compiler": subprocess.check_output([compiler, "--version"], text=True).splitlines()[0],
              "linker": linker, "sdk": str(sdk), "sdk_version": sdk_version,
              "deployment_target": deployment, "architecture": "arm64", "device_tested": False,
              **source_provenance()}
    (dist / "build-report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"Package: {package}\nSHA-256: {digest}\nDevice testing: NOT RUN")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Validate the packaged Mach-O, entitlements and install metadata (offline)."""
from pathlib import Path
import plistlib
import struct
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
NAME = "HaruGalaxy"


def verify(path):
    expected_info = plistlib.loads((ROOT / "Resources/Info.plist").read_bytes())
    with zipfile.ZipFile(path) as archive:
        prefix = f"Payload/{NAME}.app/"
        assert all(name.startswith(prefix) for name in archive.namelist()), "Unexpected package path"
        assert archive.testzip() is None, "Corrupt zip member"
        info = plistlib.loads(archive.read(prefix + "Info.plist"))
        assert info["CFBundleIdentifier"] == "io.github.airskotex.harugalaxy", "Wrong bundle ID"
        assert info["CFBundleExecutable"] == NAME
        assert info["CFBundleDisplayName"] == "初春星河" and info["CFBundleName"] == "HaruGalaxy"
        assert '"初春星河"' in archive.read(prefix + "zh-Hans.lproj/InfoPlist.strings").decode()
        assert '"HaruGalaxy"' in archive.read(prefix + "en.lproj/InfoPlist.strings").decode()
        assert info["MinimumOSVersion"] == expected_info["MinimumOSVersion"]
        assert info["CFBundleShortVersionString"] == expected_info["CFBundleShortVersionString"]
        assert info["CFBundleVersion"] == expected_info["CFBundleVersion"]
        assert isinstance(info.get("NSMotionUsageDescription"), str) and info["NSMotionUsageDescription"].strip()
        assert info["UIDeviceFamily"] == [1, 2]
        assert "UIInterfaceOrientationPortrait" in info["UISupportedInterfaceOrientations"]
        assert set(info["UISupportedInterfaceOrientations~ipad"]) == {
            "UIInterfaceOrientationPortrait", "UIInterfaceOrientationPortraitUpsideDown",
            "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"}
        assert archive.getinfo(prefix + NAME).external_attr >> 16 & 0o111, "Executable mode missing"
        for resource in ["LICENSE", "NOTICE.md", "AppIcon60x60@2x.png", "AppIcon60x60@3x.png", "AppIcon76x76@2x.png"]:
            assert len(archive.read(prefix + resource)) > 0, "Missing resource: " + resource
        binary = archive.read(prefix + NAME)
    assert binary[:4] == bytes.fromhex("cffaedfe"), "Expected a thin little-endian 64-bit Mach-O"
    cpu, subtype, file_type, ncmds, sizeofcmds = struct.unpack_from("<IIIII", binary, 4)
    assert cpu == 0x0100000C and file_type == 2, "Expected an arm64 executable"
    assert sizeofcmds + 32 <= len(binary)
    cursor = 32
    signature = None
    platform_ok = False
    dependencies = []
    for _ in range(ncmds):
        command, size = struct.unpack_from("<II", binary, cursor)
        assert size >= 8 and cursor + size <= 32 + sizeofcmds
        if command == 0x32:
            platform_id, minimum, sdk = struct.unpack_from("<III", binary, cursor + 8)
            components = [int(value) for value in expected_info["MinimumOSVersion"].split(".")]
            components += [0] * (3 - len(components))
            expected_minimum = components[0] << 16 | components[1] << 8 | components[2]
            platform_ok = platform_id == 2 and minimum == expected_minimum
        elif command == 0x1D:
            offset, length = struct.unpack_from("<II", binary, cursor + 8)
            signature = binary[offset:offset + length]
            assert len(signature) == length
        elif command in (0xC, 0x80000018, 0x8000001F):
            offset = struct.unpack_from("<I", binary, cursor + 8)[0]
            dependencies.append(binary[cursor + offset:cursor + size].split(b"\0")[0].decode())
        cursor += size
    assert platform_ok, "Missing expected iOS deployment command"
    assert signature and len(signature) >= 12, "Missing signature blob"
    magic, size, count = struct.unpack_from(">III", signature)
    assert magic == 0xFADE0CC0 and size <= len(signature)
    entitlements = None
    code_directory = False
    for index in range(count):
        slot, offset = struct.unpack_from(">II", signature, 12 + 8 * index)
        blob_magic, length = struct.unpack_from(">II", signature, offset)
        assert offset + length <= len(signature)
        if blob_magic == 0xFADE0C02:
            code_directory = True
        if blob_magic == 0xFADE7171:
            entitlements = plistlib.loads(signature[offset + 8:offset + length])
    expected = plistlib.loads((ROOT / "Resources/entitlements.plist").read_bytes())
    assert code_directory and entitlements == expected, "Signed entitlements do not match project"
    # Explicit guest Close now uses an original-process-handle termination
    # request; automatic teardown and display-mode reopen do not.
    assert entitlements.get("com.apple.runningboard.terminateprocess") is True
    assert "com.apple.runningboard.terminatemanagedprocesses" not in entitlements
    assert any("UIKit.framework" in dependency for dependency in dependencies)
    assert any("CoreMotion.framework" in dependency for dependency in dependencies)
    print(f"PASS: {path.name}: package layout, plist, arm64/iOS {info['MinimumOSVersion']}, signature structure, entitlements and resources")
    print("Offline checks do not prove installation, entitlements being granted, or runtime compatibility.")


if __name__ == "__main__":
    if len(sys.argv) > 2:
        raise SystemExit("Usage: python3 scripts/verify_package.py [path/to/app.tipa]")
    version = plistlib.loads((ROOT / "Resources/Info.plist").read_bytes())["CFBundleShortVersionString"]
    verify(Path(sys.argv[1]) if len(sys.argv)==2 else ROOT / "dist" / f"{NAME}-{version}.tipa")

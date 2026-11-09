# HaruGalaxy · 初春星河

[简体中文](README.md) · [Releases](https://github.com/Airs-Kotex/HaruGalaxy/releases) · [Issues](https://github.com/Airs-Kotex/HaruGalaxy/issues)

An experimental native multi-window workspace for TrollStore. HaruGalaxy hosts installed applications through FrontBoard scenes and provides movable windows, an edge window panel, free/original-aspect resizing, half-screen snapping, and local diagnostic exports.

**Version 0.3.1 is an alpha.** A user confirmed background floating use with 0.2.2 on iPhone 14 Pro Max / iOS 16.2. New keyboard and gesture behavior still requires device verification. Compilation and interface availability do not prove universal runtime compatibility.

## Install

Download `HaruGalaxy-0.3.1.tipa` from [Releases](https://github.com/Airs-Kotex/HaruGalaxy/releases) and install it with [TrollStore](https://github.com/opa334/TrollStore). Test an app inside HaruGalaxy before enabling the floating workspace.

The bundle identifier is now `io.github.airskotex.harugalaxy`. iOS installs it separately from the previous identifier; preferences and diagnostic logs do not migrate automatically. The app displays as 初春星河 in Simplified Chinese and HaruGalaxy in English.

## Controls

| Gesture | Behavior |
| --- | --- |
| Tap the edge tab | Toggle the window panel |
| Hold the tab for 0.35 seconds, then drag | Reposition the tab without opening the panel |
| Tap outside the panel | Close it; consume that tap |
| Drag a title bar | Move the window across the screen |
| Top-right arc | Free resize; apps reflow into the new viewport |
| Bottom-right arc | Restore/use the system's original logical aspect ratio |
| Drag a free window near an edge, dwell, release | Snap to top/bottom half in portrait or left/right half in landscape |
| Minimize | Store the window in the edge panel, without a bottom shelf |
| Maximize / title double tap | Fill the full bounds; restore through the edge panel |

Keyboard focus is requested explicitly. If the floating scene cannot display a keyboard, use **“在主应用中输入”** (“Type in the main app”) to search in the normal app scene and return to floating windows afterward. Existing guest sessions remain alive. Query text is not logged.

System gestures, the Home indicator, and hardware cutouts remain subject to iOS behavior. Some apps do not accept external scenes or dynamic sizes. iOS 14 has known upstream scene-hosting limitations. The iOS 14 minimum build target is not a claim that every feature works on every TrollStore-supported release.

## Build and test

```sh
git clone https://github.com/Airs-Kotex/HaruGalaxy.git
cd HaruGalaxy
make test
make package
make verify
```

Native packaging requires Clang, an iPhoneOS SDK, a Mach-O linker and ldid. See [build instructions](docs/build-environment.md). No SDK, credentials or user logs are distributed in source. Windows developers can build through WSL. The macOS discovery path is not yet independently validated.

The CI job runs portable geometry, startup, logging and diagnostic-parser tests. It does not run UIKit or install the app on a device.

## Report issues

Open the window panel → Settings → Diagnostics → mark the problem → export. Include the app version, device, exact iOS build, TrollStore version and reproduction steps. Inspect/redact application identifiers before posting a diagnostic bundle publicly. Never upload credentials or private account contents.

Diagnostics are local, bounded to approximately 8 MiB, and exported only by the user. They include state transitions and device metadata, not screen recording or typed text. Read them with:

```sh
python3 scripts/inspect_diagnostics.py /path/to/HaruGalaxy-Diagnostics-example.json
```

## Credits and license

Maintained by [Airs-Kotex](https://github.com/Airs-Kotex). Thanks to [straight-tamago / UiharuX](https://github.com/straight-tamago/UiharuX), [YuriDevTeam / MilkyWay3](https://github.com/YuriDevTeam/MilkyWay3-Public), [khanhduytran0 / FrontBoardAppLauncher](https://github.com/khanhduytran0/FrontBoardAppLauncher), [Lessica / TrollSpeed](https://github.com/Lessica/TrollSpeed), [LiveContainer](https://github.com/LiveContainer/LiveContainer), [opa334 / TrollStore](https://github.com/opa334/TrollStore), Theos, runtime-header maintainers and LLVM contributors.

The [Chinese README](README.md#借鉴项目与致谢) explains each project's role and reuse boundary. This is an independent project, not an official release or endorsement from those authors. New implementation is Apache-2.0; third-party licenses and notices are retained in [NOTICE.md](NOTICE.md) and `ThirdParty/`.

Contributions are welcome: [CONTRIBUTING.md](CONTRIBUTING.md), [CHANGELOG.md](CHANGELOG.md), [security reporting](SECURITY.md).

## Star history

[![Star History Chart](https://api.star-history.com/svg?repos=Airs-Kotex/HaruGalaxy&type=Date)](https://star-history.com/#Airs-Kotex/HaruGalaxy&Date)

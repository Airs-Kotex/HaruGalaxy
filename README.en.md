# HaruGalaxy · 初春星河

[简体中文](README.md) · [Download 0.3.8](https://github.com/Airs-Kotex/HaruGalaxy/releases/tag/v0.3.8) · [Issues](https://github.com/Airs-Kotex/HaruGalaxy/issues)

A native multi-window workspace for TrollStore. HaruGalaxy hosts installed apps in movable windows with an edge panel, free or original-aspect resizing, half-screen snapping and local diagnostic exports.

The edge entry, title bars and window panel now use translucent glass controls, with dark/light appearance, Reduce Transparency and contrast adaptations.

## Install

1. Install [TrollStore](https://github.com/opa334/TrollStore) on a supported device.
2. Download [HaruGalaxy-0.3.8.tipa](https://github.com/Airs-Kotex/HaruGalaxy/releases/download/v0.3.8/HaruGalaxy-0.3.8.tipa).
3. Open the file in TrollStore and install it over an existing 0.3.1 or later installation.
4. Open HaruGalaxy and enable the floating workspace in Settings.

Bundle identifier: `io.github.airskotex.harugalaxy`. Versions 0.3.0 and earlier use a different identifier; their preferences and logs do not migrate automatically. Version 0.3.2 was withdrawn. Other releases remain available in [Releases](https://github.com/Airs-Kotex/HaruGalaxy/releases).

## Controls

| Gesture | Behavior |
| --- | --- |
| Tap the edge tab | Toggle the window panel |
| Hold still and release | Toggle the panel |
| Drag the entry directly | Move freely and keep the release position |
| Release near either side | Dock and retract to a small tab while idle |
| Settings → “入口保持展开” | Keep the entry expanded |
| Tap outside the panel | Close it without activating the app underneath |
| Drag a title bar | Move the window |
| Top-right arc | Resize width and height freely |
| Entire bottom strip | Resize using the system's original logical aspect ratio |
| Drag a free window near an edge, dwell, release | Snap to top/bottom in portrait or left/right in landscape |
| Minimize | Store the window in the edge panel |
| Maximize / double-tap the title | Fill the screen; restore through the edge panel |
| ↗ on an app's panel row | End that hosted window and open the ordinary app |

Each app has one window, with up to four sessions at a time. Entry position is saved across launches and adapted on rotation. An undocked entry stays expanded. Drag it away from frequently used app controls; the previous inward-pull opening gesture now moves the entry, while a tap opens its panel.

The title bar is now28 points high and the footer18 points, reducing combined chrome from92 to46 points. The entire bottom strip starts proportional resizing; guest content ends above it. The small top-right arc handles free resizing. Footer keyboard/open-app buttons and text are removed. Title-bar buttons can also start a drag: a stationary tap activates the button, movement pans the window.

## Search

Tap the search field to filter apps by name or bundle identifier. If the floating scene does not display a keyboard, HaruGalaxy opens its normal app interface for input. You can also tap **“在主应用中搜索”** (“Search in the main app”). Selecting an app or cancelling restores the floating workspace and preserves existing sessions.

If iOS rejects the foreground request, the floating workspace returns with a message. Search text is never written to diagnostic logs.

## Input board

Direct keyboard presentation inside hosted apps remains unresolved. The edge panel's **“复制输入板”** is an optional copy/paste tool: enter text, tap **“复制并返回”**, then long-press the target text field and choose Paste. Copies remain on this device and expire after ten minutes; cancelling discards the draft.

To switch to the ordinary app, use **↗** on that app's panel row. This ends its hosted window, waits for scene deactivation and local cleanup, then requests an ordinary launch. Other windows are collected into the panel. The target is not automatically recreated; use Open App to create another hosted window. Forms and cursor positions may differ. Timeouts show a message, and cancelled handoffs do not launch the app.

On iOS 14–17, the Liquid Glass-inspired appearance uses existing UIKit blur and custom edge layers. It does not provide iOS 26+'s native glass API. Guest content remains clear; Reduce Transparency switches controls to opaque backgrounds.

## Compatibility

The arm64 build targets the officially supported TrollStore range: iOS/iPadOS 14.0 beta 2–16.6.1, 16.7 RC (20H18), and 17.0. User feedback covers background floating use and entry interaction on iPhone 14 Pro Max / iOS 16.2.

External scenes, keyboard routing and dynamic sizes depend on iOS and the hosted app. iOS 14 has upstream scene-hosting limitations; see the [compatibility record](docs/compatibility.md). System gestures and hardware cutouts remain controlled by iOS. Restarting HaruGalaxy does not automatically reopen guest windows or the floating workspace.

## Build

```sh
git clone https://github.com/Airs-Kotex/HaruGalaxy.git
cd HaruGalaxy
make test
make package
make verify
```

Requires Clang, an iPhoneOS SDK, a Mach-O linker and ldid. See [build instructions](docs/build-environment.md) for Linux/WSL setup. Source archives build without Git metadata. SDKs, caches and user logs are excluded.

Packages, checksums and build reports are written to `dist/`. Developer checks and device records live in `Tests/`, `docs/` and release attachments.

## Feedback

Open the window panel → Settings → Diagnostics → mark the issue → export. Include the app version, device, exact iOS build and reproduction steps when reporting an [issue](https://github.com/Airs-Kotex/HaruGalaxy/issues).

Logs stay on the device, rotate at approximately 8 MiB, and are exported only by the user. They record scene, window and input stages without recording the screen or typed text. Inspect and redact application identifiers before sharing publicly.

```sh
python3 scripts/inspect_diagnostics.py /path/to/HaruGalaxy-Diagnostics-example.json
```

## Credits and license

Maintained by [Airs-Kotex](https://github.com/Airs-Kotex). Thanks to [straight-tamago / UiharuX](https://github.com/straight-tamago/UiharuX), [YuriDevTeam / MilkyWay3](https://github.com/YuriDevTeam/MilkyWay3-Public), [khanhduytran0 / FrontBoardAppLauncher](https://github.com/khanhduytran0/FrontBoardAppLauncher), [Lessica / TrollSpeed](https://github.com/Lessica/TrollSpeed), [LiveContainer](https://github.com/LiveContainer/LiveContainer), [opa334 / TrollStore](https://github.com/opa334/TrollStore), Theos, runtime-header maintainers and LLVM contributors.

The [Chinese README](README.md#借鉴项目与致谢) describes each project's role and reuse boundary. HaruGalaxy is an independent project. New implementation uses Apache-2.0; third-party licenses and notices are retained in [NOTICE.md](NOTICE.md) and `ThirdParty/`.

[Contributing](CONTRIBUTING.md) · [Changelog](CHANGELOG.md) · [Security reporting](SECURITY.md)

## Star history

[![Star History Chart](https://api.star-history.com/svg?repos=Airs-Kotex/HaruGalaxy&type=Date)](https://star-history.com/#Airs-Kotex/HaruGalaxy&Date)

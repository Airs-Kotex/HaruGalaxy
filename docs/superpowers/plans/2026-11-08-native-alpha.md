# Native Alpha Implementation Plan

> For agentic workers: Execute this approved plan inline, task by task, with independent code review before delivery. The referenced optional executing-plans/subagent-driven-development skills are not installed; this does not prevent implementation.

**Goal:** Deliver a buildable native TrollStore alpha with real external app scenes, safe window lifecycle, MilkyWay-style controls, and a reproducible package.

**Architecture:** A portable C model owns geometry/state; an Objective-C scene session wraps private FrontBoard APIs; UIKit controllers own window chrome and app selection. The app keeps one session per bundle and optionally presents a separate floating root scene.

**Tech Stack:** Objective-C ARC, UIKit/Foundation/QuartzCore, C11, Clang/Apple SDK, ldid, Python 3 packaging; no Swift runtime code, network service, or containerized guest apps.

## Global Constraints

- Project path `/root/UiharuXPro4MilkyWay`; project name `UiharuXPro4MilkyWay`.
- Compile for arm64, deployment target iOS 15.0. Device support is unverified until tested.
- Only destroy scenes owned by this project; never kill a guest process.
- Unique scene identity, exactly one open session per bundle, cancellation-safe startup.
- Private runtime capability checks; meaningful failure states rather than simulated app content.
- Source and package may be prepared without another approval; no external publishing is requested.

### Task 1: Portable window rules and project identity

**Files:** `Sources/Core/MWWindowModel.h`, `.c`; `Tests/window_model_test.c`; `Resources/Info.plist`, `entitlements.plist`; `LICENSE`, `NOTICE.md`.

**Interfaces:** `MWRect { double x,y,width,height; }`; `MWWindowState { MWWindowLoading, MWWindowVisible, MWWindowMinimized, MWWindowFailed, MWWindowClosed }`; `MWWindowModel { state, frame, restoreFrame, maximized }`. UI calls `MWConstrainRect`, `MWWindowApply`, `MWWindowToggleMaximize`, and `MWWindowReflow`.

- [ ] Implement tests for dragging beyond bounds, tiny viewports, nonfinite geometry, resize minimums, maximum/restore, rotation while maximized, and closed/loading transitions. Test assertions include:

```c
MWWindowModel m = MWWindowCreate((MWRect){20,30,240,360});
assert(MWWindowApply(&m, MWEventReady));
assert(MWWindowApply(&m, MWEventMinimize));
assert(MWWindowApply(&m, MWEventRestore));
assert(MWWindowApply(&m, MWEventClose));
assert(!MWWindowApply(&m, MWEventReady));
```

- [ ] Run `python3 scripts/test.py`; first compile fails until the model exists. Implement deterministic finite-value normalization and clamp to the safe viewport. Closed is terminal; restore only applies to minimized; retry applies only to failed.
- [ ] Set plist identity `io.github.uiharuxpro4milkyway`, version `0.1.0`, build `1`; derive scoped scene entitlements from the pinned upstream, retaining source notices.
- [ ] Run Core tests and commit the result.

### Task 2: Real application scenes and capability checks

**Files:** `Sources/Platform/MWPrivate.h`, `MWSceneSession.h/.m`, `MWApplicationCatalog.h/.m`, `MWFloatingHost.h/.m`; `Sources/main.m`, `MWAppDelegate.h/.m`, `MWSceneDelegate.h/.m`.

**Interfaces:** `MWApplication` exposes `bundleIdentifier`, `name`, `icon`; catalog returns sorted installed applications. `MWSceneSession` exposes `initWithBundleIdentifier:`, `startWithSize:completion:`, `updateSize:orientation:`, `setVisible:`, `close`, `contentView`, `failureHandler`. Completion carries `NSError *` or a real view. `MWFloatingHost` exposes `setEnabled:fromScene:error:` and `ownsSceneIdentifier:`.

- [ ] Declare only used private interfaces with signatures checked against pinned upstream headers; dynamically resolve private classes and frameworks.
- [ ] Implement launch transaction → process handle → unique scene definition → presenter → content view. Use a generation/cancellation guard, bounded timeout, and main-thread UI callbacks.
- [ ] Implement cleanup with the exact stored scene ID and deactivate/invalidate presenter. Never send signals to terminate the target. Detect process disappearance with a read-only liveness check.
- [ ] Add optional floating root binder and transparent window. Scope any scene update interception to the owned root scene and forward unrelated callbacks untouched.
- [ ] Cross-compile all platform files; review lifecycle paths and check entitlements/manifest with `python3 scripts/verify_package.py` after Task 4 supplies the artifact.

### Task 3: Window controls and native launcher

**Files:** `Sources/UI/MWWorkspaceController.h/.m`, `MWWindowView.h/.m`, `MWAppPickerController.h/.m`, `MWPreferences.h/.m`, `MWSettingsController.h/.m`.

**Interfaces:** `MWWindowView` exposes `session`, `model`, `activateHandler`, `minimizeHandler`, `closeHandler`, and `applyViewport:`. Workspace owns dictionary of bundle IDs to views and a horizontal minimized shelf. Picker returns `MWApplication` through `selectionHandler`.

- [ ] Build native app list with search and persisted recents; exclude hidden/placeholder/unlaunchable/self applications.
- [ ] Bind session readiness/failure to model transitions and loading/error content; retry only after disposing the failed session.
- [ ] Add 44-point title controls, title drag, resize handle, title double-tap maximize/restore; retain restoreFrame across viewport changes.
- [ ] Restore minimized windows from shelf, focus an existing bundle instead of duplicating it; persist finite, bounded normalized geometry. Do not auto-launch persisted apps at startup.
- [ ] Apply system dark/light theme and reduced-motion preference; expose experimental floating mode with observed limitations in settings.
- [ ] Compile the entire app and request a focused code review of scene, touch, geometry, and ownership behavior.

### Task 4: Reproducible build and handoff

**Files:** `scripts/build.py`, `scripts/test.py`, `scripts/verify_package.py`, `Makefile`, `README.md`, `docs/device-validation.md`, `docs/build-environment.md`.

- [ ] Build with local SDK/compiler paths supplied as arguments or environment variables; on macOS discover SDK via `xcrun`. Invoke tools using argument arrays, never shell interpolation.
- [ ] Sign the native executable using ldid and the checked-in entitlements, create `Payload/UiharuXPro4MilkyWay.app` and `.tipa` via zipfile, record SHA-256.
- [ ] Verify package layout, plist identity, platform/deployment load command, signed entitlement blob, required resources and executable. Reject empty artifacts and metadata mismatches.
- [ ] Run `make test` then `make package`, inspect compiler output, run the package verifier, fix review findings and repeat affected checks.
- [ ] Record exact tool/SDK sources and hashes, build success or precise remaining blocker, device checks still unverified; create a portable source archive excluding SDK, caches, Git history and built packages.
- [ ] Commit source and docs, leave artifacts in `dist/` with paths and validation evidence in the final handoff.

## Review

The approved feature set maps to Tasks 1–3; reproducibility and honest device limits map to Task 4. Runtime acceptance requires the user's physical iOS device and cannot be replaced by a Linux compile. This execution will prepare the complete alpha source/package and retain that acceptance item explicitly.

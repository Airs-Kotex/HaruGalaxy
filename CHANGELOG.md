# Changelog

## 0.3.11 — Withdrawn

Withdrawn at the user’s request after feedback about missing parking controls and unresolved half-screen resizing. The release and its assets were removed; 0.3.10 remains available.

The following records the withdrawn implementation:

### Fixed

- Delay proportional resize until14 points of movement, preventing small rail gestures from immediately reshaping a half-screen window. Center conversion and keep the title out of the top system pull-down area.
- Preserve outer geometry, resize/snap/full-screen state and parking when reopening a window for display-mode changes.

### Added

- A parking icon in the title and panel. Keep the live app as a top-right thumbnail; tap to restore the saved window state.
- Settings for parked size18%–50% and aspect(original,1:1,4:3,3:4,16:9,9:16). Scale thumbnails without changing the saved app canvas or restore state.
- Per-app compatibility display: reopen using the native system canvas, then scale it inside the outer window. Ordinary free resizing remains the default.
- Automatic, bounded client-connection/content-state/layer observations and allowlisted installed-app metadata to investigate blank/image failures.

### Changed

- Move “End window and open original app” into the app row's ellipsis menu, keeping four usable action buttons.

The iPhone12/iOS15.4.1 log confirms presenter creation for870 andTelegram but lacks rendered-content evidence. Compatibility display is a recovery option, not a claim that their device rendering or guest keyboard is fixed. Parking is visual window management, not process suspension or native video PiP.

## 0.3.10 — Guest edge controls and keyboard capability gating

### Fixed

- Replace always-zero guest safe areas with actual overlap against the host window's safe rectangle. Convert insets into guest coordinates for proportional scaling, and update on movement, rotation, full-screen and resize.
- Stop preparing a hosted keyboard window before checking paired PID registration/removal methods. Device0.3.9 logs confirmed those methods are absent on iOS16.2 while preparation still ran. Unsupported systems retain focus selection without partial hosted presentation.

### Added

- Passive bottom hit queries, content/rail intersection checks and requested/reported safe-area fields in timed diagnostics.
- Bounded host-delivered touch-region records during capture, excluding text and raw tap coordinates.
- Capability snapshots for guests that appear after capture has started.

### Preserved and limitations

- Keep the28-point title and8-point resize edge, plus the0.3.9 ordinary-app handoff fallback. New logs confirm that fallback acknowledged background/release and its launch request was accepted.
- The supplied log does not prove that the resize edge caused the missed buttons. Direct guest keyboard input and actual device hit delivery remain unverified for this build; keyboard-visible reports alone are not proof of usable input.

## 0.3.9 — Thin resize edge and keyboard diagnostics

### Fixed

- Stop treating `FBScene deactivate:` as mandatory. Use a runtime-checked background-settings update with completion when the older runtime lacks it.
- Check handoff capability before removing/closing the target window. If neither route is available, keep the window and report the unsupported methods.

### Changed

- Reduce the footer from18 to8 points; keep the28-point title bar and original-aspect dragging across the entire bottom edge.
- Replace the lower arc/background with a small central line and lighter contact surface.

### Added

- A20-second keyboard capture in Settings, with bounded once-per-second snapshots and stale-timer protection.
- Diagnostics for exact runtime method encodings, guest input requests, selected owner, keyboard window visibility/levels, environment mapping and host-delivered touch counts.
- Capability snapshots on problem marking/export, plus handoff-route selection and background acknowledgement events.

### Removed

- The copy input board and its panel/coordinator paths. Normal-app search stays available.

Direct guest keyboard input remains unresolved. This release gathers the missing device evidence and does not claim that a focus request or a keyboard-state report proves usable input.

## 0.3.8 — Compact controls and scene handoff

### Fixed

- Ordinary-app switching previously detached the view while retaining the target's hosted scene. End that session, wait for deactivation and verify local presenter/scene cleanup before requesting the ordinary app.
- Guard delayed handoff callbacks against lock, background, workspace changes, timeout and cancellation. Do not automatically recreate a target session after a rejected launch.

### Changed

- Reduce the title bar from48 to28 points and footer from44 to18 points; total chrome is halved.
- Make the entire bottom strip start original-aspect resizing while keeping it separate from guest content. Keep free resizing in the compact top-right corner.
- Move ordinary-app switching to the panel with an explicit “End window and open original app” label. Keep the copy board as an optional panel tool.

### Added

- Bounded native-scene handoff stages and diagnostic events distinguishing deactivation, local release and launch-request acceptance.

### Removed

- Footer keyboard/open-original buttons and resize text.
- The input board's original-app shortcut and the old behavior that kept the target scene alive during ordinary-app launch.

Direct guest keyboard presentation remains unresolved. The scene-conflict fix and reduced touch strip still need device feedback.

## 0.3.7 — Separate resize area and input board

- Move the bottom-right proportional handle into a dedicated 44-point footer outside guest content, use its full square touch target, and account for both title and footer in original-aspect geometry.
- Add a normal-app input board accessible from window footers and the edge panel, including full-screen windows. Use the system keyboard, explicitly copy and return, then paste in the target app.
- Offer “Type in the original app”: collect guest surfaces into the panel and open the selected installed app normally. Restore the previous surfaces if the system rejects the launch.
- Clear input drafts on cancellation/background/lock and record input stages without text. Clipboard writes are local to this device and expire after ten minutes.

Direct guest keyboard presentation remains unresolved; the input board provides a separate copy/paste workflow.

## 0.3.6 — Free movement and resize access

- Allow direct entry dragging in all directions; keep the release position and dock only near a side. Save normalized x/y and preserve existing edge positions on upgrade.
- Let title-bar pans begin over its buttons, preserving stationary button taps.
- Expand corner resize targets from 28 to 44 points with rounded hit regions and immediate contact highlighting; retain the small visible arcs.
- Prepare and finish the guest keyboard's hosted presentation as a pair, with cleanup-failure retention. Add guest input-request observation and delayed focus-state diagnostics.

Host search input is confirmed by the user's 0.3.5 feedback. Guest keyboard behavior remains under investigation; the new diagnostics distinguish input requests, hosted presentation and visible keyboard state.

## 0.3.5 — Keyboard focus and glass controls

- Add runtime-checked keyboard ownership for the host and hosted App scenes. Touching or activating a window selects its process/scene; minimizing, closing, locking or switching input releases ownership.
- Register hosted PID bindings where the current UIKit keyboard arbiter exposes them and keep exact scene identity/PID matching.
- Add a scoped visibility-environment bridge for owned scenes based on the upstream keyboard-focus investigation; unrelated process/environment targets pass through unchanged.
- Give the edge entry, window title bars and panel a translucent glass surface with dynamic light/dark rims and Reduce Transparency/contrast fallbacks. Guest content stays separate from the effect.
- Expand diagnostics with focus ownership, keyboard arbiter capability, environment registration/application and keyboard visibility stages.

The package is built for device validation. Keyboard grants and visual output remain system/device dependent.

## 0.3.4 — Search input

- Embed the search bar directly in the app picker and focus its text field after presentation.
- When the floating keyboard is unavailable, open HaruGalaxy's normal scene automatically; keep a direct “Search in the main app” action.
- Add checked LaunchServices foreground requests, a scene-activation fallback and bounded presentation waiting.
- Restore floating windows on selection, cancellation, lock or timeout; keep late callbacks from affecting a newer search.
- Add search-stage diagnostics and simplify the public README and release descriptions.

## 0.3.3 — Edge recall

- Correct `beginTrackingWithTouch:withEvent:`, `continueTrackingWithTouch:withEvent:` and `endTrackingWithTouch:withEvent:`. The withdrawn version implemented different selectors, leaving UIKit's actual callbacks inherited and the entry inactive.
- Call UIKit's superclass cleanup on every end/cancel path, including programmatic cancellation and nil-touch completion, so UIKit's tracking state and the entry model finish together.
- Check compiled implementation methods against SDK UIControl declarations before packaging. The original 0.3.2 source is rejected by this check; header declarations alone cannot satisfy it.
- Restore the forgiving 56×76-point touch target, inward pull, stationary hold release, deliberate hold-and-drag and persistent expanded-entry option.
- Restore panel row reuse, skipped duplicate layout/style work and queued routine diagnostic flushes.
- Add sampled root query logs and entry-only window delivery logs, callback/activation results and `panel.blocked`; expose these stages through the diagnostic reader.
- Use build 8 with the existing bundle ID. Keep v0.3.2 withdrawn and v0.3.1 available for rollback.

## 0.3.2 — Withdrawn (2026-11-09)

- Withdrawn following device feedback that the floating window no longer responded to taps across screens after the update.
- Release and tag removed; main branch application code reverted to the 0.3.1 baseline by commit `398c901693a76af4efc694a0fe3d58e0129f78e3`. The original changes remain in commit `e28b4204d14d52de4a90ced452fed62c2323b39b` for investigation.
- The [0.3.1 package](https://github.com/Airs-Kotex/HaruGalaxy/releases/tag/v0.3.1) remains available for rollback.
- Passing portable tests, static analysis and package checks did not validate real UIKit touch delivery. Subsequent investigation found an entry selector mismatch; see the [withdrawal record](docs/research/2026-11-09-0.3.2-withdrawal.md).

## 0.3.1 — HaruGalaxy / 初春星河

- Adopt the HaruGalaxy name and localized app display names; use the new `io.github.airskotex.harugalaxy` identifier (a separate installation from the old app).
- Move resize controls to small top-right/free and bottom-right/system-ratio arcs.
- Base proportional scaling on the full system logical canvas, not the last free-resized rectangle.
- Detect half-screen gestures from the proposed window edge, making the lower half reachable without dragging a finger into the Home gesture area.
- Allow ordinary window movement into the top screen region.
- Coalesce guest geometry updates with a display link, skip duplicate layouts and shadow updates, and log resize duration/update counts.
- Request search focus explicitly and observe keyboard visibility. Provide a normal-scene search path if the floating scene cannot show a keyboard.
- Add open-source documentation, contribution templates, and Core test CI.

## 0.3.0

- Edge window panel replaces the bottom minimized-window shelf.
- Explicit tap versus long-press-drag entry gestures.
- Free/proportional resize modes, half-screen previews and full-bounds maximization.

## 0.2.2

- Wait for hosted root readiness before activating the floating workspace.
- User confirmed background floating use on iPhone 14 Pro Max / iOS 16.2.

## 0.2.1

- Correct binder/presenter invalidation order and add root transparency handling.
- Introduced a premature root-availability check, corrected in 0.2.2.

## 0.2.0

- Detailed local diagnostics, background execution request and edge entry.
- Device reports exposed black background and automatic presenter teardown issues.

## 0.1.0

- Initial native scene-hosting alpha and window controls.

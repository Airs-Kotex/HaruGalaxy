# Changelog

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

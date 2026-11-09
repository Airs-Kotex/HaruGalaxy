# Changelog

## 0.3.1 — HaruGalaxy / 初春星河

- Adopt the HaruGalaxy name and localized app display names; use the new `io.github.airskotex.harugalaxy` identifier (a separate installation from the old app).
- Move resize controls to small top-right/free and bottom-right/system-ratio arcs.
- Base proportional scaling on the full system logical canvas, not the last free-resized rectangle.
- Detect half-screen gestures from the proposed window edge, making the lower half reachable without dragging a finger into the Home gesture area.
- Allow ordinary window movement into the top screen region.
- Coalesce guest geometry updates with a display link, skip duplicate layouts and shadow updates, and log resize duration/update counts.
- Request search focus explicitly and observe keyboard visibility. Provide a normal-scene search path if the floating scene cannot show a keyboard.
- Add open-source documentation, contribution templates, and Core test CI.

These changes are compiled and checked locally; new keyboard and gesture behavior still needs device validation.

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

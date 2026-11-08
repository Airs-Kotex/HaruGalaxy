# Device Feedback Implementation Plan

**Goal:** Produce 0.2.0 with a background-retention fix candidate, edge handle, proportional content scaling and exportable device diagnostics.

**Architecture:** Extend the existing scene backend; keep private background assertions and scoped diff normalization in Platform. Add portable C geometry/log-rotation rules, a serial local logger, and one UIKit edge control. Share one workspace as in 0.1.0.

**Constraints:** iOS 14 minimum host; TrollStore capabilities probed at runtime; no claims of universal device verification; logs local/bounded/exported by user; guest processes are never terminated.

- [ ] Task 1: Test and implement content-aspect fitting/resizing/maximization and edge-handle positioning in `Sources/Core/`; wire to the real presenter with uniform transform. Test narrow viewports, portrait/landscape, restore and repeated resizing.
- [ ] Task 2: Add `Sources/Diagnostics/MWDiagnostics` with serial JSONL writes, bounded rotation, crash/previous-session metadata, heartbeat, capability snapshot and asynchronous export. Wire settings actions and all platform lifecycle boundaries.
- [ ] Task 3: Add `MWBackgroundLease` and `MWSceneUpdateGuard`; verify private signatures before use, normalize only the active owned root, forward all originals once, release on stop, log rejection/timeout/invalidation.
- [ ] Task 4: Replace the round bubble with `MWEdgeHandle` using a 44pt hit area and 8pt visual tab, idle retract, drag snapping, persistence and accessibility. Add iOS 14 appearance fallbacks.
- [ ] Task 5: Bump app/package metadata to 0.2.0, document the 16.2 device report and compatibility matrix, run tests/analyzer/build/verifier plus focused code review, export the new source archive and instructions for sending diagnostic JSON.

Verification commands: `make test`, `make package`, `make verify`, `python3 scripts/export_source.py`. Final device evidence remains pending the next user test; code completion and device validation are recorded separately.

# 0.3.0 Window Interaction Plan

**Goal:** Implement explicit gestures, an edge window panel, full-bounds maximization, optional proportional scaling and drag-to-half-screen.

**Architecture:** Keep the proven Platform startup intact. Extend the shared C geometry model; bind native gestures to explicit modes in MWWindowView; replace bottom shelf with one anchored panel owned by Workspace.

**Tech stack:** Objective-C/UIKit, C11 geometry, existing native cross-build/diagnostics.

**Constraints:** iOS14 minimum; main-thread UI ownership; one guest session per app; no guest process termination; preserve startup and teardown behavior; device claims limited to user-confirmed 0.2.2 background use.

- [x] Test and implement `MWResizeFreeRect`, `MWHalfScreenRect`, `MWSnapTargetAtPoint`, model resize mode and full-screen restoration using actual full bounds.
- [x] Replace edge tap/control/pan mixture with exclusive tap versus long-press-drag, haptic threshold, rollback on cancellation, single-tap panel activation.
- [x] Add anchored window panel with restore/minimize/close/fullscreen actions, open-app/settings controls, outside-tap dismissal shield; remove bottom shelf and its viewport reservation.
- [x] Bind left/right resize handles, App logical-size reflow versus uniform scale, title move/half-screen preview dwell and cancellation restoration. Fullscreen hides own chrome and keeps edge-panel escape route.
- [x] Persist window mode/geometry without auto-opening apps; log interaction state; record user success on 0.2.2.
- [x] Run tests/native build/static analysis, focused code review and fixes; package 0.3.0 and portable source; document actual gesture map and device acceptance.

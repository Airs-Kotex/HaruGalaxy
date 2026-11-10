# Compact chrome and ordinary-app scene handoff

User feedback authorizes reducing window chrome and correcting original-app white screens; copy/paste input is not an adequate fix for direct guest keyboard access.

Confirmed source defects: window chrome consumes48+44=92pt; original-app launch only detached/minimized views while the target's FBScene stayed alive. No current device diagnostics are available, so direct keyboard failure remains unlocated. Do not add another undocumented focus hack or claim native input is fixed by the input board.

## Design and execution

- [x] Change title/resize rail to28/18pt (46pt total). Use the whole thin footer for proportional drag and a28pt top-right free handle, keeping both outside guest content. Remove footer keyboard/open-original buttons and text. Preserve glass, full-screen, system ratio and half-screen.
- [x] Keep the input board only as an optional panel tool. Per-App panel action directly opens the ordinary app and says it ends the hosted window. Remove the ambiguous original-app action inside the input board.
- [x] Replace view-only collection with target-scene release: cancel interactions, end target session, wait for its deactivation callback, invalidate presenter and destroy owned scene, require successful local teardown before launching. Bound the wait, suppress stale completion after close/lock/background, and never reopen the target automatically. Other windows remain collected for explicit restoration. Never terminate guest processes.
- [x] Add portable handoff-stage tests covering callback-before-launch, timeout, cancellation and stale generations. Update geometric tests for full-width rail isolation and reduced chrome. Check actual production integration using native build/static review.
- [x] Clarify README, changelog and release text with fixed issues, additions and removals; label direct guest input still unresolved pending current diagnostics. Version0.3.8/build13.

Release verification is recorded with artifacts in verification-report.json: clean commit build, source archive rebuild, CI and public download digests. Direct guest keyboard work remains uncompleted; do not equate the release workflow with resolution of that issue.

## Source boundaries

Geometry: Sources/Core/MWWindowModel.*, Sources/UI/MWWindowView.m, MWCornerHandle.m. Input actions: MWWindowPanel, MWWorkspaceController, MWWorkspaceCoordinator, MWInputBoardController. Scene teardown: MWSceneSession, new pure-C MWNativeHandoff stages. Runtime declarations checked against fixed MTACS headers; source findings retained in implementation-status0.3.8.

Alternatives considered: shrinking only the hit rectangle risks the old hard-to-hit corner; extending invisible hits into guest content reintroduces overlap. A full-width18pt reserved rail retains a physically separate initiation area. Keeping the old original-app scene alive reproduces the ownership conflict; automatic process termination would risk unsaved data and is excluded.

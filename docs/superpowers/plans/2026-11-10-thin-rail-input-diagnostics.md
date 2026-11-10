# Thin resize rail, compatible handoff and bounded keyboard diagnostics

User authorizes a thinner footer, evidence-driven keyboard feasibility work, removal of ineffective input UI, and correction of the0.3.8 unsupported-handoff behavior.

Source findings: error64 is returned solely when FBScene deactivate: fails the ABI check, after the UI already removes/closes the target. Earlier runtime headers and retained upstream declarations expose updateSettings:withTransitionContext:completion: even when deactivate: is absent. Upstream FrontBoardAppLauncher explicitly lists keyboard failure over SpringBoard; no new device diagnostic is available, so direct guest input cannot be promised or categorically ruled out for all host modes.

- [x] Shrink the isolated full-width resize rail18→8pt and adapt marks to fit; retain28pt title, full screen and original aspect geometry. Regression test36pt total and guest/rail separation before implementation.
- [x] Remove MWInputBoardController and its panel/coordinator callbacks. Preserve actual host App search/handoff.
- [x] Preflight native handoff before any window mutation; select direct deactivation or the older copied-settings foreground=false update callback through runtime ABI checks. Unsupported leaves target intact. Check callback foreground state, local cleanup, timeout/cancellation; log capabilities and chosen route.
- [x] Add20-second bounded, generation-protected keyboard diagnostics triggered from Settings. Sample registered guest state, input request, exact selector types, focus-owner/state, native window visibility/level and environment-bridge status. Count delivered guest touch starts; no text, clipboard, keycodes or coordinates, and no focus change caused by sampling. Sample on problem marker/export too.
- [x] Add geometry/handoff-route/capture-budget regressions and diagnostic-reader tests. Version0.3.9/build14, independent review, native/static checks complete.

Release archive rebuild, CI and publication results are recorded in the release verification report. Direct guest keyboard remains unresolved until device evidence establishes a supported path; do not interpret release completion as keyboard success.

Source boundaries: Core/MWWindowModel, MWNativeHandoff, new MWDiagnosticCapture; UI/CornerHandle, WindowPanel, WorkspaceController/Coordinator, Settings; Platform/SceneSession, KeyboardFocus, SceneInputEnvironment, new RuntimeDiagnostics helper; Diagnostics/MWDiagnostics and reader. No process termination or global event-routing changes. No automatic removal of legitimate App text fields, and no claim of fixing a keyboard from request acceptance.

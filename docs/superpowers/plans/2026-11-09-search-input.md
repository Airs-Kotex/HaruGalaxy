# Search Input Repair Plan

**Goal:** Make application search usable from the floating workspace and remove repetitive testing language from the public GitHub presentation.

**Evidence:** User confirms the 0.3.3 interaction repair and reports the remaining search keyboard and main-app handoff failure. The current picker presents a nested UISearchController, cancels focus observation in every disappearance callback and relies on a single scene-activation request for foreground handoff. No new device log is available; these are source findings, not a measured device trace.

**Design:** Embed a UISearchBar directly in the picker, focus its actual text field after presentation, and observe keyboard intersection with the owning window. A failed keyboard request in the floating picker automatically hands the query to the normal application scene. Use the already-declared LaunchServices open-own-bundle API with capability/error checks; use scene activation as a bounded fallback, wait for actual foreground activity, and preserve guest sessions. Keep callbacks generation-bound so cancellation, late activation and lock/background events cannot restore the wrong search.

**Scope:** iOS 14+ arm64, existing bundle ID, existing scene backend and touch callbacks. Public docs describe use, features and concise compatibility limits; developer verification evidence stays in docs/reports. Do not claim unseen device results.

- [x] Add a production search-handoff state model with tests for already-active main scene, accepted/rejected launch, stalled activation, stale callbacks, one presentation, cancel and timeout.
- [x] Replace nested search presentation with an embedded search bar; focus after appearance, observe keyboard notification coordinates, provide one-shot automatic fallback and an explicit main-app button.
- [x] Add checked own-app foreground launching and integrate bounded scene activation/presentation/cleanup with lock and background handling.
- [x] Run native compilation, input selector contract check, six C suites, ten Python tests, 28-unit static analysis and independent source review; confirm source-copy build without Git.
- [x] Simplify Chinese/English README and prepare concise release descriptions while preserving credits/star history.

**Review correction:** Invalidate the picker before cancellation and guard queued focus by generation. Late presentation completion dismisses only its own obsolete navigation controller; dismissal guards avoid duplicate cleanup. A stale fallback after floating-host shutdown is ignored.

**Publication:** Commit the reviewed source, fast-forward main to include the user-confirmed 0.3.3 repair and this input change, rebuild/export from that clean commit, verify the exact archive, and attach commit/digest/check evidence in `verification-report.json`. Update old release wording without replacing their binaries. Device outcomes remain recorded separately from host checks.

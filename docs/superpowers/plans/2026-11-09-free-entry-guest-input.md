# Free entry movement, resize reachability and guest input

**User feedback:** 0.3.5 host search keyboard works. Guest keyboards still do not appear; floating controls are difficult/impossible to reposition, and the bottom-right proportional handle is hard to trigger.

**Evidence/scope:** Source requires a 0.35s hold before entry motion, rejects early displacement and always stores an edge-only position. Corner targets are only 28pt with 12pt-wide bands. Guest input currently registers a hosted PID but never prepares a hosted keyboard window; no new device JSON is available to establish actual keyboard grants.

- [x] Replace the entry hold requirement with direct drag, retain tap/stationary hold activation, persist normalized x/y, and dock only when released near a side. Preserve touch callback cleanup and cancellation.
- [x] Permit title-bar pans beginning on its buttons while keeping ordinary button taps; expand corner targets to 44pt rounded regions with visible contact feedback and no extra guest-covering label.
- [x] Pair runtime-checked prepareForHostedWindowWithScene / finishWithHostedWindow around guest keyboard hosting. Preserve accepted host search, prevent switching past failed cleanup, and add delayed state observations plus guest systemInputActive evidence.
- [x] Verify C behavior/geometry, native SDK contracts, lifecycle review, native build and static analysis. Prepare the source archive verification procedure.
- [x] Update concise tutorials and prepare 0.3.6 notes; distinguish code corrections from unobserved guest keyboard behavior.

Runtime API references are the pinned MTACS UIKitCore protocol `_UIKeyboardArbiterClient` (prepare returns UIWindow for UIWindowScene), and FBSceneObserver for client-settings notifications. Do not add unverified broad system hooks or infer a grant from completion.

Review corrections: guest input observations now refresh only a matching current owner/window, so delayed events cannot replace panel/host input. Free entry panel placement has narrow-side and compact-header fallbacks that retain a complete98pt row;667×375 landscape and320×568 portrait regressions were reproduced then corrected. No confirmed blocker remained in the focused read-only review.

Release finalization: rebuild from the clean commit, export/check its exact tracked source, build/test the archive without Git, run public CI, and publish0.3.6 with matching digests. Attach verification results to the release; device keyboard acceptance remains pending.

# Keyboard focus and glass controls

**Goal:** Address input across host search and all hosted apps, and give the floating controls a transparent glass appearance on supported TrollStore systems.

**Evidence:** User confirms 0.3.4 now opens the main app but the keyboard remains absent, including every guest window. Source currently changes visible/active borders without selecting a process/scene through keyboard arbitration. No current device trace is available. Runtime declarations identify `UIKeyboardArbiterManager` and hosted-PID registration; availability and method ABI must be checked before invoking them.

**Input design:** One coordinator owns the selected guest or local scene. Obtain real FBS scene identity tokens, select the target PID through UIKit's keyboard arbiter, register/unregister hosted PID when the paired APIs exist, and ignore stale completion callbacks. Select guest input at actual touch begin before forwarding the unchanged UIEvent. Select local input for app search/panel/settings. Release on minimize/close, host changes and lock. Record capability, selection, actual keyboard notifications and bounded state snapshots; never capture input text.

**Visual design:** Apply a reusable UIKit blur surface to the edge tab, title bars and panel, with translucent neutral tint, static light/dark rims and restrained shadows. Keep guest content opaque and readable. Respect dark mode, increased contrast and Reduce Transparency. iOS 14–17 use a compatible Liquid Glass-inspired appearance; do not claim they contain iOS 26/27's UIGlassEffect. Keep existing gesture hit regions.

- [x] Implement/test selection ownership, suspension and stale-callback protection.
- [x] Integrate runtime-checked keyboard focus and lifecycle cleanup for host and all guest sessions.
- [x] Add shared glass surface and refresh appearance/accessibility behavior in all chrome.
- [x] Verify native build, eight C suites, eleven Python tests, 33-unit static analysis and independent review; source copy also tests/builds without Git metadata.
- [x] Update concise public docs/credits and prepare 0.3.5 release notes and device checklist.

**Primary references inspected:** Apple Liquid Glass documentation and WWDC26 design guidance; MTACS iOS-17 runtime headers (`UIKeyboardArbiterManager`, `_UIKeyboardArbiterClient`, `UIKBArbiterClientFocusContext`, `UIScene`, `FBSSceneIdentityToken`); khanhduytran0's scene-host keyboard investigation; LiveContainer scene hosting. No upstream implementation or Apple SDK is distributed.

**Review correction:** A failed hosted-PID removal now retains its registration for retry and blocks adding another. Same-owner fast path cannot bypass pending cleanup. Native forwarding still calls super exactly once and does not rewrite UIKit hit-test return values.

**Release finalization:** Build from the clean commit, export and verify the exact source archive, run public CI and upload artifacts/checksums. Store the final commit/digests and limits in the release verification report, without changing the source just to mark publication. Keyboard grants and rendered glass remain pending actual device observation.

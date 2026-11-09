# HaruGalaxy 0.3.2 Edge Recall and Response Plan

**Goal:** Make a retracted edge entry reliably reachable and reduce avoidable UI work, preserving the existing scene backend and window actions.

**Evidence:** User reports the rest of 0.3.1 is broadly usable, but the collapsed entry frequently does not open. Source has an 8-point visible tab, separate tap/hold recognizers, animations without interaction options, full panel-row recreation on each open, and synchronous disk flushing for routine lifecycle notifications. No new device trace accompanies this report, so these are identified source risks, not a measured device root cause.

- [x] Add a production C touch-decision model and behavioral tests for small-drift taps, inward pulls from both edges, stationary holds, hold-and-drag, cancellations, and no double activation.
- [x] Use direct single-touch control tracking with a stable 56×76-point frame and 12×60-point collapsed tab. Touch-down highlights immediately, idle collapse pauses while tracking, animations allow interaction and start from their current state. Hold-and-drag remains distinct from wake.
- [x] Provide an optional persistent expanded entry. Cancel pending edge tracking on hide/window changes; preserve stored edge position and clamp the enlarged target inside the viewport.
- [x] Reuse unchanged panel rows and leave repeated hidden-panel layout out of ordinary drag layout. Skip redundant state/style changes and replace routine foreground disk barriers with queued flushes; retain synchronous crash/background durability where necessary.
- [x] Record touch outcomes, panel preparation time and row rebuild counts; keep performance claims limited to inspected code and tests.
- [x] Run portable tests, static analysis and native package checks.
- [x] Complete focused source review and an independent source build without Git metadata; prepare the 0.3.2 release notes and device checklist.

**Device checks:** taps near the visible edge, taps during retract, small inward pulls, stationary hold, deliberate drag, fast open-close-open, panel outside dismissal, lock/unlock, and coexistence with guest edge controls. Do not claim an FPS or measured latency improvement without device evidence.

**Verification notes:** Portable tests include a regression first observed failing when pre-hold drift incorrectly became a drag. Movement now uses the hold/haptic position. Native compilation uses Debian ARM Clang/LLD 14.0.6 and ARM ldid; Clang analysis covers all 26 production Objective-C/C translation units. Real UIKit event delivery and perceived responsiveness remain pending device validation.

**Source review:** No blocking findings remained after the hold-baseline and cross-edge layout corrections. The reviewer checked cancellation, panel row state/actions and serial logging order; this was a source review, not an independent UIKit/device execution.

**Publication:** Build the release package from the final clean commit, export and check its source archive, then publish through the previously authorized GitHub workflow. The release's `verification-report.json` records the frozen source commit and artifact checks; publication does not require modifying the source used to build those artifacts.

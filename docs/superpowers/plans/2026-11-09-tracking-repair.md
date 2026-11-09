# Edge Tracking Repair Implementation Plan

**Goal:** Repair the Objective-C tracking callback contract that made the 0.3.2 entry inert, retain the requested recall/response improvements, and provide an explicitly experimental 0.3.3 package for device confirmation.

**Architecture:** Keep the established scene/root routing. Restore the existing 0.3.2 entry model on `fix/edge-tracking-0.3.3`, correct its UIControl selectors and verify actual compiled implementation methods against UIKit. Observe root queries, window event delivery, control tracking and panel requests with bounded diagnostic events. No private routing replacement is needed to repair the confirmed selector mismatch.

**Tech Stack:** Objective-C/UIKit, portable C, Python, Clang 14, iPhoneOS SDK.

**Constraints:** arm64/iOS 14.0; bundle ID `io.github.airskotex.harugalaxy`; keep v0.3.2 withdrawn. The current user explicitly requests continued implementation after the rollback. Work on a repair branch; publish a testing prerelease without presenting it as device-verified or the default download. Ordinary source checks cannot demonstrate real input delivery.

- [x] Compare the withdrawn implementation to SDK `UIControl.h`: `beginTracking:withEvent:`, `continueTracking:withEvent:` and `endTracking:withEvent:` are new methods, not overrides of the required `*TrackingWithTouch:withEvent:` methods.
- [x] Add a compiled-AST contract check to native packaging. Demonstrate that the actual withdrawn source fails and the repaired source passes against the same SDK; run portable tests for gesture decisions.
- [x] Correct the three selectors. Check holding/cancellation, source-to-control integration, animation interruption and reuse of panel rows. Keep fixes scoped to verified defects.
- [x] Add bounded, local input-stage logs and diagnostic-reader interpretation; distinguish query results, actual touch delivery, tracking start/cancel, activation and blocked/open panel requests.
- [x] Run native compilation, package verification, focused source review and static analysis. Confirm the candidate source copy can test and build without Git metadata.
- [x] Update root-cause record, device checklist and build instructions; prepare branch-only 0.3.3 testing release notes with checksums and verification limits. Preserve the public 0.3.1 rollback entry.

**Failure evidence:** The original 0.3.2 Objective-C implementation contains zero overrides for all three required begin/continue/end selectors; its model tests call C functions directly and cannot detect that dispatch never reaches them. SDK headers and Clang AST are the contract evidence. End-to-end behavior still requires the user's iPhone.

**Review correction:** UIKit requires superclass cleanup in end/cancel overrides. Both now call super, and programmatic cancellation follows the same path with idempotent model cleanup before a possible nil-touch end callback. Compiled negative variants verify the checker rejects a missing superclass call in either method.

**Checks before commit:** Five C suites (UBSan), nine Python cases, native packaging with the SDK contract check, all 26 production translation units analyzed without diagnostics, and focused independent review after the cleanup correction. No device was available.

**Artifact finalization:** Rebuild from the final clean commit, export its tracked source and verify the exact archive without Git metadata, push the repair branch, run its CI and upload a testing prerelease with `make_latest=false`. Record the final commit, artifact digests and archive checks in `verification-report.json` attached to that release; do not change source merely to mark publication.

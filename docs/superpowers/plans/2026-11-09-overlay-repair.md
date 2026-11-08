# 0.2.1 Overlay Repair Plan

**Goal:** Repair the observed overlay teardown assertion, root black background and presentation scaling; preserve current UI/features.

**Evidence:** `docs/research/2026-11-09-overlay-crash.md` and the user-supplied diagnostic JSON. No further authorization is needed to correct these requested bugs.

- [x] Parse Objective-C type qualifiers before checking the scene-update ABI. Test Vv, qualified objects, rejected nonvoid and malformed types; log the complete runtime method encoding.
- [x] Ensure the owned root window/container is transparent and nonopaque, preserving original runtime method behavior for every unmarked instance. Log root identity and layer alpha. Fail startup if owned root cannot be resolved safely.
- [x] Tear down in order: hide/detach our overlay; binder removeScene → invalidate → destroy FBScene → release binder. Clear state before callbacks, reject reentrancy, record each stage.
- [x] Put the system guest view inside a project-owned logical-sized container. Only scale the owned container, keep geometry based on stable screen/scene orientation, and record actual guest/host transform metadata.
- [x] Review the fix, run Core and diagnostic tests, native compile/static analysis/sign/package verification, document remaining device checks and deliver 0.2.1 with source archive.

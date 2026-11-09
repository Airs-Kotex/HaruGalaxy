# 0.2.2 Root Readiness Regression Plan

**Goal:** Correct the premature root check reported on 0.2.1 while preserving the crash/scale repairs.

**Evidence:** User's exact error and the pre-addScene root gate in 2c476f9; no new 0.2.1 diagnostic JSON was provided. Do not reinterpret the old 0.2.0 run as current evidence.

- [x] Identify the single premature gate and distinguish a pending root/window from actual type/ABI incompatibility.
- [x] Add shared production C startup state and behavioral tests for callback ordering, root loss, cancellation generations, timeout and rejection.
- [x] Defer workspace migration and key status until both root and overlay window are ready; stage only a transparent noninteractive window beforehand.
- [x] Preserve teardown ordering, remove stale root associations, check cancellation after synchronous readiness notification.
- [x] Run scoped review, complete tests/static analysis/build/sign/package checks, export 0.2.2/source and document the required device retest.

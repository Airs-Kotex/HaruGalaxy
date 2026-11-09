# HaruGalaxy 0.3.1 Implementation Plan

**Goal:** Correct the reported input and gesture behavior while renaming the product.

**Architecture:** Preserve the existing floating backend. Refine portable geometry and use a small native arc control. Search attempts local keyboard activation, with an explicit normal-scene input handoff managed by the workspace coordinator.

- [x] Test and add original-screen canvas selection, anchored top-right free resize, drag-edge snap candidates and arc hit bands.
- [x] Replace large corner buttons, remove the top movement clamp, capture system ratio, and coalesce unnecessary layout/scene changes.
- [x] Add search key/keyboard observation and a recoverable main-scene search flow; log focus outcomes but never query text.
- [x] Rename display/executable/package/UI/docs to HaruGalaxy / 初春星河, using the new io.github.airskotex.harugalaxy Bundle ID and documenting separate-install behavior.
- [x] Run tests, static analysis, source review, signed package checks and portable archive build; document keyboard fallback and device verification scope.

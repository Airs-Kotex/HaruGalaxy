# Guest bottom controls and diagnostic3B51 evidence

User provides0.3.9/build14 device logs and reports some guest bottom buttons unresponsive. Raw log remains local/ignored; sanitized findings only may be published.

Evidence:0.3.9 session684 events,20 timed samples. Target guest becomes keyboard source while keyboardVisible=true; prepared hosted window430x932 has level-9999999, overlay level1100. PID add/remove API both absent but prepare/finish called7 times. View geometry has28pt title/8pt rail; no proof of rail overlap or actual failed tap target. Existing guest settings always set safeAreaInsetsPortrait=zero, so full/near-bottom surfaces have no host Home-zone protection. Native handoff route2, background ack, local cleanup and launch acceptance succeeded (rendering not established).

Design: keep compact chrome, fix our incomplete keyboard preparation by gating all APIs used by this implementation before prepare, use focus-only fallback when unsupported. Do not forcibly change UIKit keyboard window levels or claim all direct keyboard input solved. Compute guest safe insets from actual rendered content's intersection with host safe rect, converted by its logical scale; pass matching-orientation safe area to scene at launch/move/resize/rotation. Expand diagnostics with own-window bottom hit queries (not actual delivery), bounded actual touch-route records, chrome geometry/disjoint check, system safe rect, and capabilities for guests created mid-capture. Preserve main search and native handoff.

- [x] Add failing tests for portrait/free/proportional/landscape/mid-screen safe insets, complete keyboard API gate and diagnostic parser interpretation.
- [x] Implement scene safe insets and movement-triggered geometry updates; retain the compact nonoverlapping rail.
- [x] Stop preparing hosted keyboard with missing PID API; retain cleanup pairing and focus-only fallback.
- [x] Add bounded passive hit/geometry evidence and late-guest capability snapshots. Record no text, keycodes or user coordinates; native window queries cannot prove remote WindowServer delivery.
- [x] Review code, run tests/native/static checks; version0.3.10/build15 with explicit fixes and limitations.

Final clean build, archive rebuild, CI/public asset verification are recorded in release verification-report.json. Direct guest keyboard and device bottom-control behavior remain unverified for this build.

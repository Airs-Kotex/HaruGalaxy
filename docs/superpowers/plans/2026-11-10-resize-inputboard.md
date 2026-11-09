# Resize isolation and usable input fallback

**User feedback:** Right-bottom resize still competes with guest actions after enlarging its hit target. Guest keyboards remain unavailable; user accepts any workable keyboard path. Host search input has previously worked, so reuse its normal-scene activation.

**Confirmed source issue:** The proportional handle overlays the guest's presentation area. Geometry alone cannot demonstrate remote WindowServer hit routing. Guest focus/presentation attempts have not established direct-input success; no new device logs were supplied.

**Design:** Reserve a44pt host-only bottom rail in window mode. Guest content ends above it; proportional geometry subtracts title+rail. Give the resize handle explicit local hit priority and a visible hit surface. Keep full-screen content full-size.

Add a native UITextView input board to the normal foreground scene, accessible through window controls and the edge panel. User explicitly copies locally (10-minute pasteboard expiry) and returns to paste into the guest. No automatic clipboard reads, text logging, text persistence or injection. Provide an action to open the selected App normally, with windows collected into the panel; this opens the App's ordinary scene and does not claim guest form-state migration.

- [x] Add pure geometry checks for disjoint guest/resize frames, title+rail aspect ratio, full-screen and small viewports.
- [x] Move proportional handle into reserved host rail, prioritize local chrome and preserve resizing/drag cancellation.
- [x] Add input board using existing normal-scene handoff with terminal cancellation, callback ownership and lock/background cleanup.
- [x] Add selected-App foreground action and failure restoration; expose it with honest copy/ordinary-App semantics.
- [x] Run host/native checks and focused review; document copy/paste usage and actual runtime limits.

Release stage: build from the committed tree, verify the exported archive without Git, then publish0.3.7. Archive, CI and publication results are recorded in the release's verification-report.json rather than changing the source after it is packaged.

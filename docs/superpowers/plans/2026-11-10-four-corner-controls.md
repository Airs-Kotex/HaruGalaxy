# Four-corner resizing and visible parking controls

User requested withdraw0.3.11, reports no parking UI, and clarifies halfscreen-to-aspect expansion rather than split-screen bounds is the problem. Release439977139 and six assets deleted and404 verified; README restored0.3.10 links in4875478. Source/tag retained for history; no republish0.3.11.

Design: retain28pt top/8pt footer, remove App name from top. Center close/minimize/maximize/park four controls. Top-left proportional, top-right free; bottom left-half free, bottom right-half proportional. Match labels/colors. No invisible hit expansion into App content. Half→aspect first fits inside old frame (never expands height), then resets translation; subsequent opposite-corner resize may shrink from either direction, with top safety during resize. Keep normal halfscreen occupancy. All corners require deliberate14pt movement so touches don't immediately reshape.

Parking: source0.3.11 contains code but no new device log/package identity proves why user cannot see it. Provide custom drawn universal PiP glyph (no missing SF Symbol dependency), explicit “挂起/还原” menu item and “挂起小窗设置” panel text shortcut. Show version/build in settings title and log UI contract on launch. Preserve restored parking state and settings preferences.

- [x] Regression tests first for conversion not exceeding halfscreen frame, symmetrical proportional corners, bottom-left/top-right free anchoring, small-window chrome nonoverlap and persistence/reflow.
- [x] Implement four controls + bounds-safe chrome geometry, centered top row, shrink-to-fit aspect entry and translation reset. No change to guest hit delivery.
- [x] Expose parking in title/panel/settings with custom icon and version evidence. Verify built binary includes required symbols/UI strings without claiming actual device render.
- [x] Run tests/native/static/review and update docs; version0.3.12/build17. Follow-up short-window clipping regression corrected and reviewed.

Clean commit build/archive rebuild, CI and public download checks are recorded in release verification-report.json.0.3.11 release remains withdrawn, raw device logs excluded, device behavior unverified.

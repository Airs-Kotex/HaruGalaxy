# iOS15 image feedback: compatible canvas and rendering evidence

User supplies diagnostic9D9 and reports870 game box and Telegram fail to display images on iPhone12/iOS15. Log establishes iPhone13,2/iOS15.4.1/19E258, app0.3.10/build15;1133 records,9 launches with presenter objects, no launch/guest exceptions.870 first content390x164; reopening390x844 still reported bad. Telegram350x731 then339pt half content. No layer/client attachment observations. Both exported snapshots have no registered guests; no timed capture. Do not infer first frame from presenter existence, or hardcode App/OS blacklists.

Design: per-App opt-in compatibility display keeps system logical canvas from scene creation, scales uniformly inside freely resized outer windows. Menu actions explicitly reopen that hosted window, save per-App preference and preserve outer frame/resize preference; reuse checked asynchronous release before replacement, generation/lock guards and no process termination. Normal free resize remains default.

Add read-only installed App metadata on launch: app version/build/minimumOS, scene-manifest/multiple-scene declaration, supported orientations and full-screen requirement. Keep unknown distinct from absent and do not dump plist/paths. Observe scene client connection, contentState, layer-manager counts and presenter hosting at attachment,0.5/2/6/12seconds plus bounded change events; layer presence is not successful pixels. No screenshot/media/network interception and no arbitrary default-scene takeover.

- [x] Geometry test first: fixed system canvas for164pt window, ordinary mode unchanged, uniform fit and rotation.
- [x] Implement/persist per-App canvas mode and panel menu recovery with safe release/reopen ownership.
- [x] Add installed metadata and passive scene-layer evidence; adapt reader and tests to preserve unknown/zero/render distinction.
- [x] Review and host/native/static checks for0.3.11/build16, including user-steered parking and gesture scope.

Release clean build/archive rebuild/CI/download results are recorded in verification-report.json. Neither this checklist nor successful host checks establish device rendering or thumbnail input success.

Files: Core/MWWindowModel.*, UI/MWWindowView/Preferences/WindowPanel/WorkspaceController, Platform/MWApplicationProfile(new), MWSceneSession/MWRuntimeDiagnostics, reader/tests/docs. Raw diagnostic is ignored and must not enter source/release fixtures. Current Telegram upstream differs from installed versions; exact installed metadata is required before any legacy-scene compatibility claim.

## User steering: half-screen gesture and parking

User reports slight bottom-rail interaction after half-screen immediately creates a tall left-aligned window whose title intersects system pull-down. Root source issue: proportional gesture began changes snap/geometry immediately and fits against the full viewport. Delay proportional conversion until14pt actual translation; keep tiny movements no-op. Conversion centers on the previous frame and uses top-safe viewport; all nonmax titles avoid top system exclusion.

Add parked live thumbnails at top-right, preserving complete model/frame/mode/snap/maximize restoration state and the existing guest logical canvas. Parked thumbnails intercept touch for restore and release guest keyboard ownership; scenes stay alive, so this is visual parking, not process suspension or native AVPictureInPicture. Multiple thumbnails fit vertically within safe bounds. Restore through thumbnail/panel; minimize parked first restores state then collects. Add settings for size18–50% of screen short edge, default36%; ratios follow-content(default),1:1,4:3,3:4,16:9,9:16, without changing saved restore state. Panel original-app action moves to existing options menu to keep4×44pt controls.

Independent review found compatibility reopen lost top position/fullscreen/snap state. Capture full restorable model and initialize replacement before launch, bypassing default placement. Tests cover this roundtrip along with parking/small viewport/rotation geometry and deliberate resize activation. Expanded review must check gesture cancellation, parked state transitions, layer ordering, keyboard ownership, settings updates and lifetime/cancellation of compatibility reopen. This remains one0.3.11 release until all authorized work is complete.

Completed: full snapshot restoration plus initial parking after scene ready; existing/late-loading detached windows attach before parking. Follow-up review reports no confirmed remaining blocker. UIKit/device checks remain in device-validation-0.3.11.md.

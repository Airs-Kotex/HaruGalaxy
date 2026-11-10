# Input evidence, minimized execution and physical orientation

**Goal:** Stop unsupported guest keyboard selection, collect the missing layer evidence automatically, offer a minimized execution policy, and orient every hosted window with the physical device. User authorization covers implementing these behaviors and a normal new release. Latest user instruction supersedes same-version merging: publish0.3.13/build19 and preserve0.3.12/build18.

**Architecture:** Keep process execution, presentation and keyboard ownership independent. `MWGuestPolicy` contains portable execution and orientation decisions; `MWDeviceOrientation` supplies balanced UIDevice notifications. Rotate an app-owned workspace canvas relative to the host scene, update guest interface/device orientation, and convert safe areas in the canvas coordinate space. Background assertions target only the launched guest PID and are released on restore/close/policy changes. Incomplete keyboard hosting never selects a guest or makes its host key. Diagnostic probes observe registered/hosted/excluded layer categories without reading pixels, input or clipboard.

**Tech Stack:** Objective-C/UIKit (iOS14+), existing FrontBoard/BKS capability checks, portable C and Python verification.

## Constraints and evidence

- Preserve four-window limit, 28pt top controls, 8pt bottom resize rail and current snap/parking interaction.
- System background suspension is not a forced process freeze. Keepalive requires an OS grant and cannot guarantee arbitrary guest background tasks or survival under memory pressure.
- Sensor directions and UI landscape directions are opposite; face-up/down/unknown retain the last valid orientation. Host rotation must not double-rotate the canvas.
- FCCEA diagnostic has22409 records/20 sessions. Only two sessions are build18 (1079+158 records). `cn.aliqin.KB` reports zero registered layers before/after original-canvas reopen. Another guest reports3 layers/2 non-keyboard layers. `searchScreen` visibility belongs to a different source. No build18 timed capture with a live guest is present. These observations do not prove which layer swallowed a tap.
- Do not revive prepare-only keyboard hosting or introduce global keyboard suppression. Retain working host search. Compatibility canvas only changes layout; it is not an input or missing-layer repair.
- No device/simulator available. Do not claim keyboard or universal third-party orientation success from host tests.
- Raw diagnostics remain ignored/local. Preserve the previous release;0.3.11 and0.3.2 stay withdrawn.

## Tasks

- [x] Add `Sources/Core/MWGuestPolicy.{h,c}` and regression cases in `Tests/guest_policy_test.c`. Cover all lifecycle states, minimize toggle, both landscape mappings, invalid sensor values,180-degree turns and relative canvas rotations. Register the suite in `scripts/test.py`; run it failing before implementation.
- [x] Extend `MWBackgroundLease` to accept a validated owned PID. Integrate execution policy in `MWSceneSession` and `MWWindowView`; expose a setting and current grant in panel/diagnostics. Every exit, restore, failure and native handoff releases the guest assertion.
- [x] Add balanced physical orientation observation; rotate only the owned canvas relative to UIWindowScene. Feed the same resolved orientation to logical sizing, safe areas and guest settings, including minimized/parked guests. Reflow saved proportional/full/snap state without changing the parking control footprint.
- [x] Remove the incomplete guest focus fallback before `makeKeyWindow`. Add exact source matching, actual remote keyboard window observations and bounded registered/hosted/excluded layer snapshots on change. Keep unavailable distinct from false. Extend diagnostic reader with per-session selection and tests so older capture events cannot be attributed to a new build.
- [x] Replace misleading compatibility wording with original-canvas wording in UI/tutorials. Update feature usage, remaining limitations and build19 changes. Re-render the affected operation illustration.
- [x] Run portable tests, native warnings-as-errors package build, static analysis and independent review (requesting-code-review skill), fix findings and verify the exported source. Publish authorized0.3.13/build19 with accurate notes and check public package/version/digests.

## Key policy contracts

```c
typedef struct { bool presented, keepAlive; } MWGuestExecution;
MWGuestExecution MWGuestExecutionForState(MWWindowState state, bool hostVisible, bool keepMinimizedAlive);
/* UIKit enum values, explicit mapping rather than a cast. */
int MWInterfaceOrientationForDevice(int device, int previous);
int MWDeviceOrientationForInterface(int orientation);
int MWOrientationQuarterTurns(int orientation);
```

For example, a minimized window with keepalive enabled always has `presented=false, keepAlive=true`; a visible window hidden by lock has both false. `MWInterfaceOrientationForDevice(3,1)==3` and `MWInterfaceOrientationForDevice(4,1)==4` (UIKit enum names already reverse the numeric mapping). No input policy decision may infer a usable keyboard from `keyboardVisible` alone.

## User additions during execution

Support iPad explicitly: retain universal device families and all four iPad orientations, cover tablet/split-view sizes in geometry regressions. No claim of device verification.

User reports native first-open crashes after closing guests and explicitly authorizes real process termination if seamless scene handoff cannot be established. Existing local teardown callbacks do not establish seamless native rendering, so explicit Close now finishes scene cleanup and requests termination of the original RBS process handle. It never targets a bundle-wide or all-process predicate. Observe exit before allowing a same-bundle guest reopen. Preserve the non-terminating compatibility-reopen and host-shutdown paths. Retain exact process handle across failed/local scene cleanup; a Close during launch waits for the original launch to resolve. The user understands unsaved guest state may be lost.

## Review corrections

UIKit landscape names are reversed but their physical/UI numeric values are equal; the initial double-swap was corrected and named SDK static assertions added. Panel snapshots include keepalive request/grant and refresh on lease changes.

Explicit process close no longer waits for native handoff. Keep the closing window/panel row until actual exit, distinguish pending/rejection, and retain errors for retry. Observe process exit before requiring termination capabilities so manual termination clears unsupported systems. The portable close state covers a pending execute, exit-before-reply, rejection, exactly-once completion and ESRCH vs EPERM. Only user Close invokes it; canvas reopen and automatic host teardown do not.

Release verification/publication is recorded by the final build, source-archive, CI and public-download reports in ignored dist/, not inferred from this plan.

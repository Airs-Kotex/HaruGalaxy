# Flush half-screen header

User wants half-screen to occupy the top/title region like the earlier appearance; prior four-corner resize and parking are accepted. Interpret as snapped-window header flush with its half-screen top edge, without an additional full safe-top spacer. This is not a global removal of free-window reachability protection.

Source: layoutSubviews applies safe-top padding and short-title reposition to every nonmax/nonparked window, including snaps. The model already fills the exact half-screen rect. Change policy centrally: snapped windows have0 extra header inset and keep their snap frame; ordinary free/aspect windows keep existing reachable-title behavior. Guest safety insets and physical cutout limits remain system controlled. Four-corner shrink-to-fit resize continues when exiting snap.

- [x] Add geometry tests for top/bottom/left/right snap exact occupancy and header/content position,59/47/0 safeTop, ordinary-window safety, park/unpark/fullscreen restore/rotation.
- [x] Use shared layout policy in MWWindowView; diagnostics record snap/header origin and layout version. No guest focus changes.
- [x] Focused independent review completed; signed chooser-row comparison corrected. Version0.3.12/build18 with merged changelog/README.

User steering: add GitHub images highlighting core behavior and controls. No iOS simulator/device screenshots exist. Produce deterministic operation illustrations via repo-native drawing code, visibly labelled“操作示意图 · 非真机截图”; abstract sample content only. Cover flush halves, four resize zones+center controls, and parking/settings/restore. Add PNGs to Chinese/English README, retain reproducible renderer and disclose physical cutout/system gestures and device-verification limits. Do not claim images came from actual tests or expose diagnostic data.

Further steering: user cannot find compatibility action. Add an explicit panel-top“兼容显示”button next to Open App/Parking Settings (three≥44pt buttons within existing row), opening a normal table controller of current window names and clearly labelled reopen actions. Dismiss before invoking existing checked reopen; callback resolves exact target identity, existing hidden/lock/pending guards remain. Preserve ellipsis fallback. Add a fourth operation diagram showing this path and update all docs. No claim that canvas mode fixes870/Telegram.

Final user instruction: merge this scope into existing0.3.12 release, keep marketing version0.3.12 and raise build to18. Backup published build17 metadata/assets before replacement, rebuild all artifacts from new commit, retarget v0.3.12 to that commit, replace same-named release assets and verify public digests. No0.3.13 release.0.3.11 stays absent.

Four labelled PNGs rendered and visually reviewed; both README image references checked. Final clean commit build/archive rebuild/CI and replacement-download checks are recorded in verification-report.json. No device rendering claims.

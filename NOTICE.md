# HaruGalaxy — Source and attribution

HaruGalaxy (初春星河), formerly UiharuXPro4MilkyWay, is an independent native alpha project maintained by Airs-Kotex. It is not an official UiharuX or MilkyWay release.

- UiharuX by straight-tamago: product/behavior reference. The official 2.0 binary was inspected locally; no upstream executable, icons or other binary assets are bundled.
- MilkyWay 3 by YuriDevTeam / Soh Satoh: interaction reference. No MilkyWay binary or implementation source is bundled.
- FrontBoardAppLauncher by khanhduytran0 and contributors, commit `fe304c66b87e9bd77896366f234dfadae01df0b6`: private interface declarations in `ThirdParty/FrontBoardAppLauncher`, and the scene launch/presentation and floating binder approach. Upstream repository supplies Apache License 2.0; its LICENSE and original header notices are retained. New platform source files identify modifications, including unique scene IDs, cancellation, cleanup without process termination, and capability checks.
- TrollSpeed by Lessica: global-window architecture reference only. No TrollSpeed source or resources are included in this alpha.
- LLVM compiler-rt 14.0.0: `ThirdParty/CompilerRT/os_version_check.c` provides the real Apple availability runtime needed by the Linux cross-linker for `@available`. Source is unmodified, licensed Apache-2.0 WITH LLVM-exception; license retained and included in the application. Source: https://github.com/llvm/llvm-project/blob/llvmorg-14.0.0/compiler-rt/lib/builtins/os_version_check.c
- Theos headers and nst/iOS-Runtime-Headers: reference declarations for BKSProcessAssertion flags/reasons and FBSSceneSettingsDiff construction. The project defines only the required declarations and probes them at runtime.
- LeoNatan/Apple-Runtime-Headers: runtime declaration reference for binder removeScene/invalidate/_rootView, UIRootSceneWindow and the oneway scene-update method. 0.2.1 implements scoped adapters with runtime capability/ABI checks; no upstream implementation is copied.
- LiveContainer: consulted as a scene-management reference. No LiveContainer implementation files are copied into this project. Some declarations in FrontBoardAppLauncher's retained upstream header identify LiveContainer as their original context; those notices remain intact.
- MTACS/iOS-17-Runtime-Headers, commit `d1d960dfaa4107765dd7fcf891e4967c0930d5fd`: selector/type references for UIKeyboardArbiterManager, _UIKeyboardArbiterClient, UIScene, FBSSceneIdentityToken and RBSTarget. 0.3.5 checks method ABI at runtime; no complete runtime header collection is bundled.
- khanhduytran0 and HugeBlack: hosted-scene keyboard/visibility investigation, gist `504b16d86a2091e676c412bd0a517306`, revision `90ff2251f458b9600292e3d8ed29105693e869c8`. The project's implementation independently limits environment mapping to registered exact PID/token-derived environment pairs and manages their lifetime. Research reference: https://gist.github.com/khanhduytran0/504b16d86a2091e676c412bd0a517306/90ff2251f458b9600292e3d8ed29105693e869c8
- Apple Liquid Glass design guidance: visual reference for translucent controls, hierarchy, contrasting edges and accessibility. On TrollStore-supported iOS versions the project uses existing UIKit blur and custom layers, not Apple's iOS 26+ UIGlassEffect. No Apple design assets are copied.

New project implementation is licensed under Apache License 2.0. See `LICENSE`.

Links: https://github.com/straight-tamago/UiharuX · https://github.com/YuriDevTeam/MilkyWay3-Public · https://github.com/khanhduytran0/FrontBoardAppLauncher · https://github.com/Lessica/TrollSpeed · https://github.com/LiveContainer/LiveContainer


# 0.6 review

12 October 2026. This revision continues the actual-match comparison in REFERENCE-0.5.md and the recorded 0.5 room/FFA review. It does not claim recovered proprietary physics or literal 100-fold improvement.

## Changes selected from evidence

- Team AI previously initiated no passes without a human request, and its off-ball destinations still crowded the ball or waited near the rim. The new collector/support roles, pressure-aware receiver selection and decision cooldown are exercised through real action and ball-flight paths. The 29 focused tests include collinear receiver selection, interception, active/passive credit, pass bounds and action priorities. Full autonomous cooperative/custom/FFA matches complete; both team modes pass and receive, FFA remains pass-free. See REVIEW-0.6-AUDIT.md.
- Retained near-rim footage showed labels covering the ball. Matched native fixtures now prove local-name removal, useful separate names at readable size, ball/marker exclusion, physical dunk scoring, attachment continuity and immutable simulation input. The new paneled ball/dark board make possession and rim location easier to distinguish. Controlled deck descent plus yaw gives the same roughly .305 m maximum camera step before/after, so follow tuning was retained.
- HUD feedback depended on one latest event and could miss a score or erase it on the next bounce. Score differences now drive a persistent +1. Nine checks cover overwritten-event scoring, repeated snapshots, fresh-HUD baselining, keyboard/PlayStation prompts, countdown and correct tackle/possession wording. Actual native HUD captures were inspected.
- Headless processes animated a world that cannot render. A same-process ABBA replay of 900 fixed snapshots, excluding 120 warmup samples, measured presentation-enabled process-work p95 2.495/2.888 ms versus disabled .527/.424 ms, with equal HUD/reward signatures and unchanged state. This is a script-work measurement. The prior 183 ms scheduling gap was not reproduced in either short three-process probe; its cause remains unresolved.

## Release evidence

Final exported-package, network and natural-match receipts are summarized in VERIFICATION.md. Source-only results above are not substituted for packaged or household checks. GPU tests are serialized; recordings use normal input/action/physics paths with active opponents. Controlled visual fixtures are identified separately from natural matches.

The first candidate (EXE `4F905831CB61C9A9BDC586BF4607EA7C75625656A8C02F42D0AA99EADDAD4C48`) passed source/exact-pack/input/controller checks but retained old Windows file-version metadata. It was rejected before packaging; its interrupted movie and `v6-final-*` diagnostics remain as development evidence. The Windows metadata was corrected and the build now refuses a version mismatch. Final receipt labels use `v6-release-*` and a new executable hash. Gameplay production code was unchanged by that packaging correction.

## Remaining human checks

Play with two/three physical PCs and the actual mixed controllers. Judge moving catches, passing choices, repeated airborne dunks, boost-to-extra-jump timing, camera sightlines and long-session smoothness. Exercise 3-vs-bots and 2-vs-1 with balancing on/off, then a winning bag, wardrobe and rematch. No physical-pad or human enjoyment claim is made.

The no-extra-app room transport is implemented and tested locally, but the public WSS service is not deployed. The release retains a blank internet.cfg and disabled Internet controls. Cross-home play requires approved hosting and a real external connection test. TCP head-of-line stalls and the earlier unassigned host scheduling pause remain explicit limits.

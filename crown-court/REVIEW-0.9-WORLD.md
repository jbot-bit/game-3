# Crown Court 0.9 — presentation review

**Source and exact-package native review are complete; natural full-match acceptance is pending.** No new presentation blocker was found in the focused source tests and native images below. This document does not claim household playtesting, universal network smoothness, or reference-game parity.

## Changes and demonstrated defects

| Area | Reproduced problem | Result |
| --- | --- | --- |
| Immediate catch and pass | Exact 0.8 jumped 1.724 m normally or 2.587 m as Giant when passing in the catch tick. The catch transaction still held the loose-ball position. | The simulation now publishes the held position atomically. All six source transfer cases have zero release-position jump. |
| Pass during catch gather | A pass two frames into the gather moved backward 0.228 m in one frame; Giant moved backward 0.043 m. The renderer retired its carry offset too quickly. | World limits correction to 65% of actual incoming travel. All six cases have zero backward horizontal step. The largest remaining offset at 300 ms is 15.36 mm. |
| Stalled network input | An intermediate velocity-based limit still drifted 1.565 m while incoming position was frozen for 200 ms. | The final correction pauses when input position stops advancing. The repeated-position test has zero drift. |
| Hoop opening | A decorative support reached the hoop center although no matching collider existed, making valid shots appear to pass through a solid bar. | The support stops at the rear rim. Nine vertical rays through the opening hit no support geometry; the opening is visibly clear in the native close-up. |
| Homing projectile stepping | The retained pre-polish 0.9 package held still for 60 of 90 rendered frames and jumped up to 0.899 m at snapshot updates. It also kept drawing a projectile after its known lifetime. | Client presentation uses replicated velocity and the existing bounded 80 ms clock. The same 90 authoritative samples now advance every frame, with maximum step 0.300 m and maximum curved-flight error 31.95 mm. Lifetime, deletion and reset guards pass. |
| Expanded arena | The new canonical 64 × 112 m court needed matching routes, boosters, goals, stands and obstacles. | Connected side/cross routes, widely separated boosters and four padded rotating bars use shared simulation geometry. Rotor centerline error is at most 0.00000135 m across four sampled clocks. |

The existing catch gather, held-ball hand attachment, partial rim/net visibility and camera geometry are retained. World does not write authoritative snapshots or add an ordinary loose-flight position filter. These are original authored visuals; the arena dimensions and tuning are not claimed measurements of another game.

## Verified source evidence

The final presentation source, after projectile polish, is:

`world.gd` SHA-256: `9A0B5A9145C9DEB987C41776CA178CCA9DED74EBBF71151270C1F1C82235CBD4`

The earlier transfer and legacy receipts below retain their original world SHA-256 `D5C88597B2BF12C1205888B4FF6351858652BF70B6716483A04573E034798FB6`. Only Hype projectile presentation changed afterward; the projectile native capture records the final source identity.

The final native transfer capture used Sim SHA-256:

`9748D33215F36603E550C2673218A3312C877BC8FC33048E36F35320C3A7FB29`

| Probe | Result | Retained workspace evidence |
| --- | --- | --- |
| `world_projectile.gd` | 12 checks pass; four matched native after images inspected | `build/crown-court-evidence/v9-projectile-native-after` |
| `world_ball_transfer.gd` | Six physical transfer cases and one frozen-input case pass | `build/crown-court-evidence/v9-ball-transfer-final-native` |
| `world_court_v9.gd` | Five checks pass; four native images inspected | `build/crown-court-evidence/v9-court-final-native` |
| `world_feel.gd` | 13 checks pass | `build/crown-court-evidence/v9-world-feel-final` |
| `world_polish.gd` | Eight checks pass | `build/crown-court-evidence/v9-world-polish-final` |
| `world_visibility.gd` | Nine checks pass | `build/crown-court-evidence/v9-world-visibility-final` |
| `world_visual_review.gd` | Zero failing regressions | `build/crown-court-evidence/v9-world-visual-final` |

The legacy camera, backboard, rim and deck fixtures now follow canonical geometry; they do not pass by testing an empty old goal location. Flight-convergence probes advance the simulation, while the starvation probe deliberately repeats a fixed input position. `regression-receipts.json` in the final transfer folder records the retained result hashes and their source identities.

The native transfer images show catch contact, release and six successive flight frames. The comparison sheet shows the corrected ball continuing out of the hands with its pass trail attached. The arena shots show the whole field, a crossing route, a padded rotor and the open basket. Native runs used Godot's OpenGL Compatibility renderer on an RTX 4070 Laptop GPU, exited successfully and had empty stderr.

The four court images were captured before the final ball starvation guard, at world SHA-256 `452AD6B925B1A56C5508C25201D7EBEAF90341999D5451FF882A845B8A48CDE8`. Terrain, rotor and hoop geometry did not change afterward. The original manifests retain that distinction.

The baseline is the retained exact 0.8 executable, SHA-256 `F64672B2B8520728827B2D64C746B7FC8113D99280A98C38F33EB8622FE1822D`, in `v9-ball-transfer-native-before`. Four of its six transfer cases intentionally fail. The frozen-input RED/GREEN pair is separately retained in `v9-ball-transfer-frozen-red` and `v9-ball-transfer-frozen-green`; that case was added after the baseline native capture.

## Game Development Studio receipts

The project-owned `import-v9-review` scenario imported the existing native images and diagnostic manifests. It verified PNG hashes, preserved failed baseline cases and sealed the provenance. It did not run Godot, execute a GPU workload or measure performance during import.

| Phase | Sealed run |
| --- | --- |
| Exact 0.8 transfer baseline | `run_1791776061767_f5cf4b75735648ec9b06e3f0292ea574` |
| Final 0.9 source transfer | `run_1791776074419_5fe4084a0ea54a078666e86b0b3e8acd` |
| Expanded source court | `run_1791776069011_586e592326c749ddad8f5440a9d57e84` |

All three plan/run/verify/analyze sets returned `ok: true`; the baseline/candidate visual comparison also returned `ok: true`. Receipts are retained in `build/crown-court-evidence/v9-visual-cli`.

The image comparison is **exploratory**: camera and resolution match, but arena dimensions and the physical pass solver also changed. Whole-image deltas are not a causal quality or performance score. The specific release defect is established by action telemetry and frame inspection. The sealed evidence is a capture-integrity result, not an automatic artistic judgment.

## Homing projectile follow-up

`tests/world_projectile.gd` activates the real simulation power, runs 90 actual physics steps including a moving target, publishes snapshots at 20 Hz and presents at 60 Hz. The baseline and candidate authority positions match for all 90 samples. The native four-frame crop sheet visibly shows the baseline holding still between updates while the candidate orb and its trail move forward each frame.

The shared 80 ms limit produces zero drift after starvation reaches its cap; this trace leads the last snapshot by 1.434 m. Host and frozen authority positions remain exact. New rounds discard old corrections and trails. Removed or known-expired projectiles are hidden immediately, and the inputs remain byte-identical. Presentation does not generate predicted impact events or change physics. Network latency, delayed authority impacts and arbitrary packet jitter remain outside this controlled cadence fixture.

- Failed baseline: `build/crown-court-evidence/v9-projectile-native-before` (four failures among the original nine checks).
- Final source: `build/crown-court-evidence/v9-projectile-native-after` (12 checks pass; later host/round/freeze guards are additional candidate checks).
- Before executable: retained `v9-pre-power-polish/CrownCourt.exe`, SHA-256 `69027F564E9387E3905C71E1A1AA4E52CF1B349276E350303DEDC850334E21E1`.
- Reviewed crop sheet: `v9-projectile-native-after/projectile-comparison.jpg`; original full-resolution PNGs and source copies remain beside it.

The project-owned `import-projectile-review` scenario verified and sealed the native images by CPU import. Both plan/run/verify/analyze sets and their visual comparison returned `ok: true`; no new GPU run or performance measurement occurred during sealing. Receipts: `build/crown-court-evidence/v9-projectile-cli`. Baseline run: `run_1791777874204_c5d47f3de7cb490897acf3d8dd7a7695`; candidate run: `run_1791777880886_9bbc77225bd34f87a8ff7192849c0028`. Unlike the earlier court/pass comparison, these capture frames share the same authority trajectory, camera, resolution and simulation ticks. Raster deltas still do not establish artistic quality or household feel.

## Final embedded-package native review

The final executable was loaded with the matching Godot 4.7.2 console runtime and its embedded `res://tests/` scripts. SHA-256 before and after all four serial captures was `9120C048816C600EB2EE5BD0C9DF0B15056E99EA50655827E2460E785EC149BB`.

| Native probe | Result | PNGs | Evidence folder |
| --- | --- | --- | --- |
| Court | 5 checks pass | 4 | `v9-final-native-court` |
| Ball transfer | 7 checks pass | 8 | `v9-final-native-ball` |
| Homing projectile | 12 checks pass | 4 | `v9-final-native-projectile` |
| Hype feedback | 21 checks pass | 3 | `v9-final-native-hype` |

Every process exited 0 with empty stderr. All 16 court/transfer/projectile PNGs match their previously inspected source images byte for byte. This is recorded in `build/crown-court-evidence/v9-final-native-image-comparison.json`. The three Hype images were inspected directly: menu selection explains Jump pad, the ready state identifies its key and power, and activation shows the active timer. The unavailable public Internet-room controls are correctly disabled for this undeployed build.

Independent inspection of the final court images confirms the connected raised routes, separated launch pads, padded rotating bars and open scoring aperture. The eight transfer frames preserve catch/release contact and show forward ball travel; the four projectile frames show continuous center motion and a connected trail. No new presentation blocker was found in these samples. Contact sheets sit beside the original PNGs.

The combined receipt is `build/crown-court-evidence/v9-final-native-verification.json`; each capture folder also has a `verification.json` with exact command, process status, package hashes and PNG hashes. These are controlled native fixtures, not live match, remote Internet, physical-controller, household-feel or performance evidence. Natural offline and room recordings remain separate release checks.

## Release acceptance still required

- Review natural offline and room matches for passing, catches, obstacle contacts, basket play, score/result flow and any new persistent obstruction.
- Keep household controller feel and real remote connectivity separate from local automated evidence.

No remaining source-only presentation rewrite is proposed without a new reproduction.

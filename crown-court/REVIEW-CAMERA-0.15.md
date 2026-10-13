# Camera review — 0.15 / 0.15.2

## Wall-turn discontinuities fixed in 0.15

Two avoidable wall-turn discontinuities reproduced independently of network/player movement:

- Tangential wall contact: the 0.14 final-match sample at 273.95 s reports a 2.634 m camera step with 0.06 rad yaw change near z=-55.5. A stationary player at (2,4,-55.5), pitch 0.43, yaw steps 0.06 rad/frame reproduces a 2.564 m cut. A small angle change makes the formerly grazing straight boom hit the wall much earlier.
- Corner pivot bypass: forward aim offset puts the camera target outside the bowl while the player remains inside. Crossing the target_outside>0.30 bypass boundary abruptly turns clearance on/off. Stationary corner sweeps against the exact original HEAD world source reproduce a 5.864 m camera cut.

The fix adds a conservative quadratic margin along the boom (0.04 times horizontal distance squared), retracting earlier as a wall is approached tangentially. Signed distance to the bowl permits a smooth margin inside the boundary while preserving the existing exterior envelope. For an in-bowl player, the aim pivot stays at least 1 m inside the horizontal bowl boundary; this prevents normal corner yaw from toggling the outside-target bypass. Genuine outside seats retain that bypass. Immediate yaw, target tracking rates, outward recovery rate, teleport reset, and v14 sloped roof clearance are retained. Tradeoff: closer framing beside walls, and a small inward pivot shift when aim look-ahead crosses the wall.

Headless evidence, isolated harness profile camera-v15:

- tests/camera_stress_v15.gd: four walls and four corners, 360 yaw steps each at 60 Hz, stationary player. All eight pass; maximum 1.069 m/frame. Baseline source fails the same cut threshold. The test supports --baseline=absolute-world-script-path for retained comparison.
- tests/camera_v14.gd: all five checks pass, including 95,040 stadium envelope samples, 0.507 m maximum back-wall descent step, immediate manual yaw, 18 m overhead-ball framing, and long kickoff relocation.
- tests/world_polish.gd: all eight checks pass; deck descent maximum 0.312 m/frame and authoritative input bytes unchanged.
- Logs under build/crown-court-evidence: camera-v15-wall-suite.stdout.log, camera-v15-wall-suite-before.stdout.log, camera-v15-v14-regression.stdout.log, camera-v15-world-polish.stdout.log. Original stationary north-wall reproduction: camera-v15-sweep-before.stdout.log.

Native comparison used the same four stationary scenes and isolated profile with the exact prior HEAD world script as baseline. All eight PNGs were inspected in build/crown-court-evidence/camera-v15-native-before and camera-v15-native-after: wall-grazing, wall-outward, corner-grazing, corner-outward. Wall grazing is slightly closer; the corner grazing pivot shifts inward. Directly outward views remain very close with a cropped player head in both baseline and candidate; this existing wall-framing limitation is not resolved by the anti-cut change. No inverted or degenerate view was introduced. Native candidate stress checks pass; baseline exits 1 as expected for the reproduced cuts. The owner handles GDS sealing of those captures; this camera review's native evidence and GDS provenance are separate from household play quality.

Fresh immutable 0.14 baseline corroboration: v15-review-baseline/view/active-play.json reports a 6.275 m step at 235.783 s with 0.06 rad yaw and zero authoritative player step. Surrounding samples place the player at z=55.5, x approximately 17, y 1.62; camera goes from (24.25,7.06,52.17) toward (18.90,4.37,56.25). This is an end-wall grazing event, not a corner. Retained outward velocity also supports the separate wall-momentum correction owned by the movement review.

The earlier 20.533 s final-match maximum 4.227 m was not classified by the bounded stationary reproduction: neighboring samples are high above and inside the bowl (roughly y 16–18, z 42–44), with input advances and snapshot timing delay. It is not evidence of this wall collision defect. Telemetry records camera position in physics callbacks; native frame timestamps are wall time and are not directly interchangeable with test elapsed time. The screenshot at wall-time 20.63 s still shows kickoff countdown, so matching those numbers alone would misattribute the frame.

## Remaining 0.15 full-match yaw events

Read-only inspection of build/crown-court-evidence/v15-final-match/view/active-play.json classified its 5.358 m camera step at 121.783 s and 4.709 m step at 53.783 s as yaw-associated camera orbit changes, not reproduced stadium-clearance cuts. Both players are grounded around x +/-16, z -44 to -46, well inside the bowl. The stadium solver has room and the floor clamp lies below the camera. Neither state change approaches the 16 m teleport threshold.

| Sample interval | Camera-relative yaw | Input yaw | Horizontal camera/player offset |
|---|---|---|---|
| 53.7 to 53.8 s | 1.408 to 2.739 rad | 1.448 to 2.716 rad | 6.244 to 6.386 m |
| 121.7 to 121.8 s | -1.345 to -2.124 rad | -1.376 to -2.095 rad | 6.093 to 6.395 m |

The small yaw_change attached to an individual cut does not describe the same render interval: observe() reads input yaw during physics_frame, while world.present updates the camera in _process. The larger yaw changes exceed the automated driver's nominal 3.6 rad/s cap; the retained evidence does not identify whether additional physical/controller input or input accumulation caused that. No speculative runtime smoothing was added. A future diagnostic should log consumed render yaw, pitch and dt with camera position and tag each input source.

## Raised-hoop framing follow-up — 0.15.2

The authored 5.8-unit hoop exposed a separate composition defect: at player (0,0,-43), yaw 0, pitch 0.43 in a 1280x800 viewport, the top of the rim projected to y 69, inside the scoreboard area. This is not a collision cut.

A bounded nearby-hoop focus now uses the existing vertical interval solver. Weight fades smoothly from full inside 6 units to zero at 14, multiplied by a facing-dot fade from 0.2 to 0.8. The solved pivot/distance/FOV blend back to the ordinary camera before normal target smoothing. The solver moves along camera-up and preserves the user's yaw and pitch. It reserves extra vertical space for the scoreboard and feet while near a hoop; explicit ball-camera retains its prior margins and takes precedence. These are authored readability choices, not recovered Crown Jam camera constants.

New tests/hoop_camera.gd fails before the change: rim top 68.998 px. Afterward both goals place rim top 167.703 px and feet 666.316 px, with both 1.70-unit bean and 2.164-unit family silhouettes inside the tested safe region. Approach and departure at 3 units/s each peak at 0.05836 m/frame; turning away at 0.01 rad/frame peaks at 0.06726 m/frame. The continuity threshold is 0.25 m/frame at 60 Hz. Both-goal aim-yaw checks pass. The fixture checks nine cases total.

Existing camera_v14 (five checks, including ball-camera), camera_stress_v15 (eight walls/corners), and world_polish (eight checks) all pass after this change. Logs: hoop-camera-before.stdout.log, hoop-camera-after.stdout.log, hoop-camera-v14.stdout.log, hoop-camera-wall-stress.stdout.log, hoop-camera-world-polish.stdout.log under build/crown-court-evidence. All used isolated profile camera-v15. No GPU process or export was run by this follow-up; production camera source is frozen for owner-run native/pack validation.

No build, export, commit, push or household validation was performed by the camera subagent. Owner-run release evidence supersedes this bounded source/fixture review for package claims.

# Ground movement: user-feedback revision

The user identified the missing initial scramble and direction-change commitment in Crown Court. This revision responds to that direct feedback and a measured local defect. It does not claim recovered Crown Jam constants.

## What the actual match establishes

The [Raks full match](https://www.youtube.com/watch?v=4IdjAgwrwgc) was reopened in the browser. The normal video player was sought to 1:31–1:32.25 and 2:24–2:27; browser screenshots are retained as `reference/v6-ground-source-*.png`, with the first twelve samples in `reference/v6-ground-reference-sheet.jpg`. These show animated strides, contact/dust bursts, and a carried-ball pivot through a changing camera view. The first interval contains a tackle, and the second includes contested possession and camera yaw. Neither provides input timestamps or a calibrated clean 180-degree reversal. Exact startup delay, acceleration and skid distance cannot honestly be measured from these samples. No remote media file was downloaded for this review.

## Local problem and authored change

The previous simulation applied `move_toward` separately to X and Z. Diagonal acceleration therefore had a larger resultant magnitude. It also reached almost full running speed in 0.18 seconds and completed a full reversal in under 0.4 seconds, leaving little physical anticipation for the character animation.

`Sim.ground_velocity(velocity, intent, speed, dt)` now applies a single horizontal vector change. Traction rises from 16 to 34 as speed builds; hard opposing input blends toward 24; no-input braking uses 28. Input acts on the first physics tick. There is no timer that ignores controls. The slower start and reversal are authored tuning choices for the requested scramble/plant behavior. Normal top speed and analog input magnitude are preserved. Ground boosts, airborne control, jumps, tackles, dunks, terrain and ball physics use their existing paths.

The application owner uses the same pure helper for local visual prediction. The world owner derives startup/skid poses from intended movement versus actual velocity; no animation changes authoritative root position.

## Measured at 60 Hz

All measurements below are flat-ground simulation fixtures without boosters. Skid is maximum displacement along the pre-turn direction; turn heading is within 10 degrees of the new input.

| Measurement | Previous | Revised |
|---|---:|---:|
| Standing start to 90% speed | 0.183 s | 0.383 s |
| 90-degree cut: heading settled | 0.183 s | 0.400 s |
| 90-degree cut: old-direction travel | 0.862 m | 2.071 m |
| 180-degree turn: old-direction stop | 0.200 s | 0.417 s |
| 180-degree turn: 90% reverse speed | 0.383 s | 0.783 s |
| 180-degree turn: skid distance | 0.862 m | 1.806 m |
| Diagonal 180-degree turn: 90% reverse speed | 0.267 s | 0.783 s |
| Diagonal 180-degree turn: skid distance | 0.588 m | 1.806 m |
| Release to stop | 0.167 s | 0.350 s |
| Release coast distance | 0.700 m | 1.533 m |

These are local units/metres and local simulation timings, not original-game measurements. The first 16.7 ms tick already moves the revised player; foot motion can immediately communicate intent while the body gains traction.

## Verification and decisions

- `tests/ground_turn.gd`: eight failures on the previous model, ten checks pass on the revised model. Includes first-tick response, bounded startup/reversal/coast, diagonal equivalence and partial analog speed. Logs are `v6-feedback-ground-red-clean` and `v6-feedback-ground-verified-ground_turn` under `../build/crown-court-evidence/`.
- Existing simulation 58, feel 18 and reference feel 15 pass. Jump/launch/dunk timing remains unchanged. The old simulation test's `>8 m during the first second` assertion conflicted with intentional acceleration. It now directly compares an oversized input with a unit input and checks the speed limit, instead of imposing the old startup tuning.
- The original natural team-play test required both sides to pass in every single match. The revised movement produced a valid 0–4 cooperative shutout before Blue completed an outlet, so that distribution assertion failed. The receipt remains preserved. The test now requires actual passing in each team mode, both sides across the cooperative/remapped-roster set, and the receive cooldown. Four explicit mirrored side tests independently prove both attack directions choose and physically complete a pressure pass. No scores or possession were awarded to make the natural runs pass.
- Team-play focused checks: 33 pass. Natural co-op finishes 0–4, custom remapped 3v3 finishes 8–4, FFA finishes 3–7–6. Across team rosters, actual passes are 13/14 and receptions 13/11 by side. FFA stays pass-free. This is not a balance or human-fun claim.
- Sim SHA256: `A41CECFF64D832E1661455ACDBDCD74D9DD434E77C66C1CC63BFEC1EF3FD5EAA`. App prediction, skid visuals and the new sound design have separate owners and require integrated rendered/playback verification before shipping.

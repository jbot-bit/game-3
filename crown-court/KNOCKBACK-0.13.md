# Crown Court 0.13 - momentum and recovery

## Evidence boundary

These are authored Crown Court tuning values. Original Fall Guys/Crown Jam runtime constants remain UNKNOWN; no original game artifact was available for this task. The requested REA skill explicitly routes complete source analysis through ordinary repository tools. Existing reference footage informs the visual goal but does not certify exact physics parity.

## Reproduced issues

The 0.12 motor switched immediately from the committed dive or stun into ordinary ground braking (28 units/s²) or driven acceleration. The knockdown drag also damped X and Z separately, causing diagonal impacts to travel less far than cardinal impacts. A focused 60 Hz simulation reproduced five failures before edits: short knockback recovery, unequal diagonal travel, opposing input erasing momentum, short missed-dive recovery, and run release already stationary at 0.4 seconds.

## Changes

- Running release brakes at 22 units/s², keeping a short coast while preserving start and hard-turn traction.
- Dive remains committed for 0.34 seconds. A 0.85-second slide timer starts with the dive, leaving about 0.51 seconds of progressive recovery.
- Tackles retain the existing 11.5 horizontal / 5.2 vertical impulse, 0.65-second stun, 0.85-second cooldown and 1.4-second guard. A 1.15-second slide timer spans knockdown and recovery; control returns after stun with bounded traction, not instant momentum cancellation.
- Sweepers receive the same recovery behavior with their existing 0.35-second stun and a 0.85-second slide timer.
- Recovery traction rises from 10 to 22 units/s² over the last 0.52 seconds. Players can steer after stun, and momentum always settles when input is released. Boosts retain priority.
- Knockdown drag uses one horizontal vector, removing diagonal bias.
- Receiver forecasting and local grounded client prediction use the same recovery motor and countdown. Prediction edits a snapshot copy.
- Snapshots expose `slide_time` and `slide_kind` (`dive` / `impact`) for grounded glide/recovery poses. Respawn clears both. Grounded status remains the presentation gate; these timers do not imply an airborne player has landed.

## Measured before / after

Flat court, no bots or pads, normal-size player, isolated test save, 60 Hz:

| Measurement | 0.12 | 0.13 |
| --- | ---: | ---: |
| Knockback speed at 0.85 s, input released | 3.053 | 6.353 |
| Knockback full stop | 0.967 s | 1.183 s |
| Knockback total travel | 8.077 | 9.413 |
| Knockback ground travel after landing | 2.521 | 3.858 |
| Diagonal knockback total travel | 7.526 | 9.413 |
| Knockback forward speed at 0.85 s, opposing input | 3.920 | 6.353 |
| Missed-dive speed at 0.70 s | 5.200 | 9.858 |
| Run-release speed at 0.40 s | 0 | 0.700 |
| Run-release travel at 0.40 s | 1.533 | 1.967 |

At 30 Hz the new knockback travels 9.232 units and stops at 1.20 seconds, within the authored tolerance of 60 Hz behavior. Landing remains at approximately 0.52 seconds at 60 Hz. Authored acceptance thresholds are usability targets, not recovered original-game measurements.

## Verification

`tests/slide_recovery.gd`: 15 checks pass, including cardinal/diagonal equality, stop bounds, opposite-input retention, 30/60 Hz consistency, missed-dive stop, released-run coast, receiver forecast agreement for dive/impact, snapshot state, unchanged guard and respawn reset. `tests/client_slide_prediction.gd`: 16 checks pass, including predicted position/velocity/countdown and source snapshot immutability under neutral and opposite input.

Existing suites pass: `ground_turn`, `sim_test` (58), `tackle_contacts` (12), `tackle_pressure` (39), `reference_feel` (15), `gameplay_v11`, `client_ground_prediction`, `teamplay_sim`, `feel_sim` (18), `hazard_prediction`, `review_v8_terrain_recovery`, and `arena_powers` (24). Logs: `build/crown-court-evidence/slide-recovery-before-v13.*`, `slide-recovery-after-v13.*`, and `physics-v13-*.stdout.log` / `.stderr.log`. All engine launches use the repository harness and isolated `physics-v13` save scope.

This verifies local simulation behavior. Household feel, controller comfort, physical three-PC networking and original-game parity remain unverified. Visual review and packaged executable checks belong to the parent task's final evidence.

# Crown Court 0.15 movement stress review

Scope: authored Crown Court motor behavior. No original-game executable or recovered constants; no physics-parity claim. Source baseline e70e717 (published 0.14). All engine launches use harness.ps1 with ProfileScope movement-v15; household saves are untouched.

## Reproduced defects and changes

Focused real Sim.step probes failed before changes and passed afterward:

| Probe at 60 Hz | Before | After |
| --- | --- | --- |
| Released airborne speed after 0.5 s, cardinal / diagonal | 8.24999 / 7.73224 | 8.24999 / 8.25000 |
| Reversing airborne speed after 0.5 s, cardinal / diagonal | 0.50000 / 3.22792 | 0.50000 / 0.50000 |
| Perpendicular airborne steering speed after 0.5 s, cardinal / diagonal | 9.01388 / 7.09470 | 7.09470 / 7.09470 |
| Run into side or end wall: retained outward velocity | 9.5 | 0 |
| First reverse-input tick after wall contact: displacement away | 0 | 0.00444 |

The airborne motor independently moved X and Z toward target, giving heading-dependent acceleration and braking. It now uses one horizontal vector with the same acceleration constants. This also applies to boost steering through the existing motor branch. Ground traction, dive duration, knockback impulse, recovery timer and guard constants are unchanged.

The wall clamp previously stopped position while retaining blocked outward velocity. New shared Sim.constrain_player_bounds cancels only the velocity component directed into the touched wall; tangential and inward motion survive. Authority integration and pass-receiver forecasting use it. Root owns corresponding client prediction integration.

Additional focused tests verify both side-wall dive tangents and 0.5-second pass forecasts match real wall slides. Final focused suite: 9 checks pass. Red evidence: movement-v15-focused-before.stdout.log and .stderr.log. Green evidence: movement-v15-focused-final.stdout.log, all under build/crown-court-evidence.

## Matrix and regressions

movement_stress_v15.gd sweeps 4,608 scenarios: 30/60/120 Hz, eight headings, released/opposite/perpendicular/forward input, flat/bank/wall starts, grounded/airborne starts, normal/giant size, and run/dive/impact/boost. Each runs three seconds and checks finite bounded motion, no terrain penetration, and full rest after released input. Motor isolation uses normal pad/hazard cooldown fields; the final matrix carries a ball to avoid unrelated loose-ball collision work. Free-player behavior is covered by the focused probes and existing regression suites. Giant is exercised directly; boost state uses its normal movement fields. This is not an assertion that every power acquisition interaction was covered by the matrix.

Existing scripts passed: slide_recovery, ground_turn, tackle_contacts, tackle_pressure, reference_feel, arena_powers, client_slide_prediction, client_ground_prediction, hazard_prediction, gameplay_v11, teamplay_sim, feel_sim and sim_test. Logs use movement-v15-regression-* labels. These include real power-pad and hazard integration in arena_powers.

Full matrix result is recorded below after completion. Initial loose-ball baseline matrix exceeded the 55-second harness bound and was rerun with a longer bound; focused red receipts establish both defects independently.

Headless simulation evidence does not establish household feel, physical three-PC networking, or original-game parity. Visual/playtest and exact packaged builds are owned by the parent review.

Completed candidate matrix: **4,608 scenarios pass, zero violations** in movement-v15-after.stdout.log. Matrix run contains the first five focused probes; the separate final focused receipt covers all nine. Use a 300-second harness timeout for the full sweep, or --focused-only for the short regression subset.

The longer baseline run also completed: all 4,608 loose-ball matrix scenarios met the broad invariants, while the five focused behavior regressions failed as expected (movement-v15-before.stdout.log). The baseline and final matrices differ in ball ownership, so they are coverage runs rather than a direct performance comparison. Final matrix elapsed about 76 seconds; the 300-second bound allows machine load variation.

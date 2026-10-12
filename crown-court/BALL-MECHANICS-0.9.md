# Ball mechanics revision for 0.9

The user's direct feedback rejected the ball feel and the small arena. This revision addresses demonstrated mechanics faults and the parent-owned larger arena. It does not claim recovered Crown Jam physics or human playtest approval.

## Baseline and reference

The held 0.8 candidate is `../build/crown-court-0.8.0/CrownCourt.exe`, SHA256 `F64672B2B8520728827B2D64C746B7FC8113D99280A98C38F33EB8622FE1822D`. New external test drivers loaded that exact embedded pack for the retained failures. Its partial networking receipt is `v8-held-network-partial.json`: relay and impaired ENet gates passed, but the LAN matrix/action sequence was intentionally not started after the release hold. There is no completed 0.8 network-suite claim.

[Epic's gameplay article](https://store.epicgames.com/news/fall-guys-crown-jam-slams-into-fortnite?lang=en-US), reopened for this task, describes shots from the team's own half and a long lob creating follow-up dunk opportunities. Earlier sampled gameplay records in [REFERENCE-0.5.md](REFERENCE-0.5.md) show a conspicuous arcing pass at approximately Tocanscenes 2:34.75–2:37.75. That is a sampled release-to-reception sequence, not a calibrated flight-speed measurement or an input trace. Exact internal constants remain unknown.

## Demonstrated failures

`tests/review_v9_ball_mechanics.gd` against the exact 0.8 pack retained five failures in `v9-ball-mechanics-exact08`: stationary 16 m reception worked, while steady sideways motion missed by 4.494 m in either direction; a 24 m moving reception missed by 8.332 m, a braking receiver by 2.225 m and an airborne receiver by 4.874 m. The release code led the receiver for only 0.4 seconds even when the ball would fly for much longer. After release, these tests advanced actual simulation input/physics without moving the ball or players into a result.

`tests/review_v9_shots.gd` against the same pack retained the launch discontinuities in `v9-shots-exact08`: changing aim by 0.1146 degrees across the old dot-0.92 gate changed launch velocity by 9.973 m/s. Moving two centimetres across the 22 m gate changed it by 5.698 m/s. Full-power attempts from the team's own half and the deep court could not physically reach either basket. One overheld shot banked in; that is a legitimate physical outcome, not a reason to suppress a score.

## Repair and authored choices

- Passes predict the receiver's current movement intent for the whole flight, using the same `movement_velocity` motor as live simulation. The forecast includes traction, braking, current airborne gravity, boost expiry and surface landing. Future input changes, collisions and newly encountered launch pads can still beat it. The ball remains ballistic after release, with no homing or guaranteed catch.
- The enlarged court permits passes up to 70 m. Flight duration is distance / 18, clamped to 0.3–2.6 seconds; the old 16 m timing is retained. These distances/timings are authored choices. An unimpeded 69 m pass to a running receiver completes in 2.567 seconds in the current fixture.
- Shot assistance fades across angle and usable range instead of switching launch models abruptly. Charge controls a free lob's range, from 6 m to the court's length minus 4 m at full charge. A higher, distance-dependent apex makes long attempts viable. Underpowered long attempts fall short; overholding introduces visible overshoot/lateral error. Actual aim preview must use the same `throw_velocity` result. After release, opponents, the rim, backboard and terrain remain physical obstacles.
- Bot support width and forward outlets now derive from lane and hoop geometry rather than the previous court's hardcoded bounds. Explicit dunk/pass priorities and receiver decision cooldowns are retained.
- The parent separately repaired atomic possession: `secure_ball` immediately writes the carried hand position along with owner/velocity, removing a same-tick catch/release origin inconsistency reported by the world reviewer. The parent also owns the larger arena, separated backboard, hazards, kickoff and assist credit.

## Verification and limits

Current receipts under `../build/crown-court-evidence/`:

- `v9-ball-mechanics-long-range`: ten checks pass, including stationary/running/braking/airborne receptions, a 69 m pass, opponent interception and unchanged horizontal velocity during unblocked pass flight.
- `v9-shots-physical`: fourteen checks pass. Aim-boundary velocity change is 0.219 m/s; range-boundary change is 0.00957 m/s. Own-half/deep-court shots physically score in both directions, with a possible real rim rattle. Undercharge, overhold and aiming away can miss; outside-rim contact does not grant a basket; both backboard faces rebound; an airborne opponent can catch an assisted shot.
- Existing `sim_test` 58, ground-turn 10 and feel 18 pass. `teamplay_sim` 33 passes after replacing obsolete hardcoded out-of-range/old-hoop fixtures with current canonical dimensions.
- `v9-ball-teamplay-match` contains three complete autonomous modes: co-op 2–6, custom teams 4–0, free-for-all 4–0–7. Team modes produced 13 and 17 received passes across the two sides and retained at least 1.0167 seconds between reception and a bot's next pass. These deterministic runs establish active behavior, not win-rate balance or enjoyment.

An intermediate 24 m fixture crossed a newly added rotor (and an earlier version crossed a speed strip), so its assumed unobstructed route was invalid. Those failed receipts remain. The final fixture moves the entire route into clear terrain; it does not disable hazards or alter their collision response.

Rendered preview/attachment/arena review, input-driven recordings and the final exact-pack network suite remain separate integration gates. No physical-controller, household or cross-home success is inferred from these headless checks.

## Independent integration review

The review found that an actual own-basket lob correctly gave the opponent a point but incorrectly gave its shooter 30 Hype. The parent repaired the scorer-team check; `v9-assist-edges-independent-final` passes eight checks for physical own-basket scoring without Hype, expiry, tackle/drop, bot-to-human identity remapping and round reset. Its earlier failing receipt is retained.

Review also identified release-offset retirement against a frozen client target: world testing reproduced 1.565 m of visual drift over 200 ms despite a fixed incoming position. The world owner now bounds retirement by actual incoming travel, freezes it on identical positions and clears it on possession/reset. This is separate from the ballistic pass calculation; authoritative trajectories are unchanged by that presentation fix.

For shot-preview cost, Sim provides a conservative `ball_clear_of_static_colliders` broad phase. It may bypass the detailed solver only away from terrain, walls, decks, rim/backboard bounds and every possible rotor angle. It is not used to change live collisions. `v9-shots-broadphase` adds a fifteenth passing check: 4000 seeded points, 3296 admitted clear, zero differences from the real contact solver at those points. The app additionally compares entire forecast paths to actual throws; its measurements and rendered acceptance remain separate owner receipts.

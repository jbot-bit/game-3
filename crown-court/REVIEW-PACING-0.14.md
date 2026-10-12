# Crown Court 0.14 bot release-origin review

Scope: sim.gd only; baseline published commit 953cc833511b51efa6b816fb91e0192c288cd9ea. No movement tuning, human shot physics, profiles, family characters, unlocks or saves changed.

The retained ordinary-input matches show sparse opponent shooting: v13-confirmed-match has 3 bot throws and two opponent baskets (5-2 final); v13-verified-match has 1 bot throw and no opponent baskets (2-0 final). These observations motivated a release-path audit; they do not prove a general AI pacing defect or a win-rate estimate.

Reproduction: an approaching carrier entering a shot windup still brakes for 1.74-1.94 metres. Previously bot_command captured its shot solution before this braking, then used that stale origin at release. The corrected code starts the same visible windup and increments the same attempt number, but defers bot_shot until the release command. Its deterministic yaw and power error remain functions of the same player ID and attempt. Once released, the ordinary physical ball never consults a target. All reaction, decision, hold and windup durations are unchanged.

## Matched comparison

864 controlled trials: 24 attempt numbers/seeds, both hoops, starting distances 8/12/15 m, stationary/running approaches and all three difficulty levels. Seeds are matched, but bot aim is deterministic; varying attempt number is what varies its error. Each trial uses ordinary bot_command, move_input, action and physics after an isolated fixture setup. Every trial is one uncontested shot; this is not a representative match scoring rate.

| Level | Stationary baseline/candidate (144) | Moving baseline/candidate (144) |
|---|---:|---:|
| Easy | 25 / 25 | 39 / 27 |
| Normal | 51 / 51 | 62 / 33 |
| Hard | 127 / 127 | 36 / 80 |

All 432 stationary records are identical, including origin, velocity, release delay and score. All 864 release delays are unchanged. Lower-level scoring falls in this particular sample: the stale origin sometimes compensated for intentional aim/power errors. Hard scoring improves. This establishes a release-origin correctness fix, not a general pacing or difficulty improvement. Very close running shots can still overshoot because the 12 m/s physical minimum launch speed is unchanged.

The focused regression requires the first Hard attempt from moving 12/15 m approaches to score at both ends. Baseline fails; candidate passes. The broader sample also verifies that every shot actually releases and remains finite. Optional --baseline=<absolute script path> compares an immutable baseline; normal runs load the embedded res://sim.gd and are portable.

## Regression evidence

- gameplay_v11: PASS, including literal human aim across yaw/charge and position-independent launch.
- slide_recovery: PASS; existing skid and momentum values retained.
- tackle_contacts: 12 checks, 0 failures.
- sim_test: 58 checks, 0 failures.
- teamplay_match: PASS for full coop, teams and versus matches, on baseline and candidate. Baseline coop 1-2, candidate 4-2; teams 2-1 vs 1-2; versus identical 2/2/3. These deterministic trajectories establish completion, finite physics and passing, not human enjoyment or balanced win rates.

Receipts: build/crown-court-evidence/pacing-v14-comparison.json; pacing-v14-broad-{baseline,candidate}.stdout.log; pacing-v14-match-{baseline,candidate}.stdout.log; pacing-v14-final.stdout.log; pacing-v14-{gameplay_v11,slide_recovery,tackle_contacts,sim_test}.stdout.log. All execution used harness.ps1 with isolated pacing-v14 profile scope, headless Godot 4.7.2. No GPU playtest, export, commit, push or physical household verification performed by this worker.

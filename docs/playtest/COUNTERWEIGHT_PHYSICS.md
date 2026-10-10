# Counterweight physical course evidence

Verified 10 October 2026 against the second-course world in `prototypes/physics_party/party_counterweight_world.gd`. This is bounded developer evidence, not a household playtest or a claim that every power/crew combination succeeds on its first attempt.

## What changes in this course

The first crossing is a broad board on an off-centre hinge. Its long, low arm gives ordinary movable blocks useful leverage: a player can leave weight behind and then cross alone, or another player can help hold the low end. A generous raised checkpoint follows the board. The route then turns right across two independent movable planks in reversible crosswind to the shared finish.

The world inherits the original hands/prop recovery/replication machinery and retains the same seven prop identifiers, one hinge, checkpoint API and shared goal API. It adds no controller, interaction, inventory or network mechanism. The small loading step, platforms and supports use existing box geometry. All four cubes are movable 2 kg props; the board is 4.5 kg. The hinge is deliberately nearer the exit so cube weight has useful leverage against a ten-bone puppet.

## Full route outcomes on the frozen geometry

`tests/physics_party_counterweight_route_probe.gd` drives actual physical puppets with ordinary `set_controls` input and applies the same wind acceleration as the game. It never places a prop, fabricates a joint or assigns completion. The loader grips a cube through collision overlap, carries it, releases it, and verifies by a physical ray that the board supports the released cube. Every successful full-route actor has actual foot-contact evidence for both the seesaw and movable plank before settling inside the live goal volume.

Near-waypoint braking, cargo steering and helper position maintenance use analog bot input. These are not literal keyboard-only or human timing measurements. Crew routes are staged sequentially to give clear per-player contact evidence; they are not a claim that human players must take turns.

| Run | Result | Simulated time | JSON in `logs/` |
|---|---|---:|---|
| One base puppet, loaded board, fan +1 | All at goal | 40.13 s | `counterweight-route-1-base-wind-1.json` |
| Two base puppets, loaded board, fan +1 | Both at goal | 63.68 s | `counterweight-route-2-base-wind-1.json` |
| Three base puppets, loaded board, fan +1 | All three at goal | 92.10 s | `counterweight-route-3-base-wind-1.json` |
| One Heavyweight, loaded board, fan +1 | At goal | 29.95 s | `counterweight-route-1-heavy-wind-1.json` |
| One Feather Fall, unweighted jumping route, fan +1 | At goal | 25.15 s | `counterweight-unweighted-1-feather-wind-1.json` |
| One base puppet, loaded board, reversed fan -1 | At goal | 38.50 s | `counterweight-route-1-base-wind--1.json` |
| One base puppet, native OpenGL rendering | At goal, actual carried cube supported by board | 40.95 s | `counterweight-route-1-base-wind-1-native.json` |

The native traversal exited cleanly without engine errors or warnings. Its cargo, seesaw and checkpoint screenshots were inspected at 1280×720: `counterweight-native-cargo.png`, `counterweight-native-seesaw.png`, `counterweight-native-checkpoint.png`; the final view is `counterweight-route-1-base-wind-1-native.png`. This route probe's camera is an overview following the actor, not the game's normal player camera. The separate main native probe covers production camera/UI and performance.

## Weight changes the physical crossing

Three balance trials guide the rider to the front arm and attempt a three-second wait. The minimum below is sampled only while the rider has a real upward-facing foot contact with the seesaw and torso Z is below -10 m; it does not sample the empty board after a fall. The assisted rider then backs up using ordinary movement to make the normal running jump to the checkpoint.

| Trial | Minimum tip centre Y during far-arm foot contact | Outcome |
|---|---:|---|
| Empty rear arm | 1.218 m | Rider falls; cannot return for takeoff. This negative control intentionally exits with failure. |
| One actually carried 2 kg cube | 2.269 m | Cube is physically board-supported, rider survives the wait, returns for takeoff and reaches checkpoint. |
| Second puppet maintaining rear-arm position | 2.495 m | Helper has live seesaw foot contact at the end of the wait; rider returns for takeoff and reaches checkpoint. |

Evidence: `counterweight-balance-1-base-wind-1.json`, `counterweight-balance-block-1-base-wind-1.json`, `counterweight-balance-partner-2-base-wind-1.json` and matching `counterweight-balance*-final.log` files. The loaded and partner trials contain 302 and 314 qualifying foot-contact samples respectively (two floor casts can contribute samples in one physics tick).

This demonstrates a useful physical effect in these bounded control scenarios: the loaded cube preserves about 1.05 m more minimum exit height, and the helper about 1.28 m, compared with the empty control. The trials are not a statistically sampled difficulty measure or a perfectly matched kinematic experiment. The full solo loaded route separately proves that a permanent attendant is unnecessary.

An earlier partner trial allowed the helper to slide back to Start and therefore did not prove sustained rear-arm weight. The final probe corrects that evidence gap by maintaining the helper with ordinary analog input and explicitly asserting live rear-arm foot contact after the wait. No production physics changed for that correction.

## Recovery

The recovery mode begins with an explicitly labelled checkpoint-spawn fixture. In each of the one-, two- and three-player scenes, an actor walks off the checkpoint using ordinary controls and falls below the actual -12 m game recovery plane. The probe then invokes the same `reset_at(world.spawn_point(slot, 1))` API used by main. After three seconds, the recovered actor has floor contact inside the checkpoint; all other crew members remain finite and inside the checkpoint.

All three cases pass: `counterweight-recovery-{1,2,3}-base-wind-1.json`, with `natural_fall_below_minus_12=true` and `recovered_checkpoint=true`. This is component recovery evidence with a real fall and an initial checkpoint fixture. It does not exercise main's automatic recovery dispatch, assign checkpoint progress or assert a full post-recovery route.

The separate course contract probe checks seven prop identities, all three start/checkpoint/finish spawn volumes, wind presence/reversal reset and the inherited pose API. Main lifecycle/LAN checks and original puppet/recovery regressions are covered in `HANDS_FULL_STATUS.md`.

## Retained failures and limits

The following final-geometry first attempts remain unsuccessful and are not converted into passes:

- The one-Feather Fall loaded route grips and moves the cube, but releases it off the usable board area at 12.57 s (`counterweight-route-1-feather-wind-1.json`). That same power completes the separate unweighted jumping route above. This does not prove reliable cargo placement with Feather Fall.
- The three-Heavyweight loaded attempt releases the cube back on Start at 10.77 s (`counterweight-route-3-heavy-wind-1.json`). The solo Heavyweight loaded route passes; the all-Heavyweight crew route remains unproven.
- The three-Feather Fall unweighted route fails when the third actor crosses the movable plank at 75.68 s (`counterweight-unweighted-3-feather-wind-1.json`). The failed attempt was not replayed through recovery to full completion.
- The earlier weighted balance bot tried a standing jump too far from the checkpoint and missed. The final weighted balance run uses an ordinary retreat and running takeoff after the recorded wait; no platform or motor change was made to rescue that trial.

Spring Legs, Quick Feet and Grip have not received a complete second-course physical matrix here. Existing power/save tests passing is not evidence that every new-course power combination has been traversed. No claim is made about human fun, 45–90 second first-goal timing, three-PC Wi-Fi feel or repeated long-session reliability.

## Reproduce

Use the bundled Godot console executable with `--headless --fixed-fps 60 --path . --script res://tests/physics_party_counterweight_route_probe.gd -- --crew 3`. Optional arguments are `--mode route|unweighted|load|balance|balance-block|balance-partner|recovery|look`, `--power heavy|feather|spring|swift|grip`, `--wind -1|1`, and `--tag LABEL`. The empty balance negative control is expected to fail. To render a route, omit `--headless` and add `--rendering-method gl_compatibility`; no frame-time claim comes from that route run.

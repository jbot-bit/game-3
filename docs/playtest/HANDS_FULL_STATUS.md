# Hands Full 0.2.0 — verified local family build

Verified 10 October 2026 on Windows. Two short courses, five powers and a shared saved collection. This is a tested local package, not a household fun rating. No public upload was performed.

## Playable output

- `build/hands-full/HandsFull.exe` — 109,530,832 bytes; standalone embedded game data.
- `build/HandsFull-windows.zip` — 38,351,631 bytes; executable, controls/joining README and licenses.
- EXE SHA-256: `f564754ea49b6c0b81373480451ff689125b016058f1420d9202c48ccb53b494`.
- ZIP SHA-256: `ed44450183bc45516b7d5ed3e6046d5ed1625a3977ee5dfbe790384228254557`.

Extract the ZIP on all three PCs. The host selects First Crossing or Counterweight; Esc shows the join address. Everyone must use 0.2.0 on the same home network. Keep the same host PC for the shared collection. After a clear, the host can replay or move everyone to the other course without reconnecting.

The 0.1.1 executable and ZIP are preserved under `build/hands-full-previous-20261010T040205643` and `build/HandsFull-previous-20261010T040205643.zip`.

## What changed

Counterweight starts with an off-centre tipping board. Carrying a block onto its long end steadies the short exit end. The crew can help load and cross, leaving the block behind when everyone follows. The crew then turns right across two movable planks exposed to the existing reversible fan. The middle platform is a shared checkpoint.

Course selection, replay and Next course use the existing session and save system. Only the host can advance, only after completion, and failed saves must succeed first. Course transitions release old grips, hide stale client bodies until fresh poses arrive and discard the previous run's snapshots. Collected powers and clear counts remain shared across both courses with no save migration.

Godot 4.7.2, built-in Jolt, the physical puppet motor, two hand joints, five powers, recovery and rendering settings are retained. The new world has the same seven movable props as First Crossing. No new gameplay system or dependency was added. The previous grab-priority, jump-buffer, ledge-grace and held-prop recovery corrections remain intact.

## Verification

| Check | Result | Evidence / limit |
|---|---|---|
| Unit/regression suite | **47 tests, 752 assertions passed** | `logs/party-unit.log`; course selection, host-only completion/advancement, save failure/retry, replay, stale packets, collected choices, UI, session validation and presentation. |
| Existing physical controller | **51 puppet, 9 interaction, 6 ground-contact and 6 held-prop recovery checks passed** | `logs/physics_party_*_probe-020.log`; actual physical contacts, with controlled setup fixtures for some cases. |
| Independent course lifecycle review | **40/40 passed** | `logs/counterweight-review-lifecycle.json`; actual collision-created grips, old-world cleanup, repeated transitions, save retry, client world reconstruction and fresh camera/poses. State/completion fixtures, not LAN traversal. |
| Counterweight cooperation and routes | Actual carried-block weight and complete one-, two-, three-puppet routes demonstrated | `tests/physics_party_counterweight_route_probe.gd`, `logs/counterweight-*.json`; physical analog waypoint bot, not human or literal keyboard-only play. Limits below. |
| Source networking | **224 checks passed**, three clean exits | `.tools/physics-party-network-probe/20261010T035224839_170108a8/summary.json`; real ENet loopback across both courses, rejoin, restart and collected power choices. |
| Exact exported-pack networking | **224 checks passed**, three clean exits, no engine warnings/errors | `.tools/physics-party-network-probe/20261010T040302119_1615b18f/summary.json`; matching Godot runtime loads the exact embedded release pack from its clean folder. Completion and lever interactions use positioning fixtures. |
| Actual Windows executable | Clean-folder headless startup and native OpenGL rendering passed | `build/evidence-20261010T040205643/`; separate from instrumented pack tests because official release EXEs prohibit external probe scripts. |
| Package inspection | **29 resource entries**, both new scripts present, no legacy/development directories | Same build evidence folder. The old fishing game and household save remain separate. |
| Native UI | Course chooser, play, completion, retry and client screens inspected at 960×540; native course at 1280×720 | `logs/counterweight-ui-*.png`, `logs/hands-full-counterweight-*.png`. A singular clear-count wording correction followed capture and passed the final unit suite. |

### Physical route evidence and limits

The frozen course has completed loaded solo, two-puppet and three-puppet routes in **40.13 / 63.68 / 92.10 simulated seconds**. The helpers can all follow; the block stays behind. Solo Heavyweight completed in **29.95 seconds**. Feather Fall also has a valid unweighted jumping route, completed in **25.15 seconds**. These are scripted practiced routes; they do not predict a family's first-play duration. The slight departure from the 45–90 second design guide is accepted without artificial waiting or longer travel.

In the slow balance comparison, the minimum exit-tip height during the rider's far-end foot contact was **1.218 m without support** and **2.269 m with a carried block**. The unsupported rider fell during the wait; the loaded rider waited three seconds and then jumped to the checkpoint. Real overlap-created grips and a support ray verified that the block was carried and resting on the board. These are distinct physical trials, not a perfectly matched scientific benchmark.

Independent review caught an initial partner trial in which the helper returned to Start. The corrected probe uses ordinary analog movement to maintain the helper on the rear arm and asserts live foot contact after the wait. It passed: minimum supported tip **2.495 m**, 314 rider foot-contact observations, then a successful checkpoint jump. This demonstrates active partner counterweight, not a requirement to stand perfectly still. The reviewer rechecked and accepted the corrected evidence; production physics was unchanged.

A native rendered solo route also completed in **40.95 seconds**, including a real grip, board-supported cargo and all-at-goal. Cargo, seesaw and checkpoint screenshots were inspected. Natural falls below the recovery plane followed by the existing `reset_at` checkpoint API passed with one, two and three puppets. Recovery uses an initial checkpoint-spawn fixture and direct invocation of the existing recovery API; it does not replace the separate session tests.

Automated cargo placement still failed under Feather Fall and a three-Heavyweight setup; a three-Feather trial lost its third rider at the bridge. These failed first attempts are retained, not relabeled as successful compatibility checks. The earlier First Crossing power/wind matrix was 8/10 strict first attempts, with a Heavyweight approach fall and a Spring Legs post-arrival drift. There is no claim that all powers/crew combinations complete without mistakes.

## Performance and engine decision

Counterweight, native OpenGL Compatibility on this PC's RTX 4070 Laptop GPU, 1280×720, three host-simulated puppets (30 physical bones), seven props. Ten timed seconds after three seconds of warmup; vsync off and FPS uncapped for measurement:

- **5,501 frames**; mean **1.818 ms**, p95 **3.034 ms**, p99 **3.399 ms**, maximum **4.180 ms**.
- **Zero frames over 16.7 ms**; 67 draw calls. Bodies remained finite; the native completion fixture passed.
- Evidence: `logs/hands-full-counterweight-native.json`, matching stdout and empty stderr.

Normal play caps at 120 FPS. This bounded run contains no remote clients and cannot prove performance on the other laptops. It gives no reason to replace the engine or add a rendering/physics framework for this course.

Clients still show host-authoritative physics through the shared 67 ms presentation buffer; that buffer is only part of total response time. The exported-pack probe reached its 0.1 m visible-motion threshold at **210 ms host / 292 and 291 ms clients**, including body acceleration and observation cadence, not hardware input latency. No prediction/rollback rewrite was added. Real Wi-Fi feel, packet-loss behavior and human enjoyment still need the three-PC family test.

## Reproduce

Build: `powershell -ExecutionPolicy Bypass -File tools/build_hands_full.ps1 -RenderSmoke`.

Pack networking: `powershell -ExecutionPolicy Bypass -File tests/integration/run_physics_party_network_probe.ps1 -ExportedPack C:/game-3/build/hands-full/HandsFull.exe`.

Native course check: `.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path C:/game-3 --script res://tests/physics_party_visual_probe.gd -- --course counterweight`.

All probes use separate test saves. Household progress remains at `%APPDATA%\OneMoreCast\physics_party\progress.json`. Keyboard/mouse only; no controllers or internet matchmaking. Generated sound lifecycle is checked, but speaker quality has not been subjectively auditioned.

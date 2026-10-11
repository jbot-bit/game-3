# Hands Full 0.8.0 — Knockout release

Built 11 October 2026. Download the single self-contained [HandsFull.exe](https://github.com/jbot-bit/game-3/releases/download/hands-full-v0.8.0/HandsFull.exe) on each Windows PC and double-click it. No installer, extraction or Godot installation is needed. The optional ZIP contains the same executable plus readable documentation. Complete third-party notices are embedded and available from the opening screen's Credits button.

**Published and downloaded back successfully:** public release/tag `hands-full-v0.8.0` points to source commit `730abd39f05204b733615eb4e90a7ae32ca3a6e1`. The 109,769,920-byte EXE downloaded from GitHub matches the tested SHA256 below and exits cleanly after standalone headless startup from its own folder. Verified 2026-10-11 03:25 UTC; `logs/knockout-download-verification.json` and `logs/knockout-downloaded-startup.log`. Source history and the separate fishing releases remain available.

Four modes are included: Knockout, Gladiator, Wipeout and the twenty co-op courses. Knockout adds a real circular pad, two counter-rotating padded sweepers, stick shoves and first-to-three last-standing rounds. Speed rises smoothly through five stages to 2.5×, with warning beats before each change. Between 30 and 60 seconds the actual floor shrinks from radius 9m to 6m. The shorter high arm leaves a usable outer lane at the final size. Countdown and intermission freeze the hazards; each round resets the floor and speeds. Scoring, spectating, cosmetics, saves and network authority use the existing systems.

The opening screen now uses original illustrated arena artwork, four clear mode choices and direct Host/Join controls. The host can copy their address from the pause menu. Spectators see who they are watching and that they return next round. Credits can be read without extra files.

- EXE: `build/hands-full-0.8.0/HandsFull.exe`; ZIP: `build/HandsFull-0.8.0-windows.zip`.
- EXE SHA256: `4f1fcfab7777ff2f0ea9e4347b33c195d6470a66e0e571bb666e7a45a2afe343`.
- ZIP SHA256: `d50318ad822dd29a3cd58d17fe287df5c5d8c1e1f3cbdd53b785656972c4a4c5`.
- Final import/export, embedded-resource inspection and actual EXE clean-folder headless/native startup passed: `build/evidence-20261011T031730826/`, `logs/knockout-build-shipping.log`. The pack excludes fishing, Nightfall and development resources, and includes complete license notices.
- Full working-tree unit suite: **314 tests / 8,197 assertions passed**, `logs/knockout-release-unit.log`. The subsequent final arm-clearance change passed **9 world tests / 132 assertions**, including both the floor-edge and high-arm clearance. Clean published-source verification is recorded below.
- Clean archive of the exact staged source: import passed; **143 Hands Full tests / 4,943 assertions passed** across all 20 party test scripts, with no engine errors. `logs/knockout-clean-source-import.log`, `logs/knockout-clean-source-unit.log`. This includes the final arm geometry and avoids reliance on unrelated untracked local files.
- Real Knockout physics: **18/18 checks passed**, `logs/knockout-physics-probe.json`. Actual sweeper contact rings out an outer-lane puppet in 2.30s; normal early jumps avoid contact. Retracting support alone causes a gravity ring-out at 42.68s. At final speed and radius, five normal jumps survive a ten-second sample with the competitive arm stance and both hazards enabled. Initial placements are explicit fixtures; the floor-isolation trial disables only sweeper collisions. This proves feasibility, not human timing or a whole human match.
- Existing combat physics: **21/21 checks**, `logs/knockout-combat-regression.log`; continuous Wipeout route passes all checkpoints, real beams and jump podiums in 41.17 simulated seconds, `logs/knockout-wipeout-regression.log`.
- Final exact-pack co-op network probe: **2,221 checks passed**, three clean exits without engine errors/warnings or forced stops. `.tools/physics-party-network-probe/20261011T031825543_83496683/summary.json`. Includes all twenty transitions, both grapples, held teamwork input, shared cosmetics, saves and rejoining.
- Final exact-pack Gladiator/Wipeout: **384 checks passed**, `.tools/physics-party-modes-network-probe/20261011T031942788_43149dee/summary.json`; Knockout: **183 checks passed**, `.tools/physics-party-knockout-network-probe/20261011T032032329_8977369e/summary.json`. Both have three clean exits, no engine errors/warnings or forced stops. Coverage includes attack/brace input, spectator collision, round restarts, shrinking-floor presentation, mode changes, disconnect/rejoin protection, saved rewards and replay. All three suites used the final EXE hash above.
- Native opening/session/credits/spectator views were inspected at 960×540 and the menu at 1280×720. The separate 3D arena capture shows the moving hazards, shrunken pad and results. That display-fixture script reports two OpenGL texture cleanup errors on shutdown; the actual exported EXE startup/render smoke is clean. Root cause of the fixture cleanup remains unconfirmed.

Network probes use a matching engine to load the exact executable's embedded pack, without source fallback; the official release executable is separately exercised for startup and rendering. Probe positions, forced finishes and stage jumps are explicit fixtures. Test harness synchronization races were fixed by adding readiness barriers before releasing held inputs or restarting, preserving all gameplay assertions.

Play together on the same home network: one person chooses Host game, then Esc → Copy address; the others paste that address and choose Join. Allow private-network access if Windows asks. Automated host-plus-two-client checks run on this PC; three-physical-PC human feel and Wi-Fi performance remain unverified. Internet matchmaking is not included. The historical movement caveat below remains unchanged. Existing unrelated fishing/Nightfall work and household saves are preserved.

# Historical Hands Full 0.7.0

Built11 October2026. New selectable Gladiator and Wipeout modes sit alongside the existing twenty co-op courses. Gladiator uses physical padded-stick shoves, directional brace, ring-outs, first-to-three scoring, draws, late-join spectating and disconnect cancellation. Two or three players compete; solo practice earns no reward. Wipeout has a130m route with two hinged balance beams, two moving collision sweepers, four jump podiums and three ordered grounded checkpoints. One to three players race, with falls, continuing time and a five-minute limit. At least one finisher is required for a bag. Departing a live race forfeits that connection's result. Earned cosmetic bags/appearances remain shared and saved; competitive modes disable powers, grabs and grapples.

- EXE: `build/hands-full-0.7.0/HandsFull.exe`; ZIP: `build/HandsFull-0.7.0-windows.zip`.
- EXE SHA256: `f3c37756730f76acecd693b9174e58e9c9ece9e3af3a80dce94d6793256e48d8`.
- ZIP SHA256: `0c9de807ac8bb8c03470821ec5d63701ddc4c7a7946df8b7feecd51379d9aac4`.
- Import, export, embedded-resource inspection, actual EXE headless and native startup passed: `build/evidence-20261011T013823958/`, `logs/modes-build.log`. Pack excludes separate fishing/nightfall code and development resources. Previous releases preserved.
- Full unit run: **293 tests /7,820 assertions passed**, `logs/modes-full-unit.log`. Subsequent focused HUD regression: **9/9 tests /163 assertions**, `logs/mode-ui-reward-regression-after.log`; an earned bag remains visible if an opponent departs, including already-revealed cards. Final production changes after the full run are that covered HUD fix and visual-only arena palette/lighting.
- Real combat physics: **21/21 checks**, `logs/gladiator-combat-probe.json`. Two actual Jolt puppets; unbraced shove3.258m versus braced0.345m. Stick contact caused an actual physical ring-out and a round point. Initial contact positions are fixtures.
- Continuous Wipeout traversal: **41.17 simulated seconds**, all three checkpoints in order, both real tipping beams and all four jump podiums contacted; standing finish,11 ordinary jumps, no reposition after initial spawn. Beam tilts8.09°/9.30°. Separate idle-puppet sweeper contact displaced it7.68m without artificial force. `logs/wipeout-physics-probe.json`. This proves route feasibility, not human difficulty or a fastest time.
- Exact exported-pack new modes: **381 checks passed**, three clean exits, no engine warnings/errors or forced stops. `.tools/physics-party-modes-network-probe/20261011T013917831_ab1e796c/summary.json`. Real attack/brace input and physical contact, late arrivals with all ten bodies non-colliding, disconnect protection, wins, saved bags, replay, same-course mode changes, stale frames, moving hazard poses, checkpoint order and recovery. Positions are explicit fixtures.
- Exact exported-pack co-op regression: **2,221 checks passed**, three clean exits and no engine warnings/errors or forced stops. `.tools/physics-party-network-probe/20261011T013918756_b38fa302/summary.json`. All twenty transitions, both grapples, teamwork input, cosmetics, exact-once saves and rejoining remain functional.
- Native960x540 menus, stick stance/swing/brace, arena, Wipeout obstacles and named results captured and inspected: `logs/modes-native-final.log`, `logs/modes-native-*.png`. Explicit display fixtures, not human matches.
- Native1280x720 with three physical puppets and both moving sweepers,5-second sample: p95 **2.966ms**, max **3.698ms**, no frames above16.7ms on RTX4070 Laptop GPU. `logs/modes-native.json`. Not performance evidence for the other PCs.

Only local automated physics/network checks and native image inspection are claimed. Household saves were not used as fixtures. Three-physical-PC human feel, opponent timing and real Wi-Fi latency remain to be tested. No public upload or external action occurred. Existing unrelated fishing/nightfall work and project default were preserved. The0.6 movement caveat below still applies; this release only adds a bounded combat-impact grace to the existing motor.

# Historical Hands Full 0.6.0

Built 10 October 2026. All 20 approaches now lead to three mandatory physical teamwork stages: bridge relay, freight lift, and real cargo delivery. Two distinct players hold controls while the third performs the task and locks its far latch. Shared checkpoints preserve completed stages. All three must reach extraction; visiting either endpoint cannot skip the tasks. Solo exploration is available. The three-stage sequence is shared across the 20 different approaches.

Each saved clear awards a three-card cosmetic surprise bag: Common 60%, Rare 28%, Epic 10%, Legendary 2% per card, with foil reveals for rare and higher cards. Fifteen paints/accessories; blank faceless bodies remain the default. Ownership and per-slot appearances save on the host. Failed-save retries retain the pending roll; duplicate completions cannot reroll.

- EXE: `build/hands-full-0.6.0/HandsFull.exe`; ZIP: `build/HandsFull-0.6.0-windows.zip`.
- EXE SHA256: `3b1e31848dc93b3b055bcdf50089bd8eddc667850e86cf0420e8c5bc5e2f1547`.
- ZIP SHA256: `09c234de19f22782db65130010d0f5191617164c35fe196c3ef1a80bd26267dd`.
- Import, export, embedded-resource inspection and actual EXE headless/native startup pass cleanly: `build/evidence-20261010T084120925/` and `logs/coop-build.log`.
- Full unit suite: **251 tests / 5,925 assertions pass**, `logs/coop-unit-final.log`. Includes all20 endpoint gates, three-player requirement, ownership, save retry/reward screens, and the separately maintained fishing game.
- **Continuous First Crossing: 22/22 checks, 91.40 simulated seconds, zero recoveries or reposition after initial spawn.** Three concurrent physical puppets cross the original bridges/seesaw, operate all stages, physically ride the lift, carry/deliver the crate, regroup and stand at extraction. No powers, grapples or minimum-time gates. `logs/teamwork-full-route.json` and `.log`. Scripted traversal, not a human timing or fastest-grapple claim.
- Physical stage/bypass/disconnect fixtures: **24/24 checks pass**, `logs/teamwork-physics.json` and `.log`. Credit belongs to actor instances and is discarded on replacement/recovery; the lift waits for a real rider. These fixtures start at each stage.
- All 20 tail placements: **2 tests / 1,356 assertions pass**, `logs/teamwork-layout-final.log`. Raised/lowered stages clear original course collision boxes beyond the intended join; decorative cranes clear playable bounds. This is not 20 full three-player traversals.
- Exact exported-pack LAN: **2,218 checks pass**, three clean exits, no engine errors/warnings or forced stops. `.tools/physics-party-network-probe/20261010T084223811_c4624789/summary.json`. All 20 transitions, held-E packets, both grapples, ordered card rewards, locked-style rejection, earned appearance replication, restart/rejoin and exact-once rewards. Pad/clear positioning is an explicit fixture. Motion 84/125/168 ms on loopback, not three-PC Wi-Fi evidence.
- Native customization, accessories, cards and navigation inspected at 960x540; dressed stages and three characters rendered correctly. `logs/coop-native-final.log`, `logs/coop-native-*.png`. Explicit display fixtures; no household-save changes.
- Native 5-second standing-crew sample at 1280x720: p95 **3.893 ms**, max **5.448 ms**, zero frames over 16.7 ms on RTX 4070 Laptop GPU. `logs/coop-native.json`. Not weak-PC or remote-performance evidence.
- Grapple physics **22/22**, `logs/coop-grapple.log`; cosmetic host/remote rig **164/164**, `logs/cosmetic-probe.json` and `.log`.
- Movement caveat: unchanged motor starts within 67 ms and reverses within 100-133 ms. Expanded-scene benchmark passes 23/24: Grip torso stopping 267 ms versus 250 ms bound, with 0.214 m coast. Fixed-fps and real-time runs agree. `logs/coop-movement.log`, `logs/coop-movement-realtime.log`. Acceptance threshold retained; not a complete benchmark pass. One isolated diagnostic with teamwork disabled passes24/24 and exactly reproduces every legacy trial measurement (`logs/coop-isolated-diagnostic-valid.log`, `logs/movement-response-coop-isolated-diagnostic.json`). Added physics bodies changing initial ragdoll/solver ordering is a plausible explanation, not a proven engine cause. Production motor and benchmark assertions remain unchanged.

The 0.5.0 package is preserved. Its playtest was observed closed before native 0.6.0 capture. Opened the verified 0.6.0 executable for the user: PID29428, title Hands Full, exact versioned path confirmed. Human first-time pacing, enjoyment and three-PC responsiveness still need a household test. No public upload; unrelated fishing work and real saves preserved.

# Historical Hands Full 0.5.0

Opened for the user's immediate playtest on 10 October 2026. It contains blank, faceless, single-colour humanoids and twenty selectable courses. **User feedback: the first level can be crossed in roughly four seconds.** The current routes demonstrate feasibility, not adequate pacing. Mandatory three-player stages, longer objectives and earned RNG cosmetic bags are being developed separately; they are not in this executable.

- Executable: `build/hands-full/HandsFull.exe`; version **0.5.0**.
- ZIP: `build/HandsFull-windows.zip`.
- EXE SHA-256: `0bac76d2017bbd9462e8bb980fb1bb86a40bf6fb6e9aae8d2fa1fcdbf7812223`.
- ZIP SHA-256: `b4a88c15e68c2b3283bce796538b2b77ad3dffdea51c8c69fe7592f633b180a6`.
- Actual EXE clean-folder import/export/pack/headless/native smoke: `build/evidence-20261010T080351892/`, clean.
- Full unit suite: **216 tests / 3,664 assertions passed**, `logs/level-pack-unit-full.log` (includes the separate fishing game).
- Blank host/remote appearance: **68 checks passed** in headless and native runs, `logs/blank-person-regression.log`, `logs/blank-person-native.log`.
- Movement response: **24 checks passed**, `logs/level-pack-movement.log`; first 0.1 m remains 67 ms, reversal 100–117 ms.
- Original two ordinary-control physical routes passed: `logs/level-pack-crossing-route.log`, `logs/level-pack-counterweight-route.log`.
- New eighteen routes: **18/18 passed** with sustained checkpoint/goal standing and actual foot contact on each required movable board, `logs/level-pack-final.json` and `.log`. Solo, unpowered, analog waypoint bot, initial spawn only. First-run failures are retained; Round Trip's long boards received physical trestles, and Skybridge's probe waits up to three seconds for the unchanged standing criterion.
- Exact exported-pack multiplayer: **1,392 checks passed**, three clean exits, no engine errors/warnings, `.tools/physics-party-network-probe/20261010T080601567_bdce247e/summary.json`. All twenty transitions, checkpoint replication, clear persistence, fresh poses, both grapples, restart and rejoin. Completion/checkpoint fixtures are not traversal evidence.
- Native Final Shift with three physical puppets: p95 **4.902 ms**, max **6.777 ms**, zero frames over 16.7 ms in the ten-second sample on RTX 4070 Laptop GPU. `logs/level-pack-native-final-shift.log`. No weak-PC claim.
- Native 960x540 menu/game/completion captures were inspected; final level is selectable. Popup pixels were not present in the root-texture capture, so it is not evidence of the expanded list's on-screen scrolling. `logs/level-pack-native-ui.log`.

Only local scripted testing and image inspection; no human or three-physical-PC result is inferred. The real household save was not replaced by fixtures. The test game remains open while its follow-up is developed.

# Historical Hands Full 0.4.0

Rebuilt and verified 10 October 2026. This build includes the movement response fix and full visual overhaul: helmeted crew with workwear and backpacks, steel course platforms and cargo, hazard markings, crane grapple targets, dusk lighting/shadows, a new menu and compact HUD. The two courses, ten-body physics rig, seven props per course, five saved powers and both grapple modes remain.

## Current package

- Executable: `build/hands-full/HandsFull.exe`; version **0.4.0**.
- ZIP: `build/HandsFull-windows.zip`; use the matching build on all PCs.
- EXE SHA-256: `7867cfde16948d7a56d67ba452f03886598ca995ff3ff1f1909c4e5303b7cbec`.
- ZIP SHA-256: `dd706500716c396b372cc58ed6968feceeb77291925ce28809bbe6c43fda8ba8`.
- Export inspection, clean-folder startup and actual EXE native rendering passed without errors/warnings: `build/evidence-20261010T070513521/`.
- Previous movement-only 0.3.1 package preserved at `build/hands-full-previous-20261010T070513521/` and matching previous ZIP.

## Current verification

| Check | Result and evidence |
|---|---|
| Full unit suite | **199 tests / 2,451 assertions passed**, `logs/overhaul-unit-final.log`. Includes the separately maintained legacy game. |
| Real input-to-physics movement | **24 checks passed**, `logs/movement-response-final.json`. First 0.1 m in 67 ms for Grip, Heavy and Swift; reversal 100–117 ms. Before: 167–233 ms and no reversal within 600 ms. Host polls each physics tick. Native keyboard-event benchmark also passed: `logs/movement-response-native.json`. |
| Puppet physics and remote costume | **51 checks passed**, `logs/overhaul-puppet.log`: body poses, jump, independent hands, teammate rescue, reset, remote skin and visor eyes. |
| Grapple physics | **22 checks passed**, `logs/movement-grapple-regression.log`: pull, fixed-length swing, release momentum and invalid/stale targets. Motor is unchanged since this run. |
| Native course traversal | First Crossing completed via real bridge/seesaw contacts and ordinary scripted controls, `logs/movement-native-course.log`; initial spawn only, no completion teleport. |
| Counterweight cargo route | Full canonical route passed in 22.83 simulated seconds, `logs/movement-counterweight-canonical-route.log`. Real hand grip, block supported by board, moving-platform contacts and goal asserted. Faster movement required slowing only the analog bot's pickup approach from 0.65 to 0.25; assertions and jump timing unchanged. Original fast pickup failed, and an old-motor comparison also failed placement. This does not establish human pickup difficulty. |
| Native artwork/UI | Final menu, power cards, crew and 1280×720/960×540 gameplay captures pass and were visually inspected: `logs/overhaul-visual-final.log`, `logs/overhaul-*.png`. |
| Grapple HUD and rope presentation | **24 gameplay/visual checks passed**, including minimum-window torso visibility and rope endpoints, `logs/overhaul-grapple-native-final.log`. This capture script prints two 349,524-byte OpenGL texture cleanup errors on shutdown. They did not reproduce in the actual EXE smoke, final overhaul capture or performance probe. Root cause remains unconfirmed; do not describe this particular probe as error-free. |
| Native frame pacing | **3 physical puppets, 7 props, 1280×720, 10-second warmed sample**: p95 **4.606 ms**, max **6.482 ms**, zero frames above 16.7 ms on RTX 4070 Laptop GPU. `logs/overhaul-native-performance-final.log`. Batching reduced sampled draw calls from 1,819 to 672. Not weak-PC evidence. |
| Exact exported-pack multiplayer | **275 checks passed, three clean exits, no engine errors/warnings**, `.tools/physics-party-network-probe/20261010T070640386_7f960cad/summary.json`. Host and two local clients; build identity 0.4.0, both courses, grapples, saves, restart and rejoin. First visible motion 83 ms host / 126 and 167 ms clients in this loopback run. Not three-PC Wi-Fi latency. |

Research and implementation decisions: `docs/research/2026-10-10-movement-response.md` and `docs/research/2026-10-10-visual-overhaul.md`.

Desktop-control tooling could not start in this session. Verification used native rendered scripted input/playthroughs and image inspection, not a hands-on human playtest. Tests used isolated saves. The release remains local; no upload, push or public action was performed. Existing unrelated fishing-game changes were preserved.

## Historical 0.3.0 grapple build

The record below describes the earlier package, not the current executable. Shared preview filenames may now show the latest appearance.

Rebuilt and verified 10 October 2026. Hold **Q** to attach/release; **G** switches between **Pull** (reel toward the hook) and **Swing** (fixed rope length with tangential momentum). Mode switching works while attached. Both courses have two static overhead beams. The camera and compact HUD keep the target and player visible when aiming upward. The five powers and existing saved collection are retained.

## Current package and evidence

- Executable: `build/hands-full/HandsFull.exe`.
- ZIP: `build/HandsFull-windows.zip`; use this matching 0.3.0 build on every PC.
- EXE SHA-256: `aeb904efd20c29c0a61c6da30da23f31b9db702b0fa592623a01f3030510588d`.
- ZIP SHA-256: `c1f8b295278ccb604e8dbcbfc725a556d5e6d102239bc5af359c5a584b63c499`.
- Build inspection, clean-folder startup and native OpenGL smoke passed: `build/evidence-20261010T062811969/`.
- Previous package preserved by the builder at `build/hands-full-previous-20261010T062811969/` and `build/HandsFull-previous-20261010T062811969.zip`.

| Check | Result | Evidence / limits |
|---|---|---|
| Full unit suite, including legacy game | **194 tests / 2,426 assertions passed** | `logs/grapple-unit-full.log`. Input validation, camera response, saves, course lifecycle and rope interpolation. |
| Actual Jolt grapple physics | **22 checks passed** | `logs/grapple-physics.log`; pull displacement, sustained fixed-length swing, airborne release momentum, range/occlusion, stale controls, reset and target removal. Controlled bodies, not a human playtest. |
| Existing puppet regression | **51 checks passed** | `logs/grapple-puppet-regression.log`; movement, jumping, hand grabs, teammate rescue and remote rendering. |
| HUD/world integration | **20 headless checks passed** | `tests/physics_party_grapple_ui_world_probe.gd`; both courses retain seven movable props and expose reachable static anchors. |
| Actual native grapple presentation | **24 checks passed** | `logs/grapple-visual.json`; normal camera center-ray aiming, unobstructed player/reticle at 960×540 and 1280×720, pull/swing visuals, rope endpoints within 0.000001 m. Scripted controls and positioning fixtures. |
| Source three-process LAN | **275 checks passed; three clean exits** | `.tools/physics-party-network-probe/20261010T062737571_d41a0c9a/summary.json`. Both modes, all three ropes, release, both courses, replay, saves and rejoin. |
| Exact exported-pack LAN | **275 checks passed; three clean exits; no engine errors/warnings** | `.tools/physics-party-network-probe/20261010T062927529_31afcef4/summary.json`. Matching engine loads the exact embedded release pack; builder separately runs the actual Windows EXE. |

Screenshots: `logs/grapple-normal.png`, `grapple-aim.png`, `grapple-aim-960x540.png`, `grapple-pull.png` and `grapple-swing.png`.

Limits: 28-metre reach, static scenery only, straight rope without obstacle wrapping. Multiplayer checks use three local processes, not three physical PCs or real Wi-Fi. Human control feel still needs playtesting. Tests use isolated saves; household progress was not replaced. No public upload or push was performed.

## Historical 0.2.0 verification record

The following measurements and hashes describe the preceding build, not the current grapple package.

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

# Hands Full 0.1.1 — developer playtest and build

Verified 10 October 2026 on Windows. This update improves the existing compact LAN physics game before household play. It remains one short introductory course with five saved power choices; it is not a finished campaign or a human-validated fun rating. No public upload was performed.

## Playable output

- `build/hands-full/HandsFull.exe` — 109,521,792 bytes; standalone embedded game data.
- `build/HandsFull-windows.zip` — 38,343,631 bytes; executable, controls/joining README and PiCode/Godot notices.
- EXE SHA-256: `09a10f3d396f2452fe70f26fd67194a895321a9018ba6c46e0b0c7612f07c48d`.
- ZIP SHA-256: `d2083d4b28496e5e43a492e3ba1d32e431665b68865ba89b135fe25bbb8f2902`.

Extract the ZIP on each PC and launch `hands-full/HandsFull.exe`. One player hosts; Esc shows join addresses. Everyone must use 0.1.1 on the same home network. The host retains the shared collection. The previous package is preserved under `build/hands-full-previous-20261010T033027271` and the matching previous ZIP.

## Changes driven by observed problems

- Hands prefer movable props and teammates over overlapping static supports. Existing holds still release only when commanded or when their target recovers/disconnects.
- Jump taps survive the 30 Hz input sampler. The controller accepts a jump 120 ms before landing or 100 ms after leaving a ledge; it clears downward speed when applying an accepted jump. Held jump still does not repeat. Own legs no longer count as ground; a teammate can still provide support.
- Two ready movable bridges replace the awkward loose-plank setup. The existing seesaw and central landing form the second crossing. Bridge friction increased from 0.2 to 0.55 after Quick Feet pushed a bridge off its rests. Mass, hand joints and movement forces remain unchanged.
- A falling held prop releases only its attached hands before returning home. The other hand's unrelated grip survives.
- The host can choose Esc → Restart course when the bridges are stranded. This starts a fresh draft and restores props while preserving collected powers. Clients cannot restart the crew.
- The live menu says the game continues, retains facing direction, and fits 960×540. Long crew names truncate instead of pushing other information offscreen. Controls explicitly say Hold R.

Three parallel agents handled controller tests, course tests and independent review; the parent integrated input, UI, release checks and packaging. No gameplay system, rendering plugin, currency or inventory was added. Existing 60 Hz host physics, 30 Hz poses and shared 67 ms remote presentation buffer remain in place.

## Verified checks

| Check | Result | Evidence / limit |
|---|---|---|
| Unit/regression suite | **39 tests, 643 assertions passed** | `logs/party-unit.log`; includes short taps, menu restart, saved powers, saves, networking validation and presentation. An existing audio cleanup test now polls actual mixer release with a deadline instead of assuming exactly 150 ms. |
| Physical puppet | **51/51 passed** | `logs/party-puppet-final.log`; real movement, grabs, release, limp, held-jump, recovery and remote pose checks. Setup fixtures are used for some interactions. |
| Landing/ledge/grab corrections | **9/9 passed** | `logs/party-interaction-final-headless.log`; earlier rendered version also inspected in `logs/party-interaction-native.log` and screenshots. |
| Ground support classification | **6/6 passed**, versus 5/6 before | `logs/party-floor-contact-after.log`; real ShapeCast contacts with own leg, friend leg and static floor, using controlled gravity-disabled fixtures. |
| Held-prop recovery | **6/6 passed**, versus 5/6 before | `logs/hands-full-prop-recovery-after.log`; real overlap-created joints and a controlled below-floor prop position. |
| Full-size bridge grab | Real grip, **1.017 m** backward drag in one second, clean release | `logs/hands-full-bridge-grab-digital.log` / `.json`; final controller, full digital movement presses/releases, initial player spawn only. No prop teleport, force injection or fabricated joint. |
| Five powers × both winds | **8/10** first-attempt routes reached and settled in the goal; all ten contacted the actual bridge and seesaw | `logs/party-course-power-matrix.json`; limitations below. |
| Source networking | **169 checks passed**, three clean exits | `.tools/physics-party-network-probe/20261010T031941166_a29c9ed2/summary.json`; real ENet loopback, with positioning fixtures for lever/completion. |
| Exact exported-pack networking | **169 checks passed**, three clean exits, no engine warnings/errors | `.tools/physics-party-network-probe/20261010T033214711_89784fcd/summary.json`; matching Godot runtime loads the exact embedded release pack from its clean folder. Official release EXEs prohibit external probe scripts. |
| Actual release executable | Clean-folder headless startup and native OpenGL rendering passed | `build/evidence-20261010T033027271/`; separately from the instrumented exported-pack gameplay check. |
| Package inspection | 25 runtime resources, expected scripts/model present, no legacy/development directories | Same build evidence folder; older fishing game/save remain separate. |
| UI/rendering | Native gameplay, menu, draft and completion screens inspected at 1280×720 / 960×540 | `logs/hands-full-*.png`; an independent maximum-name-width layout check is in `.tools/research/party-ui-review-probe.log`. |

### Course evidence and unresolved limits

The final power matrix uses one scripted puppet, 60 Hz physics and accelerated headless rendering. It starts the player once and applies controller inputs and the same wind as the game. It does not teleport props or force completion. Near-waypoint analog braking means this is **physical route evidence, not literal keyboard play or family enjoyment**.

Quick Feet originally slid its bridge roughly 4.3 m off the rests and fell in both wind directions. With 0.55 friction, both final runs passed (19.77 s and 19.47 s). Digital full-size grab/drag remains proven separately.

Two strict first-attempt cases remain unsuccessful:

- Heavyweight/right wind: the bot fell sideways off the seesaw before pressing its planned exit jump. A separate checkpoint-start run with the same power/wind reached and settled at the goal in 9.57 simulated seconds (`logs/party-heavy-checkpoint.log`, `logs/hands-full-seesaw-heavy-wind-right.json`). This proves that section is physically traversable, not that every approach succeeds or that the full failed attempt was replayed through the recovery UI.
- Spring Legs/left wind: the bot reached the finish platform, then drifted out of the goal while releasing input for 90 settling ticks. The game's completion condition does not require that extra settling period. The strict probe still records this as a failure.

The prior native base-power route reached and settled at the finish in 22.38 s (`logs/hands-full-course-revised-settled.log`) before the final friction/own-leg corrections. The final matrix supersedes it for current power compatibility. None of these short automated runs establishes the intended family session duration or lasting replay appeal.

### Performance on this PC

Final code, OpenGL Compatibility, RTX 4070 Laptop GPU, 1280×720; three host-simulated puppets (30 physical bones), seven props, scripted movement/grabs/jumps. Ten timed seconds after three seconds of warmup, vsync off and FPS uncapped for measurement:

- 5,415 frames; mean **1.847 ms**, p95 **3.056 ms**, p99 **3.467 ms**, maximum **4.614 ms**.
- **Zero frames over 16.7 ms**; 67 draw calls at capture. Bodies remained finite and native recovery reached completion.
- `logs/hands-full-native.json`, matching stdout and empty stderr.

Normal play caps at 120 FPS. This bounded render test has no network clients; it does not prove other laptops' performance or Wi-Fi feel. The separate exported-pack test measured the 0.1 m visible movement threshold at 207 ms host / 291–292 ms clients, including physical acceleration, presentation buffering and observation cadence—not hardware input latency.

## Remaining scope

Actual three-PC household play, human cooperation/fun and long sessions are unverified. There is one short course and light saved progression. Keyboard/mouse only; no controllers, internet matchmaking, PvP scoring or campaign. Generated sound lifecycle is tested, but speaker quality has not been subjectively auditioned.

Build again with `tools/build_hands_full.ps1 -RenderSmoke`. Check the resulting pack with `tests/integration/run_physics_party_network_probe.ps1 -ExportedPack C:/game-3/build/hands-full/HandsFull.exe`. Keep household saves separate from test fixtures.

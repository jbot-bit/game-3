# Crown Court 0.2.0 verification

Windows, 11 October 2026. Godot 4.7.2, Compatibility renderer. This release improves the existing standalone Crown Court; the earlier game projects and 0.1.0 ZIP are preserved.

Executable: `../build/crown-court-0.2.0/CrownCourt.exe`

Executable SHA256: `B527634FB44AAD7E1B73336EC7C8813B49AA0BCCB43E49BA86B683B95502671E`

Portable release: `../build/crown-court-release/CrownCourt-Windows-0.2.0.zip`. Its final checksum and extraction result are recorded in `../build/crown-court-evidence/v2-release-results.json` after packaging.

## What changed and why

Actual full-match footage was inspected in dense jump, launch, catch and dunk sequences. REFERENCE.md records timestamps, corrections to ambiguous observations, measured local profiles, and unknown original constants.

- Court: 24×44 to 40×72, or 2.73 times the area, with four traveling launch pads, four ground speed strips, broad crossing ridges and raised side routes.
- Movement: independent air steering/drag, retained launch momentum, extra jumps that no longer cut boosted ascent, and a short landing-jump buffer. Normal jump impulse remains 12.2.
- Dunk: incoming motion leads into a tucked sideways roll, outside-rim reach, windup, physical downward release and landing. A score preserves that sequence for .85 seconds before kickoff reposition. Giant expiry and bank clipping regressions were found and repaired.
- Camera: closer framing and vertical tracking, boost expansion, high-ball framing and manual-look release from ball camera. The oversized persistent control banners were removed.
- Inputs/network presentation: both catch inputs buffer, quick mouse shots survive between ticks, previews follow current aim, and early F presses queue after takeoff. Client extra jumps survive stale first-jump packets; the rendered body, hands and carried ball share motion.

## Passed against the embedded release pack

- 58 simulation checks, 18 movement/dunk regressions, 23 profile checks, complete autonomous co-op/free-for-all matches, and application/reward/session regressions.
- 18 rendered keyboard/mouse flow checks: menu, move/look, two jumps, catch, shot scoring, separate dunk scoring, pause/resume, wardrobe and reward reveal. These include controlled player/ball fixtures.
- Rendered input diagnostic: camera release, early catch, correct context prompts, quick click shot, current-aim preview, quick jump/dunk, client jump acknowledgement/correction, ball attachment, ballistic presentation and result/reward timing.
- A continuous real InputEvent route starts at the actual spawn, runs to the ball, catches, reaches a launch pad, takes the extra jump, approaches and dunks, physically scores, lands and returns to kickoff. There are no position/possession/score fixtures after this route starts; opponents are held still to isolate the controls. The final pack run completed this route with zero focus recoveries and one kickoff respawn.
- Native exported executable startup.

The final packaged route reached 19.02 world units high. Its largest dunk physics step was .383 units at 60 Hz; its largest camera step during the dunk was .199 units, with zero yaw change. The larger whole-route camera steps came from deliberate single-frame mouse turns in the route controller, including one 76.4-degree turn; these were inspected rather than attributed to smoothing.

The client presentation probe reproduced a 2.105-unit held-ball lag in the old snapshot presentation; the corrected hand-position error is zero in that fixture. An actual compressed stale first-jump packet previously caused a .344-unit downward snap during a predicted second jump. The repaired packet path retains the second jump and leaves authoritative state unchanged. These are controlled delay/snapshot tests, not measurements of a household network.

## Independent stress and visual checks

288/288 dunk cases score: two hoops, twelve approach angles, four starting heights and three Giant states. Six actual-action tackle checks interrupt ordinary/Giant dunks at different phases. Minimum feet-to-floor clearance in the final matrix is +.020 units. Articulated rig offsets are bounded and hands remain attached during the roll; captured sequences were inspected.

Normal camera framing measures 14.07% of image height for the bean, with feet at 67.63% from the top, close to the observed grounded source framing. A high-ball camera fixture keeps both feet and an 18-unit-high ball inside the frame.

One local RTX 4070 Laptop GPU run at 1280×800 measured approximately 8.42 ms p95 render intervals in ground, boost and dunk fixtures. Warmup and screenshot readback/encoding were excluded. The packaged application flow ended at 105 FPS. This is one hardware sample, not a broad performance claim.

## Network release check

All eight network cases passed against this exact embedded release pack, with 22 passing process results and empty runtime error logs. Each checks roster/bot counts, delivered movement/actions, scoring, win rewards, cosmetics, rematch and clean departures.

| Scenario | Humans | Teams |
| --- | --- | --- |
| Custom teams | 2 | 1v1 |
| Custom teams, late third join | 3 | 2 humans v 1 human + 1 bot |
| Co-op, LAN interface | 3 | 3 humans v 3 bots |
| Custom teams, LAN interface | 3 | 2 humans v 1 human + 1 bot |
| Custom teams, balancing off | 3 | 2 humans v 1 human |
| Co-op | 2 | 2 humans + 1 bot v 3 bots |
| Co-op, late third join | 3 | 3 humans v 3 bots |
| Free-for-all | 3 | 1v1v1 |

A separate host plus two clients passed all eleven shared checkpoints: catch, passes in both directions, tackle/drop/catch, south-hoop shot, north-hoop dunk, traveling launch, extra jump and ground speed strip. All three peers acknowledged the same outcomes; final score was 1-1. A spatial/height guard prevents a stale airborne snapshot from passing the speed-strip check.

These are separate ENet processes on this one PC using loopback and its LAN interface `192.168.20.15`, loading the exact embedded executable pack through Godot. Lifecycle fixtures deliberately arrange a shot and final physical basket; they now wait through celebration/kickoff and observe the win before rematching. The full-match and separate action tests cover additional unscripted scoring and gameplay. Native executable startup is checked separately. Packaging requires the matching `v2-network-verified.json` hash and a fresh extraction/startup check.

## Limits and household playtest

No physical three-PC household session or human enjoyment test has been performed. Use the same 0.2.0 ZIP on all PCs. Test actual Wi-Fi/Ethernet latency, firewall access, hardware controllers, audio, and whether running, aerial steering, catching, tackles and dunks feel good under real opposition. HOUSEHOLD_TEST.txt gives the short sequence.

Exact Crown Jam physics/gameplay equivalence is not established. The source constants, input frames and latency compensation are unknown; this is an original Godot recreation with authored tuning. In two deterministic final bot matches, co-op bots used fixed launch pads, but free-for-all bots did not; speed strips were unused by bots in both samples. That limits the bot route/balance evidence.

Native desktop input automation was unavailable in this environment. Rendered tests used Godot's actual InputEvent path and native GPU renderer; they are automated, not manual human play. The Game Development Studio skills guided the workflow; its CLI was unavailable and produced no verification results. Reference footage is not shipped as a game asset.

Raw results: `../build/crown-court-evidence/v2-playtest-results.json`, `v2-source-manifest.json`, `v2-network-verified.json`, final process logs, and the `v2-pack` screenshots. Reference stress scripts/logs remain under `reference/` in the source tree. Reproduce with `build.ps1`, then `verify-network.ps1 -Address <host IPv4>`; `package.ps1` checks the matching evidence before archiving. No public upload was performed.

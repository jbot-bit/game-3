# Crown Court 0.1.0 verification

Verified on Windows, 11 October 2026, using Godot 4.7.2. The standalone release is at `../build/crown-court/CrownCourt.exe`; the portable ZIP is at `../build/crown-court-release/CrownCourt-Windows-0.1.0.zip`.

Executable SHA256: `AC9E352942AB06E763D81A647FBC753841C5476C3FBB0547E247849A7866E364`

ZIP SHA256: `7A9E572A4E5DB4A4C51D5ED11D0C450C23F99AF83B2701DF510B69109A3841FC`

## Passed

- 58 simulation checks: movement, double jump, banks/pads, possession, passes, tackles, rim crossing, dunks, both hoops at four shooting distances, team rules, sudden death, Hype, and late-join ownership/balancing.
- 23 profile checks: blank start, earned bags, rarity draws, ownership, equip/save/reload, duplicate protection, completed collections, and backup recovery.
- Complete autonomous co-op and free-for-all matches, ending through real scored baskets.
- Application smoke, reward-save regression and session regression on both source and the embedded release pack. Includes exactly-once rewards, failed-save retry after leaving, connection-bound reward eligibility, preserved team assignments, and inactive-peer shutdown guards.
- 18 rendered keyboard/mouse input checks against the release pack: menu entry, movement/look, double jump, catch, charged shot scoring, separate dunk scoring, pause/resume, wardrobe and bag reveal. Captured images were inspected. Test fixtures place players/ball for controlled action checks; this is automated input, not human play.
- Eight ENet network scenarios, 22 process results, all passing with empty runtime error logs. Every scenario verifies roster/bot counts, movement/input delivery, scores, win rewards, power choices, cosmetics, rematch and clean client departures.

| Scenario | Humans | Actual teams |
| --- | --- | --- |
| Custom teams | 2 | 1v1 |
| Custom teams, third human joins during play | 3 | 2v2 with one bot |
| Co-op over this PC's LAN interface | 3 | 3 humans v 3 bots |
| Custom teams over LAN interface, balancing on | 3 | 2 humans v 1 human + 1 bot |
| Custom teams, balancing off | 3 | 2 humans v 1 human |
| Co-op | 2 | 2 humans + 1 bot v 3 bots |
| Co-op, third human joins during play | 3 | 3 humans v 3 bots |
| Free-for-all | 3 | 1v1v1 |

- Separate host-plus-two-clients action sequence: pickup, pass and catch in both directions, opponent tackle/drop/catch, an actual shot through the south hoop, then an airborne dunk through the north hoop. All three peers acknowledged all eight checkpoints; final score 1-1.
- Native exported executable startup. Final ZIP was extracted into a new folder; its executable hash matched the verified build, and the extracted executable started without errors.

The network tests use real separate ENet processes on this one PC, via loopback and `192.168.20.15`. They load the exact embedded release pack through the matching Godot runtime. The native release executable is checked separately for startup. Lifecycle tests use a controlled shot and final physical basket to reach the result/rematch flow reliably; the complete autonomous-match and separate action tests provide additional gameplay coverage.

## Fixes found during testing

Close shots hit the front rim; the arc solver now clears it. Stunned divers could chain tackles; stunned players now lose their active dive. Hype pads could appear beyond reachable bounds. Replacing a bot left stale projectile references. Late joiners could inherit a previous occupant's reward; eligibility is now connection-bound. Failed saves now retry while the app stays open. A late third player failed to add the selected balancing bot; live balancing now preserves positions, possession, score and clock. Host shutdown could query an inactive network peer; presentation and input paths now guard that state.

Two network harness assumptions were also corrected: short AI-driven 1v1 play need not attempt a shot within 17 seconds, and simultaneous clients need not connect in process-launch order. The final harness issues an explicit shot and checks power selection against player identity.

## Still needs the household playtest

Actual separate-PC Wi-Fi/Ethernet and firewall behavior; physical controller input; audio on each PC; and human assessment of camera, jump, catch, tackle, shot and dunk feel. Exact equivalence to Crown Jam is not established. This is an original recreation with locally tuned physics informed by sampled full-match gameplay, documented in `REFERENCE.md`. The Game Development Studio CLI was unavailable; no verification is attributed to it.

Use `HOUSEHOLD_TEST.txt` for the first match. Raw logs, screenshots and the audited result JSON are in `../build/crown-court-evidence/`. Reproduce with `build.ps1`, then `verify-network.ps1 -Address <this PC's LAN address>`. The release and its source remain separate from the existing games; no public upload was performed.

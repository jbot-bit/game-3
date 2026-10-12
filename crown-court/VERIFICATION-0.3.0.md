# Crown Court 0.3.0 verification

Windows, 11 October 2026. Godot 4.7.2, Compatibility renderer. Earlier release archives and sibling games are preserved. The prior report is retained in VERIFICATION-0.2.0.md.

The final export, both complete recorded matches, event-footage inspection and network matrix passed. Packaging requires a fresh extraction and native startup; its completed receipt and ZIP checksum are written to `../build/crown-court-evidence/v3-release-results.json`.

Executable: `../build/crown-court-0.3.0/CrownCourt.exe`.

SHA256: `A4DD4F0457EAA686DA65D033FE20A3BC462B0B2F43EA610B34B88C252EF10D81`.

## Reproduced defects

- A turn followed immediately by a LAN tackle could use stale movement. The reliable action now carries its current direction.
- A catch press could become an unwanted pass when the server caught an incoming ball before the client received possession. The client sends the resolved catch/pass intention.
- Delayed movement/actions could affect a rematch. Each input identifies its round; previous-round inputs are rejected.
- Boosted carry-to-throw added a 0.677317-unit visual jump with no simulated ball movement. The corrected transition adds zero jump and leaves a 0.000060-unit offset after one third of a second. Recatch and kickoff clear it.
- Giant growth separated hands and ball for three frames. Their visible transforms now grow together; measured detached frames are zero. Independent checks cover four actual throws and six normal/Giant dunks without authoritative state mutation.
- In mirrored 2v1 openings, both flank bots abandoned the kickoff ball for launch routes. The nearest teammate now pursues it directly. The same full-match driver then recorded 27.217 seconds of possession and 16 tackles within 90 seconds, compared with none before; teammates still use launches.

The first three-process full match finished 10-6 with matching winners and one earned bag per winning human. Its host emitted an ENet oversized unreliable packet warning (1393 bytes, MTU 1392), so that build failed release verification despite finishing. Its exact executable, logs, frames and diagnostic video remain under `../build/crown-court-evidence/v3-network-recorded`.

Snapshots up to 1200 compressed bytes now retain unreliable delivery. Larger updates use a separate reliable channel with one unacknowledged item per peer. Per-round sequences prevent late fallback updates from rewinding newer state. Review also caught and fixed the first snapshot arriving before the match-start message: delivery is acknowledged using that packet's own round identity. All 21 real-ENet regression cases pass against the final embedded pack, including preserved fields, delayed acknowledgements, old-round rejection and disconnect cleanup. Under high latency/loss, oversized updates slow instead of accumulating; actual household network feel remains to be tested.

The repeated final-build three-process match completed normally at 4-0 after 53.17 seconds (the four-point-lead rule). All peers agreed on match, score and winner and saved one bag each. The host sent 624 small snapshots and 1484 reliable fallbacks; maximum payloads were 1200 and 1542 bytes. Eighteen obsolete large updates were coalesced. All three logs were free of runtime warnings/errors. The joining client exercised every tracked action, with zero focus recoveries. Its 606 captured frames form the 54.57-second real-time client video in `v3-network-recorded-final`.

## Recorded play and inspection

The 0.2.0 baseline is a complete 197.28-second, 7-3 match with five active bots and actual keyboard/mouse InputEvents. It includes catches, passes, shots, tackles, dunks and the result screen. The driver does not grant positions, possession, scores or clock changes. One focus interruption and external mouse movement remain in the evidence; their camera spikes are not claimed as improvements.

The improved build uses the same adaptive input driver. A separate three-process run has a rendered joining client, a host and a second client against three opponent bots. Host/second-client decisions use normal input/action submission; the rendered client uses actual InputEvents. This is automated play, not household feedback.

The final offline match ran 188.32 game seconds and ended in a 4-8 loss, correctly awarding no bag. All tracked action categories occurred: local events include 27 grabs, five passes, two throws, three dunks, three tackles, 47 jumps and four scores. The complete game recorded 12 baskets, nine dunks and 45 tackles with five active bots. No match fixtures were used. One focus interruption was automatically resumed and remains in the footage. These different match trajectories are not a controlled before/after performance comparison.

The offline movie contains 11310 frames at 60 FPS (188.50 seconds including startup/exit frames), captured in 7 minutes 30 seconds of wall time. Its inspected flow, dunk, pass/catch, shot and focus-resume sheets are under `v3-candidate-recorded`. The full-resolution result frame confirms the loss and absence of a reward. MP4 SHA256: `88CEA59885A4BA23DACD0277307967F4727176A41088212267A2BE2E9A23C553`.

Native Godot movie capture uses a fixed 60 Hz game clock and is not a performance benchmark. The network recording runs in real time and retains timestamped viewport frames, encoded as variable-frame-rate video without audio. Camera terrain, aim and framing checks pass; this revision does not change camera code.

Five final network contact sheets and the decoded video were reviewed. Catch/pass, dunk follow-through, physical score and reward screen remain readable. A brief Giant opponent can obscure the view in crowded play. The final recorded active-play camera delta peaks at 1.919 units; camera observations, render timing and packet receipts were not timestamped together, so this cannot be separated into network correction versus capture/render timing. There is no claim of zero jitter. Details are in `v3-network-recorded-final/REVIEW.md`.

## Release checks

Source and exact embedded-pack checks cover simulation, movement/dunk, profiles, complete matches, application flow, rewards, sessions, adversarial networking, mirrored kickoffs and world continuity. Rendered checks exercise actual menu/gameplay inputs. A continuous input route starts at the real spawn, picks up the ball, launches, double jumps, dunks, physically scores, lands and returns to kickoff; opponents are held still only for this isolated route.

Eight network scenarios cover 1v1, balanced/unbalanced 2v1, two/three humans against bots, late joins and three-player free-for-all. Eleven shared action checkpoints require agreement on catches, passes in both directions, tackle/drop/catch, shots, dunk, launch, extra jump and speed boost. Lifecycle tests use controlled finish fixtures; the full recorded network match covers the natural finish/reward path separately.

All eight scenarios passed against the exact executable above: 22 process results, plus three passing processes for all 11 action checkpoints. The LAN interface was `192.168.20.15`. The matrix receipt is `../build/crown-court-evidence/v3-network-verified.json`; it matches the executable hash.

Network processes run on this computer using loopback and its LAN interface. Packaging checks exact executable/source hashes, completed recorded matches, video hashes and the network matrix, then verifies a fresh ZIP extraction and native startup.

## Local tools

Game Development Studio CLI 1.5.0 is installed. Required doctor checks and the official sample capture/verification pass. The game adapter imported, sealed, verified, analyzed and compared native Godot before/after images. `.game-dev/README.md` links the receipts: this is CPU analysis of existing captures, not another GPU execution.

The Computer Use plugin is installed, but its kernel fails during Codex sandbox setup because a deny ACE cannot be applied to `C:/game-3/.git`. Supported reset/retry did not repair it. Sandbox protection was not weakened. TOOL_SETUP.md records the installation and remaining diagnostic step. Players need none of these tools.

## Household test remaining

Use the same 0.3.0 build on every PC. One hosts; others join the address in the lobby. Test actual Wi-Fi/Ethernet/firewall access, physical controllers/audio, and the feel of camera tracking, aerial steering, moving catches, contested dunks and tackles. Complete a win, open/equip the earned bag and rematch. Try balanced/unbalanced 2v1 and leaving/rejoining. HOUSEHOLD_TEST.txt provides the sequence.

No physical household session, human fun rating, exact Crown Jam physics/gameplay equivalence or public upload is claimed.

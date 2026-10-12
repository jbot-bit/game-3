# Crown Court 0.9.0 held baseline verification

Windows, 12 October 2026. Godot 4.7.2 Compatibility renderer. Earlier games, packages and saves are preserved. Version0.8 remains an unshipped candidate after the user rejected the arena/ball mechanics. This pass used retained0.7 footage, a fresh0.8 three-client recording and current feedback; no new household recording was attached.

## Changes with reproduced evidence

- Court expanded from40x72 to64x112, with96m hoop separation, connected wider routes, relocated boosters and four physical padded sweepers. Giant crosses the sweepers; other players can jump them. The shared simulation drives visible hazard phase and ball/player contact. These are authored choices informed by the reference topology and feedback, not recovered Crown Jam dimensions.
- Passing forecasts a receiver's movement through the full flight. Exact0.8 missed a steadily running receiver by4.494m on a16m pass. New checks cover moving, braking and airborne receivers, interception, no post-release homing and69m reception.
- Shot assistance changes continuously with aim, range and charge. The old.114-degree aim boundary changed velocity9.973m/s; the revised difference is.219m/s. A2cm range boundary changes.00957m/s instead of5.698. Real own-half/deep-court shots reach both baskets; poor charge/aim and physical interception can still deny a basket.
- Catch/ownership position is atomic. Ball presentation no longer jumps or moves backwards when passing during the catch gather. It also stops retiring release corrections when incoming snapshots freeze. Backboard spacing and the decorative support leave the rim opening clear.
- Selected Hype power, charge, readiness, active lifetime and small earned increments are visible. A real completed pass followed by the receiver's goal within8seconds earns assist Hype. Own-goal scoring cannot farm scorer Hype. All three effects, expiry, hazards and assist lifecycle are exercised through real simulation actions.
- Includes0.8 audio event-history/priority, possession-charge cancellation, foreground visibility and bounded network-recovery fixes. The21-sample CC0 bank is retained. Detailed pre-repair and independent evidence is in REVIEW-0.8.md, REVIEW-0.8-AUDIT.md, BALL-MECHANICS-0.9.md and REFERENCE-0.9.md.

Native source comparisons show the larger arena, powers and ball transfers. Actual browser-rendered Crown Jam gameplay and primary descriptions were reviewed. REA instructions were available but no REA runtime or installed original-game artifact was available; no binary-decompilation or private-constant claim is made. Game Development Studio checks import actual native Godot captures and do not constitute another GPU playtest.

## Exact release checks

Final executable: `CrownCourt.exe`, 110,696,336 bytes, Windows file version 0.9.0.0. SHA-256: `9120C048816C600EB2EE5BD0C9DF0B15056E99EA50655827E2460E785EC149BB`.

The final build passed all 44 embedded test scripts, native keyboard/mouse input (18 checks), native audio integration (14), controller-event/menu flow (63), the full input-driven pickup/boost/launch/extra-jump/dunk/score/reset route, and independent startup of the actual EXE. The source suite ran before final power review; changed power and route paths then received focused source regressions before the full final embedded suite. No source-only result substitutes for a packaged check. Final rendered shot-preview component time was 2.071 ms; this is not a whole-frame performance benchmark.

Exact-pack room integration passed 25 application checks and 81 native menu/controller checks. A separate real three-peer local relay fixture passed all 27 power-lifecycle checks: selection, earned charge, activation, physical effects, joined world/HUD state, expiry and a live bot-to-human replacement. It uses explicit setup/time-step fixtures in one SceneTree; it is separate from the natural multi-process recording.

Power review reproduced nearly 0.9 m homing-projectile steps at 20 Hz. Bounded presentation now advances at 60 Hz with a measured maximum 0.300 m step and 0.032 m curved-flight error in the controlled run. All 12 lifecycle/continuity checks pass, including authority immutability, the 80 ms starvation cap, deletion, expiry, host placement and round reset. The selected power remains visible when an inherited active effect has a different timer.

Two test-driver defects were also repaired without changing production physics: the old native route crossed a newly added sweeper and continued after losing possession; its shared pad cooldown could also mistake a speed strip for a launcher. The corrected route navigates the clear crossing and requires a real nearby upward launch. The network action fixture independently rejected a stale kickoff that previously satisfied its launch condition. Original failures and the rejected candidate EXE remain under `v9-release-*`, `v9-pre-power-polish` and `v9-rejected-candidate-network.json`; final receipts use `v9-final-*`.

## Networking and complete recorded matches

The final exact pack passed eight LAN configurations (22 peer reports), 11 physical action checkpoints on three peers, room application/menu/power integration, raw relay/RPC/stalled-TCP and three impaired ENet scenarios. Eighty captured logs were clean. The final offline FFA recording completed and is retained under v9-final-match. The full three-process natural room recording and ZIP were not made: the user rejected the arena, so 0.9 is held as comparison evidence while 0.10 replaces its terrain and stadium. Controlled fixtures and complete normal-input matches are distinct evidence types. Recording counts now consume recent event history and are not directly comparable with older latest-event-only logging.

## Package and remaining physical playtest

Packaging requires matching source/EXE hashes, native input/controller/audio gates, eight network configurations and action checkpoints, room integration, impaired transport tests, complete normal-input match/video receipts and successful startup after fresh ZIP extraction. No public upload, host deployment, router or firewall change is included.

Physical mixed controllers, speaker/headphone preference, separate household PCs, human enjoyment and long-session/cross-home smoothness remain unverified. Software controller events are not hardware evidence. The public WSS relay endpoint is blank, so no-extra-app Internet play is not live. An approved deployment and external connection test remain necessary. Fixed-clock offline recording is not a frame-rate benchmark; local network impairment does not establish real WAN performance.

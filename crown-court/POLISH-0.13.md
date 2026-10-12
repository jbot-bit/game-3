# Crown Court 0.13: movement and match polish

User direction: improve all aspects toward the satisfying Fall Guys/Crown Jam feel, particularly run-release skid, dive carry-through and knockback landing slide. Continue existing family basketball project and preserve unlocks. Source publication is explicitly authorized; hosting remains undeployed.

Implementation: preserve momentum through a bounded recovery phase; remove direction-dependent knockback friction; share recovery between simulation, receiver forecast and local prediction. Match physical slide state with planted-foot coasting, low dive recovery and braced landings. Keep hands and ball anchors, character identities and accessory support. Clamp the follow camera inside foreground stadium geometry. Add correct scorer/lead/tie feedback and restrained clock and power-ready cues using licensed existing samples.

Verification: reproduce abrupt braking and diagonal discrepancy; measure displacement, stopping time, frame-rate stability and prediction consistency; regress family save preservation, actions, shots/dunks, multiplayer and feedback. Build and check both architectures, inspect actual rendered frames, seal evidence with Game Development Studio and compare retained REA controlled replay evidence. Automated correctness is distinct from human enjoyment or physical three-PC/controller testing.

Original-game equivalence: public reference footage and user feedback guide the reconstruction. No Fall Guys/Fortnite entry found in standard Epic manifests or this PC's sole Steam library. Original code constants remain unknown; our authored physics is not claimed to be decompiled Epic behavior.

## Evidence boundary and comparison

The REA MCP session was inspected, original movement constants were retained as unknown (unk_b9d4b702af16b6f68b97f22db4a3ecfb88b33710f8f1d076a508e9c400b8c0e0), and the requested Windows process probe returned capability_unavailable: native descendant cleanup is not supported. Evidence export: build/crown-court-evidence/rea-v13-unknowns.json. No original binaries were decompiled.

The same observational Godot script ran against the unchanged 0.12 embedded pack and 0.13 source: cardinal ground slide 2.520884 -> 3.857513, stop time .966667 -> 1.183333 seconds, speed at .85s 3.053321 -> 6.353320. Diagonal travel now agrees with cardinal to 0.00003 units. Original footage and the user's explicit slide feedback motivate these authored choices; these numbers measure our implementation only.

Game Development Studio 1.5.0 sealed and verified two native camera intervention captures for each of baseline and candidate. Same actor, scene and intended boom; constraint disabled/enabled. Both corresponding images are comparable. Root visually inspected the wall-obstructed and corrected view; the actor and playable court become visible. A peripheral hoop pillar remains in the controlled view, which does not invoke normal in-game basket fading. Tackle motion baseline/candidate captures are exploratory because a baseline simulation hash was not retained. Root also inspected low dive recovery and score/Hype-ready native frames. No frame-rate/performance claim follows from CPU sealing.


The first final-pack full match reached a 2-0 win, but its wrapper rejected the rendered client's zero unopened bags. The retained final frame shows the awarded Court Rookie outfit reveal: the bag had been opened. The driver now reloads the isolated profile and checks the redeemed round plus conserved unopened bags/new inventory. Peer evidence is frozen when the result first arrives, before a leaving client removes its appearance from the roster. Both host and peer use the same external driver against the unchanged gameplay pack. The failed wrapper and its original frames are retained; the corrected recording is separate.

# Gladiator matches and Wipeout balance course

User direction: padded-stick matches where players push each other off, plus Wipeout-style obstacles requiring balance. Keep the existing blank people, earned cosmetics, fast controls and three-PC LAN game.

Implementation choices: selectable Co-op, Gladiator and Wipeout modes. Co-op keeps its twenty levels. Gladiator supports two or three contestants, first to three round wins, brief countdowns and last-player-standing scoring; one player can practice without wins or rewards. LMB swings a visible padded staff, RMB braces at reduced walking speed. Reach, direction, obstruction, swing cadence and hit counts are checked by the host. A short bounded impact response prevents the normal ground brake instantly erasing a shove. Falling or F forfeits the round; no grapple rescue or power advantages. Disconnects and simultaneous falls cannot grant accidental wins.

Wipeout is a separate authored course with real tipping beams, rotating padded sweepers, stepping podiums and sequential checkpoints. One to three players can run it. The first finisher wins the race; the run ends when everyone finishes or after a bounded time limit, with finish times/falls and DNF results. Each finisher must visit checkpoints in order while supported on the course. F/falls return to the last checkpoint, with elapsed time continuing. No grapple shortcuts. One saved bag per completed match/course; practice and abandoned matches award nothing. Existing save format and cosmetic ownership remain authoritative.

Scope and safety checklist completed before implementation: current C:/game-3 is the existing dirty shared repository, with no root AGENTS.md or CLAUDE.md. Preserve unrelated fishing/nightfall work. Godot4.7.2, Jolt, Compatibility renderer, existing ENet and atomic saves. No dependencies, public upload, branch operations or real-save test fixtures. New build0.7.0 goes to a separate folder. Check existing game processes before native test windows.

Validation checklist:
- [x] Match rules: two/three players, draws, disconnects, late join, forfeits, first-to-three, exact-once rewards.
- [x] Real padded-stick pushes: direction/range/obstruction, miss, cooldown, brace and physical ring-out.
- [x] World physics: tilt from real weight, rotating bar contact, supported ordered checkpoints, actual Wipeout traversal.
- [x] Mode selection, scoreboard, controls, finish/customization screens at960x540 and native render inspection.
- [x] Multiplayer mode rebuilds, attack/brace transport, elimination, scores, hazard poses and reset/rejoin; existing co-op regressions.
- [x] Versioned export, clean-folder actual executable checks, exact exported-pack multiplayer, playable handoff.

Results and limitations are recorded in `docs/playtest/HANDS_FULL_STATUS.md`. Wipeout continuous route41.17 simulated seconds; combat21/21 physical checks; full unit run293/293 plus focused reward regression9/9; packaged new modes381 checks. Test saves are isolated. Native images are explicit display fixtures, not human play. Departing a live Wipeout race forfeits that connection's result; replacement actors start over. Eliminated/late Gladiator actors stop physical simulation and collision until their next round.

Physics references: [Godot AnimatableBody3D](https://docs.godotengine.org/en/stable/classes/class_animatablebody3d.html) documents moving bodies imparting their estimated velocity to physical bodies; use actual physics-tick collision sweepers. [Godot PhysicsDirectSpaceState3D](https://docs.godotengine.org/en/4.5/classes/class_physicsdirectspacestate3d.html) documents shape/ray queries for host-validated hits. Validate actual behavior in Jolt; documentation alone is not playtest evidence.

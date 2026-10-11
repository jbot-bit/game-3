# Three-player stages and cosmetic surprise bags

**Goal:** Make the twenty levels require actual cooperation and prevent a quick grapple from skipping the objectives. Award fun cosmetic surprise bags with rarity tiers after successful clears.

**Accepted direction:** Three players operate obstacles together. Two hold controls while a third completes the crossing/task; the third latches the obstacle so both operators can follow. Each level adds bridge, lift and cargo stages with checkpoints. Keep the responsive controller and both grapple modes. Target several minutes of first-time cooperative play, to be measured rather than asserted from geometry alone.

**Architecture:** A shared physical teamwork module extends each authored course and owns its three stage states. Host validates three distinct participants, proximity, current held input, real lift riding/cargo placement and final completion. Clients render authoritative progress. The original short endpoint becomes the staging area. Existing saves gain optional cosmetic ownership and slot appearances atomically; cosmetic rewards have no gameplay stats.

**Rewards:** One three-card surprise bag for each successful new clear. Common 60%, rare 28%, epic 10%, legendary 2% per card. Prefer an unowned item within the rolled tier. Failed save retries preserve the same pending roll; duplicate completion never grants another bag. Cards reveal through a foil-style UI. Earned paints and optional rounded accessories retain the faceless body.

**Constraints:** The user is playing the verified 0.5.0 executable now. Do not close it or launch native test windows over it. Stage the next release separately. Keep old powers, clears, matching LAN builds and rollback package intact. No public upload or paid loot.

- [x] Test and implement owned cosmetic catalog, RNG bags and atomic save/retry behavior.
- [x] Add optional rounded accessories on host and remote skeletons; keep default blank.
- [x] Add customization, locked rarity entries and authoritative bag/card reveal screens.
- [x] Implement three physically different cooperative stages and checkpoints for all twenty courses.
- [x] Integrate held operation input, replica state, completion gating, saved appearances and rewards.
- [x] Prove one/two players and direct endpoint grappling cannot clear; prove three participants can operate all stages with physical contacts.
- [x] Measure a full three-player route and review all level tail placements/clearance.
- [x] Run regressions, package the next build separately and verify the exported game without interrupting the current playtest.

Verified 0.6.0 release: build/hands-full-0.6.0, with its matching versioned ZIP. Continuous first-course test: 91.40 simulated seconds, all three physically at extraction, no recoveries or reposition after spawn. Full unit suite: 251 tests. Exported-pack LAN: 2,218 checks. All 20 extended layouts pass collision clearance checks. The native capture ran after the earlier game was observed closed. Movement retains one narrow stopping-time benchmark miss (267 ms versus 250 ms); detailed evidence and limits are preserved in docs/playtest/HANDS_FULL_STATUS.md. Human timing remains unmeasured. Opened the new executable for the user, PID 29428.

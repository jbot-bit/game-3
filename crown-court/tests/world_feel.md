# World feel revision ledger — 0.7

Approved scope: ground reversal/startup pose and catch/held/release continuity in `world.gd`. Sim owns acceleration, inertia and collision. Main owns packet correction for loose flight. No renderer motion writes physics and no second loose-flight filter is added.

- [x] Reproduce absent foot work through zero velocity and absent intent-dependent braking pose. Before: zero foot travel; reverse/coast torso tilt both about -.104 radians.
- [x] Reproduce real catch contact discontinuity. Before: a normal legal catch moves the rendered ball 1.309m without advancing simulation time.
- [x] Ground intent/velocity pose: short fast foot strokes, planted braking stance, crouch and directional lean. Air, boost, dunk, dive and stun exclude traction pose.
- [x] Shared 100ms ball/hand catch gather. Quick catch→throw inherits the gather's existing release offset; ongoing loose flight remains unfiltered. Kickoff and large relocation clear/skip the gather.
- [x] Reproduce/fix Giant reach guard. A legal Giant catch initially bypassed the normal guard and jumped 3.710m; scale the guard with Giant size. Both legal catch onsets now report zero no-time jump.
- [x] Native normal/reversal before/after inspection and 10-second actual-Sim reversal movie. Existing normal/Giant throw/dunk and release tests still pass.
- [x] Final eight-frame native Giant gather inspection, matched against exact 0.6.0 pack: current source 13/13; baseline preserves four expected failures.
- [ ] Exact 0.7.0 package repetition by release owner.

Ruling: retain authored ground tuning and derive presentation from `move`, `vel` and `facing`; introduce no new snapshot timer. This keeps network behavior shared with the simulation. The exact feel of Fall Guys is not claimed recovered from video.

Ruling: animate catch presentation only over 100ms rather than delaying ownership. Ball and both hands use the same target, and a throw remains immediately usable. The brief visual separation from the authoritative carry point is deliberate and bounded; headless tests verify convergence and immutable snapshot input.

`world_feel.gd` has 13 checks. Run source headless with `--evidence-dir=<new-folder>`. Add `--capture` and omit `--headless` for the eight-frame native diagnostic. Exact pack runs must pass `--pack-source=<exe>` after `--`; this records the executable SHA and suppresses raw `res://` source hashes, which can describe loose files even when compiled scripts execute from a pack.

`world_reversal_video.gd` drives the real `Sim.move_input` and `Sim.step` paths for 600 frames; it does not animate the player's position directly. Use Godot `--write-movie <new-path.avi> --fixed-fps 60 --disable-vsync`. The default sequence starts, reverses 180 degrees, turns 90 degrees and releases input. MovieWriter output is a controlled motion demonstration, not wall-clock performance evidence or household control testing.

Evidence: `build/crown-court-evidence/v7-world-feel-native-{before,after}/`, `v7-world-feel-giant-{before,after}/` and `v7-world-reversal/`. The native comparison's before pack identity comes from the explicit `provenance.json` launch receipt. Captured raw source hashes in older pack probes are not treated as compiled-script identity.

Final native pair: build/crown-court-evidence/v7-world-feel-final-{before,after}. Both original logs identify native OpenGL rendering; stderr is empty. The CPU-only import-feel-review scenario seals these images without rerunning Godot. Receipts are in v7-world-feel-cli. Brief Giant self-occlusion during the 100ms rear-view gather is retained and documented; no detached hand or sustained hidden carry was observed.


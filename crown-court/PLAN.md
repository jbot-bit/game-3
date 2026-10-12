# Crown Court Implementation Plan

## Current: 0.13 polish and source recovery

The 12 October user explicitly authorized publishing source to the existing public repository. Earlier source-privacy limits below are historical and superseded. 0.12 source, authored family assets and both EXEs are saved on main at 935da3c. The original basketball chat was restored and pinned; local recovery archive retained.

0.13 scope and verification: POLISH-0.13.md and KNOCKBACK-0.13.md. Preserve unlocks and family characters. Hosting stays undeployed. Current work adds momentum-preserving recovery, matching client prediction, visual bracing/camera clearance and meaningful score/clock/ready feedback. Exact final publication receipts belong in VERIFICATION.md.


## 0.11.0 play-feedback correction

The user reports an architecture compatibility failure on a second PC, overpowered bots that immediately shoot, excessive basket aim correction, weak tackle knockback, slow/janky dunks and a court still unlike the gameplay reference. The son has the full ~106MB file; exact Windows System type/error remains pending. Preserve the published 0.10 executable and runtime source before changing it. Publish only verified executables and their minimal download/notice support files; the earlier source publication was rejected by automatic approval review.

- [x] Use the actual REA CLI for shipped-PE compatibility evidence and retain its Evidence IDs. Public gameplay/overhead comparison supplies observed layout and timing; private Crown Jam constants remain unknown.
- [x] Prepare and verify a matching 32-bit Windows fallback from the retained official template archive, including clean-folder startup and mixed-architecture network agreement. Confirm the user's system/error rather than declaring his PC fixed from local evidence.
- [x] Add host-owned Easy/Normal/Hard bot settings, saved locally and visible/synchronized in the lobby and match. Default to Easy. Give bots finite reactions, possession build-up, passes and real charging/accuracy differences instead of instant near-hoop actions. Human input remains immediate.
- [x] Remove all basket-target correction from ordinary shots. Preserve literal camera yaw/pitch through client/host input and use a physical launch direction/speed controlled by aim and charge. Preview the same actual flight; misses, blocks and rebounds remain physical.
- [x] Reproduce current tackle displacement and repair visibly weak knockback/recovery without cancelling legitimate player movement, dunk interruption or authority. Improve dunk reach/slam timing and hand/body continuity against actual retained action frames; freeze committed axes as before.
- [x] Rebuild the playable court topology and finish against the official overhead and actual player-camera frames: open green central areas, narrower rounded raised routes, shallow traversable banks, broad rounded team ends and clear basket approaches, rather than the current thick bright cliff network. Share analytic terrain between simulation and visuals. Retain original authored art and keep readable scoring openings.
- [x] Run affected source and exact-export checks, difficulty/match pacing, raw aim/knockback/dunk regressions, native input/arena captures, two/three-client network agreement and complete play recordings. Publish the new verified one-file executable to root/main only after public-download/hash/startup verification.

Ownership for the independent implementation work: root owns sim.gd, shot/AI/knockback/dunk physics and release; input worker owns main.gd and menu/network input integration; arena worker owns world.gd plus a shared terrain layout module and arena regressions; compatibility worker owns isolated old-version export/REA evidence and template extraction only. No concurrent shared-file edits or GPU captures. The applicable dispatching-parallel-agents skill explicitly calls for one worker per independent problem domain; use that workflow for this plan.


Release closeout: commit `09e3f482184fe062eaac52c0a27940e2ef646588` is on remote main. Both public standalone EXEs were anonymously downloaded, SHA256-matched and started from a clean folder with isolated saves. The local ZIP is 81,755,861 bytes, SHA256 F5699D2E17C957B209ED8FBCE03F87BFD56ECA57BF363BE96983D5CCC9E6B63C. Source and sibling WIP remain local; only the five reviewed EXE/download metadata files were published. Hosting remains explicitly declined; physical household/son-PC/controller checks and transient behind-goal scenery occlusion remain follow-ups.

## 0.10.0 reference-driven arena rebuild

The user rejected the expanded 0.9 court as blank and boring while its final recording was running. Hold that release, retain its verified executable and network evidence, and finish the current recording as a comparison baseline. No launcher switch or ZIP publication. The next version changes the arena's visible and playable structure, using the retained full-match frames and official overhead. Existing action, ball, power, reward and networking repairs carry forward.

- [x] Replace shallow straight ridges with broad winding roads: 3m flat crowns, 6m crown width and 2.4m shoulders, connected transverse routes and front goal loops. Keep 64x112 bounds, hoop positions, boosters, ordinary jump and shot mechanics. The tight final bend was widened after a real running test exposed unwanted airtime. Twenty terrain checks pass, including both dunks, boosters, bank rebounds and corrected relative-height bot catches.
- [x] Build a surrounding stadium with curved crowd tiers, tall fascia, team-colored end shells, original large mascot silhouettes, strong terrain borders and launcher surrounds. Preserve ball/player/hoop sightlines and avoid fake walkable geometry inside the physical field. Native inspection checks all scenery, including actual crowd instance transforms; no geometry enters the playable rectangle.
- [x] Compare the same player-camera views against 0.9 and actual gameplay. Nine corrected source captures pass 37 checks and independent inspection, preserving eight baseline cameras and FOV. Repaired reversed terrain fronts and refined intersecting banks; worst sampled facet-centroid deviation fell from 0.418m to 0.04345m. The denser stadium adds measurable construction and draw cost; REVIEW-0.10-ARENA.md retains those limits.
- [x] Run the affected mechanics and exact-pack integration, record complete matches and independently inspect the result. All 48 final embedded regression scripts and native gates pass; eight LAN configurations, impaired transports and room lifecycle checks pass. Fresh offline 1-2-7 and three-client 2-6 matches complete with correct rewards and no fixture mutations or focus recoveries. Targeted changed-aim/deck tests and natural-coverage limits are documented in VERIFICATION.md and REVIEW-0.10-MATCHES.md. The separate 40,337,700-byte CrownCourt-Windows-0.10.0.zip has SHA256 5BD0E67AE46F6A01854485C3D2E2DE562C9098F9D6E74277C05B2C8BCE3B445F. Fresh extraction matches executable 12BB9FF780BD9F273E9DF3D10ED0F0295C71C09C5614980C3B0C9B855044AC6B and actual extracted-EXE startup passes. PLAY_CROWN_COURT.cmd now targets 0.10.0; previous builds/packages remain. Physical controllers, household enjoyment and real cross-home/public-relay play remain unverified.
- [x] Repair the release blocker found in the complete 3-4 room recording: changing aim during a dunk redirected the hand/release while the body followed its original fixed path. The committed dunk axis now controls physical release and presentation. Final exact-package changing-input checks pass 64/64 and hand/body alignment passes 9/9. The first 0.10 executable and both videos remain as before evidence; final complete recordings are part of the integration gate above.
- [x] Repair the independently reproduced launch-deck prediction dip. A still-grounded snapshot could predict X/Z beyond the one-way deck and incorrectly project feet five metres down before the next airborne packet. Preserve continuous elevated-support departure without changing banks or local jumping. All 27 real packet/physics/presentation checks pass on the final combined executable under the v10-release prefix.

Detailed authored layout and evidence: ARENA-0.10.md. Ownership: reference owns Sim terrain/functions and physical regressions; world owns world.gd arena/art; app independently checks sightlines/presentation; root integrates, documents and releases. GPU work stays serialized. The user has repeatedly authorized direct implementation; the design skill's question opt-out applies. No additional approval pause is needed for these local changes.

## 0.9.0 ball mechanics and complete arena

The user's new feedback explicitly rejects passing/shooting, the arena's small scale and missing/unclear power-ups. Hold 0.8 as an unshipped test candidate, preserving its executable and completed 10-9 three-client recording. Continue the earlier audio/control/network repairs, but do not package another revision without substantive ball and arena changes. REA instructions were read; no REA runtime or selected installed Fortnite artifact is available. Browser gameplay, official descriptions and production Sim/runtime probes supply evidence instead. No binary-decompilation claim.

- [x] Reproduce moving-target passes and shot-assistance discontinuities against exact 0.8. A 16m pass misses a steadily running receiver by 4.494m; a .114-degree aim shift changes launch velocity by 9.973m/s; a 2cm range change changes it by 5.698m/s.
- [x] Repair predictive passing, continuous charged shots and backboard/rim geometry. Verify interception, misses, rebounds, both baskets and readable full-flight previews.
- [x] Enlarge the playable arena to 64x112, widen connected raised routes, relocate launch/boost pads and kickoff decks, and add four physical padded rotating hazards. These are authored dimensions, not recovered original constants.
- [x] Complete the three Hype ability flows: selection, charge, ready/activation feedback, duration, physical effects and expiry. Award real pass-to-score assists. Retain simple controls and menu flow. Final embedded three-peer room lifecycle passes 27 checks; projectile prediction passes 12 checks. Inherited active-power timers and stepping homing visuals were reproduced and repaired before the final export.
- [x] Source/exact-pack checks and complete recordings were retained. Packaging was superseded by 0.10 after the user rejected the blank arena; no 0.9 ZIP or launcher switch was made.

Ownership: reference owns Sim passing/shooting and larger-field bot support; world owns ball presentation, arena construction and hazard graphics; app owns preview/input/Hype UI and network prediction; root owns arena constants, physical hazards, assist credit, integration and release. GPU runs are serialized. Public deployment and real cross-home/controller play remain separate limits.

## 0.8.0 recorded-play debugging

Use the shipped 0.7 match recordings and current feedback; no new household recording was attached. Preserve 0.7 and its source manifest before changing production. The user authorizes local debugging, normal-input game execution, recording, tests and a new separate package. Public hosting remains unapproved. REA tools/CLI are unavailable in this session; the applicable work uses source and recorded/runtime observations, without a decompilation claim or tool installation.

- [x] Reproduce and repair the largest remaining network-presentation discontinuity, retaining authority and lifecycle/reset behavior.
- [x] Reproduce missing/incorrect sound or control feedback, and fix the production event/input path rather than substituting another unreviewed sound bank.
- [x] Inspect camera/carry/rim visibility in the existing recordings and fix a demonstrated obstruction or tracking problem.
- [x] Independently review focused changes; capture comparable native before/after evidence and run the source/exact-pack release gates.
- [ ] Record complete new offline and three-client matches, review outcomes/audio/footage, package 0.8.0 and test a fresh extraction before updating the launcher.

Ownership: app owns main network/prediction, world owns world/camera, reference independently reproduces controls/simulation feedback issues, root owns audio/HUD/input integration and release. GPU runs serialized by root. Audio-event transport changes must be coordinated with app. GDS native image comparison remains separate from hardware/human play proof. No arbitrary ground/jump retune without new evidence.

## 0.7.0 sound, traction and ball continuity

The user's next play feedback rejects the sounds and calls out unsmooth ball movement and the missing directional scramble/skid. Hold the 0.6 package; preserve its completed recordings and exact executable as the before comparison. Continue local implementation and release authorization. These changes approximate observed mechanics; no undisclosed Crown Jam constants are claimed.

- [x] Ground-only traction with immediate response, slower speed build, a meaningful reversal and identical cardinal/diagonal behavior. Shared with client prediction, with measured startup/reversal/diagonal checks; airborne/boost rules preserved.
- [x] Keep feet working through reversal, show braking lean, gather a caught ball into the hands, and remove delayed-snapshot backward ball corrections without changing authoritative physics. Exact-pack native images and receive-state regressions passed; independent review also repaired stale client animation intent/velocity.
- [x] Replace oscillator cues with a small licensed sample bank; bound volume/overlap, vary repeated impacts and add restrained traction sounds. Twenty-one samples pass integrity/routing checks; real native audio, concurrent voices and keyboard motion passed.
- [x] Review actual source gameplay samples and matched local reversal/catch footage, run complete 2/3-player and exact-package checks, then ship a separate 0.7 build. Natural room match 6-2 and offline FFA 6-7-4 completed with correct rewards and independently reviewed footage. Eight LAN configurations, eleven action checkpoints and impaired-transport checks passed. The 40,114,832-byte ZIP has SHA256 A25C14BC83AC2A3168D8120AD4644A7275E72ECFD9FC7A9A0E7C1774DE5C518C; fresh extraction matched executable 1BCC8ADFF6ABFCD685F670EB9578A11EF55045B4C5DA5D406D093587098CF232 and native startup passed. PLAY_CROWN_COURT.cmd now targets 0.7.0. VERIFICATION.md retains the network gaps, recording interruptions, public-service and physical-play limits.

Ownership: reference owns Sim traction and reference research; world owns rig/catch presentation; app owns network presentation/prediction; root owns audio, integration, documentation and release. GPU runs remain serialized. Public hosting and physical controllers remain pending.

## 0.6.0 play and presentation revision (development baseline)

The user requests a substantial improvement to the existing game. Continue the already authorized design and local release; preserve previous packages and sibling projects. Ruling: prioritize evidenced team-play, feedback, readability and presentation work over another unmeasured physics retune. Ordinary jump/gravity and court dimensions stay unchanged. No claim of a literal 100-fold improvement or exact proprietary physics.

- [x] Repair active-catch pass credit; deliberate pass eligibility; pressure-aware bot passing, spaced support and action priorities. Retain regression coverage for all team modes.
- [x] Refine the ball, court, bean animation and label placement; isolate hoop obstructions from rim/net. Camera evidence did not establish a reproducible camera-only defect, so camera physics were retained.
- [x] Compact the HUD, show possession and remaining extra jump, use device-specific contextual prompts, and retain score feedback when a newer event replaces the score event. The interim sound design was superseded by the 0.7 sample bank after user feedback.
- [x] Measure app work separately from OS scheduling gaps and eliminate measured headless presentation waste. The separate host scheduling-gap limit remains unresolved.
- [x] Review native captures, complete natural offline and three-client matches, and run exact-pack rules/input/network/reward gates. Preserve the verified 0.6 executable and recordings as a comparison baseline. Packaging was superseded by 0.7 before a 0.6 ZIP was created.

Ownership: reference agent owns sim.gd and team-play tests; world agent owns world.gd and visual/camera fixtures; app agent owns main.gd init/process/prediction/network and performance probes; root owns main.gd build_hud/update_hud/feedback helpers, hud.gd, audio.gd, docs/build/release. Use scoped edits in shared main.gd. GPU runs are serialized. Actual household controller/cross-home play and public relay hosting remain separate unresolved requirements.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deliver a playable, visually readable 3D physics basketball game for three household PCs.
**Architecture:** Host simulation in sim.gd; original procedural 3D presentation in world.gd; main.gd owns UI, inputs and ENet; standalone Windows package.
**Tech Stack:** Godot 4.7.2, GDScript, Compatibility renderer, ENet.
**Spec:** DESIGN.md. Interfaces are in CONTRACT.md.

## Constraints
Only crown-court/, PLAY_CROWN_COURT.cmd and its dedicated build outputs may change. Existing dirty games belong to other work. No public actions. Tool installation requires an explicit user request; the later request authorized the local Game Development Studio CLI install and native helper diagnosis.
Ruling: use a separate project directory in the existing checkout rather than moving existing dirty work to a worktree; all tasks have explicit file ownership.

## Review focus
- Input events must actually move and interact in a rendered game, including camera-relative direction and cursor capture.
- A ball must physically pass through a hoop to score; no scripted make/miss result.
- Three network peers must agree on roster, ball owner, position, score and rematch state.
- Joining/leaving during play must not break the remaining players.
- Exported executable must start independently after ZIP extraction.

## Tasks
- [x] Simulation: movement, large jumps, banked terrain, catches, aimed passes, rim collisions, separate dunk, scoring, Hype, team composition and behavioral regressions.
- [x] Presentation: original 3D court, characters, deep baskets, orbit/ball camera, motion feedback, cosmetic previews and inspected GPU renders.
- [x] Player flow: simple menus, keyboard/controller mappings, practice, lobby, co-op/custom teams/free-for-all, saved rewards and wardrobe.
- [x] Integrate: rendered input tests and network matrix; independent action test confirms two passes, tackle/drop, catch, shot and dunk with all three peers agreeing.
- [x] Review closeout: targeted fixes for late-join reward identity, save retry, projectile ownership, pad placement, live balancing and inactive-peer shutdown; final package checks passed.
- [x] Deliver: export, run packaged checks and eight network scenarios, ZIP, verify a fresh extraction. Launch for household playtest.

## Reference-driven revisions
The first trailer-only research was insufficient. Two full gameplay matches and dense dunk/catch sequences drove corrected PC controls, contextual catches, aim-selected passes, independent dunk input, 5-minute/four-point rules, banked terrain, overhead carry, and a longer dunk wind-up. Physics constants remain authored tuning, not claimed reverse-engineered constants.

## 0.2.0 movement revision
Observed defects: a 4.6-second end-to-end court, stationary launch pads, an extra jump that cuts boosted ascent, instant air braking, a ball camera that ignores manual look, stale shot preview aim, unbuffered E catches and quick jump/dunk inputs. Full-match footage establishes a larger traversal space, long traveling launches, and a closer/lower avatar framing; exact internal physics remain unknown.

- [x] Expand the court from 24×44 to 40×72, keeping player/ball/rim scale; move goals and spawn positions; add four ground boosts alongside four traveling launch pads.
- [x] Preserve boosted extra-jump momentum and airborne coast; buffer landing jumps and early dunks; make catch eligibility shared by simulation and prompts.
- [x] Correct rendered input/camera/preview defects and verify a route from spawn to basket using actual input events without position fixtures.
- [x] Inspect after renders against source framing and measure jump/launch profiles; independent review of gameplay changes.
- [x] Verify source and packaged complete matches plus two/three-client modes and launch/extra-jump/ground-boost synchronization.
- [x] Deliver versioned 0.2.0 ZIP, preserving 0.1.0, with explicit household playtest limits. Final archive extracted, executable hash matched, and native startup passed.

## Bugs found by testing
The first input fixture was being tackled by active bots; movement checks were isolated from opponents and the full-match test retained bots. Independent review found stunned divers chain-tackling, unreachable boundary Hype pads, and stale projectile targets on bot replacement; each received a failing regression and fix. Network action testing exposed shallow near-hoop shot trajectories; the solver now chooses a clearance apex, and both hoops are tested from 5, 9, 14 and 20 metres. Reward identity/save retry, live team balancing and inactive-peer shutdown received regressions and fixes. Final evidence and physical household limits are recorded in VERIFICATION.md.

## 0.3.0 recorded match revision

The user requested agent-operated play, recording, review, fixes and a new local release. Native computer control failed on initialization twice (`helper_unknown_error`); the Game Development Studio CLI was initially absent and is now installed as described below. Ruling: use the installed Godot runtime's input events and movie recorder, preserving active opponents and real match rules. Call this automated play, never household feedback. Preserve 0.2.0 and all sibling games.

- [x] Record a complete 0.2.0 match with active opponents and normal input/score paths; inspect event footage and telemetry. Exact pack: 197.28 seconds, 7-3, five active bots, local catches/passes/shots/tackles/dunks, no match fixtures. Native AVI decoded to MP4. One focus interruption and external mouse motion are retained in the record.
- [x] Reproduce the biggest remaining visual, simulation and network issues; fix only evidenced defects and retain regressions. Three adversarial ENet failures, boosted release/size transitions, and both mirrored kickoff chase failures repaired. Camera terrain/aim checks pass; externally influenced recording spikes do not justify a camera change.
- [x] Record the improved complete match and a network client view; independently review gameplay and release checks. Final build completed a 4-8 offline loss and a 4-0 three-human network win, with correct rewards, full tracked action coverage and inspected event footage. A 1393-byte unreliable packet warning in the earlier candidate blocked release; bounded reliable fallback and round/sequence handling now pass 21 regression cases and the repeated complete match, including payloads up to 1542 bytes without warnings.
- [x] Export 0.3.0, verify packaged input, match and 2/3-client scenarios; extract and launch the new ZIP. All eight network scenarios and eleven action checkpoints pass against executable A4DD4F0457EAA686DA65D033FE20A3BC462B0B2F43EA610B34B88C252EF10D81. ZIP 18C39310EAAD6A52210AF93A01A120624B4C3A3F5F4B79E579ECB5F2384BCFC9 (39619251 bytes) passed extraction/hash/native startup. The root Crown Court launcher points to 0.3.0; household play remains unverified.

Ownership: app agent owns the active-input driver/main.gd, world agent owns world.gd/visual probes, independent reviewer owns new review probes, root owns sim.gd/build/release/documents. GPU runs are serialized. All share existing simulation/presentation contracts. New tests must exercise production paths without granting scores or possession during active matches. Video movie mode uses a fixed game clock and is not a real-time performance benchmark.

Tool setup: the user subsequently requested local installation. Game Development Studio 1.5.0 was installed from the publisher's release tarball, checked against both release and checksum-manifest digests, with npm lifecycle scripts disabled. Required doctor checks and the official first capture pass. A game-owned adapter imports the actual native Godot baseline/candidate images; CLI verify/analyze/compare receipts are in .game-dev/. This CPU import does not claim a new GPU execution. Computer Use is already installed, but its kernel cannot initialize because Codex sandbox setup cannot apply the deny ACE to C:/game-3/.git; sandbox protection was not weakened or bypassed.

## 0.4.0 controllers and internet

The user now needs friends in separate homes to play and asks for working controllers. This expands the previous LAN-only scope. Keep Godot/ENet and all game modes, saves and earlier releases. Tailscale is already installed locally but requires sign-in; Windows detects a DualSense. Private overlay connectivity avoids a public game service or router changes. Code/help may support it now; account sign-in, friend invitations and changes to network access remain user actions unless explicitly authorized. No remote-home success is inferred from a loopback test.

- [x] Complete controller navigation, name/address entry, play, pause, rewards and reconnect handling; 64 rendered checks pass against the final pack using parsed joypad events. Desktop hardware discovery reports no active controller; physical testing remains below.
- [x] Show VPN and LAN addresses, validate IP/hostname endpoints and include short internet setup instructions.
- [x] Measure three-process ENet with internet-like delay/jitter/loss, including oversized snapshots. Four bounded in-flight updates reduce sustained-large median gaps from 150 to 50 ms. Final-pack actions, saturated load and complete connection timeout all pass; no cross-home claim.
- [x] Review source and packaged controller/menu/gameplay tests, two/three-client modes, complete matches and extraction; ship local 0.4.0 ZIP and launcher. Final executable 892503559A4F8820FF072BE9A0A6DDAB800B8784C1B57DD743EB552050A7E1D5 passed 64 rendered controller checks, eight network configurations, eleven action checkpoints and all three simulated-internet gates. Natural recorded matches finished 6-2 offline and 5-1 with three clients, with correct rewards. ZIP 98AF950F20F28114D2668CEDCB08A5C34FF668878E6B9D76086D95252B418E33 (39665692 bytes) passed fresh extraction/hash/native startup. Launcher now points to 0.4.0; prior builds remain available.
- [ ] Connect separate-home PCs and physically play the complete match, bag and rematch flow. Requires friends and authenticated network access; not an automated release claim.

Ownership: app agent owns controller/input/focus sections of main.gd and controller tests; root owns network/UI address sections, docs and build/release; world agent owns isolated internet proxy tests; reference agent independently reviews network changes. GPU use remains serialized.

## 0.5.0 reference comparison and built-in rooms

The user prefers no extra app for internet play, uses mixed controllers, and will test physical controllers later. Latest steering asks to deconstruct actual Crown Jam gameplay and bring the experience closer. Preserve these requirements together; no new engine or sibling-project changes.

Ruling: compare the retained decoded full-match sequences with the exact 0.4.0 recordings before changing physics. Existing 1.2-second ordinary jump, overcharge, separate dunk and momentum preservation already exist; do not repeatedly implement them. Source internal constants remain unknown. Adjust only a demonstrated difference or defect, then measure and record the result.

Ruling: prepare an outbound secure WebSocket room relay and native transport adapter locally. This removes the additional client app and router configuration requirement. A publicly reachable relay still needs hosting; do not claim internet availability or deploy publicly before user approval. Local router discovery found zero usable UPnP gateways and changed no settings. TCP delay/backlog must be tested explicitly.

- [x] Write timestamped reference-to-current comparison, select and repair evidenced gameplay differences. REFERENCE-0.5.md and sealed native captures cover rear-deck kickoff, longer dunk wind-up/hold and pass trail; underlying constants remain authored approximations.
- [x] Correct mixed-controller prompts and exercise input/menu paths; defer physical pad validation as requested. Exact pack passes 63 controller/menu and 16 mixed-input checks, plus 81 room UI checks. Controller-only pointer isolation is documented in VERIFICATION.md.
- [x] Implement bounded private room relay, native adapter and simple Host/Join flow; retain LAN. Exact-pack RPC, application 25/25, room UI 81/81 and delayed/stalled TCP probes pass. Public service remains unconfigured.
- [x] Verify room isolation, three-client game actions, complete match/reward/rematch, disconnects and latency handling. Natural room recording finished 13-9 with all seven local action categories and one correct bag on each of three peers; separate transition fixtures cover rematch/rejoin. Eight LAN configurations and eleven action checkpoints also pass. Recorded catch-up/camera-dip limits remain documented.
- [x] Export and test a separate candidate with recording and fresh extraction. Local 0.5.0 ZIP is 39,721,025 bytes, SHA256 EA429B17C82026942C3BA40BB710402ED3F9BD7CC3512B156C7096CE62B26F68; extracted EXE SHA256 03D7E4464F0C3E1A18927C462160FB78BF3A624A09FAA7EBCBF57AB53FD86F08 starts successfully. Full natural room match 13-9 and offline FFA 2-7-4 have correct winning/losing rewards, independently inspected footage and verified movies. Root launcher now selects 0.5.0; earlier builds remain. The short no-capture probe leaves a documented host scheduling-pause limit. Public upload and relay hosting remain approval-dependent.
- [ ] After approved service deployment, configure the endpoint and verify actual public connectivity before calling internet play shipped.

Ownership: app agent owns main.gd and controller/room UI integration; world agent owns room_peer.gd, relay/ and isolated relay probes; reference agent owns REFERENCE-0.5.md and independent gameplay comparison; root owns sim.gd, world.gd, docs and build/release. Shared interfaces are agreed before edits. GPU runs remain serialized. No physical controller or separate-home play claim.

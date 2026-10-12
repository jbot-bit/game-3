# 0.8 input and sound-event audit

Scope: actual simulation actions, production HUD routing and the sound bank; headless reproductions only. This review does not claim an audio audition, physical-controller play or internet play between homes.

## Lost local action feedback

The 0.7 snapshot exposed only the latest event. A valid local throw followed by a nearby opponent's jump before one HUD update caused only the jump sound to be requested. `tests/review_v8_audio_routing.gd` reproduces this through real `Sim.action` calls and `update_hud`, with a sound-call spy. Both actions occurred; the throw cue was absent. The failing receipt is `../build/crown-court-evidence/v8-audio-routing-red/result.json`.

Simulation repair: snapshots now include `recent_events`, compact tuples `[id, kind, position, source_player, event_clock]`. The ring retains at most 16 entries and 350 ms. Its separate `event_clock` advances with simulation steps even during score celebration/final freeze; reset starts it at zero and clears history. Existing event IDs remain monotonically increasing, and existing latest-event fields remain compatible. Snapshots deeply copy the history. The HUD consumer is owned by the root agent.

`review_v8_event_history.gd`: eight failures before the change, nine checks pass afterward. Existing `sim_test.gd`: 58 checks pass. Sim source SHA256: `6E6B7ED171EF24A0FB53C622092478A9A0F8D66FD252BE753E50D4DD73D6BA57`.

`review_v8_event_payload.gd` sampled an actual six-bot match at 20 Hz. Across 829 snapshots the new fields added 37.8 compressed bytes on average, at most 140 bytes. Peak Sim-only payload changed from 1361 to 1454 bytes; the largest observed history held five events. This compares the same dynamic snapshot with/without the two added fields, not complete application/network packet sizes. The existing bounded reliable fallback still handles payloads above the 1200-byte unreliable threshold.

## Local priority across adjacent snapshots

The first event-history consumer prioritized local cues within one batch, but the sound bank's global per-kind cooldown still suppressed a local jump following a remote jump 50 ms earlier. `tests/review_v8_audio_priority.gd` uses actual accepted jumps and the real initialized SoundBank. The local jump occurred, but `played_count` remained 1 rather than becoming 2. The failing runtime receipt is `v8-audio-priority-red-runtime.stdout.log`; the earlier `v8-audio-priority-red` is a retained test parse failure and is not gameplay evidence.

The priority repair lets a first local cue supersede a recent remote cue, while local-to-local cooldowns remain. Local cues may replace the quietest nonlocal impact voice when the pool is full; score and announcement voices stay reserved. Independent current-source reruns pass both real-bank priority checks (`v8-priority-independent-green.stdout.log`) and all 13 HUD routing checks (`v8-routing-independent-green.stdout.log`). Native playback/voice-pool checks belong to the root's separate rendered audio gate; this headless review does not claim an audition.

## Input review

The root's charge-lifecycle repair cancels charge when possession is lost while preserving the held-button latch. Recatching with the trigger still held cannot revive the previous shot; a fresh press can. Read-only review found the mouse/controller combined-held path consistent with this rule. The targeted test uses parsed mouse events; physical pads remain unverified.

Event-consumer round seeding, mute/pause cursor advancement and local-catch transition deduplication were reviewed. Malformed-host tuple type/finiteness and future-ID checks were recommended defensively; the production simulation emits typed tuples with IDs no greater than its latest event. These are separate from the demonstrated normal-gameplay audio-loss defect.

The defensive tuple checks are now implemented, including duplicate IDs within a batch. The independent charge-lifecycle rerun passed all seven checks (`v8-independent-charge-lifecycle.stdout.log`).

## Delayed presentation and terrain contact

Independent inspection of the new snapshot recovery found that horizontal correction could put a grounded target back on the higher part of a bank while retaining the newer, lower incoming Y. `tests/review_v8_terrain_recovery.gd` reproduces this through actual 60 Hz Sim movement, compressed `receive_state`, prediction and world rendering. After initial placement on the bank, physics is never moved or rewritten. One 200 ms delivery gap is followed by normal 20 Hz samples.

The retained failing runtime receipt is `v8-terrain-recovery-red-runtime.stdout.log`: the presentation target sank 0.796 m below its terrain surface. At 60 Hz the world actor interpolation masked that worst target error, so this receipt does not establish a visible 0.796 m body penetration. The earlier similarly named log without `-runtime` records a test parse error only.

The app repair computes grounded contact at the corrected XZ, preserving pending local jump Y and the one-way platform surface rule. Independent rerun `v8-terrain-recovery-independent-green.stdout.log` passes: target clearance is zero within floating-point tolerance, and the actor's worst interpolated clearance is -0.0137 m. Authoritative packet bytes remain unchanged.

The independent final `snapshot_recovery.gd` rerun passes 21 checks (`v8-snapshot-recovery-independent-final.stdout.log`), covering delayed carrier packets, a plausible 525 ms gap, convergence at 30/60/120 Hz, the 80 ms starvation cap, invalid large relocations, the 600 ms admission limit, action transitions, kickoff reset and pending local jump acknowledgement. Read-only review found no further blocker in those paths. These are bounded synthetic packet timings and the separate real-Sim bank regression, not physical WAN evidence.

## World visibility and freeze review

Read-only review of the sectioned rim/net confirmed that occlusion changes presentation materials only. Bounds are captured from static basket geometry; each section owns duplicated materials, rays stop before the followed body/held ball, and alpha returns toward opaque when no longer obstructing. No camera, attachment or simulation mutation was found. GPU visibility assertions and visual judgement remain the world owner's separate evidence.

No remaining release blocker was found in this assigned review. Reviewed source SHA256 values: main `4CCEF30008C41A60E33D3ABC8081C46CFD22F1B051A20B91EFAD72B62729EFBC`; audio `3B69B56A56EB8A0909E46B76BED2360466E6AC1C4D8E13DDE58E5839925B792A`; world `FCE222C666ACF83AF08271B1BCF3F34F89484DDC7F26704FA80EF6344A65AC8E`; Sim as recorded above. Final exported-pack/network/recording gates remain separate release requirements.

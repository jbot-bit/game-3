# Match recording review, 0.10

**Final replacement package accepted within the tested scope.** Exact `12BB9FF…44AC6B` passes the targeted repairs and both completed normal-input recording reviews below, with no new release blocker found. The original `0B601D55…D9930` package remains held as failed historical evidence: six room-client dunks released off-axis and a separate deck-edge prediction dip was reproduced. Those old movies are not post-fix evidence. Human play feel, physical three-PC use and cross-home Internet remain unverified.

## Historical held package and method

Both recordings use executable SHA256 `0B601D55B3EC358404463A536443DD7EAAC575B321DAB83DF252CA3F4D0D9930`. They were driven through normal keyboard/mouse InputEvents with active opponents and no fixture mutations. This is synthetic play, not a human evaluation of feel or fun.

I decoded every video frame and every available audio stream with FFmpeg, limiting decoder/filter threads to two, and verified the supplied movie and package hashes. I independently read telemetry and directly inspected the event sheets, consecutive crest frames, successful/failed dunk sequences and native result frame. This was CPU review of existing captures; no new game process or GPU capture was run.

## Offline FFA

[Recording](../build/crown-court-evidence/v10-final-match/recording.json), [telemetry](../build/crown-court-evidence/v10-final-match/active-play.json), [integrity receipt](../build/crown-court-evidence/v10-final-match/INTEGRITY-REVIEW.json).

The match ended naturally **4–4–7**, Bot 3 winning after 170.783 simulation seconds. The local loss correctly awarded **zero bags**; reward eligibility and correctness are true, sanity-only and fixture mutation flags are false. There were zero focus recoveries. Local authoritative events include 20 grabs, 54 jumps, four dunks, seven throws and 15 tackles. FFA has no teammate pass, so `coverage.pass=false` is expected and is not counted as passing coverage.

The [full-flow sheet](../build/crown-court-evidence/v10-final-match/full-flow.jpg) shows live competition, the new connected terrain and the final result. [Crest traversal](../build/crown-court-evidence/v10-final-match/terrain-crossing.jpg) and [catch/throw frames](../build/crown-court-evidence/v10-final-match/catch-throw.jpg) show actors traversing raised crowns and a held ball transitioning into flight. The [dunk sequence](../build/crown-court-evidence/v10-final-match/dunk-followthrough.jpg) includes Giant approach, windup, release and the local score increment. Opponents briefly cross the foreground; this does not establish an uninterrupted clear view of every action.

The reported maximum camera step, **54.245m**, is a reset cut. All five logged large camera discontinuities have `reset=2.133s`, zero player step and zero yaw change. The [reset frames](../build/crown-court-evidence/v10-final-match/reset-cut.jpg) visibly switch from the completed goal to the center countdown. No active-play discontinuity passed that logger's threshold in this run; that is not proof of zero small jitter. The logger's maximum dunk camera step was 0.972m and maximum dunk player step 0.211m.

The movie is 1280×800, 30fps, **5,138 frames / 171.267s**, SHA256 `506DD379203BF945E377D3A164720B231BAF5F1ED980D354666CBA22E9750B5F`. This fixed-clock MovieWriter capture is not a real-time performance benchmark. Its sole game stderr warning was low disk space; complete output and full decode were independently verified.

Decoded stereo 48kHz audio is nonzero: peak **−15.847dBFS**, RMS **−41.713dBFS**, extrema −0.161304/+0.153104, with no nonfinite samples. These measurements establish signal integrity and no full-scale samples in the decoded track. **No auditory audition was performed**; sound taste, speaker output and perceived mix quality remain unassessed.

After verification, only the authorized 777,996,470-byte AVI intermediate was removed. [The retention receipt](../build/crown-court-evidence/v10-final-match/raw-intermediate-retention.json) preserves its exact path, size, SHA256, retained MP4 identity and decode provenance.

## Three-process room match

[Recording](../build/crown-court-evidence/v10-final-room/recording.json), [joined-client telemetry](../build/crown-court-evidence/v10-final-room/view/active-play.json), [integrity receipt](../build/crown-court-evidence/v10-final-room/INTEGRITY-REVIEW.json).

Host and two joined clients reached the same natural **3–4 loss**, match ID `1791781084-16341599-1911459393`. All three losing human seats received zero bags correctly. The rendered client played 326.75 simulation seconds with three opponent bots and all seven action categories covered. Its authoritative events include 27 grabs, seven passes, seven throws, 75 jumps, nine dunk starts and three scores. **Three focus recoveries** remain a capture limitation.

The [full-flow sheet](../build/crown-court-evidence/v10-final-room/full-flow.jpg) shows the real lobby, possession changes, raised routes, kickoff platform, live goals and the Bots win screen. [Passing frames](../build/crown-court-evidence/v10-final-room/pass-catch.jpg) show target indication, release and the loose ball; the telemetry establishes the seven pass events. [Successful dunk frames](../build/crown-court-evidence/v10-final-room/successful-dunk.jpg) show the score changing from 1–2 to 2–2, follow-through and the next kickoff.

The VFR room movie retains 3,560 timestamped frames, SHA256 `119AE1DF49852BC382A531F870AE35864892C29E18D618642608362745D7C3E1`; full decode and hash verification passed. This JPEG-derived room movie has no audio stream and provides no room-audio evidence. The relay is owned loopback WebSocket transport. It is not public-service, cross-home Internet or physical three-PC evidence.

## Actual blocker: changing aim during assisted dunks

The six non-scoring local dunk starts occur at telemetry times **18.0, 146.7, 148.733, 155.283, 157.167 and 225.567s**. Ownership changes at normal release timing roughly 1.2s later, with no corresponding successful score. They must not be labelled six tackle cancellations.

[The first failed sequence](../build/crown-court-evidence/v10-final-room/failed-dunk-first.jpg) shows the bean's body approaching the rim while the hand/ball axis turns toward the backboard. [A later failure](../build/crown-court-evidence/v10-final-room/failed-dunk-late.jpg) shows the same disagreement from behind the hoop. The independent simulation audit found that `begin_dunk` commits the body target, while subsequent input overwrites the aim used by `hand_position` and release. For example, the first failed approach holds the ball around z=−52.583 while the hoop is z=−48. The three successful local dunks keep their release near the intended opening.

The old executable, Sim and World are retained under `v10-dunk-held-baseline`. The narrow World regression also reproduced reversed body heading and post-release hands **3.361m** from the committed rim contact when input aimed away. Its fix reads the committed `dunk_direction` for body heading and post-release hands; held hands still follow the supplied ball. Both hoops, normal/Giant size and immutable presentation inputs now pass **9/9** in [the source regression](../build/crown-court-evidence/v10-world-dunk-axis-green/result.json), versus four failures in [the retained RED](../build/crown-court-evidence/v10-world-dunk-axis-red-checked/result.json). World SHA256 after this repair is `1EA66E7412AFE6E701EC5327B72F6CDFAE71E00DC769665126A6285ED1602743`.

These source checks do not turn the old movies into successful post-fix evidence. The simulation owner subsequently verified 64/64 physical dunk cases, and the replacement exact-package results are recorded below. The completed replacement normal-input recording reviews are appended below; the original held verdict is preserved.

## Camera and terrain findings

Consecutive room frames 973–977 show partial lower-body coverage on a descending crown, spanning **0.359s**; the surrounding clear frames 972/978 bound it within **0.537s**. Frames 990–993 show a second goal-bowl crest event spanning **0.266s**, bounded by clear 989/994 within **0.443s**. The local head and held ball remain visible throughout. The [every-frame detail](../build/crown-court-evidence/v10-final-match/room-crest-detail-provisional.jpg) was made before timestamps were published; its frame identities are exact, and these durations now use the completed timestamp manifest.

The independent analytic checks sample camera rays against the exact floor at 5cm intervals. Neither run has a blocked local head or held-ball sample. Room ball-ray obstructions concern loose/opponent balls, which terrain can legitimately hide. The longest sampled torso obstruction spans 0.1s, lower-body obstruction 0.3s. Separately, visual root interpolation can briefly lag below the analytic bank: worst sampled depth 0.177m offline / 0.210m room, while authoritative feet have no corresponding penetration. The 10Hz diagnostic does not bound unsampled instants.

This supports a documented brief crest/foot presentation limitation, not a persistent terrain camera failure. No arbitrary camera retune or terrain change was made. The room's active maxima of 2.603m camera and 2.418m authoritative player step are retained; [the reviewed burst](../build/crown-court-evidence/v10-final-room/active-correction.jpg) shows departure from the kickoff deck with input yaw changing. Packet timing, prediction and capture timing prevent a zero-jitter or causal-performance claim from these samples.

A separate deck-edge sample at telemetry t=225.0s has rendered root y=5.103m while authority is y=7.483m, recovering to roughly 7.024m one sample later. This exceeds the small ordinary-bank interpolation dip above and was confirmed as a client presentation defect. A grounded snapshot still described the elevated one-way deck while extrapolated XZ had crossed its edge. Ground-height reconciliation incorrectly projected the presentation down to the distant floor before the airborne snapshot arrived.

The narrow Main repair detects loss of raised support and preserves the extrapolated falling height instead of forcing the lower-floor projection. Continuous-bank contact projection remains in place; the step-down threshold uses the simulation's 0.4m contact rule. Physics, terrain and camera geometry were not changed for this repair.

The [27-check RED](../build/crown-court-evidence/v10-deck-edge-test-red/result.json) failed eight deck exits through actual Sim movement, compressed 20Hz `receive_state` snapshots and 60Hz presentation. For the north-front example, the old predicted target dropped 5.071m and the rendered local root lagged 2.604m below authority; the remote root reached a 3.224m downward error. Both front/side exits of both decks failed for local and remote presentation.

The [source GREEN](../build/crown-court-evidence/v10-deck-edge-test-green/result.json) and [independent repeat](../build/crown-court-evidence/v10-deck-edge-independent/result.json) pass 27/27. In the same example, the false downward error is zero and maximum target Y step is 0.139m local / 0.141m remote. Held-ball alignment and authority immutability checks also pass. These are deterministic presentation probes, not substitute native footage.

## Recommendation

Keep the original `0B601D55…D9930` package and its reviewed movies marked held. Preserve the reviewed room bursts, timestamp/hash ledger, movies and telemetry. Authorized JPEG compaction is complete: 991 reviewed/diagnostic frames remain, with the original 3,560-frame hash ledger and full MP4 retained. Do not infer gameplay quality from test counts alone.

## Replacement package: exact checks and recording reviews completed

Replacement executable: `C:/game-3/build/crown-court-0.10.0/CrownCourt.exe`, 110,750,464 bytes, SHA256 **`12BB9FF780BD9F273E9DF3D10ED0F0295C71C09C5614980C3B0C9B855044AC6B`**.

Frozen source identities are Main `F2218A9C05C5D08E556B35C1403C69659E2DC32BC0FFF41666209FC4C73B5A2F`, Sim `70ADEAE588356C4F25D9463708740BB21D231B39C4BD525BAB07348B662B4A92`, and World `1EA66E7412AFE6E701EC5327B72F6CDFAE71E00DC769665126A6285ED1602743`.

I inspected the targeted embedded-package receipts, each identifying that exact executable hash:

- [Dunk scoring](../build/crown-court-evidence/v10-release-pack-dunk_aim/result.json): **64/64**, compared with 32/64 on the old exact package. Cases cover both hoops, cardinal approaches, normal/Giant size and changing input through direct and host action paths.
- [Dunk presentation](../build/crown-court-evidence/v10-release-pack-world_dunk_axis/result.json): **9/9** for the committed body/hand axis and held contact.
- [Deck-edge prediction](../build/crown-court-evidence/v10-release-pack-deck_edge_prediction/result.json): **27/27**, including local/remote front and side exits.

The completed `v10-release-match` and `v10-release-room` recording reviews follow. This document reports their independent footage/integrity acceptance; the build owner retains the broader package/native gate receipts.

## Replacement offline recording: reviewed

The completed [v10-release-match recording](../build/crown-court-evidence/v10-release-match/recording.json) uses exact package `12BB9FF…44AC6B`. It ends naturally **1–2–7**, Bot 3 winning after **115.883 simulation seconds**, with zero focus recoveries and the correct zero-bag local-loss result. Reward eligibility and correctness are true; sanity-only and fixture mutations are false. Local authoritative events include 12 grabs, 30 jumps, four throws, two dunk starts and one score. Passing remains inapplicable to FFA.

I directly inspected six event sheets and the native result image: [full flow](../build/crown-court-evidence/v10-release-match/full-flow.jpg), [successful dunk](../build/crown-court-evidence/v10-release-match/dunk-first.jpg), [challenged dunk](../build/crown-court-evidence/v10-release-match/dunk-last.jpg), [catch/throw](../build/crown-court-evidence/v10-release-match/catch-throw.jpg), [terrain crossing](../build/crown-court-evidence/v10-release-match/terrain-crossing.jpg) and [largest reset cut](../build/crown-court-evidence/v10-release-match/largest-camera-step.jpg). The authored court, opponent interaction, loose-ball flight, Giant slam, recovery and 1–2–7 result are visible. Brief crest coverage remains on descending banks; these selected frames do not establish perfect visibility or human-rated smoothness.

The two dunk outcomes are independently classified in [dunk-classification.json](../build/crown-court-evidence/v10-release-match/dunk-classification.json):

- At **66.3s**, the uninterrupted dunk keeps the ball at approximately **0.400m horizontal radius** from the hoop through release, then scores at **67.567s**. It does not show the old package's off-axis normal-release miss.
- At **110.7s**, the dunk starts, then Bot 3 lands an actual **tackle at 111.333s**. Ownership drops at that same time; the next sample changes dunk from 0.883s remaining to zero and stun to 0.633s. Bot 3 grabs at 111.583s, throws and scores the winner at 113.017s. The frames show knockback and recovery. This is an evidenced interruption before release, not an unclassified failed dunk.

All three logged large camera discontinuities occur during reset countdown, including the 54.245m maximum. The inspected reset burst switches from basket follow-through to the center countdown. There are no logged active-play threshold crossings. This FFA route has no grounded elevated-deck samples, so it cannot independently validate natural deck departure; the exact 27-case regression passes. The final room route also uses upward launches rather than natural walking exits, so neither recording replays that specific walk-off defect.

The [integrity receipt](../build/crown-court-evidence/v10-release-match/INTEGRITY-REVIEW.json) verifies all **3,491 frames / 116.367s**, 1280×800 at fixed 30fps, complete video/audio decode exit 0 and MP4 SHA256 **`60F050A553B7268545741C4440BC64C6856CADA563DEA0741969B5436EF9CBAB`**. Decoded audio peak is **−15.847dBFS**, RMS **−41.749dBFS**, extrema −0.161304/+0.152385, with zero NaNs/Infs. No listening assessment is claimed. The only game stderr warning was low disk space; the completed file and all streams were verified.

The authorized **525,365,218-byte AVI** was removed only after full decode and identity checks. [Its retention receipt](../build/crown-court-evidence/v10-release-match/raw-intermediate-retention.json) preserves raw SHA256 `A101BCD6A1CE4B9E017147490190795FF0E228288FD7B50B8CD7745A8EDE4760`, exact path and verification provenance.

**Offline verdict:** no new release blocker found in the reviewed final-package recording. The completed room review follows; physical-controller testing and household feedback remain outside this evidence.

## Replacement room recording: reviewed

The [final room manifest](../build/crown-court-evidence/v10-release-room/recording.json) identifies exact package **`12BB9FF780BD9F273E9DF3D10ED0F0295C71C09C5614980C3B0C9B855044AC6B`**. Host and both clients agree on the natural **2–6 loss**, winner 1, match ID `1791783582-17033699-3085344808`, and correct zero-bag rewards. The rendered client reaches the result after 117.667 simulation seconds, with **zero focus recoveries** and no fixture mutations. All peers are reward-eligible and not sanity-only runs.

I directly inspected seven event sheets (65 selected native captures), plus full-resolution dunk and [final result](../build/crown-court-evidence/v10-release-room/view/frames/001310.jpg) images: [full flow](../build/crown-court-evidence/v10-release-room/full-flow.jpg), [local dunk](../build/crown-court-evidence/v10-release-room/local-dunk.jpg), [pass/catch](../build/crown-court-evidence/v10-release-room/pass-catch.jpg), [contested goal](../build/crown-court-evidence/v10-release-room/contested-goal.jpg), [deck launch](../build/crown-court-evidence/v10-release-room/deck-launch.jpg), [court traversal](../build/crown-court-evidence/v10-release-room/court-traversal.jpg) and [largest camera-step neighborhood](../build/crown-court-evidence/v10-release-room/kickoff-camera.jpg). The images show ball pickup/flight, movement over raised routes, the local tucked slam through the opening, score feedback, and the Bots win screen without a bag award. Brief foreground-crest coverage and crowded rim views remain visible limitations; no new persistent obstruction or side-release failure was found in these selected sequences.

The [independent telemetry audit](../build/crown-court-evidence/v10-release-room/telemetry-audit-final.json) classifies all eight dunk starts: **seven uninterrupted physical dunk goals**, with held/release samples at approximately **0.400m rim radius**; the remaining start at 48.217s is interrupted by an actual tackle at 48.450s, followed by a board deflection and goal at 49.167s. It is not the old mutable-axis normal-release miss. The rendered client's sole dunk starts at 10.900s and scores at 12.150s. Its yaw is nearly fixed, so changing-yaw proof comes from the exact **64-case** regression, not this natural sequence.

Coverage is **six of seven categories** on the rendered client: move, catch, jump, pass, tackle and dunk. **Completed shot is false**; charged attempts were disrupted and must not be counted as completed throws. The second client records two throws; the offline final recording separately includes four local throws. This is complementary coverage, not seven-category coverage on one rendered client.

All eight sampled deck departures are upward kickoff launches. **No natural walking exit occurred**, so the repaired deck-edge walk-off is supported by the exact **27-case compressed-packet regression**, not a claim that this movie reproduced it. The maximum logged camera step is 2.354m at telemetry 52.7s during kickoff ascent and automated yaw; the corresponding captured neighborhood shows that transition. The maximum dunk-camera step is 0.154m. Sampled telemetry, snapshot delivery and JPEG readback timing do not establish zero jitter or a causal performance improvement.

[Full integrity verification](../build/crown-court-evidence/v10-release-room/INTEGRITY-REVIEW.json) passes: movie SHA256 **`ECA323E952987C2CF67D1D0E647804BDD1CDC0A88F93CD57B239456262E985A3`**, exact executable identity and complete video decode exit 0 with an empty error log. There are **1,311 source captures over 119.264s**, encoded as 1,312 frames including the terminal repeat, with a 119.400s container duration. This JPEG-derived movie has **no audio stream**; numeric audio evidence is from the final offline movie only, with no listening/taste claim. All final raw JPEGs remain retained.

**Final recommendation:** the replacement package may proceed to local packaging within this tested scope. No additional blocker was found in the completed final recordings. Keep the old held evidence and the explicit coverage limits. This is automated normal-input play over local loopback relay, not a human fun assessment, physical-controller session, three-household-PC test or public Internet deployment.

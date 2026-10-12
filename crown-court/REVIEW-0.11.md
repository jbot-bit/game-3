# Independent release review, 0.11

**No reproduced simulation, input or network release blocker remains in the reviewed evidence.** Two concrete review findings were repaired and independently reproduced as fixed: a returning bot now discards its pre-human cached shot and begins a fresh reaction/wind-up; a changed authoritative possession timestamp cancels an old human charge even when missed intermediate snapshots leave the same visible owner. The review made no production edits.

The exact recorded executable is `build/crown-court-0.11.0/CrownCourt.exe`, SHA256 `05ED54AA59FC683867985CF8494CC9C81069FD750A931EE1CFD3BC0DA19321E9`. Native footage, telemetry and controlled probes establish local automated behavior; they do not establish household enjoyment, physical controllers, second-PC compatibility or real cross-home connectivity.

## Completed match inspection

| Evidence | Recorded outcome | Independently inspected scope |
| --- | --- | --- |
| Offline versus Easy bots | 7–0, seven accepted dunks, six throws, one correct reward bag | Seventeen extracted event frames and three contact sheets: released shot/flight, basket approach and slam/score, double jump, local tackle, received knockback/roll/recovery and actual result panel. |
| Three-human room versus Easy bots | All peers agree 4–0 and one correct bag; viewed client receives 2,307 snapshots | Fourteen selected retained frames, bounded adjacent event frames and contact sheets: passing, shot attempts, real dunks, kickoff flight, ordinary-shot score, goal approaches and actual result panel. Zero focus recoveries; all seven action categories occur in telemetry. |

Offline evidence is in `build/crown-court-evidence/v11-release-match/`; selections and source digests are in `review-arena-events/frames.json`. Room evidence is in `build/crown-court-evidence/v11-release-room/`, with original `view/frames/`, capture timestamps and selected-frame references in `review-arena-events/`. Original videos and frames were preserved. The room video is a montage of real-time native captures requested at 8 fps, with no audio; it is not a continuous high-frame-rate motion or audio review. Its monotonic capture clock and the telemetry physics clock are distinct, so selected-frame event labels are approximate and checked against visible HUD/action states. The root's full room-video decode passed with no errors.

## Camera and visibility observations

- The offline recording has six paused/focus recovery observations and three actual `focus_resume` actions. It also shows abrupt yaw changes around telemetry 54.48–54.72 s. The largest non-reset camera step is 3.863 m while player movement in that cluster is at most 0.064 m, with no dunk or stun. Recorded yaw changes of 0.3216 and 0.312 radians exceed the driver's nominal 0.06-radian per-tick steering cap. The pixels show an orbit/tilt around an airborne carried-ball player. Extra input/focus interference is plausible, but the recording lacks exact input-event and pitch provenance; this does not reproduce a game-physics defect.
- Seven large offline camera cuts accompany score/kickoff reset transitions. They must not be presented as spontaneous live-play camera warps. The recorded maximum consecutive dunk player step is 0.207 m; its camera step is 1.886 m.
- The room's largest camera step is 2.944 m during changing look direction and a kickoff launch, with approximately 27 m/s player velocity. Its maximum 1.708 m authoritative player delta is a snapshot advance, not a measured single-step motor teleport. The consecutive dunk camera maximum is 0.572 m. The inspected launch/dunk pixels do not reproduce an authority/ball/body discontinuity.
- **A real transient scenery visibility limit remains:** room capture time 82.993 s places the camera within foreground stadium/crowd geometry near a goal and obscures much of the playfield. Adjacent retained frames at 82.719 and 83.127 s show its approach/departure; 83.378 s is clear and the following ordinary-shot score appears at 83.666 s. Telemetry in the corresponding goal orbit includes camera positions beyond Z −56. This is scenery/crowd occlusion, not an identified Giant opponent or ball-physics fault. The fixed nine-view clearance gate does not prove unobstructed visibility at every natural camera position. No score or control failure was established from this transient view.

## Other evidence and limits

The shared terrain probe passes 15 checks; native arena clearance passes 37 checks with actual instanced transforms; native pose probes pass 45 checks. Inspected reference and native images, analytic layout, source hashes and Game Development Studio CPU-import comparison are documented in ARENA-0.11.md. The sealed comparison matches all nine cameras/images and verifies their artifact digests; threshold-0 raster changes are not causal, quality, GPU-performance or human-review proof.

Root integration reports the frozen 57-file production manifest unchanged, all 52 embedded suites passing, and room application/UI/power/impaired-transport gates passing. The room UI now has 84 successful assertions; an older wrapper expecting 81 was obsolete after three difficulty-control assertions were added. These coordinated receipts remain separate from the independent pixel inspection above.

Easy automated wins demonstrate completed game/reward flows, not balanced difficulty or human fun. This local room uses an owned loopback WebSocket relay; it does not establish public relay availability or cross-home play. The user declined hosting, and no hosting deployment is part of this review. Physical controller and household/second-PC checks remain user-side evidence.

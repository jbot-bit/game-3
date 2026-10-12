# Crown Court 0.7.0 verification

Windows, 12 October 2026. Godot 4.7.2 Compatibility renderer. Previous packages and sibling games are preserved. The previous published report is VERIFICATION-0.5.0.md; 0.6 was retained as a development baseline when further user feedback arrived.

Exact executable SHA256: `1BCC8ADFF6ABFCD685F670EB9578A11EF55045B4C5DA5D406D093587098CF232`. Windows FileVersion is 0.7.0.0 and ProductVersion is 0.7.0. Evidence paths below are relative to ../build/crown-court-evidence/. All release receipts use v7-release. A local package is not a public internet deployment: internet.cfg remains blank.

## Movement, ball and audio changes

REFERENCE-0.7.md records newly sampled actual Crown Jam gameplay and the limits of that comparison. No input telemetry or proprietary numerical physics was recovered. The requested direction-change commitment is implemented as authored ground traction: first-tick response, .383 seconds to 90% speed, .417 seconds to stop the previous direction during a full reversal, and 1.806 metres of skid. Diagonal and cardinal motion now agree. Local client prediction shares the same integration and passes current intent and predicted velocity to the animation immediately.

The renderer keeps the feet working through zero speed and adds braking lean. A nearby catch previously snapped 1.309 metres; the new 100 ms shared ball/hand gather begins without that jump. Giant reach is covered separately (previously 3.710 metres of immediate jump). Quick releases, resets and large relocations remain explicit cases. Native before/after footage and actual-Sim reversal video were inspected. A brief self-occlusion during the Giant lift remains visible from one rear angle; the ball returns to visible overhead carry.

A production receive-state reproduction exposed a .2667-metre backward correction of a forward-flying ball. Bounded render-only correction removes it, including a separate 200 ms starvation case. Normal periodic ballistic delivery gains under .000002 metres of error in the isolated probe. Ownership, resets and large relocations clear correction. Tests compare untouched authoritative snapshots. This is a specific discontinuity repair, not a whole-match smoothness guarantee.

The sound bank now uses 21 short CC0 samples with documented sources and transformations, quieter movement, variations and cooldowns. A native 7.9-second diagnostic recorded 26 real playbacks with nonzero PCM and no clipping (peak -11.392 dBFS). It also exercised actual keyboard reversal and the HUD-to-skid/step path. Headless tests cover file integrity/routing; they are not substituted for rendered playback or human listening. See REVIEW-0.7.md and LICENSES/Audio-CC0.txt.

Game Development Studio 1.5 sealed the native before/after images for CPU verification and comparison in v7-world-feel-cli. The captures came from actual Godot rendering; importing them does not create another GPU run. The installed CLI has no WAV inspection/admission path, so audio uses ffmpeg decoding, a closed manifest, PCM measurements and hash verification instead.

## Exact-pack checks

The complete build pipeline passed source checks, export, repeated embedded-pack checks, rendered input/audio/controller checks and a separate actual-executable startup. No warning/error logs occurred in that pipeline. Full logs and v7-release-playtest-results.json bind the results to the executable above.

Focused embedded-pack checks include:
- Simulation 58; existing feel 18; reference feel 15.
- Team play 33, including mirrored pressure passes, active/passive catch credit and pass eligibility.
- Ground traction 10; ball continuity 10; client ground prediction 8; independent rig integration 6.
- World feel 13; world polish 8; feedback 9; headless result/presentation 9.
- Audio sample/routing 33; native concurrent playback and keyboard motion 10.
- Profiles 23; snapshot transport 21; endpoint validation 38.
- Mixed inputs 16; rendered controller/menu flow 63; rendered input 18.
- Application, rewards, sessions, deck prediction, mirrored kickoff, adversarial network actions and a continuous spawn-to-boost-to-dunk route.

Three complete autonomous simulations ended naturally: co-op 0-4, remapped custom 3v3 8-4, free-for-all 3-7-6. Both team sides made and received passes across the roster set. One shutout ended before Blue passed; no result or possession was awarded to force distribution. These runs do not establish competitive balance.

Controller coverage uses parsed joypad events and injected discovery, including mixed labels, deadzones, neutral rearming, charge/release, disconnect, wardrobe and rematch. Physical controllers were not connected for this test; the user deferred that check.

## Room application

Exact-pack room application integration passed 25 checks and rendered UI passed 81. Four native UI states were checked for layout: unavailable service, configured service, controller keyboard and custom teams. The fixture includes private registration, three peers, full-room rejection, real inputs/snapshots, result/reward/rematch transitions, leave/rejoin and host closure. It is separate from a natural recorded match.

Receipt: v7-release-room-application/verification.json. The released configuration has no public endpoint. No hosting account, router or firewall settings were changed.

## Network and recorded-match closeout

The independent exact-pack network suite passed eight LAN configurations (22 peer reports), eleven physical action checkpoints on each of three peers, impaired ENet actions/load/timeout, six raw relay checks, three room-RPC checks and three stalled-TCP checks. Eighty audited logs contain no warning/error lines; executable identity remained unchanged. The LAN matrix uses controlled result/reward/rematch fixtures, while the action tests use positioned players and real physics/input/RPC. These fixtures are separate from the natural recordings. Receipt: v7-release-network-suite.json.

The impaired ENet path applies 50 +/- 10 ms per direction and 1% packet loss. The saturated snapshot test still observed a 525 ms worst client gap; typical intervals were around 50 ms. An intentional 1.2-second TCP stall produced a 1.217-second snapshot gap and 1.392-second action round trip, with bounded queued updates and successful rejoin. These are retained limitations, not a claim of uninterrupted motion. All owned test ports were released.

The final natural room match used three distinct human seats driven by normal input events against three bots. It ended 6-2; all peers agreed on the match identity, winner and exactly one earned bag each. There were no score/possession/state fixture mutations or focus recoveries. The joining client caught, passed, shot, jumped, tackled and dunked. The complete 106.92-second video decoded cleanly, and independent frame review covered charge/release, pass-to-catch, contested dunk, scoring and the result screen. See v7-release-room/FOOTAGE-REVIEW.md and recording.json. Video SHA256: B726CCA6DBDE52EED1BD0A4C63B9195635CFDB691AF648561683352296C3CEFB.

Room capture samples roughly eleven frames per second and has no audio stream; it cannot establish 60 fps smoothness or listening quality. The largest 1.553 m player snapshot step coincides with a booster launch. A retained 1.520 m camera transition combines kickoff ascent and driver yaw; the exact maximum 1.592 m event lacks sufficient retained context to classify. Dunk camera/player maxima were .469/.381 m. No whole-match ball-position trace exists, so separate production-packet regressions support the specific correction repair.

The separate fixed-60-fps free-for-all completed naturally at 6-7-4 after 172.917 game seconds. The local loss correctly awarded zero bags. It used two active opponents and normal input, with no state/score/possession fixtures. Two focus recoveries are retained in the receipt. Passing is unavailable in free-for-all, so its pass-coverage flag is correctly false. The complete 173.367-second, 10,402-frame movie decoded without errors; sampled catch/dunk and full-flow frames show the progression and matching result screen. Fixed-clock recording is not a real-time performance test. Video SHA256: 8CE6E2DF57BB98D0DD58FE97F9DA4B54A6DDFDC0F416B7DE141E76ECD99C1DFE.

Native match PCM contains nonzero audio for 36.85% of samples, with absolute peak .111969 and no full-scale clipped samples. That proves real output and headroom, not human preference or listening quality. The only recorder diagnostic was the low-free-disk advisory; the completed AVI and MP4 were preserved and decoded successfully. Receipts and review frames are in v7-release-match/; independent observations are in REVIEW.md and review-integrity.json.

## Packaging and remaining playtest

Packaging checks the unchanged production and audio source manifest, exact executable identities, native controller/audio/input receipts, complete natural recordings, video hashes, all network gates, and fresh ZIP extraction with native startup. The successful archive/extraction receipt belongs at v7-release-release-results.json.

Actual mixed controllers, physical two/three-PC play, separate-home connectivity, long-session smoothness and whether these controls/sounds feel right still require human play. The room transport is implemented locally; no-extra-app internet play needs an approved public WSS deployment and a real external connection test. TCP head-of-line stalls and the earlier unexplained host scheduling gap are not claimed resolved by these presentation fixes.

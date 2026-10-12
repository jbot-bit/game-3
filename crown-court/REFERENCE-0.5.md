# Crown Jam comparison for Crown Court 0.5

Research: 2026-10-11. Baseline: the released **0.4.0** recording, not the concurrently changing 0.5 source. Recommendations below were sent to the implementation owners; their presence in later source is not independent verification of the resulting feel.

## Evidence and limits

This pass reopened and decoded the actual long-form player recordings, not the trailer:

- [Raks — Game 1, No Commentary](https://www.youtube.com/watch?v=4IdjAgwrwgc), 3:12.261, decoded at 1280×720. New samples cover kickoff 1:20–1:34, jump/dunk 2:00.4–2:05.5, and a second dunk 2:39.5–2:44.0.
- [Tocanscenes — Unreal Rank Gameplay](https://www.youtube.com/watch?v=ZU24J-EkOVQ), 5:40.761, decoded at 1280×720. New samples cover catch/pass 2:29–2:39 and airborne interception 4:03.8–4:06.5.

Browser playback was available through Playwright. The analysis uses timestamped decoded frames and the earlier full-match contact sheets described in [REFERENCE.md](REFERENCE.md). This is **sampled visual analysis**, not continuous human viewing, an original-game play session, recorded controller inputs, or recovered engine code. No source video was found downloaded locally. Native computer inspection still failed with `helper_unknown_error`; browser video decoding worked.

New evidence, with source timestamps printed on each tile:

- [Kickoff](reference/v5-raks-kickoff.png)
- [Ordinary jump and first dunk](reference/v5-raks-jump-dunk.png)
- [Second dunk](reference/v5-raks-dunk-two.png)
- [Catch and pass](reference/v5-toc-catch-pass.png)
- [Pass flight and receipt](reference/v5-toc-pass-flight.png)
- [Airborne catch](reference/v5-toc-aircatch.png)

The 0.4 comparison uses [recording.json](../build/crown-court-evidence/v4-network-recorded/recording.json), [active-play.json](../build/crown-court-evidence/v4-network-recorded/view/active-play.json), and sampled recorded frames. EXE SHA256: `892503559A4F8820FF072BE9A0A6DDAB800B8784C1B57DD743EB552050A7E1D5`. Video SHA256: `EB2DF812487D311EC3F9BED3FDECBF91808CDA50C892093738FC323A5B7F86F1`. The three local processes agree on the natural 5–1 result and one bag each. This establishes local automated network behavior, not physical controller or internet play.

## Three high-confidence differences

### 1. Replace the grounded kickoff with a raised launch entry

**Observed:** Raks 1:21–1:23 places the team on a three-position rear deck; 1:24–1:26 is airborne entry, with landing near midfield around 1:26.5–1:27. The [official overhead image](https://cdn2.unrealengine.com/fnfg-39-30-pimlico-screenshot3-blog-1920x1080-1920x1080-36a098a872ab.jpg) places those decks above/behind the hoops. The [Epic gameplay article](https://store.epicgames.com/news/fall-guys-crown-jam-slams-into-fortnite?lang=en-US) explicitly describes entering the court from above.

**0.4:** `spawn_players()` places players grounded at z=±24 with zero velocity. The resulting opening is a ground run, visibly different from the source's launch-and-contest rhythm.

**Recommended authored approximation:** A rear deck beyond each hoop, three positions across, and a GO launch toward midfield. The proposed z=±34, y=7.5, width 14 / depth 3 and 22-up/14-forward impulse are implementation choices, not measured Crown Jam dimensions. With local gravity 20, that initial height/vertical speed gives roughly 2.5 seconds to the base floor before steering, terrain or extra jump. Keep the playable space beneath the deck separate from terrain height so it does not raise the floor around the basket. Validate the entire post-score restart, not just initial spawn.

### 2. Give the dunk a longer, readable windup

**Observed:** First source dunk: rise/roll 2:03.8–2:04.1; suspended windup through about 2:04.6; downward slam around 2:04.9–2:05.2; score burst about 2:05.5. The second repeats the hold at 2:40.7–2:41.3, downward streak at 2:41.6, and body follow-through at 2:41.9. These support a roughly 0.5–0.7-second visible hold. The DUNK prompt does not identify the exact button-press frame.

**0.4:** The base duration is 1.25 seconds. Reach occupies 58%, hold 22% (=0.275 seconds), release starts at 80%. Actual joining-client dunk-to-score event intervals are 13.30→14.3667, 47.80→48.85, and 66.45→67.50 seconds: about 1.05–1.07 seconds. These are telemetry intervals, not source-video timestamps. The local dunk presents its vulnerability and anticipation much more briefly.

**Recommended authored approximation:** Start with a 1.5-second base action and about 0.6-second hold, then compare rendered phases. Preserve incoming motion, a separate dunk button, tackles interrupting the windup, physical downward scoring, and follow-through before kickoff. Do not claim that 1.5 seconds is a recovered internal constant or derive action length simply from prompt-to-burst time. Avoid extending only the ascent, which would miss the visible difference.

### 3. Make a pass legible throughout its flight

**Observed:** Tocanscenes releases a pass around 2:34.8; a conspicuous yellow trail follows its arcing flight, and PASS/Hype confirmation appears at 2:37.75. Target brackets and teammate request markers are visible. This one long pass lasts about three seconds from release to confirmation; it is not a calibrated distance/speed test.

**0.4:** Passes are ballistic, selected using aim alignment and distance, with receiver lead and a 0.3–1.5-second flight clamp. The renderer has the aiming preview and power-orb trails, but lacked a persistent ordinary pass trail at the start of this review. That makes the ball harder to follow after release even when the underlying pass succeeds.

**Recommended authored approximation:** Add a short yellow ribbon from actual rendered ball history, cleared on catch/score/reset. Do not draw a guaranteed future path or apply steering solely to imitate a curved image. Preserve interception. Consider the long-pass duration cap only after a comparable local long-pass capture; one uncalibrated source pass does not justify slowing every pass. A trail implementation was already landing during this review; candidate validation belongs to its owner.

## Jump, camera, catch and shooting: retain what is supported

| Loop element | Source evidence | 0.4 comparison and decision |
|---|---|---|
| Ordinary jump | Raks 2:00.4–2:02.0 contains a grounded approach, takeoff around 2:00.9–2:01.0 and landing around 2:02.0. No isolated second input is established. | Prior 60 Hz probe retained in REFERENCE.md reports 1.20 s airtime, 3.62-unit apex for impulse 12.2 / gravity 20. This is already near the sampled source duration. Do not retune gravity based on the earlier withdrawn double-jump interpretation. |
| Extra jump / launch | Footage establishes airborne action but does not isolate input, initial velocity and floor height sufficiently to recover an impulse. Kickoff flight is a distinct sequence. | Double jump uses max(11.5,current upward velocity+2.2); side pads use 26 up / 18 forward. These remain authored. Preserve boost momentum; do not use the kickoff sample as proof that every side pad should have the same launch. |
| Ordinary camera | Native Raks 1:28 gives roughly 100–110px bean height in 720 px, feet at about 67–68% of frame height. | Local frame 000063 gives approximately 110–120px in 800 px, feet around 66–67%. These rough hand estimates are close. Keep the 7.8 boom/72° baseline pending matched rendered comparisons; the source FOV is unknown. Costumes, perspective and pitch limit this comparison. |
| Air catch | Tocanscenes 4:04.6 exposes CATCH;4:04.8–4:05.0 shows contact/roll and STEAL feedback while airborne. | Local active catch already has a 0.32 s window and 2.35-unit center radius. The source prompt does not measure its input window or prove held-ball stripping. Do not replace the existing rule with an automatic-pickup-only design. |
| Pass reception | The source exposes contextual catch and successful pass feedback, but no input overlay. | Local designated receivers can automatically catch within 1.5 units. Whether the source does that is still unknown; changing it requires better evidence or an explicit design choice. |
| Near-rim view | Tocanscenes 4:05.4–4:05.6 shows obstructing goal geometry becoming transparent. | Local world code already has goal-occlusion handling. Keep it in the candidate review, particularly with new rear decks; do not report it as a newly missing feature. |
| Shooting | Existing tutorial evidence shows a curved charge indicator and aiming arc; it is not an uncut player shot. | 0.4 already has overcharge, a red preview and overshoot. Safe charges within 22 units/aim dot > .92 solve an assisted hoop arc. Exact original accuracy is unverified. Joining-view shot coverage in the 0.4 full-match recording is false despite two release attempts; dedicated action tests establish functionality, not reference-equivalent shooting feel. |

All current court dimensions, radii, impulses, charge curves and camera response rates are authored. [Team Fall Guys' announcement](https://www.fallguys.com/news/the-beans-slam-dunk-in-fortnite-for-a-limited-time-crown-jam) describes the mode and physical action, but publishes no numerical physics or camera specification.

## Tool use and next comparison

Game Development Studio 1.5.0 was found at the existing local installation; capabilities and doctor returned successfully. Its current project adapter imports previously recorded 0.3 world-regression images into sealed CPU evidence. That is useful provenance, not a way to recover Crown Jam physics. No provider spending, asset generation, new GPU run, installation, upload or deployment was performed for this research.

Next prompt: “Record the 0.5 kickoff, ordinary jump, long pass, airborne catch and interruptible dunk with actual inputs. Compare the timestamps and framing against REFERENCE-0.5.md, retain only changes supported by that comparison, and validate mixed controllers and no-extra-app internet separately.”

## 0.5 candidate review

The implemented changes use authored values guided by the observations above. They do not reproduce measured internal Crown Jam constants.

- **Kickoff:** The team modes now start on a 14 × 3-unit one-way deck at z ±34, y 7.5, then launch at GO with 22 units/s upward and 14 units/s towards midfield. The extra jump remains available. The ordinary jump and the free-for-all ground start remain unchanged. The current 60 Hz `reference_feel.gd` log reports 2.6667 seconds of airborne entry **with the early extra jump used by that probe**; this is not a measurement of an unassisted launch.
- **Dunk:** The base action is now 1.5 seconds. Its declared reach ends at phase 0.4 and release begins at phase 0.8, giving a 0.6-second declared hold. The current probe measures release at 1.2167 seconds and 0.7333 seconds within 0.15 units of the target while still holding the ball. The latter is a geometric dwell measurement that includes the end of the approach; it is not a second animation-phase duration. Normal and Giant tackles interrupt the sampled ascent, hold and late windup. The owner-run matrix records 288 cases with no failures and six successful interruption cases.
- **Pass:** The yellow ribbon now follows sampled ball history and clears on catch. The eight-frame diagnostic asserts both visible pass history and clearing. No change to the flight cap is justified by the one uncalibrated reference pass.

Read-only review inspected all eight PNGs in `../build/crown-court-evidence/v5-reference-final/`. The first candidate, kept separately in `v5-reference-render/`, exposed coplanar deck stripes and an overextended dunk arm. The revised deck face is clean. The revised dunk raises the curled body and reduces the vertical hand reach, bringing the body closer to the ball/rim arrangement in Raks 2:04.1–2:04.6. The windup remains an approximation; the source uses a different character rig and more pronounced squash, roll and effects. The local name label partly overlaps the ball in the sampled near-rim angle, but possession, rim and release remain identifiable. The pass ribbon stands out against the court without drawing a guaranteed future route.

No new blocking visual defect was found in those diagnostic stills. They are controlled fixtures, not a complete input-driven match, and cannot establish animation smoothness between samples or competitive balance. A subsequent late-join simulation fix changed the Sim hash after this capture; its original images and result hashes remain historical evidence, never relabelled as the later source. A fresh release capture and its CPU seal are recorded below when available.

The reviewed timing and regression receipts are `../build/crown-court-evidence/v5-final-source-reference_feel.stdout.log`, `v5-pose-dunk-matrix.stdout.log`, and `v5-pose-dunk-interruption.stdout.log`. The matrix/interruption runs precede the separate late-join fix; they establish the pose implementation at the time of those runs.

### Mixed-controller and room integration boundary

Read-only review of `main.gd` and `tests/controller_mix.gd` found no additional blocker in the mixed-device changes. Label substitution uses placeholders so Nintendo face-button names do not cascade through later replacements; unknown pads receive physical-position labels. Rebinding/disconnection preserves a physically held keyboard action, and the restored key releases normally. Mouse-to-trigger handoff preserves an existing charge until both inputs release, firing once. The retained `controller-mix-after/controller-mix-result.json` reports 16 passing checks using parsed input events and injected device discovery. This is not physical-controller verification.

Read-only room transport review covered `room_peer.gd`, `relay/server.mjs`, and the corresponding menu/session integration. Client routing is host-only, sender identity is checked, slow queues are bounded, and departed-sender packets are removed before peer-disconnect notification. The transport carries channel metadata over WebSocket/TCP; independent UDP channel latency is not implied. Local relay tests do not prove a reachable public service. The menu correctly reports rooms unavailable when no endpoint is configured.

### Fresh release capture and sealed CPU receipt — 2026-10-12

The owner regenerated all eight images in `../build/crown-court-evidence/v5-reference-release/` after the late-join correction. All eight were inspected again. Their PNG bytes are identical to the reviewed final-pose capture, so the visual findings above still apply. The fresh result and original stdout agree exactly; all four fixture checks pass, with no reported failures and empty native stderr.

The importer checked each original PNG hash and both current source hashes before admitting any capture artifacts:

- Sim: `b112426bca85c671a5e68d4aa224c96be78421fbaf269cf76124e6688111a5fb`
- World: `85dc26ff981cd7f3b06e1d74524958b74b34c97c450fa179865eae78ee36e842`
- Original result JSON: `e3414657e4b4c9da137ba254f357ca27caffc235fd3960a34515573a2c4890e2`

Game Development Studio 1.5.0 completed `import-reference-review` using only the declared CPU/project-write capabilities. The successful closed run is [.game-dev/evidence/.game-dev/runs/run_1791727570274_00c8c7888c964052966d46123e4d457d](.game-dev/evidence/.game-dev/runs/run_1791727570274_00c8c7888c964052966d46123e4d457d/run.json). Its run-manifest SHA-256 is `43ec33bb62f59521c4e65db32217aadac5aecc0f7670615fc0a13d446b20ff87`.

[Run receipt](.game-dev/reference-release-run-v2-receipt.json), [verification receipt](.game-dev/reference-release-verify-receipt.json), and [analysis receipt](.game-dev/reference-release-analyze-receipt.json) each return `ok: true`. Verification confirms all hashes and the closed artifact roster. Analysis decodes all eight 1280 × 800 color rasters. The three attached JSON files contain metrics, native logs and source provenance; raster analysis reports them as unsupported non-raster attachments, while bundle verification still hashes and preserves them.

The first import attempt is preserved in `reference-release-run-receipt.json` and sealed failed run `run_1791727516140_921a557debe24a5aaa912afe83afa34a`. Its image/source/log checks passed, but the capture schema rejected the importer's unsupported `sum` aggregation label. Only that adapter telemetry label changed to `sample`; the successful rerun uses a new run ID and leaves the failed bundle untouched.

This seal proves source/image/log consistency and retained raster bytes. It does not execute a new GPU render, recover original-game physics, measure hardware performance, or establish full-match play quality. The original capture did not record the probe executable hash; none is inferred. No reference-game raster metric comparison was attempted because the scene, assets and camera controls are not equivalent.

# Crown Jam gameplay reference

Research date: 2026-10-11. This document records public gameplay observations for Crown Court. It does not contain extracted game code or runtime assets. Exact physics constants, collision shapes, animation curves, camera parameters and network behavior remain unknown. `CONTRACT.md` describes the local code interface; its initial dimensions are not reference measurements.

## Evidence status and coverage

- **OFFICIAL:** explicit developer material.
- **OBSERVED:** visible in decoded frames of the identified public gameplay video.
- **REPORTED:** an external description, distinguished from our own observation.
- **INFERENCE:** an interpretation consistent with footage, not uniquely established.
- **TUNING CHOICE:** our authored implementation, never an alleged recovered constant.

Actual gameplay was played in the browser and inspected through decoded frame sequences. This was not limited to the promotional trailer. The review sampled two complete match recordings every five seconds, then sampled catch/pass and dunk/jump sequences every 0.25 or 0.1 seconds. It was not an interactive session with the original game, an input recording, or a calibrated physics measurement.

| Primary footage | Inspected coverage | Local evidence |
| --- | --- | --- |
| [Tocanscenes: Fall Guys Crown Jam Unreal Rank Gameplay](https://www.youtube.com/watch?v=ZU24J-EkOVQ) | 0:00-5:40; full match from kickoff through 5-1 result; dense 2:26-2:37.75 and 4:04-4:07.75 | `reference/fullmatch-0.png` through `fullmatch-4.png`; `action-146.png`, `action-150.png`, `action-154.png`, `action-244.png` |
| [Raks: Fall Guys - Crown Jam - Game 1 - No Commentary](https://www.youtube.com/watch?v=4IdjAgwrwgc) | 0:00-3:10; setup, match from about 1:03, and 4-0 result; dense 1:59.8-2:06.1 | `reference/raks-match-0.png` through `raks-match-2.png`; `raks-dunk-0.png` through `raks-dunk-3.png` |

Raks 0:00-0:23 contains the game's tutorial montage before the match. Its shooting meter is useful UI evidence but must not be described as an uncut player shot. The subsequent match is the action reference. The official trailer was also decoded successfully after an initial browser failure, but gameplay above takes precedence. Files prefixed `trailer-` are promotional evidence only. All reference images are for local analysis, not shipping game assets.

## Rules and match structure

**OFFICIAL:** Three-versus-three basketball-like play includes carrying, throwing, passing, tackling and dunking. Five-minute matches include Hype abilities, side bounce pads, raised/dipped routes and rotating hazards. Hype can be earned through tackles, passes, assists and scores. The abilities are giant form, a deployable launch pad and a disruptive homing projectile. [Epic gameplay article](https://store.epicgames.com/news/fall-guys-crown-jam-slams-into-fortnite?lang=en-US); [Fall Guys announcement](https://www.fallguys.com/news/the-beans-slam-dunk-in-fortnite-for-a-limited-time-crown-jam).

**OBSERVED:** Both recordings use a five-minute clock. Every observed basket, including Raks's local-player dunks, adds one point. There is no observed two/three-point distance scoring. The first recording ends 5-1 with time left; this alone cannot distinguish a four-point mercy rule from first-to-five. Raks ends 4-0 with about 3:48 remaining, then displays YOU WIN and 4-0 VICTORY at 2:45-3:00. Together the recordings strongly corroborate a four-point lead ending the match.

**REPORTED:** The [Fortnite.GG mirror of the island description](https://fortnite.gg/island/5288-2880-3821/info) explicitly says games last five minutes or finish at a four-point lead. The official island page could not be fetched by the web reader. Thus the written rule is mirror-reported, supported by observed 4-0 and 5-1 endings. Overtime behavior remains unobserved in these matches.

**OBSERVED:** A score produces a large team-colored explosion and scorer banner, interrupts the clock, then resets teams to their launch positions with a ready/start presentation. Players start on raised court terrain facing the enemy basket. Hoops carry green attack/check and red own-hoop/X indicators; the attack hoop also has a tall white beacon. Match stats include goals, assists, passes, steals, tackles and Hype.

## Inputs and possession

The following are visible recorder bindings, not proof that every platform/user has identical defaults.

| Action | Keyboard/mouse HUD, Tocanscenes | PlayStation HUD, Raks | Status |
| --- | --- | --- | --- |
| Catch a nearby loose/incoming ball | Left mouse contextual CATCH | Not read clearly here | OBSERVED at 2:29.75 and 4:04.50 in first recording |
| Pass while holding ball | Left mouse | Square | OBSERVED |
| Shoot while holding ball | Right mouse | Hold R2 | OBSERVED |
| Tackle without ball | Right mouse | R2 appears in HUD; partially occluded in saved dunk frame | OBSERVED; controller also corroborated by guide |
| Dunk | Not established in keyboard footage | Circle, contextual DUNK | OBSERVED at Raks 2:03.70 |
| Ball camera | Ctrl | L1 | OBSERVED |
| Request pass | Middle mouse glyph | R3 appears in HUD; partly occluded by request icon | OBSERVED with controller reading qualified |
| Hype | Q | Triangle | Keyboard OBSERVED; controller REPORTED |
| Jump, sprint, movement/look | Exact bindings not recorded | Exact bindings not recorded | UNKNOWN bindings; movement/jumps visible |

Enlarged evidence: `controls-149.75.png`, `controls-244.5.png`, `raks-detail-123.7.png`. The mouse icon has its left or right half highlighted, allowing catch/pass versus tackle/shoot to be distinguished. Initial low-resolution interpretation as a persistent GRAB BALL line was incorrect: the regular HUD says WITH BALL PASS and WITH BALL SHOOT, while CATCH is contextual.

**OBSERVED:** A CATCH prompt appears as the loose ball approaches the player, followed by possession at the kickoff around 2:30 and an airborne STEAL around 4:05. A short catch/spin body action is visible in the dense sequence. The visible prompt establishes an active catch action. These recordings have no input overlay, so they do not prove whether passive collision can ever pick up the ball.

**REPORTED corroboration:** A [first-hand grab guide](https://simplegameguide.com/how-to-steal-and-grab-the-ball-in-crown-jam/) describes a short-radius spin catch timed against loose balls, passes and shots. Its keyboard binding is described as usual, not immutable. Do not invent an automatic-pickup-only design or an exact catch radius from this source.

**OBSERVED:** The carried ball is large, roughly body width, and held above/in front of the head with hands reaching to it. It is not a low waist carry. The player runs, changes direction and jumps while retaining it. No dribbling cycle is visible.

**OBSERVED:** Pass-target brackets and PASS labels appear over teammates. Around 2:32 a teammate displays a raised-hand request icon. Around 2:34.75-2:35 the carrier sends a conspicuous curved yellow pass toward a distant teammate; a PASS/Hype reward follows around 2:37.75. This supports explicit targeting and request communication. Whether target choice is by aim, cycling, assistance or another exact algorithm is not established; nearest-teammate-only is not a recovered rule.

## Jump and dunk: dense observed sequence

Raks 1:59.8-2:06.1 is sampled at 0.1-second intervals in `raks-dunk-0.png` through `raks-dunk-3.png`.

| Source time | Visible event |
| --- | --- |
| About 2:00.5 | Ball carrier is airborne above the grass after a small takeoff. |
| About 2:01.0 | A fresh midair puff accompanies renewed upward movement, consistent with the double jump reported elsewhere. |
| About 2:02.0 | Player returns to ground level and keeps moving toward the hoop. |
| 2:03.3-2:03.6 | Player jumps during final hoop approach. |
| 2:03.7 | Circle DUNK appears while the body and carried ball are still below the rim. Hold R2 to shoot remains independently displayed. |
| 2:03.8-2:04.1 | Player accelerates/rolls upward toward the rim; the camera tracks the ascent. |
| 2:04.1-2:04.6 | Suspended windup, ball raised over rim, expanding yellow rings and green sparks. |
| 2:04.8-2:05.1 | Ball moves downward through the basket region with a strong yellow/green impact streak. |
| About 2:05.5 | Large team-colored basket burst; score subsequently becomes 3-0. |

**INFERENCE:** This is an assisted dunk ascent followed by a readable, delayed slam. The pre-dunk jump does not independently have to reach rim height. It is not merely an instant downward release from a generic airborne throw. The first hop/double-hop combination spans roughly 1.5 seconds in this instance, but exact input frames are unavailable. Perspective, moving camera and unknown world scale prevent reliable units-per-second, jump height, gravity or acceleration recovery from these samples. The sequence times are observation timestamps, not engine constants.

**OBSERVED:** A separate Circle DUNK remains available alongside R2 SHOOT. Automatically replacing every eligible near-hoop shot with a dunk is an implementation deviation unless intentionally offered as an optional assist. A second local dunk appears around Raks 2:40-2:42.

**REPORTED:** [Phil Owen's first-hand GameSpot guide](https://www.gamespot.com/gallery/how-to-get-all-free-fortnite-rewards-in-crown-jam-new-fall-guys-sports-mode/2900-7423/) describes hold/release shooting, overholding turning the arc red and degrading accuracy, and tackles interrupting dunks/shots. The exact interruption window and charge-time curve remain unknown.

## Shooting, camera, terrain and effects

**OBSERVED tutorial UI:** Raks 0:10 shows a curved meter beside the carrier, a green safe region with red at the upper end, a white meter indicator and a solid green ballistic arc to the hoop. See `raks-detail-10.png`. This does not establish perfect aim-lock, a charge duration or the launch equation.

**OBSERVED gameplay camera:** Third-person trailing view keeps the local body in the lower middle and looks ahead across the court. The view pitches upward during airborne action; the ball-camera control is exposed. Near-rim/backboard geometry becomes translucent when it would obscure the view in Tocanscenes around 1:50, 3:30 and 4:05. A fixed opaque backboard between camera and player loses this readability.

**OBSERVED terrain:** The court is not a flat enclosed rectangle. Rounded raised lanes, recessed grass, broad inclines at ends/sides, raised starts and obstacles create meaningful routes. The basket rim is substantially above standing-head height; a dunk lift and double jumps matter. Exact dimensions cannot be inferred from screen pixels without calibration. The [official overhead](https://cdn2.unrealengine.com/fnfg-39-30-pimlico-screenshot3-blog-1920x1080-1920x1080-36a098a872ab.jpg) and local `official-overhead.jpg` help establish topology, not playable timing.

**OBSERVED feedback:** Footstep/takeoff puffs, speed streaks, strong contact bursts, distinct airborne carry poses, a spin/roll during special movement, brief toppled tackle victims, trails for ball travel, hoops highlighted for attack/defense, action/Hype reward messages, expanding dunk rings, and a large score explosion all communicate mechanics. The ball remains large and easy to distinguish. Audio was not analyzed systematically; exact samples, mixes and timing are unknown.

**OBSERVED abilities UI:** Raks 0:35 shows three selectable abilities before the match: giant transformation, thrown launch pad, and a projectile that knocks other players over. A persistent circular Hype meter fills and becomes ready during gameplay. This is an explicit pre-match selection, not an observed fixed seat-to-power assignment. See `raks-detail-35.png`.

## Actionable implementation review

These are local implementation checks, not claims that similarity is already achieved. The code is changing concurrently, so verify current code before treating an item as unresolved.

1. Preserve active catch/pass versus tackle/shoot inputs, separate dunk, and a ball-camera toggle. Show contextual catch and dunk cues with current platform bindings.
2. Carry the large ball high with a credible hand pose; make possession, pass target and incoming-ball location visible from all client views.
3. Match the observed dunk phases: approach below rim, assisted rise, exposed windup, down-slam, impact, score/reset. Keep interruption possible. Avoid instant score credit or a teleported player.
4. Keep a time-sensitive shooting meter with distinct safe/overheld states if claiming reference parity. A permanently clamped charge meter and every aimed shot solving perfectly to the hoop do not reproduce the reported overcharge risk.
5. Use raised playable routes and end/side inclines, not only decorative ramps. Maintain coherent ball-floor normals and player landing/jump resets on those surfaces.
6. Implement one-point baskets, five-minute team matches and a four-point mercy lead. Free-for-all is a project adaptation, not a mode demonstrated by these sources.
7. Provide pre-match ability selection, understandable Hype accumulation/readiness, pass requests and teammate targeting. Seat-assigned powers are a local shortcut.
8. Compare a recorded local jump/dunk/catch sequence against the timestamped sheets before calling the feel equivalent. All speed, gravity, radii, response curves, cooldowns and durations in our code remain TUNING CHOICES until calibrated by a declared method.

Minimum hands-on check: move and reverse; jump/double jump; catch an incoming pass and rebound; shoot before/within/after the safe charge window; dunk from below rim and interrupt one; track the ball with camera toggle; recover from tackles; use each ability; score/reset; repeat on host plus two clients. Automated simulation and three local processes do not establish physical three-PC household play or human enjoyment.

## 2026-10-11 comparison appendix: larger court, jumping, camera and catches

This appendix records a second inspection of actual match footage and local simulation measurements. It supersedes the earlier ambiguous jump/input interpretations explicitly identified below. The videos remain public gameplay sources; no game files, assets or proprietary code were extracted.

### Corrections after inspecting native-resolution frames

- **OBSERVED correction:** Raks at 1:28 and 2:00.4 clearly displays **R1 PASS TO ME**. The earlier low-resolution R3 reading should not be used. L1 ball camera, R2 tackle/shoot, Square pass and Circle dunk remain visible.
- **UNKNOWN correction:** Raks 2:00.5–2:02.0 does not reliably establish a double jump. At native resolution the feet are essentially grounded at 2:00.4/2:00.5, with a clear takeoff puff around 2:01.0, apparent apex around 2:01.3–2:01.5, and landing around 2:02.0. This may be one ordinary jump, approximately 1.1–1.2 seconds airborne. Withdraw the earlier inference that this sequence measures a 1.5-second hop/double-hop combination. There is no input overlay, and no independently isolated second-jump input was established.
- **OBSERVED correction:** The long launch at Raks 1:23.5–1:26.5 starts from the elevated kickoff platform. It is not an isolated test of a flank launch pad. It demonstrates sustained forward travel during a launch, but cannot establish the exact impulse of every pad.
- **UNKNOWN:** Directional shadows, camera movement, perspective and terrain prevent a defensible original jump apex in world units or body heights from these particular sequences. Exact gravity, acceleration, double-jump impulse, FOV, camera distance and catch-window duration remain unknown.

Native evidence is in `reference/compare-raks-88.png`, `compare-raks-120.4.png`, `compare-raks-120.5.png`, `compare-raks-120.9.png`, `compare-raks-121.png`, `compare-raks-121.5.png` and `compare-raks-122.png`. Contact sheets `compare-route-0.png` through `compare-route-2.png` sample 1:20–1:43.5 every 0.5 seconds. The earlier `raks-dunk-*` sheets retain 0.1-second samples around the dunk sequence. [Raks actual match](https://www.youtube.com/watch?v=4IdjAgwrwgc).

### Court scale and travel

**MEASURED LOCAL, before changes:** The original local court was 24 × 44 units with a nominal 1.7-unit body: about 14.1 × 25.9 body heights. Hoops were 38 units apart. At full ground speed 9.5, 44 / 9.5 is 4.63 seconds; carrying at 94% speed makes this 4.93 seconds. These are ideal distance/speed calculations excluding acceleration, collisions, ramps and route changes. They explain the compressed space independently of an exact source measurement.

**TUNING CHOICE, current:** The revised local court is 40 × 72, approximately 23.5 × 42.4 body heights, with hoops 62 units apart. The corresponding ideal full-length run is 7.58 seconds unloaded or 8.06 carrying. Raised flank lanes lie near x = ±13, launch pads near z = ±18, and speed strips near midfield. This is an authored enlargement, not a recovered original court dimension.

**OBSERVED SOURCE:** The full match has long approach lanes, raised kickoff areas, banked ends/sides and elevated routes. In the sampled kickoff, GO appears around 1:23; launch begins around 1:23.5, flight continues through 1:26, landing is around 1:26.5, and movement continues to combat around 1:30.5. This is not an uninterrupted end-to-end crossing test. Neither that sequence nor the official overhead image provides calibrated original court dimensions. Rim height remains visibly above standing head height; the local 4.6 / 1.7 = 2.71 body-height rim is not independently contradicted by these oblique views.

### Jump and booster profiles measured in the local simulation

`reference/measure_local.gd` calls the real `Sim.action`, `move_input` and `step` methods. Current measurements use the authoritative **60 Hz** step. Apex is feet height above initial floor. Second jump occurs at the stated elapsed time. Horizontal travel is straight displacement at landing, not path length. The baseline was captured before the edits at **120 Hz** and is retained as historical evidence; small integration differences therefore must not be attributed to tuning. Baseline and revised pad positions also differ, with revised launches starting on a 1.25-unit flank lane. Terrain and landing location affect airtime.

| Profile | Baseline apex / airtime, 120 Hz | Current apex / airtime, 60 Hz | Current horizontal travel |
|---|---:|---:|---:|
| Ordinary jump, forward input from rest | 3.67 / 1.22 s | 3.62 / 1.20 s | 8.97 |
| Second jump at 0.50 s | 6.27 / 1.82 s | 6.73 / 1.90 s | 15.62 |
| Launch pad, forward steering | 8.03 / 1.80 s | 16.68 / 2.65 s | 46.43 |
| Pad plus second jump at 0.15 s | 5.05 / 1.38 s | 19.35 / 2.83 s | 49.30 |
| Pad, no steering after launch | 8.03 / 1.80 s | 16.68 / 2.65 s | 43.51 |

**MEASURED LOCAL:** The original early extra jump reduced upward velocity from 15.17 to 10.5, cutting the launch short. The revised action raises upward velocity from 23.33 to 25.53 in the 60 Hz test. This fixes a real loss of momentum. The ordinary jump impulse remains 12.2 with gravity 20; the delayed second jump uses 11.5; launch impulse is 26 upward and 18 along the route. Air acceleration/drag are distinct from ground acceleration/braking. Current apex times are 0.60 s ordinary, 1.07 s delayed second, 1.30 s pad, and 1.42 s early pad second.

**TUNING CHOICE:** The new pad apex is about 9.8 local body heights, or 11.4 with the early extra jump. This is a substantial launch. A roughly three-second source kickoff supports sustained flight qualitatively but does not prove this apex matches Crown Jam. Retain the distinction when describing similarity. Evidence: `compare-local-baseline.log`, `compare-local-after.log` (120 Hz revised check), `compare-local-after-60hz.log` (before added crosslanes), and `compare-local-final-60hz.log` (final authoritative-rate check). The new crosslanes near z = ±12 slightly shorten the ordinary test's landing time; they do not change its jump impulse or apex.

### Camera framing

**OBSERVED / PIXEL ESTIMATE:** Native 1280 × 720 Raks frames at 1:28 and 2:00.4 show a grounded bean, excluding its held ball, roughly 100–110 pixels tall (14–15% of image height), with feet around y = 480–490 (67–68% from the top). The near-rim Tocanscenes frames show substantially larger framing; the source view is not usefully summarized as one constant distance. Near-rim geometry becomes translucent when it obstructs the view.

**LOCAL COMPARISON:** The previous 12-unit, 70-degree camera with its target 1.7 above the feet and pitch about 0.43 projects a 1.7-unit body to roughly 63 pixels, with feet about y = 423, by ideal perspective calculation. That made the bean too small and too central relative to the ordinary grounded source frames. Revised code first used an 8.5-unit ordinary boom, subsequently tightened to 7.8 by the presentation owner, with 72-degree FOV and a forward target offset, expanding during boosts; ball-camera framing expands to contain both player and focus. Those are local choices. Rendered framing, camera collision, transparency and airborne tracking require a separate GPU/hands-on comparison; this research probe does not establish their visual quality, and a source FOV has not been measured.

### Catching and dunking: what the dense sequence does establish

**OBSERVED SOURCE:** Tocanscenes 4:03.8–4:06.9 was sampled every 0.1 seconds in `compare-catch-0.png` and `compare-catch-1.png`, with native frames `compare-toc-243.8.png` through `compare-toc-245.1.png`. Around 4:04.2 there is a movement puff, 4:04.5–4:04.7 exposes CATCH, 4:04.8 shows close ball contact/spin, and 4:04.9 shows STEAL/Hype feedback with the ball secured near rim level. The bean rolls across the rim region around 4:05.0–4:05.3, the backboard fades around 4:05.5, and the carrier leaves the area still airborne. This supports an **airborne interception**, not a demonstrated direct grab of a ball still held by another player. [Tocanscenes actual match](https://www.youtube.com/watch?v=ZU24J-EkOVQ&t=243).

**UNKNOWN:** The duration of the CATCH prompt is not a measurement of an active input window. Without an input overlay, these samples cannot prove the exact button-press frame, passive collision-catch behavior, radius, latency compensation, or whether an active grab can strip possession without a tackle. Current local active catch uses a 0.32-second window and a 2.35-unit center distance; those are tuning choices. Targeted passes can be caught automatically by their designated receiver in the local implementation.

**OBSERVED SOURCE DUNK:** Raks 2:03.7 shows an eligible dunk while below rim height, approximately 2:03.8–2:04.1 an assisted rise, 2:04.1–2:04.6 a readable windup, 2:04.8–2:05.1 the downward slam, and about 2:05.5 the score burst. Circle DUNK is separate from R2 SHOOT. Exact activation distance and the initial input frame remain unknown. The held ball is high, above/front of the head and approximately body-width, making possession readable during aerial play.

**LOCAL CHANGE:** The revised dunk follows an assisted curve preserving incoming direction, hangs near the rim, releases the actual carried ball at 80% of a 1.25–2.0-second duration, then follows through. The score uses physical downward rim crossing. A 0.85-second score celebration permits the dunk to finish before the kickoff reposition. These improve continuity relative to the former instant score reposition; timings remain authored choices.

### Independent simulation review and autonomous bots

`reference/measure_bots.gd` drives every seat through the real `bot_command` and action/movement methods at 60 Hz. It does not bind a network port. The first revised-map run still had zero fixed-pad or speed-strip uses in both modes, although deployed Hype pads launched bots 14 times in co-op and 7 in free-for-all. That finding led to a new fixed-pad route choice.

**RETEST:** With the route choice present, co-op completed at simulation clock 189.82 seconds, 9–5, with **61 fixed-pad launches**, 20 deployed-pad launches, 14 baskets, 18 dunk starts and 70 tackles. Free-for-all completed at 137.00 seconds, 5–7–5, with **0 fixed-pad launches**, 10 deployed-pad launches, 17 baskets, 21 dunk starts and 81 tackles. Speed strips were unused in both. The route choice considers nearby launch pads; center-start free-for-all bots did not reach those flank routes in this run. These are deterministic autonomous simulation results, not a statistical balance study or proof of household fun. Evidence: `compare-bots-after.log` before routing and `compare-bots-routes.log` after routing.

**REGRESSION FOUND:** `reference/review_dunks.gd` tested two hoops, 12 approach angles, four initial heights (1/3/10/18 above local floor), and three Giant states. All 96 ordinary and 96 long-lasting Giant dunks scored and completed the dunk before kickoff reposition. All 96 attempts with only 0.2 seconds of Giant remaining failed: the target had been computed for Giant size, but the power expired before release, placing the shrinking hand/ball below the rim. This was reported to the simulation owner for repair. The pre-repair evidence is `compare-dunk-review.log`; a later retest must be cited before calling this resolved. Maximum pre-reset per-frame movement in the successful matrix was under 0.46 units; rear Giant follow-through could penetrate the bank by approximately 0.05 units.

No public-footage measurement establishes an exact reconstruction of Crown Jam physics. The useful comparison is the observed action sequence, readable framing and route structure, supported by declared local measurements and specific regression checks.

### Final independent retest after dunk repairs

**VERIFIED LOCAL:** The Giant timer now remains stable through an active dunk. The outside-rim body target introduced during visual work initially drove rear Giant approaches as much as 1.27 units below the end bank, followed by a 1.27-unit floor snap. That second regression is captured in `compare-dunk-review-fixed.log`. The subsequent floor-aware curve/target correction is verified in `compare-dunk-review-final.log`: **288 of 288 attempts score**, every dunk completes before kickoff reposition, the minimum feet-to-floor clearance is +0.020 units, and maximum pre-reset per-frame displacement is 0.434 units. This matrix includes both hoops, 12 approach angles, four approach heights and ordinary/full-duration/about-to-expire Giant states.

`review_interruption.gd` uses the actual opposing player's tackle action with fixtures positioning the defender for contact. All six checks cancel the dunk, drop possession and stun the dunker: ordinary and Giant at 15%, 50% and 75% of the dunk animation. Evidence: `compare-dunk-interruption.log`. This verifies the local interruption behavior, not the source game's exact vulnerability window.

**FINAL AUTONOMOUS RUN:** After the new dunk target, floor repair, crosslanes and restricted speed-strip route choice, co-op finishes 4–0 at simulation clock 63.67 seconds with 18 fixed launches, 4 deployed launches, 4 baskets, 6 dunk starts and 24 tackles. Free-for-all finishes 7–5–5 at 128.87 seconds with 0 fixed launches, 13 deployed launches, 17 baskets, 19 dunk starts and 82 tackles. Speed strips are still unused in both deterministic runs. Evidence: `compare-bots-final.log`. Earlier bot totals above describe intermediate code states and should not be substituted for these final results. The speed-strip route exists, but this sample does not demonstrate bots taking it.

The independent review found no remaining scoring, Giant-expiry or floor-penetration failure in this matrix. Network/rendered presentation verification belongs to the separate application checks; these scripts never create a network host. A code-level concern about extrapolated client players versus raw snapshot ball positions was sent to the application owner for a moving-carrier rendering check. No physical three-PC household test is claimed here.

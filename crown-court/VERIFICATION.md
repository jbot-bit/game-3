# Crown Court 0.15.2 verification

13 October 2026. One standard 64-bit Windows release, Godot 4.7.2 Compatibility renderer. [Previous verification](VERIFICATION-0.14.md).

## Exact artifact

CrownCourt.exe: **114719616 bytes**, SHA-256 **9E31FE410A6A602260596A7BF8638133F685DD723E182DA17243C8D642B17CA0**. Version 0.15.2; embedded resources; independent startup passed. All 61 runtime manifest files match the exported source. [Machine-readable receipt](VERIFICATION-0.15.2.json). The retained public 32-bit file is an older release, not a matching build.

## Reproduced improvements

- Direction-independent air/boost acceleration and removal of outward blocked wall momentum. Tangent movement, retreat and authored running/sliding/knockback tuning remain. Client prediction and pass forecasts share boundary handling. [Movement](REVIEW-MOVEMENT-0.15.md), [client prediction](REVIEW-CLIENT-0.15.md).
- Controlled wall/corner camera sweeps improve from 5.864m to 1.069m maximum step; the 95,040-sample stadium clearance check passes. Directly outward wall/deck views can still frame the avatar closely. [Camera review](REVIEW-CAMERA-0.15.md).
- Rim height rises from 4.6 to 5.8, approximately 2.68–2.69 times family mesh height. Supports reach the backboard; opening/ball size stays unchanged. Exact Crown Jam dimensions remain unknown; the smaller default bean now has a 3.41 ratio. [Measured proportions](REFERENCE-RATIOS-0.15.md).
- Native review caught the raised rim behind the scoreboard at 5m. Nearby facing-hoop framing moves its top from 69px to 168px, with feet at 666px at 1280x800. Nine both-goal, aim-preservation and smooth approach/departure/turn checks pass; explicit ball-camera keeps precedence.
- Contextual jump-and-tackle defence guidance addresses firsthand players' difficulty discovering dunk counters. Twenty checks cover real dunk state, availability, priority and input labels. [Feedback and brainstorm decisions](PLAYER-FEEDBACK-0.15.1.md), [counterplay review](REVIEW-COUNTERPLAY-0.15.md).

Two old 5m test shots clipped the higher rim. The deliberate-shot fixture now uses a steeper 78-degree arc within the existing 80-degree player limit. Both directions score; gameplay aim, charge and ball flight were not changed to force baskets.

## Verification and play review

- **71 embedded headless suites passed** on the exact executable: normal/Giant dunks, shots, counterplay, all match modes, saves/rewards, network transport and camera regressions.
- **4,608 movement scenarios passed** on that executable across 30/60/120Hz, eight headings, four input intents, ground/air, normal/Giant, flat/bank/wall and run/dive/impact/boost. Focused directional/wall checks passed too.
- Native arena, input, audio, ordinary action/route and **65 controller-input checks** passed. Generated input events are not physical controller testing.
- **43 family network checks passed**. A recorded three-client Dad/Evie/Tyler match finished **4–0** under the existing win-by-four rule, exercising move, jump, catch, pass, shot, tackle and dunk. It recorded 4 baskets, 5 dunk actions, 29 tackles, 45 grabs and 10 throws. All peers agreed on result, equipment and correct rewards.
- Recording: 675 frames across 118.220 seconds, zero focus recoveries, full decode passed. Video SHA-256: C3DE432045DA2D7696846968C13F55836C7147242040B8B46E1571758117BCDD. Local file: build/crown-court-evidence/v152-match/joined-client.mp4. No audio in the recording; native playback was tested separately. Maximum observed camera step was 1.381m; this is not a universal smoothness guarantee.
- Inspected native hoop/HUD/control fixtures and match frames. [Final captures](release-evidence/0.15.2/README.md); exact external probe: tests/hoop_visual_review.gd. Earlier wall captures were sealed/verified with Game Development Studio.

Earlier candidate evidence stays separate: 0.15 completed co-op 5–4, teams 4–0 and versus 7–0–0, plus mixed-architecture checks; 0.15.1 completed the higher-hoop match 5–2 before final framing. These are not labelled as final 0.15.2 runs.

## Preservation and limits

All launches used isolated profiles. Three household save/settings files were backed up privately and remain byte-identical. No profile schema, unlock or family-authoring migration was introduced. Hosting remains undeployed. Local automated runs do not establish physical three-PC/controller play, WAN quality, household enjoyment or exact original-game physics. Public-download hash/startup verification follows publication, with its receipt retained locally under v152-public-download.

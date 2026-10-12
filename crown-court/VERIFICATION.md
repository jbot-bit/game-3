# Crown Court 0.14.0 verification

13 October 2026. Fixes are based on retained 0.13 ordinary-input match recordings and new controlled reproductions; no newer household play feedback was available. Godot 4.7.2, Windows Compatibility renderer.

## Exact artifacts

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| CrownCourt.exe | 114517336 | 9B585FBBFF6F5F2F62D7205C006E2C6E81DEEECDCEAE178BFBB9464E8560725A |
| CrownCourt32.exe | 125857816 | 7FE72CE56838A8A2FE352C38A586D2CAAB4D1B8CFCD412F7E7267896E646B545 |

Both identify as 0.14.0, contain the matching runtime, and start independently. [Machine-readable receipt](VERIFICATION-0.14.json). The 0.13 release and [verification](VERIFICATION-0.13.md) are retained.

## Reproduced fixes

- Camera: stadium tiers previously caused abrupt inward retraction during descent. The controlled 60 Hz case falls from 5.546 to 0.507 metres maximum per frame; 95,040 clearance samples pass. Manual look, overhead-ball framing and intentional kickoff relocation remain intact. The tradeoff is a closer view at altitude beside the bowl. [Camera evidence](REVIEW-CAMERA-0.14.md).
- Bots: braking moved the release hand 1.74-1.94 metres after a shot was calculated. Bots now solve at release, keeping the same windup and error. All 432 stationary trials and 864 release timings match. Moving results per 144 attempts are Easy 39 to 27, Normal 62 to 33, Hard 36 to 80. This is a correctness fix, not proof of better overall scoring pace or balance. Human aim, speed and slides are unchanged. [Shot evidence](REVIEW-PACING-0.14.md).
- Result UI: five baseline checks fail because a declared winner still shows Overtime and live action hints. All 11 corrected result/rematch checks pass. FINAL / Full time replaces the live timer/rules, the result panel replaces temporary announcements, and earned bags survive rematch. Native captures are inspected and sealed/verified through Game Development Studio. CPU sealing proves capture hashes, not new GPU execution or performance.

## Integrated checks

65 x64 embedded suites and 20 x86 suites pass, including the three new regressions. Native arena, gameplay-input, physical scoring route, audio and controller-event gates pass. Three local processes with a 32-bit host and mixed 32/64-bit clients pass all action checkpoints; 42 family network checks cover selection, equipment, rejoining and round transitions.

The exact x64 pack completes a recorded three-client family match against three bots with score {"0":5,"1":3}. All peers agree on result, character equipment and rewards. It records 8 physical baskets, 9 dunks and 84 tackles. 1883 frames span 330.03 seconds, with 0 automatic focus recoveries. The video fully decodes; SHA-256 5AA62FF3E6D64D6B095DE7CE225EFFCD556538342E389C2613573C62076EDB3C. Local recording: build/crown-court-evidence/v14-final-match/joined-client.mp4. No audio is in this recording; native audio playback is tested separately.

The full-match telemetry still records a 4.227 m maximum camera step during a rapid yaw change and player correction; this is not a claim that all camera motion is smooth. The largest logged step without yaw change is 1.206 m with a 1.669 m player step. The isolated stadium-descent regression above is the basis for the camera fix, not a cross-match comparison. All 60 runtime files other than the architecture-specific export preset match between builds.

## Save preservation and limits

All game tests use isolated profiles. 3 existing household save/settings files were backed up locally and remain byte-identical. Character identity, equipment and unlock migrations are unchanged. Internet hosting stays undeployed. Local automated clients do not establish physical three-PC/controller, WAN, human enjoyment or exact original-game physics. Public-download hashes and startup are checked separately during publication.
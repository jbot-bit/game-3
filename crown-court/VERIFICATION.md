# Crown Court 0.17.0 verification

14 October 2026. One standard 64-bit Windows release. Claude's 0.16 report is retained in [VERIFICATION-0.16.md](VERIFICATION-0.16.md). [Review and player-research rationale](REVIEW-0.17.md).

## Current internet release

The permanent-server rebuild supersedes the artifact below. Current package hashes, online joining and native Mac status are in [internet verification](release-evidence/0.17.0-internet). The following sections preserve the earlier gameplay release evidence.

## Original gameplay artifact

CrownCourt.exe: **114,805,488 bytes**, SHA-256 **A1C266953BE6882896C6BCF984F8A5352016C2BE5FED3F501C1FE3959E4C53FA**. Windows file version 0.17.0.0, product version 0.17.0. Embedded resources, native standalone startup passed. The earlier 0.16 executable and first 0.17 candidate remain available locally and in applicable Git history.

## Final exported build

- **76/76 embedded headless suites passed**. Includes possession stats, actual ENet series/power acknowledgement races, reward uniqueness, simulation/charge/network timing, movement, slide recovery, camera, hoops, family profiles, sound and saved progression. Three local-loopback tests were initially blocked by the sandbox, then passed with the required local network access; prior attempts remain in the aggregate.
- **8 native gates passed**: arena review, keyboard render, audio render, movement input, traversal route, synthetic controller input, full-presentation capture and standalone EXE startup. The cinematic fixture checks ten actual camera/stage pairs and fails if a stage is absent. All ten images were inspected for framing and readability.
- **8 network configurations**, 22 peer reports, and 11 action checkpoints passed. **42 family-network checks** passed, including equipment, late join, rematch and reconnect. These are local multi-process ENet/room checks, not physical three-PC or WAN tests.
- Final ordinary-input **Normal best-of-three series completed 2-0**, with matches **4-2 then 4-0**. 495.9 driver seconds, 1,912 native captured frames, zero fixture mutations, all seven action categories covered, six power activations, and Giant to Jump Pad selected through the result UI. Both unique match rewards were saved correctly. Two focus-loss resumes occurred during live round two, about 23 seconds after the round transition; they are retained in telemetry. Deliberate cinematic/rematch camera cuts are included in raw displacement maxima and are not movement-regression measurements.
- Baseline ordinary-input Easy match: 4-0 in 140.38 driver seconds, 542 frames. The candidate's different difficulty/session format prevents treating duration differences as a controlled retention experiment. The recordings are silent frame-review videos; audio was checked separately through the native audio gate.
- **51/51 pre-existing household files remain byte-identical**. Backup: build/crown-court-evidence/v17-household-preservation. All test profiles were isolated from the household directory. Series standings are session-only; save schema is unchanged.

## Visual evidence

Game Development Studio 1.5.0 sealed and verified ten native images in run `run_1791945369358_04dd552cf5ab437ba8cfb8e1824541ca`; closed manifest SHA-256 `68e3abfa4fb0cec35c425926470ec12125987cf6d74ab5038e9a4d3fc26dc3f5`. The plugin verifies captured image bytes and provenance; it does not prove enjoyment or hardware performance. The native Godot runs provide the renderer evidence, and direct image inspection provides the visual review. No new paid assets or provider calls were needed.

Compact receipts, source hashes and the observed series result are in [release-evidence/0.17.0](release-evidence/0.17.0). Full logs, frames, videos and profile backup remain under build/crown-court-evidence. Root CrownCourt.exe is the standard public download. Source and build were pushed in `783a32da9f20c15075067db6a06a79d1746ed62a`; an anonymous download at that commit matched all 114,805,488 bytes and the release SHA-256, then passed native startup using an isolated profile. All 51 household files were checked again and remain unchanged. See `release-evidence/0.17.0/publication.json`.

## Limits

This establishes implemented and automated-tested replay choices, not sustained household enjoyment or exact proprietary Crown Jam mechanics. Physical controller and three-PC family play remain the next validation. Additional courts, rule variants or AI tuning should follow that feedback. Existing movement momentum and 5.8-unit hoop proportions are retained. The original gameplay audit predates hosting; see the current internet verification above.

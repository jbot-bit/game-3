# Crown Court 0.8.0 verification

Windows, 12 October 2026. Godot 4.7.2 Compatibility renderer. Prior releases and sibling games are preserved; VERIFICATION-0.7.0.md retains the previous release report. The public room endpoint remains blank.

## Repairs and evidence

REVIEW-0.8.md and REVIEW-0.8-AUDIT.md link the reproduced failures, implementation decisions and independent review. The latest pass uses the retained 0.7 recordings and existing user feedback, not a newly supplied household recording.

- Multiple accepted actions now survive between audio updates. A real local throw followed by a remote jump previously lost the throw cue. Compact history retains at most 16 events for 350 ms, with join/reset seeding, expiry, deduplication and mute/pause handling. Local priority also covers a remote sound from a previous snapshot. The ten-voice budget remains fixed and important cues keep reserved voices.
- A held shot is cancelled when possession loss is observed; recatching while still holding the button cannot revive that charge. The parsed-mouse regression went from four failures to seven passing checks.
- Exact 0.7 packet probes reproduced a .1067 m carrier-target rewind and .0272 m rendered reversal. After a plausible 525 ms delivery gap, actor/ball cuts were 8.310/9.588 m. The revised first recovery steps are .230/.750 m; subsequent catch-up remains bounded and converges to .0023/.0039 m residual after half a second at 60 Hz. Thirty/120 Hz convergence, stale prediction, real relocation and action transitions are covered. Outages still exhaust prediction after 80 ms; this does not remove network delay or prove host scheduling fixed.
- Independent review found that corrected X/Z on a bank could retain the incoming sample's lower Y. The target was .796 m below the surface; corrected contact now removes that target error. The tested rendered actor clearance is -.0137 m from the existing transform blend. The worst target error was not a demonstrated body-burial frame.
- Foreground rim/net sections now fade against the actual character and carried-ball sightlines. The reproduced view went from 9/9 torso and 8/9 ball rays blocked to zero, retaining 62.5% solid rim triangles. Camera transforms and simulation/scoring geometry are unchanged. This adds 56 small geometry draws; no hardware performance gain is claimed.

The source native audio diagnostic passes 14 checks and records 33 real playbacks. Its 9.567-second recording decodes with peak -11.394 dBFS and RMS -39.970 dBFS. A strict wrapper flagged only the MovieWriter low-disk advisory after process exit 0; the complete AVI/MP4 were subsequently decoded. This is playback/headroom evidence, not a human listening assessment. The 21 CC0 samples and their credits remain unchanged.

Game Development Studio 1.5 verified/analyzed/compared four native before/after visibility captures in v8-world-visibility-cli. It imported actual Godot images; that CPU step is not an additional GPU run. REA tools/CLI were unavailable, so no decompilation or private Crown Jam constants are claimed. Ground traction, court dimensions, jump and dunk simulation tuning remain unchanged from 0.7.

## Exact release checks

The final v8-release build passed source and embedded-pack checks, native gameplay/audio/controller gates and actual executable startup. CrownCourt.exe is 110,607,904 bytes, version 0.8.0.0, SHA256 F64672B2B8520728827B2D64C746B7FC8113D99280A98C38F33EB8622FE1822D. Receipts: v8-release-source-manifest.json and v8-release-playtest-results.json.

Source and embedded tests include simulation/team play, ground traction, ball continuity, client prediction, 21 snapshot recovery checks, independent terrain contact, event history 9, audio routing 13, local audio priority 2, charge lifecycle 7, visibility 9, carry/rig/polish, sound bank integrity, profile/reward/rematch/session, snapshot/address validation and controller mappings. Native gates passed 18 input checks, 14 audio checks with 33 playbacks, a continuous boost-to-dunk route, 63 controller/menu checks and actual executable startup. The exact-pack visibility run also captured four native comparison images.

Physical controllers are not connected to these tests. Parsed events and injected controller discovery establish software input paths, not hardware compatibility or comfort.

## Network and complete recordings

Pending final exact-pack network and natural-match recordings. Replace this section before packaging. The matrix/transition fixtures and normal-input complete recordings are separate evidence types. The recording driver now logs received event history and samples rendered player/ball positions and snapshot age; its event totals are not comparable with older latest-event-only counts.

## Package and remaining playtest

The package gate requires matching executable/source hashes, native input/controller/audio receipts, eight network configurations and action checkpoints, room integration, impaired transport checks, complete natural recordings with matching video hashes, and successful startup after fresh ZIP extraction. Final receipt: v8-release-release-results.json.

Actual mixed controllers, headphone/speaker sound preference, household PCs, human enjoyment and long-session/cross-home smoothness remain unverified. Public no-extra-app room play needs an approved deployed WSS service and an external connection test. No public upload, hosting, router or firewall action was taken.

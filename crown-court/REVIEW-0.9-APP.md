# 0.9 app review

12 October 2026. This review covers Hype feedback, shot previews and client presentation in `main.gd` and `hud.gd`. It does not establish release completion. The full package build and new complete-match recordings remain separate gates.

The app already uses shared simulation dimensions. The enlarged 64 × 112 m court therefore has no obsolete 40 × 72 m prediction clamp. The 96 m hoop separation takes 10.11 seconds at a steady 9.5 m/s; the ordinary jump remains 1.22 seconds with a 3.72 m rise. These are ideal calculations from authored tuning, not measured original-game dimensions or human traversal results.

Hype now identifies the selected ability before it is ready. A short menu description explains its effect; the HUD reports earned charge, readiness, activation and authoritative remaining duration. An unavailable press gives feedback. Q and the controller top button keep their bindings, with PlayStation, Nintendo and generic labels. The menu and ready/active indicators were inspected in three native 1280 × 800 captures; the labels fit above the temporary controls footer.

The final power audit traced selection through reliable registration, host action validation, charge spending, snapshots and joined-client effects. All three powers change gameplay: Giant changes size, movement/contact and sweeper immunity; Jump pad launches players; Homing ball tracks an opponent and applies a hit and ball drop. The host owns expiry. These are not decorative-only effects.

A real late-join regression exposed one HUD omission: replacing a Giant bot and selecting Jump pad preserved the active Giant, but displayed `0%`. The HUD now keeps the selected ability name and names any inherited active timers (`Giant 7s` in the reproduced case). The new room fixture failed only that assertion before the fix, then passed 27/27. It exercises three independent multiplayer peers inside one SceneTree, using a real local WebSocket relay, production registration/action RPCs, compressed snapshots and world/HUD consumers. Positions, partial charge and simulation stepping are explicit fixtures; it is not a naturally played three-process match.

Shot previews previously stopped after 1.44 seconds and could continue through a board or rim. They now use the actual throw velocity and an isolated copy of the ball integrator, stopping at the first static contact or legal goal crossing. The forecast is limited to 36 dots and four seconds. It cannot change possession, scores or received state. Future player movement and interceptions are excluded, so the preview is not a guaranteed basket.

A sweeper hit while a player was already stunned and airborne retained 0.262 m of stale presentation correction. A new authoritative hazard cooldown now clears that correction. Rotor presentation also uses the same bounded 80 ms prediction time as the ball and players, while reset, celebration and result phases remain frozen.

The presentation copy now includes `snapshot_clock`, the unchanged authoritative clock alongside the bounded predicted clock. World projectile presentation uses their difference for the same capped extrapolation horizon. This adds no wire field and changes no hit or expiry authority.

| Focused gate | Result | Evidence |
| --- | --- | --- |
| Hype selection, feedback and parsed input | 21/21; native images inspected | [Source log](../build/crown-court-evidence/v9-hype_feedback-freeze.stdout.log), [native captures](../build/crown-court-evidence/v8-hype-feedback-native/) |
| Three-peer room power lifecycle and inherited timer | 26/27 before, 27/27 after; clean logs | [Before](../build/crown-court-evidence/v9-powers-red-room-powers/result.json), [after](../build/crown-court-evidence/v9-powers-green-room-powers/verification.json) |
| Existing Hype feedback after inherited-timer fix | 21/21 | [Result](../build/crown-court-evidence/v9-hype-inherited-green/result.json) |
| Actual throw-path preview | 20/20 across ten paths; recorded sample error 0 m | [Preview log](../build/crown-court-evidence/v9-shot_preview-freeze.stdout.log) |
| Hazard impulse and phase prediction | 7/7 | [Hazard log](../build/crown-court-evidence/v9-hazard_prediction-freeze.stdout.log) |
| Existing snapshot recovery | 21/21 | [Recovery log](../build/crown-court-evidence/v9-snapshot_recovery-final.stdout.log) |
| Score, possession and device-specific dunk prompts | 9/9 | [Feedback log](../build/crown-court-evidence/v9-feedback-fixture-green.stdout.log) |

Preview cases include short and full-court shots, high releases, own-basket scoring, backboard/rim obstruction and a real rotating-bar rebound. Conservative shared collision bounds reduced the measured forecast component cost to 0.083–2.766 ms in the final headless probe. The rendered candidate's [native input diagnostic](../build/crown-court-evidence/v9-release-pack-feel-input.stdout.log) recorded a 3.202 ms call. These are different execution contexts, not a matched performance comparison or a whole-frame benchmark. The native diagnostic still checks that a mouse turn changes the preview before the next snapshot.

The room power checks cover below-full rejection, earning the final charge through a real catch, activation, Giant immunity and shrink, pad launch and removal, projectile hit/drop and no-hit lifetime expiry. Both joined clients consume the received effect state. The headless check inspects actual world nodes and HUD state; it does not establish rendered readability or physical controller operation.

`verify-room-powers.ps1 -Pack <exe> -EvidencePrefix v9-final` runs the embedded 27-check fixture and writes `v9-final-room-powers/verification.json`, requiring clean logs and unchanged before/after executable SHA256. It owns only its loopback relay and engine processes. Independent review corrected timeout cleanup to `Kill(true)` because the console launcher can have an engine child; final wrapper syntax passed. The source GREEN receipt predates that cleanup-only tightening. Exact-pack execution remains a release gate.

The feedback gate initially failed because its hard-coded dunk position was 19 m from the relocated hoop. The fixture now derives its location from the shared hoop, terrain and dunk range. Both exact prompt checks also require the production dunk rule to accept the position; production code was unchanged for that repair.

All listed stderr logs are empty. The [earlier source hashes](../build/crown-court-evidence/v9-app-review/source-hashes.json) identify the pre-power-polish app review. Final app and verifier identities are:

| File | SHA256 |
| --- | --- |
| `main.gd` | `AA6CFBA4B19BF952DF91653083226981C45055F180621AA22CE9609E332052CA` |
| `hud.gd` | `EB0D1D7A1D651B261AE578B246B80075B0CF299808AA9F1DF3B8757CE9045004` |
| `tests/room_powers.gd` | `F9171E4D90CAF2489CB6DE6ABF4B20261AEA69C9C84307016C11D0A70C03AF03` |
| `verify-room-powers.ps1` | `A5AA73B57651E3E2674FA5471BD866264771CABB6F2EE410A7E9DF9805BD733B` |

The retained 0.8 recording is a before comparison, not final 0.9 evidence. Physical controller operation, household enjoyment, WAN play and public relay deployment remain unverified. Final natural-room recording review is still pending.

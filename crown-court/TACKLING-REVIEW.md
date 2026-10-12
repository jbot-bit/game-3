# Tackling reconstruction and verification — 0.12 review

Date: 12 October 2026. This investigation follows the Reverse Engineer Anything workflow: identify the target, separate observations from inference, inspect our implementation, reproduce defects, and verify the changed runtime. No Epic code, constants or proprietary assets were recovered.

## Target and evidence boundary

The target is Fall Guys Crown Jam, a Fortnite mode. No matching installation was found in the checked Epic launcher manifests (zero .item entries) or Windows uninstall records. This is a bounded installation check, not a whole-drive search. REA 6.4.0 CLI doctor reports Codex registration drift; the server is not connected in this session. Receipt: build/crown-court-evidence/rea-tackle-doctor.json. Repairing agent configuration would not provide missing Crown Jam packages, so no unrelated client configuration was changed.

Our Godot project is complete source, for which the REA skill directs ordinary source inspection. Runtime claims below use our real simulation, game renders and network clients. There are no REA decompilation Evidence IDs to cite because no original-game binary analysis occurred.

## Actual gameplay observed

Primary footage: Raks, "Fall Guys - Crown Jam - Game 1 - No Commentary": https://www.youtube.com/watch?v=4IdjAgwrwgc . The normal browser video player was opened and played, then sampled at 90.5, 91, 91.5, 92, 92.5, 93, 144, 144.5, 145, 145.5, 146 and 146.5 seconds using Playwright. Native browser-video screenshots are retained under output/playwright/family-review/crown-tackle-*.png. No remote video file was downloaded.

- OBSERVED at about 90.5–91.5s: bright contact flash, an opponent tumbles away, the ball remains conspicuous above the scrum, and a TACKLE/Hype reward appears. The attacker quickly continues toward possession. By about 92s play is moving forward again.
- OBSERVED at 144–146.5s: several players converge on a loose ball, the local bean performs a spinning collection action, gains possession and turns while opponents close in; a subsequent pass leaves the scrum. A bump does not visibly award possession without a collection/ball interaction.
- UNKNOWN: input frames, exact automatic versus manual catch behavior in these moments, impulse strength, recovery timers, hit-volume shapes, camera constants and network prediction. These screenshots do not recover physics numbers.
- OFFICIAL corroboration: https://store.epicgames.com/news/fall-guys-crown-jam-slams-into-fortnite?lang=en-US describes collisions/tumbling, grabs, tackles, passes, airborne blocks and Hype. https://www.fallguys.com/news/the-beans-slam-dunk-in-fortnite-for-a-limited-time-crown-jam describes physics-driven jump/tackle/dunk feedback. Neither publishes implementation constants.

## Reproduced local faults and authored fixes

1. **Ball-origin discontinuity.** hit() placed a dropped ball at torso height instead of the carrier's live hand position. Capture the hand position before cancelling a dunk, then release physically from there. The dropped ball inherits a small part of the carrier's velocity; it remains loose and can be contested.
2. **Player-ID advantage in simultaneous tackles.** Pair resolution used if/elif, making the first ID win. Resolve both eligible attack intents before mutation; head-on simultaneous dives knock both players back. Existing guard prevents repeated stun.
3. **Rear hit volume.** A diver could hit any enemy within the contact radius, including behind them. Require the opponent to lie in the forward hemisphere. Glancing forward contacts remain possible.
4. **Weightless ordinary contact.** Bodies only separated positions. Closing contact now exchanges horizontal momentum with modest restitution and greater giant mass. Contact alone does not steal possession or cause stun.
5. **Defensive route errors.** The designated chaser could divert to boosters while pursuing a carrier. Keep the primary defender on the ball and lead the carrier briefly.
6. **Tackling away from the ball.** Marking bots aimed at the carrier but moved toward a defensive position; tackle preferred movement. Align both on the actual contest.
7. **Unreachable and missed contests.** Grounded bots spent tackles below airborne carriers and sampled close contacts too slowly. Check reachable height, jump for a reachable aerial challenge, and use a separate nearby-defense cadence. Preserve offensive difficulty, shot windup and reaction delays.
8. **Impact readability.** Replace the large coral contact donut with a brief white star/contact dust. Blend into and out of the committed dive pose; retain the victim's single knockdown/recovery roll.
9. **Approaching-carrier prediction.** Review found that a fast carrier's predicted position could cross behind the defender. Close-contact tackle aim must use the current carrier position; prediction remains useful for pursuit. Mirrored moving-carrier regression fixtures cover this case.

All numbers are authored tuning choices, not claimed recovered Crown Jam values. Existing .65-second stun, 1.4-second guard and .85-second tackle cooldown remain. No new attack/grab button or wrestling hold was invented.

## Verification

- tackle_contacts: 7 initial failures reproduced; 12 checks pass after fixes, including actual hand release, two ID orders for mutual clashes, no rear hit, momentum transfer/conservation, no ordinary-bump turnover and teammate protection.
- tackle_pressure: 14 initial behavioral failures plus 4 approaching-carrier failures reproduced; 39 checks pass, including mirrored teams, direct chase, marker approach, aerial contact, height restraint, close-defense cadence and unchanged offensive timings.
- Broader CPU suites: sim, gameplay_v11, teamplay_sim, three complete teamplay matches and reference_feel pass. Native family menu, family dunk/Giant poses, event history and ball-presentation checks pass.
- Native visual fixture: build/crown-court-evidence/tackle-native-v12 captures a real simulated tackle and ball drop. It is a controlled fixture, not human play.
- Recorded three-client match: family-tackle-final-room, 4-0 win, matching results and one bag for each client, 39 delivered tackle events, 881 native frames over 155 seconds. Runtime hashes stayed unchanged during recording. This recording precedes the final approaching-carrier aim correction; exact executable checks are stored separately under family-tackle-final-*. Consult completed receipts for those checks.

Remaining: real controllers, three physical PCs, household judgment of contest/recovery feel, and family likeness approval. Hosting remains undeployed; no Internet claim follows from loopback tests.

Packaging note: the first x64 pack-check attempt timed out because the new pressure test tried writing its receipt into the read-only pack. Passing an absolute evidence directory fixed the harness; the identical executable immediately passed all 39 pressure checks. The complete rerun is family-tackle-final-release-r2. This was a test-output-path defect, not a gameplay timeout.

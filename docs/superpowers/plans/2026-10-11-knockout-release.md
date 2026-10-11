# Hands Full 0.8.0: Knockout and playable remote release

The user has authorized researching, designing, implementing and shipping Hands Full, including the circular last-player-standing minigame and a better opening screen. This finishes the existing local 0.7.0 work; it does not recreate Gladiator, Wipeout or the twenty co-op courses. No root AGENTS.md or CLAUDE.md is present. Preserve unrelated fishing and Nightfall work and household saves.

## Research and design decisions

The exact Fortnite island is unconfirmed. Official listings such as [Last Fall Guy Standing Wins](https://www.fortnite.com/@thegraveone/6718-6298-4285?lang=en-US) establish the shared-platform survival format with moving obstacles, while [The Moving Pillars](https://www.fortnite.com/@snowfallgames/1632-9698-1376) combines moving footing and opponent knock-offs. These are references for the rules, not artwork or code sources.

Add a fourth mode named **Knockout**: one circular pad, visible moving padded hazards, jumping and existing padded-stick attacks/brace. Two or three players compete; the last standing wins each round and the first to three wins the match. One player may practice without earning a bag. Preserve simultaneous-fall draws, late-join spectating, disconnect cancellation, exact-once saved cosmetics and rematches from the existing match controller. Equal movement; no co-op powers or grapple escapes.

Builder choices: a wide low sweeper to jump and a shorter counter-rotating elevated sweeper to avoid spatially, with a blocked center hub to prevent standing on the pivot. Hazards start stationary through countdown, then intensify in five stages over a bounded round. Following the user's feedback, speed targets are 1.0/1.3/1.7/2.1/2.5 at 0/15/30/45/60 seconds with smooth two-second changes. Audible warning beats precede each stage. The physical circular floor contracts from radius 9 to 6 between 30 and 60 seconds, and its displayed edge follows the same collision boundary. Reset their phase on each new round. All actual contact and elimination are host-authoritative. Clients render movers on the existing shared physics-pose timeline. Use Godot 4.7.2/Jolt/Compatibility and existing ENet; no new dependency. [Godot's AnimatableBody3D documentation](https://docs.godotengine.org/en/stable/classes/class_animatablebody3d.html) describes estimated movement velocities affecting physical bodies; a real contact probe must confirm the game behavior.

The opening screen should look like a party game: bold ink and warm paper colors, an original illustrated faceless crew and sweeper pad, clear mode choices and a compact Host/Join flow. Preserve legible 960×540 controls, keyboard focus, errors, the course chooser, customization and in-session controls. The host's address must be easy to find/copy. Existing signals remain stable.

## Implementation and release checklist

- [x] Inspect recent local/cloud/remote work; reuse any existing matching implementation.
- [x] Add Knockout world and mode wiring, with meaningful rule/physics regressions.
- [x] Refresh opening menu, connect Knockout copy/results, verify small viewport and native rendered appearance.
- [x] Exercise a real physical hazard contact and opponent ring-out, round reset and safe spectating.
- [x] Run three-process exported-pack checks for Knockout, existing competitive modes and co-op.
- [x] Build versioned 0.8.0 Windows ZIP; inspect embedded resources and actual EXE startup/rendering.
- [x] Review the final scoped source changes; preserve existing history and unrelated working files.
- [x] Publish source and a GitHub Release standalone HandsFull.exe plus optional ZIP, then verify remote commit/tag, download and hash. Complete third-party notices are embedded and accessible through Credits.
- [x] Give the family a direct download and short three-PC Host/Join instructions.

Automated loopback, rendered fixtures and local GPU timings are not a three-physical-PC household playtest or internet matchmaking. Record exact verification and any remaining limits in the release notes.

Published and verified on 11 October 2026: [release hands-full-v0.8.0](https://github.com/jbot-bit/game-3/releases/tag/hands-full-v0.8.0), source/tag `730abd39f05204b733615eb4e90a7ae32ca3a6e1`. The downloaded standalone EXE matches the tested SHA256 and starts cleanly in its own folder. `logs/knockout-download-verification.json` records the round-trip evidence. All implementation and delivery checklist items are complete; household playtesting remains the next evidence for feel and real Wi-Fi performance.

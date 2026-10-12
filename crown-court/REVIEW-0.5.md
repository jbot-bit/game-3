# Independent Crown Court 0.5.0 review

Reviewed 11 October 2026, 23:56 AEST. Scope: current gameplay, controller and native room source, existing local test receipts, deployment preparation and release-truth boundaries. No production edits, GPU runs, public actions or account changes were performed by this reviewer.

**Result: no concrete blocking production defect found in the reviewed source.** This is a source review, not final-package approval or a claim that public internet play is available.

## Checks run independently

- `node --test crown-court/relay/relay.test.mjs`: 6/6 tests passed on ephemeral loopback ports. Covers room/version/identity, capacity, channels, sender/target isolation, malformed and oversized traffic, lifetime/kick/refuse, registration/rate limits and bounded queue behavior. The backpressure threshold branches use deterministic socket substitutes; the other protocol cases use real WebSockets.
- `build/crown-court-evidence/v5-independent-review/gameplay.gd`: 65/65 checks passed in headless Godot 4.7.2. Covers normal and Giant dunks from four approach directions at both hoops, the physical one-basket result, post-score return to the raised deck, next-possession launch, and unfilled-seat live join plus balancing preserving both existing player dictionaries and ball possession. These are simulation fixtures, not an input recording or human match. Receipt: `build/crown-court-evidence/v5-independent-review/gameplay.json`.

## Source review conclusions

- Raised decks remain separate from the banked floor. `surface_height` selects the deck only from above, and the same function is used by players, loose balls and client extrapolation. Existing below-deck paths remain open. Team kickoff leaves one extra jump; free-for-all keeps its ground start.
- The 1.5-second base dunk reaches at 40% and releases at 80%, giving approximately 0.6 seconds at the rim. The shared hand height and release position preserve physical downward scoring. `hit` clears an interrupted dunk. The Giant timer is held through the action, avoiding a held-ball size discontinuity.
- `join_spawn_position` is used only to place new unfilled human seats and balancing bots. Existing players are not respawned during live balancing. Replacing a bot preserves its body state and rewrites possession, projectile and power-pad references.
- Room connection callbacks compare the current peer using a weak reference, and the host initializes seat 1 before entering the lobby. Joining clients wait for host welcome. The source application receipt covers three clients, full-room error preservation, input/snapshots, result/reward transition fixture, rematch, live rejoin and host close.
- Room IDs are monotonic for a room session and host authority remains ID 1. The server authenticates envelope sender against the socket and forwards only inside its room. Room codes contain 128 random bits. Remote endpoints require `wss://`; plain WS is restricted by the client to loopback.
- The transport honestly preserves channel metadata over one TCP stream. It does not reproduce ENet packet-loss independence. Existing final source stall evidence has approximately 1.23-1.28-second state gaps and 1.39-1.48-second action RTT during the imposed 1.2-second stall. These are visible pauses, not proof of smooth WAN play.
- Controller labels use physical face-button positions for Nintendo/unknown pads and a two-pass replacement avoids swapped-label cascades. Input map rebinding restores held keyboard/mouse actions; the source regression explicitly verifies held Space through controller release, removal and later key release. Physical hardware remains untested.
- The prepared relay guide and Fly template explicitly require approval, one instance, a trusted TLS proxy and no exposed backend port. Docker/public TLS/service operation are not claimed as tested. The blank shipped endpoint and disabled room buttons accurately communicate the current build's limitation.

## Release closeout still required by the owner

At review time the main build was running. Final executable/hash-bound recordings, packaged room/application and TCP checks, network matrix, release archive and fresh extraction receipts must be complete before marking the local candidate released. Previous 0.4 receipts cannot substitute for these 0.5 checks.

Documentation followups sent to the owner: archive the old `VERIFICATION.md` and write the 0.5 report, since the current file is still titled 0.4 and ends with Tailscale/100.x instructions; update `CONTRACT.md` for native rooms, deck collision and new runtime fields. These are current-document closeout items, not newly discovered gameplay defects.

The 0.5 gameplay comparison uses timestamped sampled reference footage and an exact 0.4 recording/manifest. The old compiled pack's source is unavailable to this reviewer; this review does not claim a line-by-line 0.4-to-0.5 code diff or recovered Crown Jam physics.

Public deployment approval, a working configured WSS endpoint and actual separate-home play remain additional gates. The user's deferred hardware-controller test remains deferred. The source-only result above should not be converted into a claim of physical controller compatibility, household enjoyment or available no-extra-app internet play.

## Reviewed production hashes

| File | SHA256 |
| --- | --- |
| `sim.gd` | `B112426BCA85C671A5E68D4AA224C96BE78421FBAF269CF76124E6688111A5FB` |
| `main.gd` | `BB97A526C667795939413050A882591FC0B8B47CF2B487A9F1D16DB2F3025F5A` |
| `room_peer.gd` | `5E1B24D66CA48522898667CF25C7FD324DDE520B8FC3A517F754725667A94D21` |
| `relay/server.mjs` | `B18DF48759793366701F29B22685E5F0F200DE81444735AC6BE6CD9BDFD5C8C7` |
| `world.gd` | `85DC26FF981CD7F3B06E1D74524958B74B34C97C450FA179865EAE78EE36E842` |

# Crown Court 0.5 Internet transport

Use built-in room-code WebSocket transport for the first locally testable implementation. The game opens an outbound WSS connection to an operator-owned relay; friends install only Crown Court. Keep simulation on the host and preserve the existing Godot RPC methods. A public TLS service and an exact-package test across separate homes are still required before describing Internet play as ready.

## Why this route

Godot includes a native WebSocket client with TLS. `MultiplayerPeerExtension` exposes packet, channel and identity hooks, allowing the small `room_peer.gd` adapter to deliver opaque packets to SceneMultiplayer. The Node relay neither implements Godot RPC nor deserializes its data. This matters because Godot's high-level protocol is an implementation detail. [WebSocketPeer](https://docs.godotengine.org/en/stable/classes/class_websocketpeer.html), [MultiplayerPeerExtension](https://docs.godotengine.org/en/stable/classes/class_multiplayerpeerextension.html), [SceneMultiplayer](https://docs.godotengine.org/en/stable/classes/class_scenemultiplayer.html).

The connection flow is create/join → version-checked registration → ready with room code and identity → Godot peer events → existing host welcome/seat allocation. Host ID is 1. Up to two friends get increasing IDs; clients send only to the host. The service generates 128-bit private room codes and verifies sender identity/routing. There are no game credentials or hosting secrets in the executable.

| Alternative | Suitability |
| --- | --- |
| Outbound WSS relay | Implemented locally without a native extension; ordinary HTTPS hosting; TCP stalls can block inputs and state together. |
| Native WebRTC with signaling and TURN | Better long-term candidate for a fast physics game because data channels can provide unreliable delivery. Friends still need no separate app, but the executable must bundle and test the native extension, signaling and TURN configuration. |
| ENet plus direct port/UPnP | Useful LAN/direct mode, but requires a reachable host mapping. UPnP configures the local gateway; it does not establish universal reachability through carrier NAT or another upstream router. It cannot satisfy a room-code-only promise by itself. |

Godot's documentation explicitly cautions about WebSocket latency for fast games. The choice reduces integration work; it does not prove satisfactory Internet feel. [WebSocket networking](https://docs.godotengine.org/en/stable/tutorials/networking/websocket.html).

Native WebRTC is a real alternative, not a browser-only feature: the Godot native extension supplies desktop support. It would need release-matched Windows binaries, five channel mappings, WSS signaling, STUN discovery and TURN fallback with short-lived credentials. TURN has its own ongoing bandwidth cost. Direct ICE success must never be assumed for every pair of homes. [Godot WebRTC](https://docs.godotengine.org/en/stable/tutorials/networking/webrtc.html), [native extension](https://github.com/godotengine/webrtc-native), [WebRTCMultiplayerPeer](https://docs.godotengine.org/en/stable/classes/class_webrtcmultiplayerpeer.html), [TURN requirements](https://webrtc.org/getting-started/turn-server), [UPnP API](https://docs.godotengine.org/en/stable/classes/class_upnp.html).

## Implemented boundary

`room_peer.gd` supplies `configure(url, create_room, code="", game_version="") -> Error`, `room_ready(code)` and `room_error(message)`. It remains CONNECTING until server registration succeeds and emits ready before peer-connected notifications. Plain WS is loopback only; production requires WSS with ordinary certificate validation. Five channels and their transfer-mode metadata are preserved, though all data ultimately shares TCP reliability and head-of-line blocking.

`relay/server.mjs` limits rooms, connections, frame size, rate, send buffers, registration time and stale sockets. Disposable packets may be dropped before enqueue when buffers are busy; reliable overflow closes the slow connection. Peer removal purges undelivered packets from that peer. Host exit or service restart ends the room; no migration or durable restoration is implied. Hosting is an operator responsibility, separate from the player's host role.

For the first deployment, use one continuously running Sydney instance with managed TLS. In-memory rooms require exactly one instance; multiple replicas would randomly split joins from hosts. The Docker and Fly configuration templates, operational constraints, current official hosting references and commands are in [relay/README.md](relay/README.md). No provider account, spend, public resource or network setting was changed. Available local CLIs do not demonstrate an authenticated hosting account.

## Evidence and limits

Local tests cover raw registration/version/full-room/invalid-code rejection, sender spoofing, forbidden routing, channel validation, rate/size bounds, lifecycle, and deterministic backpressure branches. Three native Godot processes exercise actual SceneMultiplayer RPCs on all five channels, large payloads and authoritative result delivery. A separate lifecycle probe confirms error text and host departure when the old adapter reference remains alive.

The delayed TCP test passes 8 KiB snapshots and actions through an actual loopback stream proxy with 40–60 ms delay each direction on both host and client legs. A 1.2 s downstream stall produced 1.23–1.28 s snapshot gaps and 1.39–1.48 s action round trips. All actions were eventually acknowledged; a departing client rejoined with a fresh identity and resumed actions. Snapshot flight stayed at four and the largest per-frame receive burst was three. This is simulated latency/stall evidence, not WAN packet-loss emulation, player enjoyment, production capacity, TLS deployment or real cross-home proof. Receipt: `build/crown-court-evidence/room-relay-stalled-tcp-final/wan-result.json`.

The RPC and delayed-stream wrappers accept `--pack <exe> --evidence <new-folder>` and load the runtime adapter from the embedded release pack. They record exact executable hashes before and after. Main integration and natural full-match tests are separate gates; a transport fixture's synthetic actions/result are not claimed as a full game.

Before public release: approve hosting and current costs, validate managed WSS with the exact build, then play and record one natural three-person match across separate home connections. Judge snapshot/action gaps and client controls alongside pass/fail results. If real TCP stalls are disruptive, move the game transport to bundled WebRTC/TURN while retaining the room-code UI and host simulation.

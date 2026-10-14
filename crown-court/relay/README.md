# Crown Court room relay

**Live service:** `wss://direct-metro.bnr.la/rooms`, deployed on the authorized BinaryLane Sydney Ubuntu server on 14 October 2026. Public TLS, native RPC, 42 family checks and a full three-client match passed. See [current receipts](../release-evidence/0.17.0-internet). Physical family devices remain a separate check.

The separate `CrownCourt-RoomRelay-0.5.0.zip` is a deployment bundle: extract it into its own directory and run `npm ci --omit=dev --ignore-scripts --no-audit --no-fund`, then `node server.mjs` for a loopback check. It includes the server, dependency lock, container/TLS templates and dependency notice. It does not include the game, repository test harnesses or `node_modules`; the verification commands below require the full repository.

## Public endpoint verification

Current Windows and Mac downloads embed the permanent endpoint. No adjacent configuration is required. An adjacent `internet.cfg` still overrides the embedded setting for operators; remove obsolete temporary configuration when updating.

After deploying an approved service, test the exact released transport over its public TLS endpoint:

```powershell
node crown-court/relay/godot-test.mjs --pack C:/game-3/CrownCourt.exe --url wss://YOUR-HOST/rooms --evidence build/crown-court-evidence/public-room-UNIQUE
```

This starts three isolated native clients and validates five RPC channels, identities, shared results and departures. It creates no local relay when `--url` is provided. Its receipt distinguishes public routing from physical separate-household play. Follow with the production family-network and active-match probes using the same endpoint, then a join from the children's house. The default UI hosts a discoverable game. No user-entered code is needed.

## Local operation commands

From the repository root, with Node 22+ (tested with 24.13.0):

```powershell
npm ci --prefix crown-court/relay --ignore-scripts --no-audit --no-fund
node crown-court/relay/server.mjs
```

Default is `ws://127.0.0.1:30220/rooms`; health is `http://127.0.0.1:30220/healthz`. Plain WebSocket is accepted by the game only for literal loopback hosts. `PORT` changes the listener; do not reuse the game's ENet port 28888. `HOST` defaults to loopback. A nonloopback listener requires direct certificate/key configuration or an explicit trusted TLS terminator.

Tests run their own hidden, bounded-lived Godot processes and relay, then close them. Run these **sequentially**; they reserve TCP 30220 and 30221:

```powershell
npm test --prefix crown-court/relay
node crown-court/relay/lifecycle-test.mjs
node crown-court/relay/godot-test.mjs --evidence build/crown-court-evidence/room-rpc-unique
node crown-court/relay/wan-test.mjs --evidence build/crown-court-evidence/room-tcp-unique
```

For an exported game, supply the exact executable containing its embedded PCK:

```powershell
node crown-court/relay/godot-test.mjs --pack C:/game-3/build/crown-court-0.5.0/CrownCourt.exe --evidence build/crown-court-evidence/v5-room-rpc-unique
node crown-court/relay/wan-test.mjs --pack C:/game-3/build/crown-court-0.5.0/CrownCourt.exe --evidence build/crown-court-evidence/v5-room-tcp-unique
```

Each destination must be new or empty. These wrappers use an absolute external test script and `--main-pack`; that script preloads `res://room_peer.gd` **from the exported pack**. Receipts record before/after executable SHA256, external probe SHA256 and server SHA256. Without `--pack`, the receipt records the adapter source hash. They do not measure the production match simulation or controller feel; main integration and full-match gates cover those separately.

## Protocol and limits

Protocol 1 registers an exact game-version string before the adapter reports connected. A room has host ID 1 and at most two friends. Rejoining gets a new monotonically increasing ID. Room codes encode 128 cryptographically random bits as 26 characters from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`. Unlisted rooms treat codes as private invitation capabilities. Listed hosts explicitly publish their room in GET `/lobbies`; full, locked and closed rooms are excluded. The game UI defaults to listed hosting and explains this visibility. The service does not log codes.

Registration/control messages are JSON. Game messages are opaque binary Godot packets with a 12-byte envelope: tag 1, channel 0–4, transfer mode 0–2, reserved zero, little-endian sender uint32 and target int32. The relay validates sender identity against its socket. Clients may target only the host; the host may address/broadcast only its own members. The relay never deserializes Godot variants or executes game RPCs. Host simulation remains authoritative and is trusted, as in LAN mode.

| Limit | Default |
| --- | --- |
| Game packet payload | 128 KiB |
| Send buffer soft/hard limit | 32 KiB / 256 KiB |
| Soft-limit treatment | Discard disposable transfer modes; preserve reliable packets |
| Hard-limit treatment | Close the slow connection |
| Incoming adapter queue | 512 packets / 256 KiB |
| Registration deadline | Server 8 s, adapter 12 s |
| Heartbeat / stale socket | 10 s / 30 s |
| Room lifetime | 2 hours |
| Service capacity bounds | 256 rooms / 800 sockets |
| Per-socket message rate | 240 frames/s and 1 MiB/s |
| Upgrade rate | 120/minute per immediate remote IP |

These are protective bounds, **not measured service capacity**. Behind a proxy the IP budget applies to the proxy address; it is not represented as end-user anti-abuse enforcement. The host leaving ends the room. There is no host migration, durable room state, reconnect replay, or restoration after server restart.

All five Godot channel identifiers and transfer modes survive the envelope, but WebSocket runs over one reliable TCP stream. It cannot provide ENet's independent packet-loss behavior. The recorded local test delays each stream direction 40–60 ms, on both the host and client relay legs, and stalls downstream delivery for 1.2 s. This is approximately 200 ms client↔host RTT before the stall, **not** 100 ms end-to-end and **not packet-loss emulation**. `droppedBytes` in its proxy receipt means pending bytes discarded after an endpoint closed during leave/rejoin; it is not injected loss.

The final source probe delivered and acknowledged all actions, rejoined with ID 4, held at most four 8 KiB snapshots in flight, and received at most three snapshots in one frame. It also measured 1.23–1.28 s snapshot gaps and 1.39–1.48 s action RTT during the stall. Those pauses are a real TCP head-of-line limitation. Socket buffers did not grow in that run; hard/soft backpressure branches are covered separately by deterministic socket-unit tests. Receipt: `build/crown-court-evidence/room-relay-stalled-tcp-final/wan-result.json`.

## Proposed deployment: one Sydney instance with managed TLS

Use the supplied Dockerfile and `fly.example.toml` as a reviewed starting point for **one** Fly Machine in `syd`. Fly currently lists Sydney; its proxy supplies managed TLS. The region is a proximity choice for Brisbane friends, not a latency guarantee. [Fly regions](https://docs.fly.io/reference/regions), [TLS](https://fly.io/docs/networking/tls/).

Before any account/resource action, the operator must approve the provider, account, app name and current estimated spend. Check current machine, IPv4 and egress pricing in that account. This repository intentionally does not promise an old fixed monthly price. [Current pricing](https://docs.fly.io/about/pricing).

After approval, the deployment sequence is:

1. Copy the example to `fly.toml`, replace the placeholder app name, select the approved account and keep `primary_region = "syd"`. Review/pin the Node container image digest for reproducibility.
2. Build from `crown-court/relay` only. The Docker context allowlist includes only the server and locked dependency manifests. Keep exactly one machine; disable HA replicas and automatic scaling. In-memory room lookup cannot span separate instances.
3. Expose only the managed HTTPS service, internally port 8080. Set `TLS_TERMINATED=1` only behind that trusted proxy; never expose port 8080 publicly. The relay also requires its `X-Forwarded-Proto: https` upgrade header. The header is a deployment check, not a substitute for controlling access to the backend. [Proxy headers](https://docs.fly.io/networking/request-headers), [configuration](https://docs.fly.io/reference/configuration).
4. Verify `/healthz`, trusted certificate/hostname, WSS upgrade, version/full-room errors and host departure on the deployed URL. Confirm all machines actually reside in Sydney and the instance count is one. Record deployment revision and image digest.
5. Run three copies of the **exact released executable** from separate home networks. Record ordinary movement/catch/pass/throw/dunk, a natural result, disconnect and rejoin, RTT/gaps and a rendered client recording. If TCP stalls harm play, keep the feature experimental and evaluate bundled native WebRTC with TURN.

Do not roll a new instance while games are active: a restart invalidates every room. Schedule maintenance with rooms empty. Monitor process health, memory, egress and connection counts; arrange a spending alert/limit supported by the provider. The health endpoint reports counts only. Certificates/secrets remain server-side. Budget planning example, not a bill: 1.6 KiB snapshots × 20/s × two friends is about 225 MiB/hour of relay egress before inputs, protocol overhead and retries.

Railway is a portable Docker alternative with managed TLS and supported WebSockets, but its current documented Asia-Pacific compute region is Singapore, not Sydney. An Australian edge entry point does not make the compute local. [Railway regions](https://docs.railway.com/deployments/regions), [WebSocket limits](https://docs.railway.com/networking/public-networking/specs-and-limits).

The Docker template has not been built here, and neither template has been publicly deployed. Local tests used plain loopback WS; successful public WSS and cross-home play remain separate release gates.

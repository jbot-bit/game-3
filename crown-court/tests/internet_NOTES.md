# Simulated internet regression harness

Run from the repository root, with Godot at `.tools/godot/Godot_v4.7.2-stable_win64_console.exe` and Node available on PATH:

```powershell
./crown-court/test-internet.ps1 -Scenario actions -Label internet-actions
./crown-court/test-internet.ps1 -Scenario load -Saturated -Label internet-large-load
./crown-court/test-internet.ps1 -Scenario timeout -Label internet-timeout
```

Each label must be new: evidence is preserved under `build/crown-court-evidence/<label>`. Use `-Pack C:/path/CrownCourt.exe` to load production code and test scripts from an exported executable that includes these resources. Receipts retain before/after pack hashes and source hashes. Source runs fail their receipt if source changes during execution. Pack runs gate on the immutable pack hash.

The harness binds only loopback UDP30180–30184 by default: host30180, client-facing proxy30181/30182, proxy upstream30183/30184. `-Port` relocates the range; port28888 is rejected. It starts three headless Godot processes and one Node proxy, closes only those owned processes, and never opens firewall rules or external services.

## What is exercised

- **Actions:** all11 inherited `network_actions.gd` checkpoints (catch/pass/tackle/physical shot/dunk/launch/extra jump/speed strip), production submit/RPC paths, identical final score1–1 observed by all three peers, then both graceful client departures. Host-only starting-position fixtures and three distant stunned bots are declared explicitly; possession and scoring are produced by actions, not granted by the harness.
- **Load:** 24seconds of six-player live simulation with bot commands submitted by three real peers. Records accepted snapshot arrival gaps, direct oversized-RPC arrival gaps, payload sizes, and application ping RTT. `-Saturated` adds384 deterministic incompressible bytes in a declared test-only snapshot field, asserting every encoded snapshot exceeds1200bytes. This is a transport benchmark fixture, not a human-play recording.
- **Timeout:** two clients attempt to connect through a100% packet blackhole to the isolated host. Both must visibly return to the production menu with a status message within18seconds; the host must remain alone in its lobby. This covers unreachable-host timeout, not abrupt loss of an already established connection.
- **Optional policy comparison:** `-Scenario load -Saturated -SingleSlot` substitutes the retained old one-outstanding-snapshot sender/ACK policy in a test subclass. Without `-SingleSlot`, overrides call the production methods unchanged. It is labeled `test_fixture_old_single_slot`; do not call it the current production behavior.

The default proxy adds50±10ms to every datagram in each direction, with independently seeded1% loss per direction. Seed7123 is deterministic by flow and packet ordinal; live gameplay packet sequences are not identical across runs. No bytes are changed. Delay/loss apply to ENet handshakes, control RPCs, ACKs, fragments, and snapshots. Timer scheduling and game ticks add latency: measured RTT can exceed the nominal80–120ms added round trip. Proxy receipts include actual delays, drops, datagram counts, and a schedule digest per flow.

`internet_proxy_test.mjs` checks the seed, varying40–60ms delay bounds, and1% distribution (91/10000 for its fixed test seed). A missing/broken proxy first failed this test before implementation.

## Reading results

`internet-result.json` contains process outcomes, packet/latency statistics, code identity, and proxy counters. All process logs are retained. A PASS requires successful process exits, no engine warning/error matches, role reports, and scenario assertions. Packets arriving in one render observation may be combined in `snapshot_arrival_gap_ms`; direct `consecutive_large_arrival_gap_ms` measures accepted consecutive oversized RPCs. `large_snapshot_arrival_gap_ms` includes intervening small-packet periods in unsaturated runs, so its high tail is not automatically a stall.

These are **simulated internet conditions on one computer**, not cross-home connectivity, NAT traversal, Wi-Fi performance, or human enjoyment proof. The proxy offers controlled impairment, while the full apps still share CPU scheduling. Loss can cause reliable retransmission bursts and residual stalls even when average cadence improves.

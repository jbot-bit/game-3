# Crown Court 0.4.0 verification

Windows, 11 October 2026. Godot 4.7.2, Compatibility renderer. Prior releases and sibling games are preserved; the preceding report is VERIFICATION-0.3.0.md.

This revision adds complete controller menus and private internet hosting/joining. Final executable SHA256: `892503559A4F8820FF072BE9A0A6DDAB800B8784C1B57DD743EB552050A7E1D5`. Tailscale is installed locally, but its live status was NeedsLogin. Desktop Godot reported no active joypads after a three-second discovery wait, although Windows listed a DualSense Bluetooth device. Those are setup limitations, not successful physical-controller or cross-home tests.

## Controller and connection behavior

Controller navigation covers mode selection, name/address entry, practice, host/join, pause, wardrobe, bags and rematches. Stick deadzones, trigger hysteresis, stable device selection and neutral-input rearming prevent drift and held-button activation on reconnect. Disconnecting cancels a charged shot and opens pause. Xbox and PlayStation labels are supported; mouse and keyboard remain usable.

The controller suite uses parsed InputEventJoypad events and a test-only discovered-device list because Godot provides no script API to register a physical controller. It tests production UI/input handling, native option popups and game actions. It does not establish hardware support for an unconnected device. Source and final rendered-pack verification passed all 64 checks, including two defects found by independent review: held confirm/back during reconnect, and held D-pad state after unplugging.

Address tests cover 38 cases: VPN IPv4 discovery, private LAN boundaries, duplicate adapters, IPv4/hostname parsing, optional ports and malformed input. The host displays separate Internet / VPN and LAN addresses. INTERNET_PLAY.txt and Check-Internet.cmd explain and diagnose the private connection without changing accounts or network settings.

## Internet transport

The old oversized-snapshot policy allowed one unacknowledged update per peer, which throttled updates as round-trip delay increased. The new policy permits four independently acknowledged updates per peer. It retains exact peer/round/sequence validation and discards unsent samples when full. It does not accumulate an unsent backlog. Small snapshots retain their separate unreliable channel; late reliable snapshots cannot rewind newer state. The real-ENet regression covers 21 cases, including maximum occupancy, wrong acknowledgements, early match-start packets, rematches and disconnect cleanup.

Three-process tests use an isolated UDP proxy with deterministic 50 +/- 10 ms delay each way and 1% packet loss in each direction. Sustained-load tests explicitly add 384 deterministic bytes to test snapshots so every packet exceeds 1200 bytes. They still run six-player matches, but are transport fixtures, not footage of an unmodified match.

The controlled source comparison encoded 480 snapshots per run, all at least 1358 bytes (maximum 1845). The previous single-slot policy sent 309 reliable updates and discarded 651 samples; client median consecutive-update gaps were about 150 ms, with 174-175 ms at the 95th percentile. Production's four-slot policy sent 920 updates and discarded 40 samples; median gaps were about 50 ms, with about 67 ms at the 95th percentile. Maximum gaps still reached 208-225 ms due to loss/retransmission. Live match trajectories differ; this is a controlled sustained-payload condition, not identical game playback or a claim of zero stalls.

Evidence: ../build/crown-court-evidence/internet-controlled-single/ and internet-controlled-window4/. Explicit old-policy comparison uses only a test subclass. Production never selects that policy.

The final exported pack repeated all three WAN gates. All 11 action checkpoints agreed across three peers, including the 1-1 score and graceful leaving. Its saturated run encoded 480 packets of 1345-1822 bytes, sent 916 reliable updates and coalesced 44 samples. Median update gaps were 49.984/49.998 ms; p95 66.939/67.247 ms; maxima 224.448/217.228 ms. Median measured application RTT was about 116.8 ms; the proxy dropped 61 of 6819 datagrams. Both completely blackholed clients returned to the menu after about 12.02 seconds. Every run preserved the exact executable hash and clean logs.

An initial packaging regression exposed two test assumptions: it checked one receiver's held-packet count after waiting only for another peer, and required unreliable delivery within roughly half a second. An instrumented failing run received no small datagram in that interval. ENet's burst throttle measured 4/32; a later successful run needed 674 ms. The repaired test synchronizes actual held delivery and runs a bounded small-packet stream until a genuine new state arrives while all four reliable slots remain occupied. Every held packet is then checked for non-rewind. Source and final embedded-pack 21-case regressions pass; production transport was not changed to satisfy the test. The failed candidate and diagnostic traces remain in the evidence folder.

Action tests verify both passes, catch, tackle/drop, throw, physical dunk/scoring, launch, extra jump and speed boost across the host and two clients. A blocked-connection test drops all packets and verifies that both clients return to the menu after the game's connection timeout. These are simulated network conditions on one PC; real ISP routing, NAT traversal, Tailscale direct/DERP paths and Wi-Fi contention are not established by them.

## Release gates

The build checks simulation, profiles, complete matches, application/reward/session flow, adversarial network cases, world continuity, keyboard gameplay, the continuous spawn-to-dunk route and rendered controller flow against the embedded game. The network matrix covers eight 2/3-client configurations and eleven shared action checkpoints.

All eight configurations and all eleven shared action checkpoints passed against the final executable, using loopback and this PC's LAN interface. This includes balanced/unbalanced 2v1, two/three humans versus bots, late join, free-for-all, cosmetics, rewards and rematch flow.

The complete offline recording finished naturally at 140.18 game seconds, 6-2, with five bots, all tracked action categories, no match fixtures and the correct one-bag reward. Its 140.37-second fixed-clock movie is not a performance benchmark. The complete three-client recording finished 5-1 at about 81.45 seconds, with the same winner/match on all peers and one earned bag each. The joining client's 871 timestamped frames produce an 82.54-second real-time video. Both recordings have zero focus recoveries and clean logs. The joining client attempted two shot releases but did not record a confirmed local throw; this video is not claimed as successful shot coverage. Actual network shooting is covered by the separate action checkpoints, and the offline movie includes three confirmed local throws.

The offline movie SHA256 is `499D430F7D7D31FD5CFEEDEAAEF3767E470747EED909F87A1F40765F793CFD81`; the network movie is `EB2DF812487D311EC3F9BED3FDECBF91808CDA50C892093738FC323A5B7F86F1`. UI and event-footage review reports sit beside their captures. Brief Giant occlusion and crowded labels remain documented; there is no zero-jitter or hardware-play claim.

Packaging requires the exact executable hash in the rendered, network and simulated-internet receipts; completed offline and three-client recorded matches; unchanged production source; video checksums; and a fresh ZIP extraction/native startup. The final versioned receipts are v4-final-playtest-results.json, v4-final-network-verified.json, v4-final-internet-{actions,load,timeout}/internet-result.json and v4-final-release-results.json in ../build/crown-court-evidence/. A build is not released merely because this file exists; those receipts must pass.

## Playtest remaining

Connect a real controller and confirm the physical buttons/sticks from the menu through a complete match, bag and rematch. Check unplug/reconnect, stick drift and Bluetooth versus USB behavior.

For internet play, sign in to Tailscale on each PC and establish membership or host-device sharing. Send the same ZIP to your friends, host, and join the displayed 100.x address. Finish a separate-home match and compare catches, passes, contested dunks, scores, rewards, disconnect/rejoin and rematches. Record whether the connection is direct or relayed, plus latency and any visible corrections.

No physical-controller success, separate-home match, exact Crown Jam equivalence, human enjoyment rating or public upload is claimed. See HOUSEHOLD_TEST.txt for the short sequence.

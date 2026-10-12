# Crown Court — basketball

**[Download CrownCourt.exe — 64-bit Windows](https://github.com/jbot-bit/game-3/raw/refs/heads/main/CrownCourt.exe)** · **[32-bit Windows](https://github.com/jbot-bit/game-3/raw/refs/heads/main/CrownCourt32.exe)**

**0.11.0** · One file, double-click to play. No installer or engine required. The 64-bit download is 110,797,256 bytes (about 106 MiB); the 32-bit download is 123,129,208 bytes (about 117 MiB). Choose the build matching Windows System type. Both architectures can play together on the same version.

1–3 players · practice and LAN. Three friends can play against three bots, or choose teams with optional bot balancing. Easy bots are the default; Normal and Hard are selectable. Shots follow your aim and charge. This update adds stronger knockback, faster dunks and a lower, more open court.

One person chooses **Host**; the others choose **Join** and enter the lobby address. Keyboard: WASD move, mouse look, Space jump/double jump, left click catch/pass, right click tackle/shoot, F dunk. Press F1 for controls. Controller software checks pass; physical mixed-controller testing remains outstanding. [License notices](CrownCourt-Licenses.txt).

Internet hosting is prepared but not deployed. Separate-home play is not enabled. Automated two/three-client and mixed-architecture checks pass; the son's PC and a real household match still need testing.

---

# Hands Full

Windows physics party game for up to three people on the same home network.

## Download and play

[Download HandsFull.exe](https://github.com/jbot-bit/game-3/releases/download/hands-full-v0.8.0/HandsFull.exe) on each PC and double-click it. This is one self-contained file; no installer, extraction, Godot installation or account is required. [Release notes and optional ZIP](https://github.com/jbot-bit/game-3/releases/tag/hands-full-v0.8.0).

One player enters a name, picks a mode and chooses **Host game**. Press **Esc → Copy address**; the others enter that address and choose **Join**. Use the same version and home network. If Windows asks, allow private-network access. The host keeps shared progress.

- **Knockout:** stay on the circular pad and knock opponents off. Sweepers accelerate every fifteen seconds; warning beats precede the changes. After thirty seconds the physical arena shrinks, forcing everyone closer. Last standing wins the round; first to three wins the match.
- **Gladiator:** padded-stick arena fights, with directional bracing and first-to-three scoring.
- **Wipeout:** race tipping beams, sweepers and jump platforms through three checkpoints.
- **Co-op:** twenty courses, each ending with a three-person bridge, lift and cargo challenge. Earn saved powers and three-card cosmetic bags.

Knockout and Gladiator support two or three competitors, plus solo practice. Wipeout supports one to three players; co-op clears require three. WASD moves, mouse looks, Space jumps, LMB swings and RMB braces in ring matches. Full mode controls appear in the illustrated opening menu. Credits and complete third-party licenses are included in the executable.

[Full controls](prototypes/physics_party/README.md) · [Verification and limits](docs/playtest/HANDS_FULL_STATUS.md) · [Developer handover](docs/playtest/DEVELOPER_HANDOVER.md)

## Development

Godot 4.7.2, Compatibility renderer, Jolt physics, native ENet. Run `prototypes/physics_party/main.tscn`. Build with `powershell -ExecutionPolicy Bypass -File tools/build_hands_full.ps1 -ReleaseName hands-full-0.8.0 -RenderSmoke`. Engine and matching templates must exist in `.tools`, as described in [third-party provenance](THIRD_PARTY.md).

Three-process checks: `tests/integration/run_physics_party_knockout_network_probe.ps1`, `run_physics_party_modes_network_probe.ps1` and `run_physics_party_network_probe.ps1`. Each accepts `-ExportedPack` pointing to the final executable. Tests use isolated saves. Household progress is `%APPDATA%\OneMoreCast\physics_party\progress.json`.

This repository preserves the earlier One More Cast history. Its separately published fishing game is available from the [One More Cast 0.4.1 release](https://github.com/jbot-bit/game-3/releases/tag/one-more-cast-v0.4.1) and `codex/one-more-cast-v0.4.1` source branch. Hands Full has its own export, network port and save.

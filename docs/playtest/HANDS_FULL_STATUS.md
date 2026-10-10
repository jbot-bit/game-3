# Hands Full 0.1.0 — family build verification

Verified 10 October 2026 on Windows. **A locally packaged, playable first release:** one compact co-op course, five powers, saved power collection and replay. It is not a finished Human Fall Flat-sized campaign or a human-validated fun game. No public release/upload was performed.

## Playable output

- `build/hands-full/HandsFull.exe` — 109,520,112 bytes; standalone embedded game data.
- `build/HandsFull-windows.zip` — 38,342,385 bytes; executable, joining/controls README, PiCode MIT and Godot notices.
- EXE SHA-256: `268f71416fdcb5f8ec52620a0dc7b4109eb533370afae2d989ff94713dd3c8e9`.
- ZIP SHA-256: `da326a47827e3d8c13596001516afada51a0e3c96f90471fe2d55f86456088d8`.

Extract the ZIP on each PC and run `hands-full/HandsFull.exe`. Host once; Esc shows join addresses, with common home-LAN addresses first. Other players enter the host address. Use the same build on the same home network. The shared power collection belongs to the host's save.

## What changed

The new default scene is the co-op physics game under `prototypes/physics_party/`. The old fishing game, export preset and household save are preserved. Current play uses independently grabbing hands, movable planks/blocks, a seesaw, a reversible fan, checkpoint recovery and a shared finish. A clear collects the powers the crew actually used; later runs permit those saved choices alongside three random offers.

Three agents worked on physics, course/presentation and progression/review while the parent integrated networking, camera and packaging. Independent code/design review caught the power-screen Esc trap, a save retry losing a departing player's power, unclear grabbing instructions, mismatched camera/character timing and camera collision against teammates. These were corrected. The course test led to lighter raised planks, a shorter first gap, gentler wind and a wider landing.

The camera follows the rendered torso, separates smooth following from immediate mouse orbit and ignores crew/loose props when checking obstruction. Remote bones and props share one bounded 67 ms source-time presentation buffer, fed at 30 Hz. Host physics remains at 60 Hz. This does not add client movement prediction or internet rollback.

Presentation now has readable navy-backed text, small original power symbols, face direction cues, subtle beveled edges and soft contact shadows. No shadow maps, postprocessing stack or extra rendering plugin was installed.

## Measured checks

| Check | Result and evidence | Limits |
|---|---|---|
| Focused unit/regression suite | **37 tests, 626 assertions passed**; `logs/party-unit.log` | Rules, saves, menus, camera, audio lifecycle and presentation logic; not human enjoyment |
| Physical puppet native probe | **51 checks passed**, no engine warnings/errors; `.tools/research/party-puppet-polish-native.log` / puppet probe script | Real joint/grab/limp/jump/recovery and remote rendering; several interactions use setup fixtures |
| Natural course traversal | Native and headless controller-input route reached the actual goal in **17.30 s**; `logs/hands-full-course.json`, `logs/hands-full-course-native.log` | One scripted player, initially spawned only; does not measure family session length. Plank grabbed at 3.37 s and moved 9.13 m. **Successful bridge placement remains unproven**; jumping via the checkpoint/stepping stone is proven |
| Three-process source networking | **169 checks passed**, three clean exits and no engine warnings/errors; `.tools/physics-party-network-probe/20261010T024949225_8ff0437c/summary.json` | One computer, real ENet loopback; completion/lever position fixtures isolate state/save rules |
| Exact exported pack networking | **169 checks passed**, three clean exits and no engine warnings/errors; `.tools/physics-party-network-probe/20261010T025549038_7cb578c2/summary.json` | Matching engine loads the embedded release pack from its clean folder. Official release templates prohibit external script overrides, so this is not three instrumented release EXEs |
| Actual executable | Clean-folder headless startup and native OpenGL rendering passed; `build/evidence-20261010T025249208/` | Menu/startup smoke, separately from the exported-pack gameplay test |
| Package inspection | 25 embedded resources; required runtime scripts/model present; no legacy game/assets, tests, tools or development directories | First scene-only export omitted script preloads; actual-EXE smoke caught it. Final preset exports runtime resources with explicit exclusions and dependency checks |
| UI | Rendered menu, gameplay, completion and all eight power buttons inspected at 1280×720 / 960×540 | Native screenshots in `logs/hands-full-*.png`; some collection/finish screens use explicit fixtures |

The exported-pack motion probe reached its **0.1 m visible-movement threshold** in 166 ms on the host and 291/292 ms on clients. This includes body acceleration, the render buffer and 30 Hz observation; it is **not hardware input latency**. Real Wi-Fi feel is unmeasured.

### Render performance

Native OpenGL Compatibility renderer, RTX 4070 Laptop GPU, 1280×720, three host-simulated puppets (30 physical bones), seven props, scripted movement/grabs/jumps. Ten seconds after a three-second warmup, vsync off, FPS uncapped for measurement:

- 5,539 sampled frames; mean **1.806 ms**, p95 **3.041 ms**, p99 **3.341 ms**, maximum **4.161 ms**.
- **0 frames over 16.7 ms** in this bounded sample; 67 draw calls at capture.
- Bodies remained finite; native recovery reached completion.
- Evidence: `logs/hands-full-native.json`, `logs/hands-full-native.stdout.log`, empty stderr.

The normal game caps at 120 FPS. This test had **no network clients** and says nothing conclusive about weaker GPUs, heavy background RAM use, long-session stability or subjective control quality. The three-process networking check is separate.

## Remaining practical limits

- One short introductory course; the original 6–10 minute session target and long-term replay appeal are not established. Five collected choices are light progression, not a large RPG.
- Actual three-PC household play, Wi-Fi jitter, helping/grabbing under real player inputs and performance on the other machines remain untested.
- Pickup and movement are proven; reliable solo plank bridge placement still needs free play. The ordinary jump route avoids making exact placement mandatory.
- Keyboard/mouse only. No controller support, internet matchmaking, PvP scoring or campaign.
- Sound lifecycle and generated samples were checked; speaker quality has not been subjectively auditioned.

## Repeat verification

`tools/build_hands_full.ps1 -RenderSmoke` produces the package only after import/export, pack inspection and actual-EXE smoke checks pass.

`tests/integration/run_physics_party_network_probe.ps1 -ExportedPack C:/game-3/build/hands-full/HandsFull.exe` tests the exact embedded game resources using the matching Godot runtime. Omit `-ExportedPack` for source testing.

The most useful next evidence is one real three-PC run: each person should move, grab a prop or player, fall/recover, finish, choose a saved power and replay. Fix the largest observed control or pacing problem before adding another system.

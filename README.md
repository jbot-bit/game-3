# Hands Full

**Windows · 1–3 players · same home network · 0.1.1 family build**

Grab a friend. Move the props. Get everyone across. A small co-op physics game with five random powers, a saved collection and a fan that any player can reverse for everyone.

## Play

Extract `build/HandsFull-windows.zip` on each PC and start `hands-full/HandsFull.exe`. One person hosts; press **Esc** to see the join address. The others enter that address and join. Pick a power, finish together and keep the powers you used for later runs.

[Controls and joining](prototypes/physics_party/README.md) · [Verified build and limitations](docs/playtest/HANDS_FULL_STATUS.md) · [Short developer handover](docs/playtest/DEVELOPER_HANDOVER.md)

## Develop

The default Godot scene is `prototypes/physics_party/main.tscn`. Use Godot 4.7.2, Compatibility rendering and built-in Jolt. The folder name records where the replacement began; this is now the active game.

Build: `powershell -ExecutionPolicy Bypass -File tools/build_hands_full.ps1 -RenderSmoke`.

Network check: `powershell -ExecutionPolicy Bypass -File tests/integration/run_physics_party_network_probe.ps1`.

The Windows builder checks the engine/template, embedded resources and actual executable startup before packaging. Saves live in `%APPDATA%\OneMoreCast\physics_party\progress.json`.

Research and exact source/license decisions: [physics reuse](docs/research/2026-10-10-physics-reuse.md). `tools/fetch_research_sources.ps1` fetches the pinned references. Only the MIT PiCode controller/model is adapted into this game.

The previous fishing game remains under `game/`, with its `Windows Desktop` export preset and separate save. [Its original README](docs/archive/ONE_MORE_CAST_README.md) is historical, not the current game's instructions.

# Crown Court — basketball

**[Download CrownCourt.exe — 64-bit Windows](https://github.com/jbot-bit/game-3/raw/refs/heads/main/CrownCourt.exe)**

**0.16.0** · One file, double-click to play. No installer or engine required. Use this version on every PC. This release updates the standard 64-bit build only; the older 32-bit download is not a matching release.

1–3 players · practice and LAN. Play as Dad, Evie or Tyler against bots, or choose custom teams. New in 0.16: walk into the ball to pick it up, shot assist with a sweet-spot meter (toggle on the menu), match intro and score-cam cutscenes with confetti and announcer lines, MVP and stats at full time, hit-stop on tackles, faster Hype, and a fully dressed stadium. Characters, equipment and unlocks are preserved.

One person chooses **Host**; the others choose **Join** and enter the lobby address. Keyboard: WASD move, mouse look, Space jump/double jump, left click catch/pass, right click tackle/shoot, F dunk. Press F1 for controls. Easy bots are the default; Normal and Hard are selectable. [License notices](CrownCourt-Licenses.txt).

The editable game and family-character authoring files are backed up in [crown-court](crown-court). [Controls](crown-court/README.md) · [Release notes](crown-court/CHANGELOG.md) · [Verification and limits](crown-court/VERIFICATION.md) · [Player feedback](crown-court/PLAYER-FEEDBACK-0.15.1.md).

Internet hosting remains undeployed. Local automated multiplayer checks do not establish physical three-PC/controller testing, human enjoyment or exact original-game physics.

---

# One More Cast

**The fishing survival game is the default again. Windows · 1–3 players · home-network co-op.**

Catch strange fish, bank your haul, find better equipment, and make it home before the island's night hunter catches you. Repair Moth and the beacon, then escape together. Short outings, shared progress, chunky block characters and a small island to learn.

## Play the fishing game

Download **OneMoreCast-0.4.1-windows.zip** from [GitHub Releases](https://github.com/jbot-bit/game-3/releases/tag/one-more-cast-v0.4.1), extract it, and run `windows/OneMoreCast.exe`. No Godot installation is needed. Choose **Host a game → Start island** to play alone or host the crew; this continues your saved island. Other PCs use the same build and join the host's home-network address.

**WASD** move · **right mouse drag** camera · **wheel** zoom · **LMB** cast · **E** interact/bank · **R** carry · **F** lantern · **K** equipment · **J** journal · **B** ready for refuge · **Esc** pause/help. While fishing, **hold left click to move your bar right; release to move it left**. Keep the moving fish line inside your bar to fill the catch meter. Normal fish take about 5–8 seconds with good tracking; rare fish take longer. Bank at Moth to keep your catches; earned gear and repairs survive a failed outing.

Catches reveal their actual species, trait, size and value, with collection and crew-record badges. The next-step card guides you from your first catch through the essential boat and beacon repairs, then the night escape. It shows where to go and how many coins you still need. Whole fish show **hold P to pack**, and nearby shelters show their real protection and remaining power even during a catch reveal. Fresh settings enable shadows and smooth edges; both can be switched off in Settings, and existing saved choices are respected.

The host's existing save remains at `%APPDATA%\OneMoreCast\household.json`. Use Continue to keep it. New Island asks before archiving and resetting it.

Open `project.godot` in Godot 4.7.2 and press **F5** for fishing. Build it with `powershell -ExecutionPolicy Bypass -File tools/build_windows.ps1 -RenderSmoke`. Full fishing controls and campaign details: [fishing guide](docs/archive/ONE_MORE_CAST_README.md). Earlier test results: [campaign evidence](docs/playtest/CAMPAIGN_STATUS.md).

## Hands Full — separate physics game

**Windows · 1–3 players · same home network · 0.8.0 family build**

[Download HandsFull.exe](https://github.com/jbot-bit/game-3/releases/download/hands-full-v0.8.0/HandsFull.exe). Download the same file on every PC and double-click it. No extraction or Godot installation is needed. [Release notes and optional ZIP](https://github.com/jbot-bit/game-3/releases/tag/hands-full-v0.8.0).

Choose **Knockout** for the circular last-player-standing arena: padded-stick shoves, warning beats, accelerating sweepers and a floor that shrinks as the round progresses. The first to three round wins takes the match. **Gladiator** keeps its foam-stick ring-outs; **Wipeout** races over tipping beams and moving hazards; **Co-op** retains twenty courses and the three-person bridge, lift and cargo stages. Your saved powers and cosmetic surprise bags are preserved.

Enter your name, select a mode and choose **Host game**. Press **Esc → Copy address**. The other PCs enter that address and choose **Join**. Allow the game on the private network if Windows asks. Gladiator and Knockout need two or three players to compete; one player can practice. Wipeout supports solo; co-op clears require three players.

**WASD** move · **mouse** look · **Space** jump · **LMB** swing · **RMB** brace · **Esc** menu. Co-op has its own grab/grapple controls shown in the menu. The original illustrated opening screen, spectator guidance and embedded Credits work inside the standalone executable.

[Controls and joining](prototypes/physics_party/README.md) · [Verification and limits](docs/playtest/HANDS_FULL_STATUS.md) · [Developer handover](docs/playtest/DEVELOPER_HANDOVER.md)

## Develop

For Hands Full, run `prototypes/physics_party/main.tscn` directly, or use its separate export preset. Use Godot 4.7.2, Compatibility rendering and built-in Jolt. Its `hands_full` export feature selects the physics scene independently of the default fishing scene.

Build: `powershell -ExecutionPolicy Bypass -File tools/build_hands_full.ps1 -ReleaseName hands-full-0.8.0 -RenderSmoke`.

Network check: `powershell -ExecutionPolicy Bypass -File tests/integration/run_physics_party_network_probe.ps1`.

The Windows builder checks the engine/template, embedded resources and actual executable startup before packaging. Saves live in `%APPDATA%\OneMoreCast\physics_party\progress.json`.

Research and exact source/license decisions: [physics reuse](docs/research/2026-10-10-physics-reuse.md). `tools/fetch_research_sources.ps1` fetches the pinned references. Only the MIT PiCode controller/model is adapted into this game.

The fishing game is under `game/` and uses the `Windows Desktop` export preset. The two games retain separate saves and Windows packages.

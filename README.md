# One More Cast

**The fishing survival game is the default again. Windows · 1–3 players · home-network co-op.**

Catch strange fish, bank your haul, find better equipment, and make it home before the island's night hunter catches you. Repair Moth and the beacon, then escape together. Short outings, shared progress, chunky block characters and a small island to learn.

## Play the fishing game

Download **OneMoreCast-0.4.1-windows.zip** from [GitHub Releases](https://github.com/jbot-bit/game-3/releases/tag/one-more-cast-v0.4.1), extract it, and run `windows/OneMoreCast.exe`. No Godot installation is needed. Choose **Host a game → Start island** to play alone or host the crew; this continues your saved island. Other PCs use the same build and join the host's home-network address.

**WASD** move · **right mouse drag** camera · **wheel** zoom · **LMB** cast · **E** interact/bank · **R** carry · **F** lantern · **K** equipment · **J** journal · **B** ready for refuge · **Esc** pause/help. While fishing, **hold left click to move your bar right; release to move it left**. Keep the moving fish line inside your bar to fill the catch meter. Normal fish take about 5–8 seconds with good tracking; rare fish take longer. Bank at Moth to keep your catches; earned gear and repairs survive a failed outing.

Catches reveal their actual species, trait, size and value, with collection and crew-record badges. The next-step card guides you from your first catch through the essential boat and beacon repairs, then the night escape. It shows where to go and how many coins you still need. Whole fish show **hold P to pack**, and nearby shelters show their real protection and remaining power even during a catch reveal. Fresh settings enable shadows and smooth edges; both can be switched off in Settings, and existing saved choices are respected.

The host's existing save remains at `%APPDATA%\OneMoreCast\household.json`. Use Continue to keep it. New Island asks before archiving and resetting it.

Open `project.godot` in Godot 4.7.2 and press **F5** for fishing. Build it with `powershell -ExecutionPolicy Bypass -File tools/build_windows.ps1 -RenderSmoke`. Full fishing controls and campaign details: [fishing guide](https://github.com/jbot-bit/game-3/blob/one-more-cast-v0.4.1/docs/archive/ONE_MORE_CAST_README.md). Earlier test results: [campaign evidence](https://github.com/jbot-bit/game-3/blob/one-more-cast-v0.4.1/docs/playtest/CAMPAIGN_STATUS.md).

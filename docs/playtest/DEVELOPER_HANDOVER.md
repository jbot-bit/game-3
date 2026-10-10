# One More Cast — developer handover

**The game:** a standalone, three-player Windows LAN fishing/survival game. Catch fish for shared coins, find the engine and beacon parts, repair them, signal at night and escape together. Outings last up to 10.5 minutes. Saved equipment, outfits, discoveries and repairs carry over.

**The fun choices:** ordinary fish pack automatically; oversized fish can be carried/thrown for a bigger reward or packed when danger rises. Anyone can commit the dock battery to one shelter, leaving the other dark. Rescue teammates and bring spare cells. No hunger chores or full ragdoll controller.

**Priority:** smooth movement and clear, fun interactions before prettier graphics or more features. Keep the island compact and menus short. Gear has three choices: rod, lantern, outfit.

**Start here**

- Code: `C:\game-3`; Godot 4.7.2, GDScript. Open `project.godot` in the bundled editor at `.tools/godot/Godot_v4.7.2-stable_win64.exe`, then F6 on the main scene or F5 to run the project.
- Play: `build/windows/OneMoreCast.exe`. Share `build/OneMoreCast-windows.zip` across the three PCs. One hosts; two join its LAN address.
- F3 shows performance; Escape opens settings/Help; F8 opens the host's test controls.
- Main files: `game/main.gd` (input/wiring), `game/player/` (movement/camera), `game/expedition/run_controller.gd` (host gameplay), `game/world/` (map/art), `game/ui/hud.gd` (screens), `game/progression/` (gear/saves).

**Current state:** build 0.3.0-coast; 285 logic tests and 462 LAN checks passed. Earned equipment and full escape/save were exercised. Remote movement/camera corrections are smoothed; shadows default off. The package starts successfully. The actual three PCs, weakest laptop, free-play feel and replay enjoyment still need testing. Startup/first-night hitches were observed; steady-state benchmark results do not cover every scene. Full evidence: [CAMPAIGN_STATUS.md](CAMPAIGN_STATUS.md).

**Next prompt:** “Continue One More Cast in C:\game-3. Play one outing with us, collect FPS and each player's biggest frustration, then fix the biggest demonstrated problem. Preserve saves, keep multiplayer working, and add no new systems until the core feels good.”

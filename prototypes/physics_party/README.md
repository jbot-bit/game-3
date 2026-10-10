# Hands Full

A small co-op physics game for up to three players on Windows LAN. Grab a friend, move a plank, balance the seesaw and get everyone across. Anyone can reverse the fan for the whole crew.

## Play together

1. Extract `HandsFull-windows.zip` on each PC. Open `hands-full/HandsFull.exe`.
2. Enter a name. One player chooses **Host game**. Press **Esc** to see the host's join address.
3. The other players enter that address and choose **Join**. Use the same home network and the same build.
4. Pick a power. Get everyone to the far platform. Choose **Another run** to play again.

No editor, account or internet service is required. If Windows asks, allow the game on your private network. UDP port: 24573. Guest Wi-Fi isolation can prevent joining; port forwarding is unnecessary.

## Controls

| Input | Action |
|---|---|
| WASD / mouse | Move / look |
| Hold left or right mouse | Reach and grab with that hand; release to let go |
| Space | Jump |
| Hold R | Go floppy; release to stand up |
| E near the fan lever | Reverse the wind for everyone |
| F | Recover at your checkpoint |
| Esc | Menu and host join address |
| M / F3 | Mute / FPS display |
| 1 / 2 / 3 | Choose a random power |

Look toward the thing you want to grab. Look up to lift it. Release a hand if it catches the floor or a support. Move objects or help each other to reach the exit. Falling returns you to your checkpoint; loose props also recover if they fall away.

## Progress

Choose one of three random powers: a stronger jump, extra weight, faster movement, gentler falling or stronger arms. Finish the course and the powers your crew used become permanent **Collected powers**. On later runs, each player can choose a collected power instead of a random offer. Keep using the same PC as host: it stores the crew's shared collection and clear count.

Only successful clears save new powers. Failed saves show **Retry save**. No coins, inventory sorting, equipment durability or escalating grind. Crew level is a record of clears; it does not make one player stronger than another.

Save: `%APPDATA%\OneMoreCast\physics_party\progress.json`. The parent folder is retained for compatibility. The previous fishing game's `household.json` is separate.

## Build scope

This first family release contains one compact course, five powers and immediate replay. It is a small standalone game, not a finished Human Fall Flat-sized campaign. Keyboard and mouse are supported; controllers, internet matchmaking and competitive scoring are not included. Actual three-PC responsiveness and family enjoyment still need a household play session.

## Source

Open `project.godot` in Godot 4.7.2, or run the project's default scene. Build: `powershell -ExecutionPolicy Bypass -File tools/build_hands_full.ps1 -RenderSmoke`.

- `main.gd`: input, camera, shared state, recovery and completion.
- `puppet.gd` / `puppet.tscn`: active physical bodies, hand joints and smooth rendering.
- `party_world.gd`: course geometry, props, fan and checkpoints.
- `party_session.gd`: host-authoritative LAN protocol and pose delivery.
- `party_hud.gd` / `party_rules.gd`: screens, power choices and atomic saves.
- `party_audio.gd`: short original sound cues generated once at startup.

The controller/model adapts PiCode9560's MIT-licensed active-ragdoll project. The adaptation adds per-player input, fixed-step control, remote presentation, recovery and LAN integration. See `vendor/picode/PROVENANCE.md`. Other researched repositories were references, not bundled frameworks. Current test evidence is in `docs/playtest/HANDS_FULL_STATUS.md` in the source project.

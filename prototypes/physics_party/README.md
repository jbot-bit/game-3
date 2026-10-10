# Hands Full

A small co-op physics game for up to three players on Windows LAN. Grab a friend, move a plank, balance the seesaw and get everyone across. Anyone can reverse the fan for the whole crew.

## Play together

1. Extract `HandsFull-windows.zip` on each PC. Open `hands-full/HandsFull.exe`.
2. Enter a name. One player selects a course and chooses **Host game**. Press **Esc** to see the host's join address.
3. The other players enter that address and choose **Join**. Use the same home network and the same build.
4. Pick a power. Get everyone to the far platform. The host chooses **Play again** or **Next course**.

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

Look toward the thing you want to grab. Look up to lift it. Release a hand if it catches a support. Falling returns you to your checkpoint; loose props also recover if they fall away.

**First Crossing:** cross the loose bridges, then balance the seesaw and jump to the finish.

**Counterweight:** put blocks on the low end of the tipping board, or have a friend steady it. Blocks can stay when that friend follows. Reach the checkpoint, turn right and cross the loose planks. The fan lever affects the whole crew.

The menu keeps the game running and releases your hands. If the bridges get stranded, the host can choose **Esc → Restart course**. This restarts for everyone; collected powers stay saved.

## Progress

Choose one of three random powers: a stronger jump, extra weight, faster movement, gentler falling or stronger arms. Finish the course and the powers your crew used become permanent **Collected powers**. On later runs, each player can choose a collected power instead of a random offer. Keep using the same PC as host: it stores the crew's shared collection and clear count.

Only successful clears save new powers. Failed saves show **Retry save**. No coins, inventory sorting, equipment durability or escalating grind. Crew level is a record of clears; it does not make one player stronger than another.

Save: `%APPDATA%\OneMoreCast\physics_party\progress.json`. The parent folder is retained for compatibility. The previous fishing game's `household.json` is separate.

## Build scope

This family release contains two compact courses, five powers and immediate replay. Keyboard and mouse are supported; controllers, internet matchmaking and competitive scoring are not included. Actual three-PC responsiveness and family enjoyment still need a household play session.

## Source

Open `project.godot` in Godot 4.7.2, or run the project's default scene. Build: `powershell -ExecutionPolicy Bypass -File tools/build_hands_full.ps1 -RenderSmoke`.

- `main.gd`: input, camera, shared state, recovery and completion.
- `puppet.gd` / `puppet.tscn`: active physical bodies, hand joints and smooth rendering.
- `party_world.gd`: First Crossing, shared props, fan and checkpoints.
- `party_counterweight_world.gd` / `party_courses.gd`: Counterweight geometry and the two course IDs.
- `party_session.gd`: host-authoritative LAN protocol and pose delivery.
- `party_hud.gd` / `party_rules.gd`: screens, power choices and atomic saves.
- `party_audio.gd`: short original sound cues generated once at startup.

The controller/model adapts PiCode9560's MIT-licensed active-ragdoll project. The adaptation adds per-player input, fixed-step control, remote presentation, recovery and LAN integration. See `vendor/picode/PROVENANCE.md`. Other researched repositories were references, not bundled frameworks. Current test evidence is in `docs/playtest/HANDS_FULL_STATUS.md` in the source project.

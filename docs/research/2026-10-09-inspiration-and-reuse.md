# One More Cast — inspiration and repository decisions

Checked 9 October 2026. Research is read-only: source pages/code/licences were inspected; no repositories or dependencies were installed and no integration test has run. The design remains in `C:\game-3\ONE_MORE_CAST_PLAN.md`; this file records evidence and reuse decisions, not another project authority layer.

## What to learn from other games

| Primary source fact | Our design adaptation | What we are not importing |
|---|---|---|
| [Fisch, creator Fisching](https://www.roblox.com/games/16732694052/Fisch) describes rare/unique catches, progression/exploration and cast/bite/active catch control | A satisfying reveal, a useful collection journal, size/trait records and equipment that changes fishing choices | No copied assets, private game source, assumed drop tables or need to match its advertised variation count |
| [Terraria's developer description](https://store.steampowered.com/app/105600/Terraria/) connects exploration, materials, treasure and developing equipment | A find that is useful immediately, a short recipe, and a repair that changes the next visit | No procedural continent, hundreds of crafting recipes or a combat progression clone |
| [Minecraft's crafting guide](https://www.minecraft.net/en-us/article/how-craft) describes recipe discovery/selection and ingredient requirements | A recipe card showing effect, two requirements and where the missing component comes from | No compulsory grid memorisation, mining/refining chain or chest sorting |
| [Minecraft's first-night guide](https://www.minecraft.net/en-us/article/how-survive-your-first-night-minecraft) connects preparation, light and shelter to surviving threats | Daytime equipment and route choices have visible consequences at night | No hunger/maintenance systems simply because survival games often have them |
| [A Short Hike's creator](https://ashorthike.com/) describes marked routes, off-path exploration and hidden discoveries | A readable island circuit with short rewarding detours and useful shortcuts | The source does not prescribe our map dimensions or travel times |
| [DREDGE's official description](https://store.steampowered.com/app/1562430/DREDGE/) connects fishing upgrades with opportunity and danger after dark | One more valuable catch competes with the decision to head for safety | Original world, fish, UI and threat; no imitation of its particular story/assets |
| [Human Fall Flat's developer description](https://store.steampowered.com/app/477160/Human_Fall_Flat/) presents a cooperative physics platformer with multiple routes and opportunities for ingenuity | Passing a giant fish, a recoverable fumble and a useful rescue create physical comedy around the existing objectives | No assumption that full active ragdolls, hand climbing or a physics puzzle campaign are quick to reproduce |

These adaptations are design judgments, not evidence that this exact combination will be enjoyable. The family's first two outings decide what to refine.

## Physics and simpler graphics revision

The user has retired the detailed concept-art target in favour of Minecraft/Roblox-like block graphics and useful physical comedy. Use original six-piece characters, flat materials, box/wedge fish and readable lighting. No imported skeletal rig is required; ordinary pivot animations supply walking sway, casting lean and rescue poses.

[Built-in Jolt](https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html) is the selected 3D backend; no separate physics addon. Godot's [physics introduction](https://docs.godotengine.org/en/stable/tutorials/physics/physics_introduction.html) warns that physics is nondeterministic, so the host simulates released fish and clients display interpolated snapshots. Logical transitions and ownership messages remain reliable. Property replication alone is not a finished network physics solution.

Use [CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html) for dependable crew movement and [RigidBody3D](https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html) for a maximum of three released whole fish. Controlled held poses need world clearance; do not continuously teleport an active dynamic body or attach it beneath a moving character. One bounded throw impulse, damping, sleeping and collision checks are enough for the first experiment. Jolt's documented unsupported joint properties make copying older grab-joint tutorials without checking them inappropriate.

The [official physics-test picking helper](https://raw.githubusercontent.com/godotengine/godot-demo-projects/master/3d/physics_tests/utils/rigidbody_pick.gd) was read on mutable master: a small local mouse-picking example with direct transform/velocity assignment, no multiplayer authority. It is a learning reference only; pin and re-read the actual file before any reuse. Its availability at the previously reviewed repository SHA was not confirmed. [PiCode9560's active-ragdoll experiment](https://github.com/PiCode9560/Godot-4-Active-ragdoll) is MIT but declares Godot 4.3 and has no verified current Jolt/LAN integration; defer it. Neither is a drop-in game foundation.

Chosen probe: one controllable block character per peer, one oversized fish, dock edge and delivery area. Stable grab/carry, a short physical toss, forgiving receive, shore recovery and one catch ID throughout. No supply crates, carts, spring-grab system, joint chains, damage from props or physical boats. Pack versus whole-delivery supplies its gameplay purpose. Logic tests, rendered engine checks, three-PC agreement and actual family enjoyment are separate evidence; none has run yet.

## Current engine and useful features

The [official latest stable release](https://github.com/godotengine/godot/releases/tag/4.7.2-stable) and [Windows download page](https://godotengine.org/download/windows/) both identify Godot **4.7.2**. Keep editor/export templates matched and pin the version during a development milestone.

Use native Windows export, GDScript, built-in ENet, [MultiplayerSpawner](https://docs.godotengine.org/en/stable/classes/class_multiplayerspawner.html), [MultiplayerSynchronizer](https://docs.godotengine.org/en/stable/classes/class_multiplayersynchronizer.html), Resource-based content definitions, simple pivot animation and spatial audio where they solve actual needs. Spawn/property replication does not provide durable economy transactions or synchronise arbitrary Resource objects. Keep item IDs and plain data in network messages.

Zero runtime addons is the initial selection, not a rule forbidding a later justified addon. GUT is a development dependency. The [renderer matrix](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html) distinguishes Compatibility from Forward+/Mobile features. Preserve a usable minimum look; choose optional lighting effects after inspecting all three PCs and measuring the busy night scene. Local GPU/RAM inventory through CIM was access-denied, so no hardware capability is inferred.

## Repository shortlist: adopt, adapt or defer

| Candidate | Decision | Evidence and exact boundary |
|---|---|---|
| [Godot official demos](https://github.com/godotengine/godot-demo-projects) | Adapt selected networking patterns | MIT. Observed reviewed head `a3b5c113112f77291d5f3d1360f33a882fdc52f7`; pin/check the actual imported revision. Include the client-spawn fix below rather than assuming an engine-number tag is sufficient. |
| [GUT](https://github.com/bitwes/Gut) | Adopt for development | MIT; pin `v9.7.1`, which lists Godot 4.7.x support. [Tagged configuration](https://raw.githubusercontent.com/bitwes/Gut/v9.7.1/addons/gut/plugin.cfg). Verify real test discovery/completion, not exit status alone. |
| [Kenney 3D Platformer](https://github.com/KenneyNL/Starter-Kit-3D-Platformer) | Adapt movement/camera ideas and selected art | Inspected revision `3fa8a04b1c01ab23db43123d4ce814a34c3fc7f0`, Godot 4.6/Forward+. Code MIT; bundled art/audio CC0. Single-player direct input and whole-scene fall reset must be replaced for multiplayer. Not our project scaffold. |
| [Phantom Camera](https://github.com/ramokz/phantom-camera/releases/tag/v0.11.0.3) | Defer | MIT; reviewed release `v0.11.0.3`, revision `cb6e0966ac305202c47f1d1a81c105966e29da96`. Camera blending may justify it later; one collision-aware orbit/fishing camera does not yet need it. |
| [GLoot](https://github.com/peter-kish/gloot/releases/tag/v3.0.2) | Defer | MIT; `v3.0.2`, revision `ce88b7adc7b952b4df8ebe4836339de334d0d0cc`, release targets Godot 4.7. Grid/weight/prototype infrastructure is unnecessary for our compact equipment and shared salvage model. Authoritative crafting/saving would still be our work. |
| [Fishards](https://github.com/charlesmaddock/fishards) | Reject as foundation | MIT project, but its installation uses an old GodotSteam build and Steam login. Actual project uses Godot 3-era structures; porting a fish-wizard arena would not implement fishing progression. |
| [Heroic Labs Fish Game](https://github.com/heroiclabs/fishgame-godot) | Reject | A multiplayer arena demo, not a fishing game. Godot 3/Nakama coupling, Apache-2.0 code with exceptions and noncommercial asset licensing make it a poor basis for this LAN game. |

### Specific useful code, not a whole template

1. Official demo `networking/multiplayer_bomber/player_spawner.gd`: custom spawn setup and consistent player node identity. The [client-spawn fix `6e5fcc62a53bdb985eb69cb7544ae41dc4d5b894`](https://github.com/godotengine/godot-demo-projects/commit/6e5fcc62a53bdb985eb69cb7544ae41dc4d5b894) follows the `4.7-6ad6167` tag. Use a revision containing the fix and reproduce a three-peer spawn check. The demo is 2D, so only the pattern transfers to our 3D scene.
2. Official demo [`player.gd`](https://github.com/godotengine/godot-demo-projects/blob/a3b5c113112f77291d5f3d1360f33a882fdc52f7/networking/multiplayer_bomber/player.gd): separate input authority from server-owned simulation. Preserve that distinction for movement, casts, item consumption and AI. Example prediction is not a finished solution for our game.
3. Kenney [`scripts/player.gd`](https://github.com/KenneyNL/Starter-Kit-3D-Platformer/blob/3fa8a04b1c01ab23db43123d4ce814a34c3fc7f0/scripts/player.gd) and [`scripts/view.gd`](https://github.com/KenneyNL/Starter-Kit-3D-Platformer/blob/3fa8a04b1c01ab23db43123d4ce814a34c3fc7f0/scripts/view.gd): camera-relative input, orbit limits and animation feedback. Remove global-input assumptions for remote characters, template node/audio coupling and full-scene respawn.

For each copied piece: record source file, revision, licence and local destination in THIRD_PARTY.md; retain notices; adapt only what is understood; run our targeted tests. Do not cherry-pick unrelated repository histories into the game or claim compatibility from a README alone.

## What stays original and small

Own the fish eligibility/roll tables, reveal, specimen records, roles, recipes, inventory transactions, island repairs, hunter rules and presentation. Use authored item/recipe Resources plus plain saved instances/counts, not a general inventory framework. A crafted item's transaction validates both requirements, consumes them once and unlocks the result for the crew in the same saved update.

The smallest honest proof of the new direction is: catch something surprising; find one useful rod; craft one alternate lantern; permanently repair a return route; survive one night together; save/restart and see those changes. The full game's later content remains a separate completion milestone, not a claim that the proof is the finished product.

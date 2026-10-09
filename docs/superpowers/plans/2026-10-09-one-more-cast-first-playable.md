# One More Cast First Playable Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Recommended execution for this small, tightly connected first slice: native implementation with a focused independent review of authority/saves and a final independent review. Do not create a fresh framework or service for each task.

**Goal:** Deliver a readable block-style 10–12 minute proof of a persistent three-player LAN island RPG: surprising catches, optional physical whole-fish delivery, a found rod, a crafted lantern, a permanent repaired route, three useful roles, a nightly battery choice, hunter/rescue and boat refuge. This milestone is not the finished standalone campaign.

**Architecture:** A single Godot project; one Windows listen server owns game rules and the persistent household island, with two clients sending intent. Focused feature models hold deterministic rules; scene controllers perform movement, rendering, audio and RPC routing. Nightly refuge/dawn refreshes transient encounters while equipment, collections, caches and repairs remain.

**Tech Stack:** Godot standard 4.7.2 plus matching Windows export templates, GDScript, Compatibility renderer, built-in Jolt/ENet, GUT 9.7.1 development-only and original primitive block art. Versions are researched candidates; Task 1 verifies them. No runtime addons or imported character rig required.

**Spec:** [ONE_MORE_CAST_PLAN.md](C:/game-3/ONE_MORE_CAST_PLAN.md), revision 4. Read the spec and this checklist together. The concept images in `C:\game-3\docs\art` are retired historical references; the block-art rules in spec section 3 govern appearance.

**Status — 10 October 2026:** implementation was explicitly authorized and the first integrated Windows playable now exists. Read [actual verification and remaining family acceptance](C:/game-3/docs/playtest/FIRST_PLAYABLE_STATUS.md). The detailed steps below preserve the original plan; a box stays open if it bundles an unperformed manual/three-PC/family check, even when its code is implemented. No box is evidence of fun by itself.

### Execution reconciliation

| Task | Actual result | Remaining acceptance |
|---|---|---|
| 1 — native foundation | Godot 4.7.2 and matching templates verified, Compatibility/Jolt, original block island, portable release | Weakest family laptop |
| 2 — three-player session | ENet host + two clients, stable profiles, intent authority, reconnect, names, pause | Physical LAN/firewall and per-PC performance |
| 2A — physical experiment | Grab/drop/toss/receive/pack, bounded host bodies, water recovery, real physics tests | Family's free passing session and visual client comparison |
| 3 / 3A — fishing and collection | Two behaviors, three species, Oversized, records/dry streak, assists, hold/toggle controls, journal | Ten hands-on catches per behavior and pacing feedback |
| 4 / 4A / 4B — lasting progress | Durable bank/receipt saves, found rod, crafted lantern, shared unlocks, repair, whole-fish bonus | Three-PC restart/load and preference between gear choices |
| 5 / 6 — cooperation and choice | Scout/Keeper/Rigger, lighting tradeoffs, one ballot with majority/fallback and actual station power | Mixed/all-Keeper family runs; both choices' value |
| 7 — night loop | Warning/chase/recovery, rescue, timed retreat, storm, refuge/dawn and frozen save retries | Naturally occurring rescues and full ordinary LAN run |
| 8 — presentation | Actual block rendering, casting float/line, effects, sparse HUD, sound/mute and host office | Family reaction and weakest-PC night visibility |
| 9 — packaging | Native Windows package, clean-folder startup, dependency notices, automated flow and network evidence | Three-PC and family acceptance below |

Small implementation adaptations: scenes composed from GDScript primitives replace several planned `.tscn`/`.tres` files; one RunController composes the small feature models. The refuge crossing is a snapshot-driven boat cinematic with frozen authoritative boarding/cargo, not a physics boat. A failed landing whose angler disconnects records discovery on retry, recovers a shared whole fish at the home dock, and forfeits packed custody even if the player rejoins. Reeds casting requires 8–12 m from its 6 m shelter. Initial names use a name-only intent; role/gear changes still require the workshop. Original per-task commit suggestions are consolidated in this fresh game repository. These do not add services or runtime dependencies.

## Global constraints

- Three Windows PCs on the same home network. First input target is keyboard/mouse.
- Native desktop game, Compatibility renderer, one host plus two remote players. Use `create_server(24563, 2)` with other ENet arguments at defaults.
- One island outline with two finished activity areas, three tools, two rods, two lanterns, three species/two fish behaviours, one specimen trait, at most three whole physical fish, two stations, one nightly battery choice, one hunter, one recipe, one found rod, one repaired walkway, one save and boat refuge/dawn.
- No shop, XP/rank UI, contracts, fuel inventory, procedural world, extra creature systems, matchmaking, WAN, cloud service, accounts or host migration in this slice. Simple crafting and persistent world change are mandatory, not deferred.
- Original block silhouettes: six-piece crew, Moth/square warning light, blunt fish, tall Last Lifeguard and sparse cream permit UI. Flat materials, no elaborate texture/rig pipeline. Stable movement; no active ragdolls, loose crates/carts, rope chains, climbing system or physics boats.
- The planning-only restriction ended with the user's explicit revision 4 implementation instruction. Tools remain project-local and development folders stay outside the release package.
- Keep root AGENTS.md/CLAUDE.md authoritative if present. Do not create another instruction/truth layer.

## Review focus

1. Duplicate or replayed bank requests, including restart: reward exactly once and keep cargo if a durable save fails. Tasks 3–4 and 9.
2. A player disconnects during a vote, rescue or departure: no stolen profile, phantom vote, blocked exit or stale-input control. Tasks 2, 6–7 and 9.
3. The parent is both host and player: their actions execute once, and client commands cannot impersonate the host. Tasks 2, 3 and 8.
4. Darkness or effects on the weakest laptop hide the route or consume the frame budget: reduced effects preserve the same navigation and warnings. Tasks 1, 8 and 9.
5. Three identical roles or a split crew trivialise/break the loop: every composition can fish/rescue, Keeper light cannot chain forever, both battery choices remain viable. Tasks 5–7 and the family test.
6. A catch exists as physical loot and pouch money at once, or a physics object launches/traps someone: one identity/state transition, server-only simulation and player/prop collision exclusions. Tasks 2A, 4B, 7 and 9.

## Decisions and shared contracts

These names are contracts between tasks, not permission to build an abstraction framework. All proposed paths below are within `C:\game-3`; they do not exist yet except the planning artifacts. GDScript models extend RefCounted unless they need a scene node. Controllers are Nodes. Use explicit `class_name` for the model names below.

### Persistent and network data

- Build ID `0.1.0-slice`; protocol `1`; save schema `1`. A mismatched build is rejected with the expected build displayed.
- Persistent profiles: `crew_1`, `crew_2`, `crew_3`; each holds `{name, role_id, rod_id, lamp_id}`. Roles: `scout`, `keeper`, `rigger`; lamps: `flood`, `surveyor`; rods: `starter`, `soft_tip`. Peer IDs never substitute for profile IDs.
- Save state: `{schema_version, household_id, revision, coins, lifetime_banked, salvage, known_recipes, owned_rods, owned_lamps, discoveries, specimen_records, dry_streaks, opened_caches, repairs, campaign_flags, day_index, profiles, landed_catch_ids, banked_catch_ids, craft_ids, repair_ids, settled_run_ids}`. Coins are spendable; lifetime_banked is cumulative. Start with Flood/Starter owned, zero salvage, no repairs/caches. No existing runtime saves need migration because implementation has not begun.
- Host-created catch: `{catch_id, run_id, profile_id, species_id, habitat_id, rare_eligible, trait_id, size, catch_value}`. catch_value is the normal packed value. Host rolls species/trait/value from the catalog; clients never supply them. IDs are unique across runs. Whole-delivery value is calculated from species base × 2, replacing packed value. Attribute discovery to profile_id even when another player delivers it.
- Standard model result: `{ok: bool, code: String, ...explicit result fields}`. Failed operations leave prior state intact. Codes such as `duplicate`, `out_of_range`, `save_failed`, `not_host`, `locked`, `build_mismatch` are UI-safe states, not raw stack traces.
- Client intent envelope: `{request_id, action, payload}`. Host resolves profile from the sender's current roster assignment. Never accept caller-supplied peer/profile IDs as authority.
- Initial allowlist: `move`, `cast`, `reel`, `cancel_cast`, `assist`, `bank` (no caller reward data), `grab_fish`, `drop_fish`, `toss_fish`, `pack_fish`, `receive_fish`, `equip_lamp`, `equip_rod`, `open_cache` (authored cache ID), `craft` (recipe ID), `repair` (authored repair ID), `use_ability`, `vote`, `revive`, `ready`, `ping`, and host-only `pause`/`host_event`. Payloads are bounded intent/target IDs, never reward balances, item lists or arbitrary paths. Validate sender, live range, phase, cooldown and state. No generic remote method invocation. Paused gameplay rejects actions; only unpause/session/recovery controls remain available.
- Snapshot: `{protocol, build_id, run_id, elapsed_s, phase, roster, players, fishing, cargo, lights, crew_choice, hunter, progression}`. Cargo records hold catch ID, state, carrier ID, pouch_profile_id, sequence and authoritative pose/velocity; no peer-local object IDs. Immutable catch_record.profile_id is the original angler; pouch_profile_id is current packed-cargo custody. Revive/forfeiture/banking use custody, not attribution. Each feature supplies its own simple Dictionary snapshot; snapshots contain data, never executable objects or file paths. Whole fish and pouch contents are transient; discoveries/receipts persist. Rejoining gets the current cargo snapshot, not duplicate fish.

### Planned file responsibilities

| Files | Responsibility |
|---|---|
| `project.godot`, `export_presets.cfg`, `.gitignore`, `THIRD_PARTY.md` | Engine/export configuration and reproducible provenance |
| `game/main.tscn`, `game/main.gd` | Boot into lobby; own session/run scene lifetime |
| `game/session/session.gd`, `roster.gd`, `intent_gate.gd`, `lobby.tscn` | Host/join, profile allocation, build check, authority boundary |
| `game/player/player.tscn`, `player.gd`, `camera_rig.gd` | Controls, movement, interaction aim and camera |
| `game/world/lido.tscn`, `style_probe.tscn`, `boat.tscn` | Authored map, visual check scene, departure/safe dock |
| `game/fishing/fishing_rules.gd`, `fishing_controller.gd`, `fish.tscn`, `species.gd` | Catch behaviour/data, optional assistance, catch creation |
| `game/fishing/cargo_rules.gd`, `physical_fish.gd`, `physical_fish.tscn` | Single catch identity through whole-fish grab/drop/toss/pack/bank; host physical-body presentation |
| `game/progression/save_store.gd`, `progression.gd`, `equipment.gd` | Durable household state, transactions and gear rules |
| `game/fishing/catch_table.gd`, `game/progression/crafting.gd`, `game/world/island_content.gd` | Authored roll/recipe/cache/repair definitions; all durable writes still go through Progression |
| `game/survival/ability_rules.gd`, `light_rules.gd`, `hunter_rules.gd`, `hunter.tscn`, `hunter_controller.gd` | Tools, protection, hunter states and navigation |
| `game/crew/crew_choice.gd`, `battery_console.tscn` | One vote and visible power commitment |
| `game/expedition/expedition_rules.gd`, `run_controller.gd`, `director.gd` | Clock, phase, revive/departure lifecycle, composition of feature events |
| `game/ui/hud.tscn`, `hud.gd`, `lake_theme.tres`, `equipment_tags.tscn`, `lake_office.tscn` | Consistent permit UI, equipment selection, host controls |
| `assets/characters/`, `assets/world/`, `assets/fish/`, `assets/hunter/`, `assets/ui/`, `assets/audio/` | Selected source assets with source/licence notes |
| `tests/unit/test_*.gd`, `tests/integration/test_run_flow.gd` | Consequential rules and composed run tests |
| `tests/scenes/physics_yard.tscn`, `physics_yard.gd`, `tests/integration/test_physics_cargo.gd` | Small rendered/runtime physics probe, actual trajectories/clearance and peer agreement; excluded from export |
| `docs/playtest/first-family-test.md`, `README.md` | Actual evidence and a short launch/control guide |

Do not scaffold empty files for all rows up front. Create each file when its task needs it. Review oversized files by responsibility; do not prebuild generic registries, event buses or dependency-injection infrastructure.

## Verification commands, for execution later

Planned portable editor path: `C:\game-3\.tools\godot\Godot_v4.7.2-stable_win64_console.exe`. Verify the actual extracted filename at Task 1 and adjust this single documented path if required. `.tools`, `.godot`, local logs and `build` are ignored. The exported players do not need the editor or GUT.

```powershell
$TaskGodotExe = 'C:\game-3\.tools\godot\Godot_v4.7.2-stable_win64_console.exe'
& $TaskGodotExe --version
& $TaskGodotExe --headless --path 'C:\game-3' --import
& $TaskGodotExe --headless --path 'C:\game-3' --script res://addons/gut/gut_cmdln.gd -gconfig= -gdir=res://tests/unit -ginclude_subdirs -gexit
& $TaskGodotExe --headless --path 'C:\game-3' --script res://addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_roster.gd -gexit
& $TaskGodotExe --headless --path 'C:\game-3' --export-debug 'Windows Desktop' 'C:\game-3\build\windows\OneMoreCast.exe'
```

For each task, replace only the `-gtest` path with its named test file. Import before testing so classes are registered. Export requires matching templates, the `Windows Desktop` preset and an existing output directory. Record exit status immediately after each command. Test success also requires a completed GUT summary, expected nonzero test discovery, zero failures and no parse/load errors; exit code zero alone is insufficient. Do not report a skipped suite as passing.

The commands are sourced from [Godot CLI](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html) and [tagged GUT CLI source](https://raw.githubusercontent.com/bitwes/Gut/v9.7.1/addons/gut/cli/gut_cli.gd). No commands in this section were executed during planning.

---

## Task 1: Reproducible engine setup and a credible custom scene

**Files:** create project/export config, `.gitignore`, `THIRD_PARTY.md`, main scene, style probe, `lake_theme.tres`, and the first crew/boat/landmark material and mesh sources. Add only the required GUT addon folder.

**Interfaces:** produces a `Windows Desktop` debug export preset, main scene entry point and reusable crew/boat scene assets. No gameplay API yet.

- [x] Recheck root instructions, workspace contents, any existing Git state and available disk; preserve work that appeared since planning. Initialise one local Git repository only as part of authorised execution. Do not create a remote.
- [x] Acquire pinned Godot/editor templates and GUT from primary sources, record version/hash/licences, and verify `--version` and resource import. Reuse a suitable verified local engine if present. Do not copy tools from the unrelated trading workspace.
- [ ] Read the selected source files/revisions in the research note; copy only useful reviewed pieces and preserve notices. Official multiplayer source must contain fix `6e5fcc62a53bdb985eb69cb7544ae41dc4d5b894`; Kenney camera/controller snippets need adaptation from single-player assumptions. Zero runtime addons initially.
- [ ] Configure Compatibility, built-in Jolt, keyboard/mouse actions (`move_*`, `interact`, `cast_reel`, `pack_fish`, `ability`, `ping`, `pause`) and the Windows preset. Reuse cast_reel as toss only while holding a whole fish. Hold Interact enables receiving; consume/latch that input on a successful grab. Keep host diagnostics out of normal game UI.
- [ ] Establish the whole island outline in the visual probe, with lido as one local pocket and open water around the island. Start near 180×140 m; tune later by the spec's travel times. Assess optional Forward+ effects only against all three machines, retaining a readable minimum presentation; no hardware capability is assumed from the denied CIM query.
- [x] Build one small **real engine** dock/boat/crew scene using boxes/wedges/low-sided cylinders, flat palette materials, six-piece pivot-animated crew, basic water and daylight/night toggles. Add no texture painting, detailed sculpt, skeletal import or procedural world generator. The simple style is the intended finish.
- [ ] Inspect gameplay-camera screenshots at 1280×720 and 1920×1080. Crew/tool silhouettes, dock edge, hunter stand-in and return lamp must remain readable. Test held-fish/camera occlusion in motion. Judge against the block-style spec, not the retired generated boards.
- [ ] Export and open on the weakest family PC when available. Record actual adapter/resolution/frame timing; no claim of cross-device readiness without that device. Target stable 60 fps, with reduced effects preserving playability. No unit test for decorative asset edits.
- [ ] Commit only authored/config/source files and provenance: `chore: establish pinned engine and lido visual baseline`.

**Gate:** a reproducible import/export and a deliberate in-engine visual baseline. Headless import or a generated image does not establish this gate.

## Task 2: Three real players, stable profiles and a single authority boundary

**Files:** session/roster/intent gate/lobby, player/camera scenes/scripts; tests `test_roster.gd`, `test_intent_gate.gd`.

**Interfaces:** `Roster.assign(peer_id: int, slot: int, build_id: String) -> Dictionary`; `profile_for_peer(peer_id: int) -> String`; `disconnect(peer_id: int) -> String`; `snapshot() -> Dictionary`. `Session.host(port: int = 24563) -> Error`; `join(address: String, port: int = 24563) -> Error`; `submit_intent(action: String, payload: Dictionary, request_id: String) -> void`; signal `intent_received(peer_id: int, action: String, payload: Dictionary, request_id: String)`. `IntentGate.authorize(peer_id: int, action: String, payload: Dictionary, roster: Roster) -> Dictionary` derives the profile from roster and rejects unknown actions/senders.

- [x] Write failing roster/authority tests. Core assertions:

```gdscript
func test_profile_survives_peer_change_and_cannot_be_stolen():
    var r = Roster.new()
    assert_true(r.assign(2, 1, "0.1.0-slice").ok)
    assert_false(r.assign(3, 1, "0.1.0-slice").ok)
    assert_eq(r.disconnect(2), "crew_2")
    assert_true(r.assign(9, 1, "0.1.0-slice").ok)
    assert_eq(r.profile_for_peer(9), "crew_2")
    assert_eq(r.profile_for_peer(2), "")
```

Add `test_build_mismatch_rejected`, `test_fourth_player_rejected`, `test_payload_profile_cannot_override_sender`, and `test_client_host_action_rejected`, asserting the named codes and unchanged roster.
- [x] Run both named scripts and observe the intended failures before implementing their rules; fix harness/import errors separately.
- [x] Implement zero-based slots 0–2, the exact contracts, build handshake and host-approved slot assignment. Instantiate the host player explicitly. Send host-local actions through the same dispatcher **once**, avoiding a local call plus an echoed RPC.
- [ ] Use built-in MultiplayerSpawner/Synchronizer for appropriate scene/property replication. Keep authoritative economy/crafting events in explicit handlers. Replicate IDs/plain values, not Resource objects. Verify the adapted demo spawn fix with host plus two peers.
- [x] Add movement with authoritative validation and immediate local presentation, camera collision, terrain interaction range and a ping. Do not add rollback networking or elaborate prediction until actual LAN feel demonstrates a need.
- [ ] Re-run tests. Check one host/two local clients, then **three physical PCs** using the host LAN IPv4. Reject accidental `127.0.0.1` use in the cross-PC guide. Diagnose private-network firewall application rules/AP isolation; never disable the firewall or forward router ports.
- [ ] Confirm each avatar moves once, old sender input is rejected after disconnect, and a slot conflict gets a readable message. Commit `feat: add three-player LAN session and stable profiles`.

## Task 2A: Prove the physical-comedy idea before building more content

**Files:** cargo rules, physical fish scene/controller, physics yard; `test_cargo_rules.gd`, `test_physics_cargo.gd`. Use an explicit test-only Oversized specimen fixture; no production reward grant or debug roll manipulation.

**Interfaces:** `CargoRules.register_catch(catch_record: Dictionary, mode: String, pouch_profile_id: String = "") -> Dictionary`; `grab(catch_id: String, profile_id: String, context: Dictionary) -> Dictionary`; `release(profile_id: String, kind: String) -> Dictionary`; `pack(catch_id: String, profile_id: String, held_s: float, context: Dictionary) -> Dictionary`; `disconnect(profile_id: String) -> Dictionary`; `set_paused(paused: bool) -> void`; `snapshot() -> Dictionary`. Context is supplied from host positions/LOS/phase, not client claims. States are `whole_loose`, `whole_held`, `packed`, `bank_pending`, `banked`, `lost`. One owner/representation at a time; catch attribution never changes. `release` kind is `drop` or `toss` and emits one action sequence for the physics controller, never repeatedly on a held input. Delivery reservation is added in Task 4B.

- [x] Write failing state tests: simultaneous grab accepts one holder; a holder cannot grab a second fish; remote/stale/out-of-range actions fail; release/receive/pack preserve catch ID; packed fish cannot be made whole again; one toss edge produces one release; paused actions reject. Pin grab 2 m/LOS, receive 1.5 m/facing/nearest-then-profile tie break, Pack 0.5 s, carrier speed ×0.85, capacity three whole fish. Ordinary/overflow catches register packed. Assert no catch can be both world loot and pouch cargo.
- [x] Implement rules after the expected failures. Use stable CharacterBody3D player capsules and pivot wobble. For held fish use a world-clearance-checked kinematic pose; release if blocked beyond allowed reach rather than pushing it through a wall. Released fish use host-only Jolt, simple convex collision and capped impulse/velocity. Initial toss 5 m/s horizontal + 2 m/s upward, maximum total speed 8 m/s; intended level-ground throw is short, not a long-range launcher. Tail flop/squash is visual; any body flop impulse is bounded and host-owned. Exclude player/hunter collision and cap at three bodies.
- [x] Add real-engine integration checks: actual body hits dry ground, stays finite, does not tunnel through the test dock, cannot fling a player, returns from water after 2 s to its last valid dry location, and preserves its ID. Test obstructed carry and release near the water boundary. No exact trajectory or bit-for-bit equality assertion: physics is nondeterministic. Check tolerances, bounds and authoritative state. Pause freezes integration and recovery timers without dropping saved velocities; unpause resumes once.
- [x] Replicate cargo state changes reliably and host poses with sequence numbers; clients ignore stale poses and interpolate. Do not run an independent client authority simulation. Start at 60 Hz host physics/20 Hz pose updates, tuning only from measurements. Keep the network body separate from interpolated visual mesh. On rejoin send current IDs/states/poses, never re-register a second catch.
- [ ] Run the yard with host plus two clients, then the three family PCs when available. Capture actual rendered motion/screenshots from host and client: simultaneous grab, useful pass, missed pass, pause mid-flight, obstruction and carrier disconnect. Verify readable pickup prompts and camera clearance. Peer agreement means same state/holder/ID and converging visuals; it does not mean identical local rigid-body simulation.
- [ ] Give the family five minutes of free passing/carrying at the dock. Observe whether a missed pass is funny and recoverable, whether a pass is useful and whether movement feels dependable. Record actual reactions, corrections and tested machines. Make one focused tuning pass; if it still feels awkward, explicitly simplify or cut the whole-fish experiment before expanding content. Unavailable players mean this fun gate is pending, not passed; independent rule/save work can continue.
- [ ] Commit `feat: prototype bounded LAN fish carrying and tossing` only with accurate completed/pending evidence. No crates, carts, two-person lifting calculation, healthy-player grabbing, full ragdolls, physics boat or rope joints.

## Task 3: Fishing worth repeating and trustworthy catch IDs

**Files:** fishing model/controller/species/fish scene; create run controller and extend HUD just enough to interact; `test_fishing.gd`.

**Interfaces:** `Species.catalog() -> Dictionary` maps `penny_perch` to `{value:10, behavior:'dart'}`, `bellgill` to `{value:20, behavior:'heavy'}`, `lantern_eel` to `{value:40, behavior:'dart'}` plus presentation references. `FishingRules.start(profile_id: String, species_id: String, catch_id: String) -> Dictionary`; `step(profile_id: String, reel: bool, opposing_pull: float, delta_s: float) -> Dictionary`; `assist(helper_id: String, target_id: String, kind: String) -> Dictionary`; `cancel(profile_id: String) -> void`; `snapshot() -> Dictionary`. Successful completion returns `{ok:true, code:'caught', catch:catch_record}` once; only host creates IDs/species rolls. `RunController.apply_intent(peer_id: int, action: String, payload: Dictionary, request_id: String) -> Dictionary` starts the common authorised dispatcher; `snapshot() -> Dictionary` initially fills integrated fields, with empty dictionaries for future features.

- [ ] Write failing tests for one outcome per cast, clamped tension/progress, cancelled casts, no self-assist, and duplicate assist rejection. Pin the helper fixture used below in the test file: `complete_cast` starts a cast then feeds bounded valid inputs until it returns the completed catch, failing if its maximum tick budget is exceeded.

```gdscript
func test_a_cast_cannot_award_twice():
    var f = FishingRules.new()
    var catch_record = complete_cast(f, "crew_1", "penny_perch", "run-a:1")
    assert_eq(catch_record.catch_id, "run-a:1")
    assert_eq(f.step("crew_1", true, 1.0, 0.1).code, "no_cast")
```

- [x] Run `test_fishing.gd` red, then implement two clear behaviours and deterministic injected test randomness. Generic assist adds a bounded progress burst once; reserve stronger Rigger burst for Task 5. Inputs never directly set progress or declare a catch.
- [ ] Connect physical cast, bite, reel/release, line bend, splash, readable tension and catch reveal. Implement hold/toggle input and immediate cancel-to-move. Give three players independent fishing opportunities.
- [ ] Check host and clients see the same fish/cargo result. Verify a remote client cannot choose a rare species by modifying intent, award a fake catch or collect twice by repeating a request ID.
- [ ] Run green, then manually land ten fish per behaviour with feedback. Target common 10–20 s/heavy 20–35 s; if it is dull, improve interaction/feedback before adding species. Commit `feat: add cooperative fishing and authoritative catches`.

## Task 3A: Surprising specimens with useful collection progress

**Files:** catch table, species data, catch reveal/journal UI; `test_catch_table.gd`. Persistence is wired in Task 4; do not create a second save writer.

**Interfaces:** `CatchTable.roll(habitat_id: String, time_band: String, dry_streak: int, species_roll: float, trait_roll: float, size_roll: float) -> Dictionary`; `next_streak(current: int, rare_eligible: bool, rare_landed: bool) -> int`. Inputs to roll come from the host's RNG, or explicit unit-test values. Rolls stay attached to a cast once started.

- [x] Write failing boundaries: jetty day selects perch for [0,0.7), Bellgill for [0.7,1); reeds dusk/night selects perch [0,0.6), Bellgill [0.6,0.9), eel [0.9,1). Eel is rare; daylight jetty has no eligible rare and does not advance that habitat's dry streak. Reject invalid rolls outside [0,1).
- [x] Test `dry_streak=11` forces an eel opportunity for a new eligible reeds cast; a failed/cancelled cast leaves streak unchanged; a landed rare resets it to zero. Existing active rolls are unchanged. Multiple concurrent rare opportunities are allowed.
- [x] Test trait roll [0,0.1) yields Oversized, otherwise none. Oversized uses the same base behaviour and a 25% sale bonus rounded down; host-forced funny appearance changes neither value nor odds. Size is a bounded presentation/record value, not another hidden power multiplier.
- [ ] Run red, implement these small tables, then run green. Add the species/size/trait/new-record reveal and a journal with habitat hints, actual current odds and the shared dry-streak rule. Reveal must not prevent teammates moving or rescuing.
- [ ] With fixed seeds, demonstrate a common catch, Oversized catch and rare opportunity on all peers. Integrate settled records once Progression exists. Commit `feat: add specimen variety and transparent collection progress`.

## Task 4: Save rewards, collections and future world transactions

**Files:** save store/progression/equipment, equipment tags, bank interaction on boat; tests `test_progression.gd`, `test_save_store.gd`.

**Interfaces:** `SaveStore.new(path: String)`; `load_or_recover() -> Dictionary` returns `{ok, state, source, code}`; `commit(next_state: Dictionary) -> Error`. `Progression.blank_state() -> Dictionary`; `Progression.new(store: SaveStore, initial_state: Dictionary)`; `record_specimen(catch_record: Dictionary) -> Dictionary`; `bank(catches: Array[Dictionary], delivery_modes: Dictionary = {}) -> Dictionary`; `set_lamp(profile_id: String, lamp_id: String) -> Dictionary`; `set_rod(profile_id: String, rod_id: String) -> Dictionary`; `snapshot() -> Dictionary`. Delivery modes map catch IDs to `packed`/`whole`; absent means packed, whole requires Oversized. Only the host controller calls this trusted API after validating current cargo/deposit state; it is never directly callable by RPC. Calculate value from authoritative species/trait records, never a client field. `Equipment.lamp(lamp_id: String) -> Dictionary` returns `{angle_deg, reach_m, active_seconds}`; `Equipment.rod(rod_id: String) -> Dictionary` returns handling modifiers. Tests use isolated temporary paths.

- [x] Write a durable-save test fixture and the critical assertions. `fresh_progression()` creates a temp SaveStore and `blank_state`; `fixture_catch(id,species)` returns a host-created record for `crew_1`/`run-a`.

```gdscript
func test_duplicate_bank_cannot_fund_extra_crafts():
    var p = fresh_progression()
    var a = fixture_catch("run-a:1", "penny_perch")
    var b = fixture_catch("run-a:2", "bellgill")
    assert_true(p.record_specimen(a).ok)
    assert_true(p.record_specimen(b).ok)
    assert_true(p.bank([a, b]).ok)
    assert_eq(p.snapshot().coins, 30)
    assert_eq(p.snapshot().lifetime_banked, 30)
    assert_false(p.bank([a]).ok)
    assert_eq(p.snapshot().coins, 30)
    assert_false(p.set_lamp("crew_3", "surveyor").ok)
```

Add `test_duplicate_after_reload`, `test_unowned_lamp_locked`, `test_settled_specimen_updates_counter_once`, `test_record_and_counter_survive_reload`, `test_failed_write_preserves_state`, `test_invalid_schema_uses_backup`, and `test_two_invalid_saves_preserved`. A failing commit returns `ERR_FILE_CANT_WRITE`; bank returns `save_failed`, preserving coins/cargo. Reject a bank batch containing an already-banked ID or invalid species rather than silently part-applying it. Only host-settled recorded catch IDs can be banked; fixtures first call record_specimen for their trusted records.
- [x] Run red, implement validate/temp-write/backup/replace/recovery and commit transactions, then run green. Increment revision only on successful durable changes. Cap receipt growth only with a separately proven rule; do not prune away replay protection casually.
- [x] Use `user://household.json` in the real game, with adjacent temp/backup files. Maintain separate test roots. Host death loses only unconfirmed changes, never silently resets the family save.
- [x] Connect settled catch recording and banking within 3 m of the boat; clear cargo only after confirmed save. Bank adds spendable coins and lifetime_banked. Implement Flood 70°/8 m/90 s and Surveyor 30°/12 m/45 s data; Surveyor stays locked until Task 4A crafts it.
- [ ] Close/reopen host, rejoin all profiles, verify coins, specimen record/counter and starter loadouts. Commit `feat: persist household rewards and specimen records`.

## Task 4A: Find a rod, craft a lantern and leave a repaired island behind

**Files:** crafting/island content definitions, workshop recipe cards, cache interactions, repairable walkway scene; extend Progression and session snapshots; tests `test_crafting.gd`, `test_world_progress.gd`.

**Interfaces:** `Crafting.recipe(recipe_id: String) -> Dictionary`; `IslandContent.cache(cache_id: String) -> Dictionary`; `IslandContent.repair(repair_id: String) -> Dictionary`. `Progression.open_cache(cache_id: String) -> Dictionary`; `craft(recipe_id: String, transaction_id: String) -> Dictionary`; `repair(repair_id: String, transaction_id: String) -> Dictionary`. Controller validates range, actor and workshop/repair context before calling these trusted methods; Progression commits all changes atomically via its one SaveStore.

- [x] Pin authored contents: `lido_workshop_cache` gives Surveyor recipe + one glass lens; `shore_rod_cache` grants Soft-tip Rod; `walkway_parts_cache` gives one brass fitting. Each cache opens once per household. Recipe `surveyor_lantern` costs 30 coins + one glass lens. Repair `return_walkway` costs one brass fitting, zero coins. Recipe/repair consume their requirements only after durable commit.
- [x] Write failing transaction assertions: starting with 40 coins, open workshop cache and craft once -> 10 coins, zero lenses, Surveyor owned by all profiles; repeat craft ID -> unchanged; new ID for already-owned gear -> unchanged. Insufficient coins or missing lens consumes nothing. Two simultaneous player requests cannot charge twice. A save failure grants/spends nothing.
- [x] Add persistence tests: find rod -> all can equip; cache reopen yields no duplicate; repair walkway -> repaired flag/scene after reload; repair retry consumes nothing; client cannot pass arbitrary reward data; crafting does not spend the guaranteed story/repair fitting.
- [ ] Run red, implement, then run green. Soft-tip Rod uses 0.85 tension-gain multiplier and 0.85 heavy-catch progress multiplier; starter uses 1.0 for both. Validate that the tradeoff is visible in fishing play, not only item text.
- [x] Connect one-click recipe cards with output effect, owned/missing requirements and ingredient-location hint. No crafting grid, weight system, inventory sorting or intermediate parts. A crafted unlock is shared, while equipment selection is personal.
- [ ] Place the guaranteed first lens/recipe on the normal route and the complete rod on a short optional detour. Make the repaired walkway shorten a measured route; next-day loading must not restore its broken collision/visual state. Capture before/after and time both routes.
- [ ] Close/reopen all three clients, equip different rods/lamps and walk over the still-repaired path. Commit `feat: add shared crafting finds and persistent island repair`.

## Task 4B: Connect physical fish to optional risk and durable rewards

**Files:** extend cargo rules, progression, fishing/run controllers, physical fish, boat deposit area and contextual controls; `test_cargo_rewards.gd` and physics integration cases. Reuse existing catch IDs and SaveStore; no second wallet or inventory system.

**Interfaces:** `CargoRules.reserve_bank(catch_ids: Array[String], context: Dictionary) -> Dictionary` returns `{ok, code, reservation_id, catches, delivery_modes}` using host-validated deposit/boarding context; `finish_bank(reservation_id: String, committed: bool) -> Dictionary`. Bank-pending IDs reject grab/pack/new reservations; false keeps the same reservation pending for retry. Controller calls Progression.bank and finalises only on success. `mark_lost(catch_ids: Array[String]) -> Dictionary` is called only after successful run settlement. No client submits delivery mode/value. Released-fish recovery modifies pose, never progression.

- [ ] Write failing tests for Oversized Perch 12 packed versus 20 whole, Bellgill 25/40, Eel 50/80; total whole value replaces packed value. Duplicate/replayed bank requests and bank-plus-extraction overlap never award both. Ordinary fish cannot claim a whole bonus. Pack produces exactly one pouch entry and removes the physical representation; copying the catch across representations fails.
- [ ] Test transitions: A lands, B receives and packs, A disconnects -> B still banks once with A retaining journal credit. If B disconnects before banking, B's packed fish is forfeited. Downing releases a whole fish independently of pouch recovery. Carrier disconnect drops it; original angler disconnect does not destroy someone else's held fish. A fourth whole fish registers packed without destroying the first three. Receiving/tossing/water recovery never updates discovery, dry streak or cash again.
- [ ] Test saving failures separately at initial specimen recording and at banking. Do not spawn/grant cargo until initial recording commits; hold the landed outcome pending and retry the same ID if that save fails. At deposit, reserve once, keep the visible fish pending if the bank save fails and retry unchanged. No success sound or payout until commit. A crash after committed bank but before visual removal cannot pay again after restart.
- [ ] Run red, connect live catches and rewards, run green. Deposit uses a broad marked crate/Area3D and a 0.3 s stable overlap, not a precise rim shot. Keep whole fish in their capped visible state; ordinary fish keep the fast pouch flow. Held lanterns remain functional; casting is unavailable while carrying, and starting revive/ability first drops the fish. Restore normal speed/control promptly on drop, pack or disconnect.
- [ ] In rendered three-client play, complete one voluntary haul and one deliberate early Pack after danger begins. Confirm both payouts, clear risk/reward text, attribution and lack of forced chores. One person lights/receives/rescues; do not require another to remain within a helper radius. Throwing into the boat and boarding while holding the fish must both succeed.
- [ ] Commit `feat: connect optional whole-fish delivery to saved rewards`.

## Task 5: Useful roles and light that cannot trivialise the night

**Files:** ability/light rules; extend player, fishing controller and HUD; `test_abilities.gd`, `test_lights.gd`.

**Interfaces:** `AbilityRules.use(profile_id: String, role_id: String, target: Dictionary, now_s: float) -> Dictionary`; `snapshot() -> Dictionary`. Caller supplies a host-validated target containing range/LOS/path/target state, never trusts client claims. `LightRules.set_reserve(station_id: String) -> Dictionary`; `station_powered(station_id: String, elapsed_s: float) -> bool`; `handheld_effect(hunter_id: String, now_s: float) -> Dictionary`; `drain(profile_id: String, lamp_id: String, enabled: bool, delta_s: float) -> Dictionary`; `recharge(profile_id: String, lamp_id: String) -> void`; `snapshot() -> Dictionary`. A fresh/recharged lamp receives its Equipment active_seconds; only enabled lamps drain, and the controller calls recharge only at the boat. Station IDs `jetty`/`reeds`.

- [ ] Write failing tests asserting Scout reveal 5 s, Keeper protection 4 s, Rigger range 5 m, all 30 s cooldowns; failed use consumes no cooldown. Three Keeper uses cannot stack duration/refresh a field. A tether through an obstruction or over invalid shore returns `invalid_path`.

```gdscript
func test_station_power_has_one_extended_branch():
    var light = LightRules.new()
    assert_true(light.set_reserve("reeds").ok)
    assert_true(light.station_powered("jetty", 239.9))
    assert_false(light.station_powered("jetty", 240.0))
    assert_true(light.station_powered("reeds", 629.9))
    assert_false(light.set_reserve("jetty").ok)
```

Add `test_handheld_slowdown_immunity_shared_between_players`: first effect ends after 2 s; additional lamps cannot extend it; immunity runs for the following 6 s. At the end of immunity another bounded slowdown may occur. Also pin `test_lamp_drain_matches_equipment`: after 45 active seconds Flood has 45 remaining while Surveyor has zero; disabled/paused time drains neither; recharge restores 90/45 respectively.
- [ ] Run red, implement bounded tools and light rules, and run green. Ordinary handheld lamps illuminate/slow, powered stations and Keeper patches protect; keep those mechanics separate.
- [ ] Connect Scout opportunity/trail indicators, Keeper field and Rigger rescue/assist. Generic fish assist and Rigger assist each apply at most once per catch; neither allows repeated instant catches. All roles retain basic revive/fishing.
- [ ] Play mixed-role and all-Keeper groups. Check both lantern modes from moving cameras, not only static cones. Recharge at the boat and expose remaining active time. Commit `feat: add cooperative tools and bounded light protection`.

## Task 6: The consequential battery decision

**Files:** crew choice/battery console, station map dressing, discreet HUD ballot; `test_crew_choice.gd`.

**Interfaces:** `CrewChoice.open(voters: Array[String], now_s: float) -> Dictionary`; `vote(profile_id: String, station_id: String, now_s: float) -> Dictionary`; `roster_changed(voters: Array[String]) -> void`; `tick(now_s: float) -> Dictionary`; `snapshot() -> Dictionary`. Result uses `committed_station` only when a commitment occurs. Controller calls `LightRules.set_reserve` exactly once for that event.

- [x] Write failing vote tests:

```gdscript
func test_majority_commits_once_and_cannot_be_reversed():
    var c = CrewChoice.new()
    c.open(["crew_1", "crew_2", "crew_3"], 150.0)
    assert_eq(c.vote("crew_1", "reeds", 151.0).code, "pending")
    assert_eq(c.vote("crew_2", "reeds", 152.0).committed_station, "reeds")
    assert_eq(c.vote("crew_3", "jetty", 153.0).code, "already_committed")
```

Also assert one vote per person, two-player unanimity, single-player choice, cancellation on roster change, no stale vote reuse, ballot collapse after 15 s, reopening only at the dock before 180 s, and one jetty fallback at 180 s. Completed choice survives roster change.
- [x] Run red and implement the specified majority/fallback rules; run green. Do not repeatedly prompt after timeout. A cancelled popup can be re-opened only by a deliberate dock interaction.
- [ ] Make the battery trolley/cable, mast state and world illumination match the result. Preview exact consequences: “Jetty stays lit” / “Reeds staging point stays lit.” Never imply the unsafe area is locked.
- [ ] Place the jetty station on an exposed return section beyond the boat's permanent light. Place reeds protection near valuable fishing but outside that return section. Measure that the safe circles do not duplicate each other. Play both choices with a fixed seed; if one always wins, adjust route exposure/opportunity placement, not add another mechanic.
- [ ] Commit `feat: make crew battery choice change the night route`.

## Task 7: A complete expedition with understandable danger and rescue

**Files:** expedition rules/run controller, hunter rules/controller/scene, director, boat exit; tests `test_expedition.gd`, `test_hunter.gd`, `test_director.gd`.

**Interfaces:** `ExpeditionRules.start(run_id: String, profiles: Array[String]) -> void`; `advance(delta_s: float) -> Dictionary`; `set_paused(paused: bool) -> void`; `down(profile_id: String) -> Dictionary`; `revive(helper_id: String, target_id: String, held_s: float) -> Dictionary`; `set_aboard(profile_id: String, aboard: bool) -> void`; `set_ready(profile_id: String, ready: bool) -> void`; `disconnect(profile_id: String) -> void`; `snapshot() -> Dictionary`. Controller validates proximity/LOS for revive and maps model events to catch/save operations. `Progression.settle_run(run_id: String, catches: Array[Dictionary], delivery_modes: Dictionary = {}) -> Dictionary` commits eligible terminal payouts, settled_run_ids and day_index +1 atomically using existing bank validation; do not perform separate bank-then-day writes. `HunterRules.advance(delta_s: float, observations: Dictionary) -> Dictionary`; `Director.request(kind: String, now_s: float, context: Dictionary) -> Dictionary`; `Director.tick(now_s: float, context: Dictionary) -> Dictionary`.

- [x] Write failing lifecycle tests. Pin 180 s dusk, 240 s night, 570 s storm, 630 s terminal settlement. No double settlement when multiple events arrive on the deadline.

```gdscript
func test_pause_does_not_advance_storm_or_revive_clock():
    var run = ExpeditionRules.new()
    run.start("run-a", ["crew_1", "crew_2", "crew_3"])
    run.advance(200.0)
    run.down("crew_2")
    run.set_paused(true)
    run.advance(60.0)
    assert_eq(run.snapshot().elapsed_s, 200.0)
    assert_true(run.snapshot().players.crew_2.downed)
```

Add tests for 3 s revive, 25 s unrescued return, 3 s spawn protection, all-downed retreat, departure requiring connected crew only, disconnect removing readiness, 20 s refuge crossing and no duplicate catch/settlement award. Pause also freezes physical fish, water recovery, lamp drain and ability clocks and rejects gameplay intents. Settlement increments day_index once; dawn resets transient choice/hunter/fish opportunities while preserving equipment, supplies, caches, collection and repairs. Hunter warning is at least 2 s, pursuit is finite and recovery at least 20 s. Director rejects new pressure during rescue.
- [ ] Freeze a terminal snapshot before resolving pending writes: eligible aboard players, pouch custody, whole-fish positions/holders, already banked IDs and landed-but-save-pending outcomes. The authoritative tick processes the terminal deadline before new gameplay intents on that tick; later boarding/catches cannot enter this snapshot. Pause gameplay during a save-failure retry. Resolve pre-terminal pending deposits/landed records against this frozen snapshot, then perform terminal settlement. A pending landed outcome that has not yet spawned a physical fish can only contribute its packed value if its pouch recipient was aboard in the snapshot; otherwise only its discovery is retained. No stale callback may spawn cargo after dawn.
- [ ] Test whole fish aboard/in the marked boat cargo area receive the whole payout; packed cargo aboard receives its packed payout; loose fish ashore do not pay. Exclude already confirmed bank IDs and serialise pending deposit writes without recomputing boarding eligibility. A failed terminal save leaves day index, balances, cargo and the frozen result intact. Test a delayed/failed write spanning 630 s, attempted late boarding, a pending catch and duplicate settlement. Do not clear the run/start dawn until commit. Host exit still abandons transient unbanked cargo under the disclosed rule.
- [x] Run red, implement lifecycle/hunter/director and connect authoritative navigation. Hunter observations use host positions/LOS/light, not client reports. One movement controller navigates around shore boundaries; no teleport-to-target shortcuts.
- [ ] Handle safe rejoin: same profile at boat, empty individual pouch, full current world-cargo snapshot, no old active cast, previous role/rod/lamp retained. Shared whole fish remain once each in the world. Show disconnect cargo rule before joining. Host exit presents a clear return-to-menu reason.
- [ ] Run green, then complete the first entire loop on three clients. Test successful rescue, timed-out rescue, all-downed retreat, early exit, storm cutoff, pause, rejoin and host exit. Do not force a knockout in the normal run to demonstrate rescue.
- [ ] Get one short family run using the working block visuals before starting final polish. Record whether catching, optional physical delivery, role help and the battery choice produced an enjoyable moment. Fix the largest loop problem first; Task 8's presentation effort should follow what this run teaches. This is an early reaction, not Task 9's packaged acceptance.
- [ ] Commit `feat: complete night hunt rescue and boat extraction loop`.

## Task 8: Custom presentation and the parent's Lake Office

**Files:** refine the existing block assets, pivot animations, HUD/theme/audio; add Lake Office scene and host command path; `test_host_events.gd`. No detailed art pipeline, new creature rig or rendering dependency.

**Interfaces:** `RunController.apply_intent(peer_id: int, action: String, payload: Dictionary, request_id: String) -> Dictionary` routes authorised feature requests. `snapshot() -> Dictionary` composes the specified snapshot. It consumes all feature APIs from previous tasks. Host event types: `odd_catch`, `fog`, `sighting`, `clear_event`, `safe_return`; delegate scheduling to Director.

- [ ] Write failing permission/budget tests: a non-host event returns `not_host`; normal effects respect one active host event and 45 s cooldown; fog expires at 15 s; clear/recovery bypass cooldown; cosmetic catches retain the original value/behaviour; a sighting consumes/replaces scheduled pressure rather than adding a second hunter.
- [ ] Run red, implement bounded commands and run green. Parent opens the panel via host-only keyboard shortcut; a hidden menu is not the authority check.
- [ ] Finish the simple block assets/theme; keep primitive geometry as the intended style. Silhouettes must remain identifiable without colour. Refine casting lean, whole-fish flop/receive motion, two catch sounds, reel/dock feedback, closing bell and hunter tell before adding decoration or music layers.
- [ ] Verify UI at 1280×720: clean legible text, minimal permit HUD, fishing tension near the action, and two brief equipment descriptions. Subtitle important sound cues. Shake/flashing default minimal/off and scare audio adjustable.
- [ ] Review actual day/night screenshots and a running catch/pass/rescue against spec section 3's block-art criteria. Retired concept images are not acceptance targets. Check readable shore, teammates and return lamp, no fish/body obstruction and no clutter hiding prompts. Reduce effects/density before adding rendering features.
- [ ] Commit `feat: finish lido presentation and bounded host surprises`.

## Task 9: Package, verify the family setup and run the fun test

**Files:** `tests/integration/test_run_flow.gd`, README, `docs/playtest/first-family-test.md`; export into ignored `build/windows`. No content expansion.

**Interfaces:** this task consumes the earlier feature APIs and exported game's normal Host/Join UI; it adds no gameplay API. Integration fixture composes real models with an isolated temp SaveStore and deterministic seed, not fake success responses.

- [x] Write and run a deterministic rule-level full-flow test: two ordinary perch plus one ordinary Bellgill bank as **40 coins**; find Soft-tip Rod; open workshop cache; craft Surveyor for 30 + lens; repair walkway using its separate brass fitting; assert **10 spendable coins, 40 lifetime_banked**. Equip different gear; choose reeds, land an Oversized Perch, pass its same ID, rescue, board holding it and settle for another 20. At dawn/reload assert **30 spendable coins, 60 lifetime_banked**, crafted/found gear, consumed components, open caches and repaired path. Replay bank/craft/repair/settlement requests and confirm no duplicate spend, reward or day increment. Inject logical cargo events here; Task 2A's real-body test separately verifies trajectories/collision.
- [x] Run all unit tests and the integration script; inspect actual discovery counts and summaries. `--import`, successful debug export, test summary and hands-on observations are separate evidence. Save logs only for this build/test round.
- [x] Package the executable and its required data together, plus a concise README and licence notices. Verify from a copied clean output folder, outside the editor project. Exclude tests, GUT, tools, saves and personal paths from the package.
- [ ] Use three physical family PCs, host on the selected machine, clients on its LAN address. Verify initial join, a rejected mismatched build, catch/assist, pack/whole payout, pass/drop/water recovery, bank/unlock, choice, chase/rescue, early/storm exit, save/reload, client rejoin and host exit. Record build ID and each machine's result; unavailable devices mean that acceptance remains unverified.
- [ ] Measure weakest-PC performance at daylight and the busiest allowed night event. Test reduced-effects mode without changing gameplay light coverage. If the target cannot be met, reduce scenery/effects and retest the affected case.
- [ ] Play two ordinary family rounds, approximately 25 minutes total. One uses jetty and one reeds when practical; allow genuine decisions and never prompt players to pretend enthusiasm. Each independently states favourite moment, frustration, whether gear/physics/help mattered, and whether they want another trip. Record voluntary passes/rescues, repeated awkward drops, useless downtime and whether anyone feels compelled to haul every fish. Test at least one packing choice as a legitimate escape decision.
- [ ] Record what actually happened. Pass fun gate only if the family wants to replay or has one clear, bounded change worth testing. If fishing/teamwork is dull, revise that loop before authorising ranks, shops, maps or more fish.
- [ ] Commit `test: verify and package first family expedition` only with accurate evidence. Provide executable location, launch steps, tested device/build list and remaining limitations.

## Coverage and self-review

| Requirement | Owning tasks | Acceptance |
|---|---|---|
| Custom look, not mismatched assets | 1, 8, 9 | Actual gameplay-camera day/night and rescue captures; weakest-PC check |
| Three LAN players including host | 2, 9 | Three physical PCs, stable profile and authority tests |
| Fishing and optional help | 3, 5 | Repeat-catch play check and identical host/client outcomes |
| Useful physical comedy | 2A, 4B, 7, 9 | Actual three-peer pass/miss/recovery, safe controls and one reward per ID; real family reaction |
| Catch surprise and collection | 3A, 4, 9 | Eligible pools, visible variant, shared counter and persistent specimen records |
| Found/crafted personal gear | 4, 4A, 5, 9 | Found rod and 30-coin-plus-lens craft; independent equipment survives restart and alters play |
| Persistent island | 4A, 7, 9 | Repaired return path remains open next morning and after restart |
| Consequential crew decision | 6, 9 | Vote rules and two visibly different viable night routes |
| Hunter, lights and recovery | 5, 7, 9 | Tells, limited protection, rescue/retreat/departure cases |
| Secret parent controls | 8 | Host permissions, event budget and ordinary progression retained |
| Short scope and family fit | All, especially 9 | Hard cap; two real family runs before expansion |

Self-review at planning time: a 40-coin bank followed by a 30-coin craft leaves 10; a later whole Oversized Perch adds 20 once, leaving 30 spendable and 60 lifetime_banked. The lens and repair fitting are separate guaranteed finds; counters settle once; nightly choices reset while repairs persist. Physical fish never duplicate pouch cargo; failed settlement cannot discard the fish or advance the day. Block-art criteria replace the retired image target. No runtime test result is claimed. Full campaign content/ending and larger catalogues remain post-slice milestones.

### Evidence-led improvement loop

For each trial record build ID, seed/scenario, machine/peer, expected result, observed result, screenshot/clip or log path, and pass/fail/unverified. Keep four distinct columns of evidence: rule tests; actual engine physics/network behavior; rendered visual review; unscripted family reaction. A headless run or a screenshot cannot substitute for play. Capture the actual viewport from normal gameplay camera; don't use generated art or fabricated screenshots.

Run a seeded scenario, inspect the picture and motion, fix the largest demonstrated problem, then replay that scenario and one ordinary fresh run. For example: change pickup tolerance if receiving is frustrating; change payout/travel cost if hauling is always/never chosen; change tells if a chase feels unfair. Do not respond to an awkward toss by adding a skill tree or to dull fishing by adding more fish. Stop expanding when a core interaction still fails. If tools/devices/people are unavailable, mark that specific evidence pending and continue work independent of it; do not claim their experience has been tested.

## Full standalone release milestones after this slice

1. Finish the same island's five pockets; expand to twelve fish species/three behaviours, the bounded four-rod/two-lantern/tool-alternative catalogue, two shortcuts and three salvage types. Each added item needs a distinct use, deterministic acquisition route and multiplayer/save check.
2. Add workshop/beacon/Moth campaign milestones and the final coordinated night channel escape. Essential components are authored/guaranteed, not rare-drop gates. Complete an ordinary-start-to-ending playthrough, then continue the saved island voluntarily.
3. Finish New/Continue/Host/Join, graphics/audio/input settings, save backup/recovery controls, packaging and credits. Run clean-folder, offline-LAN, full-campaign and save/reload checks on the actual three machines. Only this stage can be called the full standalone game; the first slice cannot.

## Execution handoff

Review the revised spec, concept direction and checklist. Recommended method: implement the connected slice in this chat, use focused independent review for networking/save correctness and at the end, and keep the family playtest as the expansion gate. No separate user-owned chats or public repositories are required.

Suggested next prompt:

> Implement revision 4 of One More Cast in this chat using the saved design and checklist. Start with simple block characters, LAN movement and the oversized-fish grab/toss/receive test yard. Verify rules and rendered motion before expanding; keep movement reliable and do not add full ragdolls. Then connect pack-versus-whole rewards, fishing, found/crafted gear, the persistent shortcut, crew decision and night/refuge/dawn loop. Review authority and saves independently. Record what is actually tested, leave unavailable three-PC/family checks pending, and improve from observed play. Preserve the full standalone game's release milestones. Ask before publication, paid purchases or a remote repository.

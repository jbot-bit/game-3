# One More Cast — game and visual design

Revision 4 · 9 October 2026 · Australia/Brisbane

**Status — 10 October 2026:** revision 4's first playable is implemented in Godot and packaged for Windows. Actual rule/controller/Jolt tests, three independent local ENet processes and rendered game captures are now available. The full campaign remains the destination. Three physical PCs, weakest-laptop performance and the family fun gate remain unverified. See [first-playable evidence and acceptance](docs/playtest/FIRST_PLAYABLE_STATUS.md) and the implementation checklist for completed versus pending work. No remote repository or public release was created.

## 1. The experience

A complete standalone cooperative fishing RPG for a parent who liked WoW and two experienced gamers aged 14 and 12, including a Fisch fan. Live on one compact, persistent island: catch surprising fish, find equipment, craft useful alternatives, improve the camp, argue about a worthwhile risk, and get each other back to the boat after dark.

**The defining moment:** “You wanted one more fish. Now hold the light while I get your brother out.”

Everyone has a useful role, nobody is permanently assigned maintenance, and the family earns progress together. The humour comes from the crew's decisions, strange catches, and the parent's secret controls. The threat is readable and recoverable. These are hypotheses to test together, not a promise that a written design guarantees fun.

Confirmed priorities: private three-player co-op; rewarding fish variation/collection; found and easily crafted equipment; a small island that feels stranded; sunset hunter; lights, rescues and boat escape; saved RPG choices; consequential crew disagreements; a full standalone game. The latest direction explicitly favours simpler Minecraft/Roblox-like block graphics and useful physical comedy inspired by the family's enjoyment of Human Fall Flat. Gameplay takes priority over detailed art. Same LAN is confirmed. Keyboard/mouse is the first input target; controllers are a later addition if wanted. Minecraft and Terraria also inform useful discoveries and equipment-driven agency; they do not imply their enormous sandbox scope.

## 2. Chosen direction and alternatives considered

| Approach | Strength | Decision |
|---|---|---|
| Persistent island RPG with short expeditions | Catching, discoveries, easy crafting and rescue improve the same place across evenings | Selected |
| Broad survival/crafting game | Many activities and systems | Deferred: delays the three-person experience and risks chores |
| Short arcade fishing-horror rounds | Quick to build and repeat | Too little lasting character choice by itself |

The first playable is a **10–12 minute proof of the persistent game**, not the finished product. The full version has **20–25 minute expeditions**, a repair-and-escape campaign and optional continued collecting. No procedural continent, PvP, matchmaking, accounts, trading, refining chains, durability, daily chores, random-stat equipment treadmill, or realistic rope/water/boat physics.

### Full-game destination and completion standard

The crew is stranded at Last Light Island. Moth can reach a sheltered mooring but cannot safely cross the outer channel. Each night ends with a short boat escape to that refuge; dawn returns the crew to the same improved island. The final escape crosses the channel after restoring the beacon and repairing the boat. Afterwards, Continue Island allows voluntary return and collecting without inventing another shipwreck.

The campaign targets 8–12 ordinary expeditions, subject to family testing: establish the workshop; reopen two useful routes and restore the beacon; prepare Moth and complete a final coordinated night escape. No required campaign item depends on a rare random catch. Persistent changes include recipes, equipment, the collection journal, shared supplies, opened caches, repaired routes and campaign flags. Fish opportunities, temporary lights and hunter pressure refresh each day. Nothing decays while the host is offline.

| Area | First integrated playable | Bounded complete island game |
|---|---|---|
| Place | Full island outline; home/lido circuit and reeds finished | Five distinct pockets on the same island; two permanent shortcuts |
| Fish | Three species, two behaviours, one unusual variant | Twelve species, three behaviours, three optional specimen traits |
| Equipment | Two rods, two lanterns, three role tools | Four rods, two lanterns, three baseline and three alternate role tools |
| Acquisition | Starter gear, one found rod, one crafted lantern | Finds, short recipes, collection milestones and optional rare curios |
| World change | One repaired return walkway persists | Workshop, two shortcuts, beacon and Moth repairs; fixed upgrade sockets |
| Story | First night and dawn return | Three campaign milestones, final boat escape, continued island play |
| Product | Working local Windows test build | Packaged Windows game, New/Continue/Host/Join, settings, controls, pause, backup/recovery, clear ending |

Full-game delivery requires clean-folder launch without Godot/Roblox/browser accounts, three-PC LAN play, save/reload of world and characters, useful found/crafted equipment, readable progression toward the ending, audio/graphics/input settings, and actual family playtests. A prototype or three windows on the development PC is not the finished game.

## 3. Visual direction: a handmade block fishing camp

Use Minecraft/Roblox-like simplicity with original proportions and setting: a small abandoned island swimming camp, a crooked pier, a square warning beacon, oversized square bobbers, box lanterns and blunt fish. Keep the name Last Light Island and the lido as one pocket. Open water and an obscured distant shore establish isolation.

**The previous generated concept boards are retired as production targets.** Preserve them as design history only. No elaborate enamel wear, texture painting, imported skeletal rig or detailed character sculpt is required. The next visual evidence must be the running block scene at its actual gameplay camera.

### Three approaches considered

| Approach | Benefit and cost | Decision |
|---|---|---|
| Block crew with reliable movement, physical oversized fish and animated wobble | Low art cost; focused cooperative comedy; manageable LAN authority | Selected for the first playable, subject to the physics fun gate |
| Fully simulated floppy bodies, independent hand grips and physics climbing | Closest to Human Fall Flat's movement; major controller, camera, joint and networking work | Defer; not a small addition to this fishing game |
| Cosmetic flops only | Cheapest and stable, but no meaningful physical interaction | Fallback only if physical hauling fails its test; report the cut explicitly |

### Production rules

- Boxes, low-sided cylinders and wedges; flat colours, broad land shapes and simple collision. One trunk and one canopy per tree. No editable voxel terrain.
- Six-piece crew: head, torso, two arms and two legs, animated around pivots. Oversized square head and boots. One shared construction; jacket colour, name and tool distinguish players. Optional one-piece hat.
- Characters use a stable movement collider. Visible limbs lean, sway and stretch toward a held fish; this does not steer the camera or knock a player over.
- Palette: ink `#202D3A`, water teal `#397884`, grass `#77935B`, wood `#826347`, cream `#E4D4AF`, lantern amber `#FFD071`; crew accents blue `#62B9DB`, coral `#E67C61`, purple `#A28AD6`. Symbols/names supplement colour.
- Fish share box-body/wedge-tail construction: short broad Penny Perch, tall Bellgill, long Lantern Eel. Two eye marks and one colour patch are sufficient. Oversized changes actual silhouette and scale within a bounded collision size.
- Moth is a chunky skiff; the hunter is a tall crooked stack of simple shapes with a life-ring motif. The tower and square warning light identify home.
- Readable blue ambient night plus a few warm lights. Simple opaque animated water. No dependence on reflections, volumetric fog, global illumination or realistic water simulation.
- Elevated third-person camera, approximately 6 m away, horizontal orbit, limited pitch and collision correction. Carrying a fish never blocks the camera or covers the fishing/rescue UI. No platforming precision or mandatory physics obstacle course.
- Sparse cream permit HUD and large simple equipment icons. No ornate UI or permanent inventory grid.

The original feel comes from consistent proportions, colour, movement, fish sounds and the island layout. Primitive geometry is the intended finished style, not a placeholder to replace with expensive assets later.

### Motion, sound and acceptance

Start with a walking sway, exaggerated casting lean, fish flop and rope-rescue skid. Use simple pivot animation for the crew and actual bounded object physics for loose trophy fish. A rescue line is a visual line plus a validated pull, not a chain of simulated joints.

Sound carries feedback: reel clicks, wooden dock knocks, a hollow Bellgill note, closing bell and distinct hunter footfalls. Never reuse the threat warning as a comedy cue. Subtitle critical sounds; minimal/off shake and flashing; separately adjustable scare volume.

At the normal camera and 1280×720, all three players, species silhouettes, bobber, held gear, rescue target and route home must be identifiable in day and night. Test throwing, carrying and rescue in motion, including occlusion. The Lake Office remains a simple host-only panel with Fog, Odd Catch, Suspicious Splash and recovery controls. Art passes by clarity and consistency, not resemblance to the retired pictures.

## 4. The first expedition

The run clock starts when the crew enters the lake, after the brief role-selection lobby. Ordinary play is not paused by voting or equipment cards.

| Run time | Target experience |
|---|---|
| 0–150 s | Immediate fishing, optional assist, first banking trip; target first catch within 90 s |
| Around 150 s | A quiet invitation to choose the reserve battery destination; first saved equipment unlock should already be attainable |
| 180–240 s | Dusk; unresolved battery choice defaults to the jetty at 180 s with an advertised result; warning bell and first distant hunter tell |
| 240–570 s | Night fishing and alternating pressure/recovery. A natural rescue opportunity may emerge; never force a player to be caught |
| 570–630 s | Storm warning and final return opportunity |
| By 630 s | Departure/retreat resolves; reward recap aims to stay under 30 s |

Early refuge departure is available when all connected crew are aboard and ready. A 20 s scripted crossing to the sheltered mooring ends the outing; it does not end the campaign or require boat-driving physics. At 630 s, aboard players reach refuge and shore players retreat with lost unbanked cargo. Banked progress survives both outcomes. All incapacitated ends in retreat. Dawn returns to the persistent island; no menu reset or re-closed repaired paths. Host pause pauses gameplay clocks and cooldowns; unpausing does not jump time forward.

## 5. Fishing, equipment and permanent progress

### Two behaviours, three catches

Darting fish require controlled reel/release and opposing the pull. Heavy fish pull more steadily and offer an assist window. The first three species are Penny Perch, Bellgill and Lantern Eel; the eel reuses the darting behaviour and a long block body with a pivot tail. A funny perch variant is a trait, not another species. No separate puzzle per species and no button mashing. Hold/toggle reel options are available.

Target 10–20 s for common active catches and 20–35 s for heavy ones. Fish opportunities appear promptly and are visible. A player may cancel a catch at any time to escape. Everyone can catch alone; generic assistance adds one useful burst, while the Rigger has a stronger specialised option. Assists are bounded once per catch per type, not a repeatable instant-finish exploit.

Initial tuning data: Penny Perch value **10 coins**, Bellgill **20 coins**, Lantern Eel **40 coins**. Cosmetic host variants keep the original value. Safe jetty fishing offers dependable perch. Valuable night opportunities sit outside permanent light coverage, so the crew still has a reason to venture out after choosing where to power a staging point.

### Anticipation, discovery and fair randomness

The full island has six common, four uncommon and two rare species distributed across habitats and day/night conditions. Each specimen records species, measured size and at most one trait: Oversized, Moonlit or Stormmarked. These change silhouette/colour, journal records and bounded sale value; they do not generate an endless ladder of required equipment stats. Author a few fish forms carefully and vary them through original silhouettes/materials, not hundreds of untested meshes. In the slice, a packed Oversized catch sells for floor(base species value × 1.25); an optional whole-fish delivery is defined below.

Location and conditions determine the eligible fish pool, with useful clues in the journal. First-slice tuning: jetty day pool is 70% perch/30% Bellgill; reeds after dusk is 60% perch/30% Bellgill/10% Lantern Eel. Ordinary Oversized trait chance starts at 10% for eligible fish. Values are our tuning proposal, not copied or verified Fisch odds. Every landed catch shows species, size, new-record/new-discovery markers and a brief distinct reveal. Teammates see a compact celebration without losing movement control.

One transparent shared dry-streak counter per habitat tracks eligible completed non-rare catches. After eleven, the next newly started eligible cast offers a rare fish. Failed/cancelled attempts do not reset the streak; landing a rare does. Already active casts keep their original roll. Simultaneous casts may produce more than one rare opportunity; this is acceptable for a private family game. Persist counters and settled catch IDs so reconnection cannot duplicate rewards or erase the counter. Common catches and guaranteed salvage always advance equipment/story progress.

No paid rolls, streak penalties, expiring collection obligations or artificial near-miss presentation. The appeal should be anticipation, skill, a surprising reveal and a visible next objective. Collection and equipment progression still work on an unlucky evening.

### Physical comedy with a purpose

Normal fish go into the existing cargo pouch after a brief reveal. Only an Oversized specimen (initially 10% of landed catches) offers a **whole-fish haul**: one chunky, flopping object that anyone can grab, carry, drop or toss. Its catch ID, record and discovery stay the same through every interaction.

- The catcher can **Pack** it immediately, or a later carrier can pack it, for the usual floor(base × 1.25) value. Packing is irreversible; it enters that player's at-risk pouch. Save transient pouch custody separately from original angler attribution: the later carrier's disconnect/knockout rules apply to their pouch. No payout occurs until banking. This keeps awkward hauling optional.
- Deliver it whole to the boat's wide deposit crate for **2 × base value total**, replacing rather than adding to the packed value. An Oversized Perch is 12 packed or 20 whole; Bellgill 25 or 40; Eel 50 or 80. The shared crew receives the money, while the journal retains the angler's attribution.
- One carrier at a time, 85% normal walking speed, no casting while holding. The equipped lantern remains usable. Interact grabs/releases, the cast button becomes a short underarm toss while carrying, and a separate labelled Pack action requires a 0.5 s hold. Starting a revive/tool action drops the fish first. There are no individual-hand controls or mandatory two-person lifting.
- Grab range starts at 2 m with line of sight. A teammate holding Interact can receive a flying fish within a generous 1.5 m facing area. The host chooses the nearest eligible receiver, stable profile ID as tie-break; an input edge/brief latch prevents immediate re-release. Misses flop on the ground. Aiming need not be precise.
- Initial toss speed 5 m/s horizontal plus 2 m/s upward; cap free-body speed at 8 m/s, with no repeat impulse from a held button. Use a simple convex collider and bounded occasional flop impulse. Props collide with the world, not crew/hunter, so they cannot launch players, block rescues or serve as an invincible barricade.
- Maximum three whole fish active. A fourth offers the packed reward with a clear full-deck message; existing fish are never erased to make room. The test yard can force an Oversized fixture, but normal progression uses the declared catch table.
- Water/out-of-bounds returns the **same object and ID** to its last valid dry point after a 2 s visible bob. Update that point only on confirmed dry contact or a valid carrier position; never at the airborne water-crossing point. No teleport to the bank, replacement roll or second award.
- Knockout or carrier disconnect safely releases the fish for any remaining teammate. Another player holding it keeps it even if its original angler leaves. It is shared world cargo, distinct from individual pouch forfeiture/revive restoration. Do not recreate it during a revive.
- A thrown fish settling in the deposit area starts one bank transaction. Keep/reserve it until the durable save succeeds. Failure leaves it visibly pending for retry; no success sound, extra reward, packing or pickup while reserved. If it must be returned from reservation, restore the same object/ID.
- Whole fish physically inside the boat's marked cargo area or held by an aboard player can be included in successful departure settlement. Freeze aboard players, pouch custody, whole-fish locations and pending catch/deposit outcomes at the terminal deadline before save retries. Late boarding cannot change eligibility. Loose fish ashore are lost only when the run successfully settles; their discoveries remain. A pre-deadline landed outcome awaiting its initial save contributes at most packed value if its recipient was already aboard; it must never spawn after dawn. No new day or cargo disposal until settlement saves successfully. Host exit still loses transient unbanked cargo as disclosed.

The funny useful sequence is: land a ridiculous fish, pass it across a gap in the return route, drop it to help a teammate, recover it and toss it into the boat. This uses existing fishing, risk, rescue and banking. It adds no cart, crate puzzle, physics climbing, throwable healthy teammates, active ragdoll controller, simulated rope chain or simulated boat.

Before developing the rest of the content, test a small LAN yard with one fish, three block characters, one dock edge and a deposit crate. Keep the mechanic only if deliberate passes are useful, misses are recoverable, and it remains readable on both clients. After one focused tuning pass, simplify excessive flopping/air-catching first. If even controlled carrying and bounded throwing remain awkward, explicitly report the failed gate and reconsider the physical-delivery mechanic; do not quietly ship broken physics or expand into a ragdoll project.

### Three reasons to come back

1. **A worthwhile next catch:** journal gaps, biggest specimens and three eventual traits, using known habitat/day-night clues. Common catches keep recipes moving. No separate achievement tree or new currency.
2. **A different crew plan:** independent rod/lamp choices, the jetty-versus-reeds battery decision and an optional whole-fish bonus create different routes and rescue opportunities on the same map.
3. **A place you improved:** the found gear, crafted lantern and repaired walkway persist; the full campaign opens two shortcuts, restores the beacon and repairs Moth toward a real ending.

After the slice, feature a fishing pocket each morning using the existing day index and authored habitat tables, with its clue displayed at the dock. Use a short repeatable rotation, not real-world schedules or weather simulation; retain access to every required component. This is a small full-game variety pass, not another first-slice system. Add further mechanics only when a recorded playtest problem gives them a job.

### Meaningful roles from the start

| Role | Baseline ability | Why another player wants it nearby |
|---|---|---|
| Scout | 5 s pulse showing nearby fish opportunities and the hunter's recent trail; 30 s cooldown | Helps choose a profitable spot or a safer rescue approach |
| Keeper | 4 s protective light patch; 30 s cooldown; no stacking/refreshing from overlapping fields | Buys a short coordinated catch or rescue window |
| Rigger | 5 m line-of-sight rescue pull OR heavy-fish assist; 30 s cooldown | Turns a near miss into a recovery, or helps secure a demanding catch |

Roles can duplicate and switch at the dock between runs. Everyone has basic fishing, light and a 3 s nearby revive. No role is mandatory. Rescue pulls must respect traversable ground and obstacles. Three Keepers must not create uninterrupted protection.

### Find, craft and equip before the first night

At the lido, a guaranteed workshop cache reveals the **Surveyor Lantern recipe** and one **glass lens**. Crafting at the boat workshop costs **30 coins + 1 glass lens** and permanently unlocks the lantern for all three profiles. It is one recipe card and one action, not a crafting grid or shop. Show the exact effect and missing ingredient location. First-night pacing places this cache on the normal route so a short fishing trip can supply the coins.

A separate optional shore cache contains a complete **Soft-tip Rod**, also unlocked for everyone. It reduces tension build-up by 15% but lands heavy fish 15% more slowly. Finding it should visibly change the held rod and offer an immediate choice. Starter equipment remains capable of completing the game.

The first permanent walkway repair uses **1 brass fitting**, guaranteed in a nearby repair cache. This repair does not compete for the coins used by the early lantern. Both caches are once-per-household discoveries with visible empty/repaired states; opening the same cache twice cannot duplicate an item.

The full game uses only three salvage types: cord spool, brass fitting and glass lens. A recipe requires coins plus at most one salvage type. Examples: Soft-tip Rod 30 coins + cord spool as a fallback when the find was missed; Braced Reel 40 coins + brass fitting; Surveyor Lantern 30 coins + glass lens. Crafted equipment unlocks for everyone and each player equips independently. No mining tools, ore refining, inventory weight or intermediate components. Guaranteed caches/known salvage opportunities provide a deterministic path to every required recipe. Major story repairs use their own guaranteed components, so personal gear does not consume the only item needed to escape.

Each player independently chooses an owned lantern at the boat:

- **Flood Lantern (starter):** 70-degree beam, 8 m reach, 90 s total active time per full charge. Broad close-range visibility and longer endurance, useful when moving together.
- **Surveyor Lantern (earned):** 30-degree beam, 12 m reach, 45 s active time. Earlier long-range visibility for careful scouting, in exchange for precision and more frequent returns to recharge.

Both recharge at the boat without a consumable inventory. Ordinary lanterns illuminate and can briefly slow a hunter, but do not create a safe zone. Starting hunter response: 2 s maximum slowdown followed by 6 s shared immunity to further handheld-light slowdown. Keeper light and powered stations remain distinct protection mechanics. Values are first-test tuning choices and must be evaluated in play.

Save the shared unlock and each player's equipment selection immediately. The second outing begins with the earned options intact. Each player should be able to explain why their equipment choice changed a route, crossing or rescue—not merely how the cone looked.

### Economy and failure

- One household save; three persistent profiles with chosen name, role, rod and lamp; shared spendable coins, salvage, recipes, equipment ownership, specimen records and repaired world state.
- A new species discovery is saved when caught. Coins are committed when cargo is banked or extracted. One catch ID can be banked only once.
- Individual cargo is at risk; banked coins, discoveries and equipment are permanent.
- A knockout leaves a recoverable marker for that player's pouch cargo. A successful revive before the 25 s timeout restores that pouch; otherwise the player returns to the boat, losing its contents, with 3 s spawn protection. A whole physical fish is released separately and may be recovered by anyone; it is never restored into the pouch by revive.
- Client disconnect forfeits individual pouch cargo in the first playable; shared physical fish safely drop and remain for the crew. Rejoin at the boat with the same saved profile; make this distinction clear on the join/help screen. No mid-cast or disconnected-pouch restoration.
- Host exit/crash returns clients to the menu. Restart loads the last confirmed household save; no host migration or exact encounter resumption.

## 6. One crew decision that visibly changes the night

At the quiet dock interval, choose where the single reserve battery goes:

| Jetty | Reeds |
|---|---|
| Jetty shelter stays lit until extraction; easy return and regroup | Outer staging point stays lit until extraction; shorter retreat from valuable night fish |
| Longer dark excursion to the best catches | Longer exposed route back to the boat |

Both stations start with power until **240 s**. The chosen station remains powered through **630 s**. The unchosen station goes dark at 240 s. The boat's baseline safe light is permanent. Both areas always remain accessible; the choice neither locks a route nor forces the crew to follow one another.

The jetty station must sit on an exposed return section **beyond the boat light's coverage**, so it supplies genuinely additional shelter. The reeds station protects the profitable area's staging point but leaves that return section exposed. Avoid overlapping safe circles that make one choice redundant. Measure actual paths and coverage in the running map.

No fuel carrying, inventory, purchase or refill loop in this slice. Maintaining lights is one consequential allocation, visually realised by a battery trolley/cable and the powered mast. If the family later enjoys upkeep, test one additional repair interaction instead of automatically adding chores.

Voting rules: one initial 15 s unobtrusive ballot, two votes of three; two-player crews require both; one player decides alone. If unresolved, collapse to a dock interaction until 180 s, then use the visibly advertised jetty fallback. No repeated popup. Unresolved votes are cancelled on roster change and can be reopened at the dock with a fresh eligible roster; completed commitments never change. Never initiate the popup during a chase, revive or active fishing struggle.

“Stay for one more” is an organic disagreement expressed through actions. Players can split up, take a longer exposed route and ask for help. The game makes each person's position and trouble visible. Tonight's cargo and time are the consequences; no one can secretly erase another player's owned gear.

Pack versus haul the Oversized catch supplies the second dilemma using the same fishing and banking systems. Do not also add the previously suggested sell-versus-risky-bait mechanic; the whole-fish decision replaces it in this direction.

## 7. Hunter and secret controls

One Last Lifeguard has patrol, investigate, warn, chase, withdraw and recover states. Hunter movement uses navigable routes. It does not appear on top of someone or strike without a tell. A chase has a finite duration and a recovery interval, even if the crew stays outdoors.

Initial pressure budget: one hunter, no concurrent chase events, at least 20 s recovery after a chase, at least 2 s warning before an attack becomes possible. During an active rescue crisis the director does not begin a fresh hunt. A hunter already present may remain a threat, giving light and teamwork a purpose.

Host-only Lake Office commands in the first playable use existing systems:

- **Odd Catch:** next normal catch gets a silly appearance with unchanged value/behaviour.
- **Fog:** a 15 s visibility treatment, never below the navigational minimum tested on the map.
- **Suspicious Splash:** a distant sighting of the same hunter, not a new enemy. If it creates pressure, it replaces the next scheduled event.
- **Clear Event:** remove host fog/sighting; a separate safe-return recovery action retains banked progress without granting rewards.

Use one active host event and a 45 s event cooldown; recovery controls are always available. Validate host authority in the command handler. No reward cheats and no no-progression mode: the parent can surprise the crew while everyone keeps earning equipment.

## 8. Map and first-playable content cap

One authored island, starting around **180 m by 140 m** before play-measured resizing. Five pockets: home cove/workshop, swimming terraces, lantern reeds, rocky tide pools and beacon ridge. The diving tower and beacon orient the crew; ridges/reeds interrupt sightlines so the island is not visible in one glance. Open water and the dangerous channel establish isolation without long empty travel.

Tune by travel time: home to farthest useful place **60–90 s** before a shortcut, **25–45 s** after repair; full walking circuit **3–4 minutes** excluding activities; a meaningful landmark/opportunity about every **20–30 s**. No empty woodland or collectible confetti. Two return paths make splitting up/rescue worthwhile. No swimming exploration or freeform construction. The first slice finishes home/lido/reeds and one shortcut, while establishing the entire island silhouette; later pockets add authored activities on the same footprint.

The first slice contains three player profiles, one island outline, three tools, two rods, two lanterns, three fish species/two behaviours, one specimen trait, at most three whole physical fish, two power stations, one nightly battery dilemma, one hunter, one household save, one crafted item, one found item, one permanent walkway repair, one refuge crossing and the bounded host panel. Water is a visual boundary; shallow player contact returns to the last valid shore point without a new swimming/drowning system. Physical fish follow their separate 2 s recovery rule. Tether and camera must handle that boundary consistently. No loose crates, carts or physics puzzles are added to this slice.

Defer full campaign content, extra recipes/species, alternate role tools, story dialogue, XP/rank systems, shops, fuel inventory, extra maps, separate bosses, pets, controller polish and internet services until the persistent first slice works. Simple crafting and a visible world improvement are now mandatory in that first slice. The slice is a milestone toward the full game, not a substitute for it.

## 9. Technical decisions and carefully selected dependencies

**Selected architecture:** native Windows Godot game, Compatibility renderer, GDScript, ENet listen server on the parent's PC, two remote clients on the same LAN. Direct entry of the displayed host LAN address comes before optional server discovery. Three local windows do not prove three-device delivery. No cloud/database/account service, router port forwarding, UPnP or recurring hosting is required by this design.

Godot 4.7.2 was rechecked against the official latest stable release on this revision. Use built-in scene replication (`MultiplayerSpawner`/`MultiplayerSynchronizer`), Resource-based item/recipe definitions, simple pivot animation and spatial audio where useful. Keep reward/crafting/save authority explicit; replication is not a transaction system. Explicitly select built-in Jolt for 3D physics, stable CharacterBody3D crew and host-simulated loose RigidBody3D fish. Carry poses use controlled collision-aware placement with the body frozen/kinematic; release restores dynamic simulation. Do not repeatedly teleport an active dynamic body or parent it to a moving avatar. Clients interpolate host physics snapshots rather than independently resolving authoritative collisions. No Jolt addon, rope extension or ragdoll package. [Stable release](https://github.com/godotengine/godot/releases/tag/4.7.2-stable), [Jolt](https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html), [RigidBody3D](https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html)

The block style targets Compatibility. Optional Forward+ lighting is a later measured choice, not a required upgrade. GPU inventory access on the development host was denied; hardware/performance remain unmeasured. [Renderer options](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)

| Dependency or reference | Selection and scope | Source |
|---|---|---|
| Engine and export templates | Godot standard 4.7.2, exactly matched templates; no .NET or source-engine build | [Official Windows download](https://godotengine.org/download/windows/), [MIT license](https://godotengine.org/license/) |
| Networking | Built-in ENet; `create_server(24563, 2)` for host plus two remote clients, remaining arguments left at defaults | [ENet API](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html), [multiplayer guide](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html) |
| Tests, development only | GUT 9.7.1 for Godot 4.7.x; tag pinned, excluded from release | [GUT repository](https://github.com/bitwes/Gut), MIT |
| Reference only | Relevant official Godot demo snippets, only if they solve a concrete implementation gap | [Official demos](https://github.com/godotengine/godot-demo-projects); pin copied revision and retain applicable notices |
| Background art candidates | Select a few Survival Kit props, edit to match the style; Watercraft Kit may provide a boat base only if useful | [Survival Kit](https://kenney.nl/assets/survival-kit), [Watercraft Kit](https://kenney.nl/assets/watercraft-kit), CC0 |
| Characters | Original six-piece primitive crew with pivot animation; no imported rig dependency | Authored for this project |
| UI audio candidate | Small selected cues; does not cover all water/monster/fishing sound | [Interface Sounds](https://kenney.nl/assets/interface-sounds), CC0 |
| Hero assets and UI | Original block shapes, flat materials and simple icons; no additional runtime library | Authored for this project; track provenance |

Versions and source licences were researched, but archives, hashes, imports and compatibility are not verified by running them yet. Acquire only the pinned editor/templates, test addon and selected assets during setup. Record URL, tag/revision, archive hash and licence in `THIRD_PARTY.md`. Do not clone whole fishing/RPG templates or all asset packs. Kenney Fish Pack is 2D; it is not a 3D fish solution.

Compatibility is selected so style relies on geometry/materials rather than unsupported high-end effects. Check the weakest family PC early. [Godot renderer matrix](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)

Use one local repository in `C:\game-3` when execution is authorised. Preserve root `AGENTS.md`/`CLAUDE.md` if they appear. No Git repository is created by this planning revision. Public/remote repository creation, paid assets, publication or external deployment require approval.

The [source research and reuse decisions](C:/game-3/docs/research/2026-10-09-inspiration-and-reuse.md) select exact code references and reject costly foundations. Initially use zero runtime addons and GUT for development. Adapt reviewed snippets with their licence notices; do not graft unrelated Git histories together or clone a whole game because its name contains fish.

## 10. Runtime boundaries and recovery

The host owns casts/catches, physical fish state and simulation, currency, equipment ownership, cooldowns, lights, votes, the hunter and expedition time. Clients submit bounded intent; they cannot award fish, send balances, impersonate another profile or invoke Lake Office commands. State-changing events have stable IDs and explicit outcomes. Physical fish have one catch ID across loose/held/packing/bank-pending/banked states. They can never simultaneously be pouch inventory and physical loot. Pause freezes all authoritative bodies/timers and rejects gameplay intents until resumed.

Keep feature scripts focused: session/profile assignment, player controls, fishing, reward/save, equipment, crew choice, lights, hunter/director, expedition lifecycle and presentation. No general-purpose framework or remote service. Resources hold small item/behaviour definitions. Shared interfaces and test fixtures are pinned in the implementation checklist.

Profiles use stable IDs, never ENet peer IDs. Host assigns/approves a free profile slot when someone joins. Slot conflicts and mismatched builds produce a clear rejection. A disconnect cancels an open vote, removes readiness requirements and clears individual pouch cargo, but safely drops a held physical fish for the crew. Rejoin receives a full snapshot at the boat. Input from an old connection cannot still affect that slot.

Save schema includes schema version, household ID, save revision, spendable coins, lifetime banked value, salvage counts, learned recipes, owned equipment, discoveries/specimen records, per-habitat dry streaks, opened caches, permanent repairs, campaign flags, day index and profile loadouts. Include committed catch/craft/cache/repair/settlement receipts. A craft atomically validates and consumes both requirements and creates shared ownership; a failed save does none of those. Write a validated temporary save, preserve last-good backup, then replace. If saving fails, do not confirm rewards or clear corresponding cargo. Recovery prefers a valid current file, then backup, then offers a clearly labelled fresh game without overwriting damaged files. No automatic reset over corrupt data.

## 11. Iteration gates and scope discipline

1. **Readable block scene:** one real in-engine dock scene, six-piece crew, fish reveal and day/night comparison at gameplay camera distance. Retired concept pictures are not the benchmark.
2. **Three-person gate:** three physical PCs join, move and see the same catch outcome. Check direct IP, build match and executable-specific Windows Private-network firewall access; never disable the firewall globally.
3. **Physics gate before content expansion:** three-player test yard, a successful pass and a missed pass, water recovery, obstructed carry, simultaneous grab, mid-flight pause and disconnect. All peers agree on the same fish; nobody is launched/trapped. Include rendered motion review, not only headless rules. Ask whether the interaction was funny/useful or merely awkward. One focused tuning pass before simplifying it.
4. **Persistent RPG gate:** find the Soft-tip Rod, bank 30 coins, acquire the guaranteed lens, craft Surveyor, repair the return walkway, close/restart, and see/use those changes on the same island next morning. Also compare packed/whole Oversized rewards without duplication. If choices are only cosmetic or repairs disappear, this gate fails.
5. **Crew decision gate:** play both battery branches with the same encounter seed, then a fresh seed. Explain what changed about movement/safety and when each branch is useful; avoid an always-best branch.
6. **Fun gate:** first get one short family reaction as soon as the complete loop exists, before final presentation work. Then play two packaged family runs, about 25 minutes total. Each person independently names a good moment, a frustrating moment and whether they want another outing. Physics mistakes must be recoverable and the whole-catch bonus must not make packing feel like a punishment.

Observe first catch within 90 s, a useful voluntary assist/rescue, no forced maintenance role, no more than about 30 s incapacitation, understandable hunter catches and an unprompted debate over staying. Do not script those responses or count compliance as enjoyment.

If catches are dull, improve their interaction/feedback. If scares are unfair, improve tells and recovery. If the family wants more action, test one stronger encounter decision before adding a weapon system. If they prefer collecting, reduce forced pursuit and add optional dangerous catches. Let play evidence change the plan.

## 12. Delivery and honest estimates

The detailed checklist ends at the first family-ready persistent-island slice. Subsequent release stages are: expand the same island to its five pockets and bounded equipment/fish catalogue; implement the three campaign milestones and final channel escape; finish packaged-product settings/save management and run complete three-PC campaign/reload checks. The full game is not declared finished until those stages pass. Complete authority/saves early, then connect catch/find/craft/repair/night/refuge/dawn before expanding content. Check custom art during construction, not in an unspecified final polish pass.

The earlier 5–10-day slice estimate predates the added persistent world, crafting and specimen systems and is no longer a commitment for this revised scope. Re-estimate after the toolchain/asset acceptance and first LAN test. A polished complete island remains a multi-stage development effort, with real playtesting rather than a one-turn quality promise. These are plans, not evidence of work done.

## 13. Current evidence and next action

Confirmed: three Windows PCs, same network, custom visual identity and meaningful crew decisions desired. Workspace inspected: previously only the first planning document, with no Git repository or root AGENTS/CLAUDE files. Git is on PATH; Godot was not found on PATH. Family GPU specifications, asset imports, network reachability and frame rate remain unmeasured.

This revision incorporates the full-game, compact-island, crafting, Fisch-inspired collection, simpler block art and Human Fall Flat-inspired physical-comedy requirements. The checklist first tests whether a bounded whole-fish mechanic earns its place, then connects it to saved rewards and the full loop. Research and design checks have been performed; runtime logic tests, rendered play, imports and three-device/family acceptance remain unperformed.

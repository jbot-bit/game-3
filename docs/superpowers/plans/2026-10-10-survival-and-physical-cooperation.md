# Survival and physical cooperation revision

The user has authorized continued implementation and will test after delivery. This extends the approved small-island design; it does not reopen design approval or require family testing before coding.

The outing remains 630 seconds. Fishing funds saved equipment and island repairs. Darkness creates a shared risk: carry more home, prepare a field shelter, or leave while everyone can reach the boat. Home remains safe. No hunger, item durability, mandatory rare drop, full ragdoll controller, or extra map is added.

## Compact game limits — latest user requirement

These limits govern either the standalone game or a possible Roblox version. The user wants a short, challenging family survival game with persistent RPG choices and a reason to play again. This does not authorize a platform migration. Historical feature lists below are subordinate to these limits.

| Part | Target and limit |
| --- | --- |
| Island | One compact island, one recognisable home, a few distinct fishing pockets. First fishing opportunity within 8 seconds of leaving spawn; farthest useful area within 25 seconds of home at normal unburdened walking speed along the actual route. Time routes, not straight-line distances. No empty travel added to extend playtime. |
| Outing | Keep the existing 10.5-minute active-play limit and early safe departure. A family can play one outing or several without losing confirmed progress. First ordinary catch within about 45 seconds of starting play is a target, not a required tutorial timer. |
| First payoff | The first successful outing should provide a useful upgrade that can be banked, equipped and felt within 15 minutes of active play. A failed outing retains established equipment, discoveries and banked progress; the current unbanked haul supplies the risk. |
| RPG choices | Three equipment choices: rod, lantern and outfit. Keep the existing small catalogue; each item has one clear benefit and at most one clear tradeoff. Outfit pieces can create a complete visual set while being equipped as one choice with one perk. No separate hat/chest/legs/boots stat management or additional levelling tree. Existing role abilities stay optional, without mandatory jobs. |
| Finding/crafting | Useful equipment can be found, earned or made through the existing short recipes. At most a named part plus coins for a craft. Essential repair parts have guaranteed locations; rare fish never gate the main escape. |
| Main goal | Find the engine part and beacon coil, bank 120 shared coins, repair both and complete a night signal/return. A prepared crew can finish within one 10.5-minute outing; learning or retreat can span several. The former 60–90-minute estimate was unmeasured and is retired. No forced outing count or time padding. |
| Replay | Keep discovered fish, best specimens and alternative loadouts. Different catches, crew choices and recoverable physical mistakes supply variation. The ending is a real finish; further outings are optional. No daily chores, prestige resets or escalating grind required to keep playing. |

The shared risk remains **bank the haul, or risk another catch after dark**. One player can also commit the dock battery for the whole crew, choosing which field shelter stays lit; the first pull decides, with no majority ballot. Show consequences through carried loot, fading light and the return trip. A compact map must still be tested while carrying a fish with low light and a hunter nearby. Tune the existing threat, cargo and light rules instead of enlarging the island to manufacture tension. No player becomes a permanent generator attendant.

Physical comedy serves those same actions: carry, pass, toss, recover a fumble and rescue a teammate. Movement must remain dependable. Reuse those interactions rather than adding unrelated physics toys or a second combat game.

**Evidence:** see the current release section of `docs/playtest/CAMPAIGN_STATUS.md` for measured routes, earned outing/escape timings and remaining family acceptance. The former layout exceeded 31 seconds even in a straight line; the compact pass replaces it. Braced Reel and Drift Rod now each have one benefit and one tradeoff. Automated correctness and ideal-input timing do not establish enjoyment.

Next validation is one complete catch–carry–bank–equip outing and one pressured night return. Record time spent travelling, fishing and in menus; time to first equipped reward; where the crew has to cooperate; and whether a failure feels recoverable. Remove or simplify what delays these moments before expanding content.

## Implementation checklist

### Final compact-loop pass (authorized 10 October)

The destination is the existing standalone game, with a complete ending. Keep ordinary catches automatic; carrying an oversized fish is an optional higher-payout choice, never the main job. Fishing funds gear and repairs; guaranteed scavenged parts and the night beacon return lead to escape. Do not add health, hunger or cooking: the existing down/rescue rules already create survival cooperation, and another upkeep meter would compete with it. Saved alternative gear, discoveries and records support optional replay after the ending.

The user's latest correction restores an individual consequential choice. Replace the majority ballot with the first physical pull at the dock battery before dusk. Any player can commit the one reserve, immediately choosing which shelter gets 150 seconds. Name the player and affected shelters. The other shelter goes dark, home stays safe, and existing spare cells offer recovery. No extra currency, voting screen or sabotage system.

- [x] Compress actual routes: first cast spot within 8 seconds, farthest useful destination within 25 seconds unburdened; preserve physical widths, cast water and hunter traversal.
- [x] Reduce each rod to one benefit and at most one tradeoff; retain rod/lantern/outfit as the three gear choices.
- [x] Validate earned catch-bank-equip progression and optional whole delivery. Adjust existing prices/rewards only where measured pacing drags.
- [x] Validate one-player battery choice, dangerous loaded return, recoverable rescue, guaranteed repair parts and the complete escape/save ending.
- [x] Inspect rendered play and concise menus; get an independent critique; fix material faults.
- [x] Run full logic, three-process LAN and isolated frame-time checks; export and smoke-test the Windows build. Report automated evidence separately from three-PC family enjoyment.

Ruling: retire the unmeasured 60–90-minute estimate. Required repairs are engine and beacon (80+40 shared coins), in either order. The three other repairs are optional and use parts only. A competent crew may escape in one outing; do not inflate costs to prevent it. Continue keeps permanent progress and permits another night signal/escape using the existing mission reset. The ending remains a genuine stopping point.

- [x] Make the hunter physically patrol supported routes, investigate nearby cargo noise, and threaten a loaded carrier while an unburdened player can escape. Protect active revival without granting island-wide immunity for any downed player.
- [x] Give the chosen field shelter 150 seconds of night power. Place two optional, throwable spare cells on existing routes, each providing 90 seconds. Preserve free home refuge and recharge; stop draining lamps in daylight.
- [x] Add host-authoritative carrying of downed teammates with empty hands and slower movement, safe dropping and complete disconnect/timeout cleanup. Keep universal three-second revival available.
- [x] Add bounded fish flops and charged cargo throws. Cargo cannot launch players; missed throws recover from water.
- [x] Add compact rescue/power/throw feedback, actual trip outcomes and concrete collection goals after the ending. Add independent ambient and action audio with existing volume controls.
- [x] Test real controller boundaries, saves, pauses, rescue/cargo ownership, station consumption and three-process network agreement. Inspect actual rendered gameplay.
- [x] Review the integrated change, repair material defects, run the relevant suite, then export and smoke-test a standalone Windows package. Preserve the prior build and document exactly what has been verified.

Implementation uses existing Godot/Jolt/ENet, a licensed KayKit crew, original fish geometry and a small curated CC0 environment subset. Save schema remains compatible; transient supplies and rescue attachments never become persistent reward items. The host validates every interaction and replicates body poses. This revision adds no runtime dependency.

## User steering: quality, equipment and graphics

The user subsequently requested a blunt outside review, concise menus, visible equipment sets and a graphics overhaul. The normal-input agent review found the existing art looked like a blockout (2/10), navigation relied too much on text, and fishing involved 15–26 seconds watching meters. Those are observed/inferred issues from a scripted route, not human family ratings.

The working visual direction is a warm low-poly coastal diorama, clearer silhouettes and blue nights with warm lamps. A style preference question remains optional; this is the stated working assumption. Curate a small CC0 Kenney Nature/Survival/Watercraft subset, retain original crew/fish identities, inspect actual game renders and preserve walkable routes. No paid packs, accounts, rendering framework or realistic art pipeline.

- [x] Replace blockout trees/rocks/shore presentation, water, character and fish silhouettes; inspect matching gameplay views.
- [x] Keep Help separate from compact HUD; move connection details out of the play view.
- [x] Add three complete collectible outfits, one equip choice each with one explicit perk: Angler reeling, Deckhand cargo speed, Stormwatch lamp life. Unlock via existing discoveries/repair milestones; no extra currency or grind.
- [x] Review the new presentation in normal-input play, fix the highest impact issues, and package only after existing gameplay/save/network regressions remain green.

Useful reference principles: [Human Fall Flat](https://curvegames.com/our-games/human-fall-flat/) for cooperative physical mistakes; [Sea of Thieves emissaries](https://www.seaofthieves.com/news/all-about-emissaries) for visible loot and the choice to cash in. These are design references, not evidence this game's implementation will be popular.

## Latest direction: finish the core before adding anything

The user rejected the current UI as generic and instruction-heavy, reported lag, and explicitly preferred smoother play over graphics. They judged the work too broad. Further feature and scenery additions are frozen. Existing earned progress is preserved; no new system is justified by this polish pass.

Acceptance focus is one complete outing: join without confusion, move smoothly, understand casting and reeling, carry/throw/bank a catch, recognize the night threat, rescue, and retain confirmed progress.

- Separate Host and Join flows. Put each field beside its purpose; keep New Island inside the host flow with the existing save-preserving confirmation.
- Remove permanent objective paragraphs and full-width instruction panels from gameplay. Show the available action, small crew/status indicators, and fishing feedback only when relevant. Keep detailed controls in Help.
- Present each equipment choice with its effect and acquisition requirement. Collection detail belongs in the journal, not on the play screen.
- Measure real rendered frame times with isolated input, fixed views and explicit shadow settings. Do not blame free RAM without evidence or compare uncontrolled camera views.
- Cache unchanged catalog UI, avoid per-frame mesh rebuilds, reduce unnecessary route solves and collision updates. Preserve authoritative interaction and physics checks.
- Default to no MSAA and no shadows; shadows remain optional. F3 exposes local diagnostics without game commands or fake network-latency numbers.
- Re-run the full logic/network/campaign checks, inspect the actual revised screens, and export a clean Windows build. Human enjoyment and three-PC acceptance remain unmeasured until the family plays.

## Current implementation and platform question

The rejected procedural crew is now replaced by a licensed KayKit rig with real movement/action clips; earned outfit IDs and crew colours remain. GDQuest's MIT acceleration/retained-facing pattern informs the revised controller, while presentation interpolation, collision-aware exponential camera motion and mouse-wheel zoom remain integrated with LAN authority. Throwing and casting explicitly face their targets instead of rotating an idle character with every camera orbit. Asset/code notices are in THIRD_PARTY.md and LICENSES.

The shore now has a curved matching collision mesh, rounded inner cove, eastern tide-pool bay, quieter footpaths and matte natural materials. Physical water checks protect all five cast targets and Moth; three-slot floor/walking regression protects spawn. These changes are not approval of the visual result. The route, full-suite, performance and Windows export/startup gates have passed. The current v0.3 executable is packaged, with v0.2 preserved in the build archives. Exact evidence and remaining family acceptance are in docs/playtest/CAMPAIGN_STATUS.md.

The earlier Roblox comparison remains research only. The current authorized task finishes this standalone game. Details and family-access caveats are preserved in docs/research/2026-10-09-inspiration-and-reuse.md. No Roblox project, migration or public upload has occurred.

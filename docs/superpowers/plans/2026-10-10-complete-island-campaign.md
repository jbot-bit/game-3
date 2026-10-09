# Complete Island Campaign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or superpowers:subagent-driven-development. Follow RED → GREEN for behavior changes and preserve the existing household.

**Goal:** Turn the first playable into an end-to-end island campaign with collection, equipment choices, a real ending and continued island play; package the resulting Windows build.

**Architecture:** Extend the existing host-authoritative models and primitive world. CampaignRules describes progress and prerequisites; Progression still owns every durable transaction. One focused CampaignController owns final-escape interactions, composed by RunController. Local settings and safe fresh-island backup stay separate from network rewards.

**Tech Stack:** Existing Godot 4.7.2 / GDScript / Jolt / ENet / GUT 9.7.1. No new dependency, server, account, map generator or runtime addon.

**Spec:** ONE_MORE_CAST_PLAN.md revision 4, full-game destination. User explicitly requested continued coding/completion after receiving the slice; family acceptance remains pending, not a prerequisite to further authorized implementation.

## Global constraints and rulings

- Same three Windows PCs, same LAN; original block visuals and stable controllers.
- Keep the current 630-second short outings as the default while pacing is untested. Do not lengthen sessions merely to hit the earlier 20–25 minute estimate.
- Preserve version-1 saves; additive/defaulted profile tool fields and existing campaign_flags/repairs suffice. Build ID becomes 0.2.0-campaign; all three PCs need the same build.
- Twelve species, three fishing behaviors, three mutually exclusive optional traits; four rods, two lamps, three baseline/alternate role tools. No XP grind, cash shop or durability.
- Five authored pockets on the same footprint. Two useful permanent shortcuts, workshop, beacon, engine, night escape, ending, Continue Island.
- Guaranteed campaign-part flags never share consumable recipe salvage. No rare catch required for any campaign step. Initial costs are tuning hypotheses; no fixed multi-night grind gate.
- Continue in the clean existing feature branch; preserve v0.1 ZIP/output via the build script. No public actions.

## Shared contracts

- Species.catalog(): dictionary metadata includes value, behavior, name, rarity, habitat hint; helpers value_for(species,trait,whole=false), is_rare(species). CatchTable keeps roll(...) signature and old Jetty/Reeds boundary behavior, adds terraces/tidepools/beacon pools and pool(habitat,time_band) for actual journal odds.
- Traits: none/oversized/moonlit/stormmarked; exactly one. Only oversized produces physical cargo. Whole payout still twice base; ordinary packed none/base, oversized ×1.25, moonlit ×1.5, stormmarked ×1.75, rounded down.
- Campaign repairs: workshop, return_walkway (unchanged), ridge_steps, beacon, moth_engine. Authored cache IDs and marker maps returned by IslandContent.cache_markers()/repair_markers(); root creates all markers. Dedicated cache flags supply story parts; gear caches use only cord_spool/brass_fitting/glass_lens.
- CampaignRules.status(state): {stage,title,objective,repair_id,can_escape,completed,repairs:Array[Dictionary],tools:Dictionary}; no writes. CampaignRules.tool_unlocked(state,role) uses collection/repair milestones. Progression.set_tool(profile,mode) stores standard/alternate without changing role; locked requests fail.
- Progression.settle_run(..., complete_campaign=false) saves eligible rewards, day receipt and escaped campaign flag atomically; completion requires all repairs and cannot be granted by client intent. Existing three-argument callers remain valid. Repeated completion cannot duplicate rewards.
- Final escape: after repairs, crew explicitly arms at Moth during night, visits beacon to send the signal, returns and every connected crew member readies at Moth. All actions validate range, phase, prerequisites and live roster. A successful crossing commits ending; failure/retreat does not. Continue Island is host-only and preserves all progress.
- HUD consumes snapshot.campaign status and snapshot.escape transient state, displays next concrete objective/requirements/ending; dynamic catalog/gear/recipes rather than another hard-coded list.
- SettingsLocal persists local master/threat volume, mouse sensitivity, invert Y, window mode and reduced effects. Root applies them; no gameplay safety radii change. Key bindings persist; UI shows current mapping. New Island requires explicit in-game confirmation and verified dated archival copies before replacing a save.

## Review focus

1. Existing save with unlocked equipment loads without reset; failed write does not spend story parts or unlock ending.
2. Expanded species and traits derive payout from host catalogue, never client catch_value; old receipts remain valid.
3. Disconnect, all-down, late join and save retry around the final crossing cannot create an unearned ending or deadlock the crew.
4. Campaign guides point to supported, reachable ground and permanent shortcuts change actual collision/navigation.
5. Fresh-island/reset and settings cannot destroy the household or remotely change the host's save.

## Task 1 — Saved campaign and unlocks

**Files:** progression.gd, save_store.gd, crafting.gd, island_content.gd, new campaign_rules.gd; focused tests.
- [ ] Write/run failing legacy-save, repair prerequisite/cost, separate story-part, tool unlock, completion transaction and safe archive tests.
- [ ] Implement durable campaign/gear APIs and preserve current save behavior.
- [ ] Run existing and new progression/save tests; report exact public contracts.

## Task 2 — Fishing/gear variety

**Files:** species.gd, catch_table.gd, fishing_rules.gd, equipment.gd, block_art.gd, physical_fish.gd; focused tests.
- [ ] Write/run failing tests for twelve reachable species, pool boundaries, two rare habitats, traits, third behavior, four rod tradeoffs and normal/whole value.
- [ ] Implement data-driven rules and recognizable primitive fish variation without changing whole-fish authority.
- [ ] Run existing fishing/cargo/physics tests plus new catalogue tests.

## Task 3 — Product UI and settings

**Files:** hud.gd; new settings_local.gd; HUD/settings tests.
- [ ] Write/run failing settings roundtrip/clamping, campaign/ending display and dynamic catalogue/equipment tests.
- [ ] Add actionable campaign journal, recipes/tool modes, ending/Continue, safe New Island confirmation, local settings and binding UI.
- [ ] Verify 1280×720 readable layouts and source startup.

## Task 4 — World, role tools and final night integration

**Files:** run_controller.gd, new campaign_controller.gd, ability_rules.gd, main.gd, island.gd, gameplay_effects.gd, session contracts; composed tests.
- [ ] Write/run failing range/prerequisite, final signal/boarding/roster/save-failure and continued-island tests.
- [ ] Integrate the five pockets, new caches/repairs, two shortcuts, useful tool sidegrades, final escape, local settings and save archival flow.
- [ ] Inspect actual rendered movement, casting, repairs and ending; fix concrete visual/interaction problems.

## Task 5 — End-to-end release

- [ ] Run full tests, true three-process network checks and a complete campaign/reload scenario with deliberate save-failure/reconnect edges.
- [ ] Fresh independent review; fix material findings with regressions.
- [ ] Build a new portable Windows package, inspect exported content and clean-folder startup, preserve original build and document hashes.
- [ ] Update source plan/checklist/README and commit tested work locally.
- [ ] Three physical PCs, weakest-laptop performance and family enjoyment remain explicitly pending until observed.

# Family characters implementation plan

Approved for implementation by the user's request to build the concept, preserve unlocks and test a three-player match. Hosting must remain undeployed. Additional correction: Tyler must have a clear small smile/mouth.

## Ownership and interfaces

- Root: local mesh-authoring tools, family GLBs/materials, family_visual.gd, world.gd rig integration, rendered review, packaging.
- Profile/UI worker: profile.gd, main.gd and focused profile/UI tests. No edits to world.gd or generated assets.
- Multiplayer verification worker: family-specific network test scripts and normal-match driver identity setup, coordinated after API contract below. No runtime physics edits.

Shared contract: equipment dictionary is {character: blank|evie|tyler|dad, outfit: existing ID, accessory: existing ID}. Profile.characters() returns ordered [{id,name}] entries; Profile.valid_character(value) returns an allowlisted String with blank fallback; Profile.select_character(id:String)->bool persists without touching unlocks/bags/equipped clothing. Profile.outfit() includes character. Defaults select blank; old save migration preserves inventory, bags and redeemed IDs. Multiple peers may select the same identity. world.gd owns visual application.

## Task 1: Save-safe selection

Create tests/family_profile.gd: test old fully populated profiles, backup recovery, character selection/reload, invalid ID, unchanged inventory/bags/redeemed and random bag opening preserving character. Update profile_test.gd expected full sanitized dictionary. Implement schema migration independent of inventory gating. Add compact controller-usable Character selector above the existing preview and preserve focus when rebuilding wardrobe. Verify native UI and preview update. Keep progression item count and rarity weights unchanged.

## Task 2: Authored family meshes and rig fitting

Preserve 0.11 runtime snapshot/manifest. Obtain verified local Blender tooling if accessible; if unavailable, author equivalent actual indexed GLB meshes locally with editable generator and record the tool limitation instead of blocking on installation. Never submit photos to a paid 3D provider. Separate face, eyes, explicit smile, hair, beard and clothing layers; use chunky sculpted locks and fitted headgear variants. Tyler smile is mandatory. Keep game collider, animation transforms, ball anchors and sim.gd bytes unchanged.

Create assets/characters/{evie,tyler,dad}.glb and family_visual.gd using the existing named rig transforms; integrate into world.gd::_make_actor/_equip_actor with character in cache key. Preserve blank appearance and all existing clothing/accessories; family skin/hair must not be team-tinted. Same body size and hitbox. No reference JPGs or concept sheet in exported resources.

## Task 3: Appearance coverage

Create tests/family_visual.gd with all 126 family/outfit/accessory combinations; inspect finite transforms, identity retention, face/mouth existence, symmetric hands and all visible attachment nodes. Capture native front/side/back starter views, outfit/accessory contact sheets and actual carried-ball/dunk/roll/Giant poses. Use Game Development Studio mesh validation and capture comparison where applicable. Review pixels; fix clipping before freezing export. Structural coverage alone is not a visual pass.

## Task 4: Multiplayer and match

Create tests/family_network.gd and runner: host Evie + clients Tyler/Dad, actual register-equipment/roster/snapshot path, late join, rematch, repeated identity, team switch and outfit changes. Validate ID fallback and profile invariants. Give existing normal-input recorded match drivers explicit isolated family profiles, not real user saves. Complete a three-client match versus bots, verify score/winner/rewards agree, inspect rendered frames and preserve recordings. Local three processes are not physical three-PC evidence.

## Task 5: Export and closeout

Export separate 0.12 builds only after source checks. Include new scripts/GLBs in source manifest. Run relevant exact-pack profile, network, controller, world/dunk and physics regressions plus actual standalone startup. Prepare x64/x86 EXEs and concise controls/release notes. Preserve 0.11 files and source privacy; no hosting change. Public publication is separately reconciled with the existing EXE publication authorization and must contain no original photos.

## Review focus

1. Old equipped items accidentally stripped by character migration: populated old-save fixture.
2. Character change erases bag rewards or collection count: repeated selections around earned bag open.
3. Same identity on multiple peers conflicts with seat/team: duplicates, team switch and late join.
4. Hats erase recognisable hair or cover Tyler's mouth: full combination visual sheets and close views.
5. Rebuilt wardrobe drops controller focus or leaks previews: real input selection/reopen and node-lifecycle checks.

No additional approval round is needed for the already approved local implementation. Paid services and hosting remain outside authorization. Preserve sibling projects and household saves.

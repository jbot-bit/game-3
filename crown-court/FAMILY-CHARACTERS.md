# Family characters: local 0.12 review build

Updated 12 October 2026. Evie, Tyler and Dad are now selectable, animated 3D characters. Tyler has an explicit visible smile. This is a functional local review build; the latest meshes still do not match the approved illustration's hair, garment shapes or finish. Public 0.11 executables remain unchanged. Internet hosting remains undeployed.

## Play

Open build/crown-court-0.12.0/CrownCourt.exe (or CrownCourt32.exe). Use this same review version on all PCs. Open Wardrobe, choose Character, then choose any owned outfit/accessory. Fresh Bean remains available. Characters are free and independent of blind bags. Multiple players can choose the same character.

The profile migration preserves inventory, bag count, equipped clothing/accessory and redeemed match IDs. No household saves were overwritten during verification; all tests used isolated profiles. Selecting a character does not rename the player or change movement, collision, reach or scoring.

## Visual work and remaining gap

The approved reference is .tools/art-sources/crown-family/family-concept-v1.png, outside the exported game. Actual runtime renders are in build/crown-court-evidence/family-visual-v8-final. Playwright's front/side comparison is saved under output/playwright/family-review. The first rejected meshes remain recorded for comparison.

Revision 8 adds shaped torso/hem, mitten thumbs, shoes with laces/soles, curved hair masses, textured cloth/hair, a continuous beard and fitted headgear. Skin and signature hair retain their colours on both teams. The current models remain visibly simpler than the concept: hair and facial styling remain simpler than the illustration, sleeves look separate, and garment shaping needs further art work. The overlapping jersey number and cap/headphone fits were corrected. Automated checks do not certify likeness or visual approval.

## Tools actually used

- Official portable Blender 3.6.23 at .tools/blender/blender-3.6.23-windows-x64. Editable generators, .blend files, procedural textures and receipts are in .tools/art-sources/crown-family. Current generator: build_family_v8.py (revision 8).
- Godot 4.7.2 imports the three GLBs and attaches them to the existing animated rig. Players need only the EXE.
- Game Development Studio 1.5.0 validated all three revision-8 GLBs. Its sealed capture run covers the earlier revision 6, not revision 8. Revised review limits: 30,000 triangles and 16 materials per identity. Measured: Evie 21,576 triangles; Tyler 16,696; Dad 26,096, plus shared animated limbs/accessories.
- Playwright opened and captured the comparison page. It did not control the native Godot game. Native captures and gameplay came from Godot's rendering and normal-input test drivers.

No paid 3D provider was used. No original photo or concept image is included in runtime resources or published. Reference photos remain in .codex-remote-attachments.

## Evidence and limits

- Family profile migration: 48 checks; existing profile regression: 23 checks.
- Controller-driven family menu: 20 checks. Real hardware remains a household test.
- Appearance structure: 507 checks across 126 family/outfit/accessory combinations. Native front, side, rear and cosmetic captures retained; this is not an aesthetic pass.
- Family dunk/Giant poses: 37 checks. The character work keeps collision/hand anchors unchanged; subsequent tackling changes are documented in TACKLING-REVIEW.md.
- Three local room clients tested selection, late join/rejoin, duplicate identities, team changes, invalid IDs and rematch. This is local networking, not Internet or three physical PCs.
- Recorded normal-input match: family-tackle-final-room. The three automated player clients won 4-0; all agreed on match/result/cosmetics and each received one bag. 881 native frames over 155 seconds, 39 delivered tackle events, and unchanged runtime/asset hashes throughout. This recording precedes the final approaching-carrier bot-aim correction. It is not three-person human play.
- Exact Windows build verification is recorded separately under family-tackle-final-release-r2 and family-tackle-final-x86-r2. Only claim completed checks present in their receipts; native startup and headless pack verification are distinct.

Remaining household checks: likeness approval, comfort/readability in motion, real controllers, existing personal save after normal launch, and three physical PCs on LAN. Internet play remains unavailable until separately approved hosting deployment.


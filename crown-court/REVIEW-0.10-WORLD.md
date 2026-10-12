# World presentation review, 0.10

The corrected arena presentation is frozen and accepted for exact-package testing. The independent nine-view review is [REVIEW-0.10-ARENA.md](REVIEW-0.10-ARENA.md); it contains the native checks, actual image observations, geometry clearance and construction/render cost. This note records the implementation and Game Development Studio evidence handoff.

## Authored changes

The field now follows the shared simulation road mask: broad, flat pale crowns connect winding side routes, transverse crossings and curved goal approaches. Saturated banks separate those routes from recessed green turf. Every terrain vertex samples the authoritative floor helper; the renderer adds no colliders or substitute movement physics.

The original procedural stadium surrounds the court with three crowd tiers, continuous fascia, substantial goal-end shells and four elevated bean mascots. These structures remain outside the playable rectangle. The camera, hoops, ball attachment and release, actors and gameplay dimensions were retained. New scenery joins the existing selective occlusion system.

The first native pass exposed reversed terrain winding and interpolation bridging across intersecting banks. The repair corrects the actual clockwise front faces and refines only cells with excessive analytic-height error, stitching shared edges. It reduced the maximum sampled centroid discrepancy from 0.418m to 0.04345m. All 103,936 final terrain triangles face upward; native scenery checks report no playable-area intrusion and omit no crowd instances. These claims are measured by the retained fixture, not inferred from a screenshot alone.

## Frozen evidence

- Corrected source/native result: [v10-arena-corrected](../build/crown-court-evidence/v10-arena-corrected/result.json), 37/37 checks, nine PNGs, empty stderr.
- World SHA256: `C15BB6C966A6BA277813D32283D6C870CC076846E480A0CE7F4A65A14DC8A25F`.
- Captured Sim SHA256: `1E6263A850BD23814EFCB291C38DAF86028937CBF21597878B3BBD51A17F0160`.
- Exact 0.9 baseline: [v10-arena-before-clean](../build/crown-court-evidence/v10-arena-before-clean/result.json), package SHA256 `9120C048816C600EB2EE5BD0C9DF0B15056E99EA50655827E2460E785EC149BB`.
- Import helper SHA256: `764B3B7B3CE6E5215A8F8D136629CB430828E17A007F5DE05F941182BDA51C15`.
- Adapter manifest SHA256: `E9827DA9201781E306D09E6B980A320B0AB790B12FC500EA4DB24CA582EB4B00`.

Source copies and the exact loaded probe are retained with the native results. The source Sim hash identifies the captured geometry; any later bot-only or other production edit must be reflected in the exported package evidence.

## Game Development Studio receipts

The existing game-owned `import-arena-review` scenario imports the eight paired native PNGs without modification. Before import it verifies their hashes, fixed camera transforms and FOV, original native renderer log, empty stderr, baseline package hash and retained candidate source hashes. The ninth outside-shell image remains native evidence only because no baseline counterpart exists.

All nine CLI operations succeeded: plan, run, capture verification and visual analysis for each phase, followed by comparison. Receipts are in [v10-arena-cli-final](../build/crown-court-evidence/v10-arena-cli-final/compare.json):

- Baseline run: `run_1791780176132_a1190e1119d04aa784cf99ccfbc52849`.
- Candidate run: `run_1791780183564_f78a4ff05d9740e7bb47cccb9eafe794`.
- [Baseline verification](../build/crown-court-evidence/v10-arena-cli-final/baseline-verify.json), [candidate verification](../build/crown-court-evidence/v10-arena-cli-final/candidate-verify.json), [candidate analysis](../build/crown-court-evidence/v10-arena-cli-final/candidate-analyze.json), and [paired comparison](../build/crown-court-evidence/v10-arena-cli-final/compare.json).

These are **CPU imports of already captured native pixels**, not another GPU execution or performance measurement. Pixel differences document the intentionally changed terrain and stadium; they do not score quality or prove gameplay improvement. Direct image acceptance was performed separately by the world owner, root and independent arena reviewer.

The initial CLI attempt remains in `v10-arena-cli`: its manifest used an object in a scalar metadata field and failed contract validation. The helper now writes scalar source hashes. No game source or raw native evidence changed to resolve that import failure. Failed first terrain images and winding-RED receipts also remain intact.

## Limits and next gate

Close bank color boundaries retain some faceting, and sunlit crowns are bright. The denser stadium costs more: this source run constructed the arena in 5.94s and reported 1,397 median follow-view draw calls. Its 75 warm CPU samples are uncontrolled host measurements, not a causal comparison or GPU frame-time guarantee.

There is no further blocker in these source fixtures. They do not establish natural gameplay across all roads, human enjoyment, household controllers or cross-home Internet service. The next gate is the frozen exported package's native arena receipt and normal-input match recordings, with active-play motion reviewed separately from kickoff/reset camera cuts.

## Repeated-build audit

A subsequent read-only concern was that menu, mode, lobby and match transitions might rebuild the arena. The current code already avoids this: `main.gd` constructs one World during setup, and `world.build()` returns after refreshing team materials when `built` is true. There is no later World replacement or reset of that flag in these files. An additional mesh cache would not remove a repeated delay because that construction path is already skipped.

The external headless [timing probe](../build/crown-court-evidence/v10-build-audit/result.json) loaded unchanged production code through a timing-only subclass. With six actors present, 30 alternating coop/versus/teams build calls took 0.084ms median, 0.126ms p95 and 0.263ms maximum. The terrain builder ran once; the terrain mesh identity and scene-node count remained unchanged. No production edit was made.

The same uncontrolled headless run measured an 8.61s first build: 4.09s adaptive terrain, 7.37s court construction inclusive of that terrain, and 0.138s stands. This confirms a one-time startup cost, not a repeating UI cost. These component timers are not comparable to the earlier native run as a performance experiment; build activity and host scheduling were uncontrolled.

## Final package acceptance after the dunk repair

Final world source SHA256 is `1EA66E7412AFE6E701EC5327B72F6CDFAE71E00DC769665126A6285ED1602743`. The narrow subsequent change makes active-dunk heading and released rim-hand contact use the committed dunk direction. Held hands still follow the supplied ball position. The nine transform regressions pass; physical scoring with changing inputs is covered separately by the 64-check simulation/application regression.

Executable SHA256 `12BB9FF780BD9F273E9DF3D10ED0F0295C71C09C5614980C3B0C9B855044AC6B` passes the final native arena gate, 37/37 with empty stderr. All nine final PNGs are byte-identical to the independently reviewed corrected source and earlier package views at identical cameras. Geometry, terrain fronts and full native scenery-transform clearance remain accepted. [Final independent image/hash receipt](../build/crown-court-evidence/v10-release-pack-arena_review/independent-review.json). This static acceptance does not replace the final complete-match review or establish human, household or WAN play.

# Crown Court arena reconstruction, 0.11

The 0.10 court's broad 3 m raised crowns and steep colored faces consumed too much of the green field. The player view looked across cliffs toward a nearly rectangular bright backdrop. The 0.11 reconstruction lowers and narrows the physical routes and replaces the goal-end silhouette with a broad semicircular team shell and curved stepped terraces. This is authored geometry from public visual observations, not recovered Crown Jam dimensions or collision meshes.

## References actually inspected

The arena worker opened the actual local pixels of `reference/official-overhead.jpg`, `reference/fullmatch-1.png`, `reference/v9-source-35.png` and `reference/match-detail-155.png`, together with `build/crown-court-evidence/v10-release-pack-arena_review/01-overview.png` and `05-player-follow.png`.

The overhead shows connected rounded pale routes enclosing open green pockets. The gameplay/player-camera frames show relatively shallow shoulders and a broad rounded team-colored structure with steps above/behind the basket. The local 0.10 images show taller wide crowns, steep faces and the rectangular-looking end ramp. The retained gameplay is from [the public full match](https://www.youtube.com/watch?v=ZU24J-EkOVQ); official article provenance remains in REFERENCE-0.9.md. No research image, branding or proprietary artwork is admitted into runtime assets.

## Shared physical surface

`arena_layout.gd` is the single analytic layout. Static functions are `bank_height(x,z)`, `road_center_x(z_abs)`, `road_cross_z(x_abs)`, `road_profile(distance)`, `road_weight(x,z)`, `floor_height(x,z)` and `floor_normal(x,z)`. World consumes this module directly; Sim delegates its terrain helpers to the same functions. Surface support for the retained kickoff deck stays in Sim.

- Bounds remain 64×112; hoop centers remain Z±48,Y4.6. The four launchers, speed pads and rotating hazard footprints retain their coordinates.
- Road crowns are 1.15 m high and 3.8 m wide, with 2 m eased physical shoulders on each side. These shoulders are visible mesh faces and authoritative floor heights, not decals hiding the old 3 m cliffs.
- Side road X centers follow absolute-Z knots `(0,21),(10,22),(21,20),(29,21),(43,12)`, with smooth joins and fade at Z44–49. Crossing roads bow from absolute-Z20 at the flank to 22 at midfield. Front goal approaches use 9.5 m-radius loops with a rear fade beyond Z49.
- Outer side banks start at absolute-X28 and rise to 1.35 m; end banks start at absolute-Z50 and rise to 1.65 m. The goal center remains on low turf. The maximum analytical terrain height is 1.65 m.
- Pale muted team crowns, a thin colored crown bevel and pale shallow shoulders preserve route readability. Green turf retains restrained authored grain and mowing bands. Existing original center/team emblems, crowd tiers, mascots, booster frames and basket occlusion handling are reused.

The initial 4.4 m crown trial left 56.1% of the inner field below 0.08 m. Narrowing its crown to 3.8 m produced 58.58% low turf within the outer-bank starts. The 0.11 sampled minimum normal Y is 0.6444, compared with much steeper 0.10 bank faces. These are local authored measurements rather than calibrated original-game ratios.

## Goal-end architecture

Each end has a convex curved footprint wholly beyond the physical Z56 boundary. A semicircular team shell spans X±18 and rises from 1.65 m to 8.95 m at its center. Eight curved terrace treads behind it rise from 9.2 m. Rounded trims and end posts frame the shell; an original ball/comet line motif fills the central backdrop. These structures introduce no hidden collider or implied playable ledge inside the field. The retained kickoff deck remains the only elevated supported departure surface behind the basket.

The follow camera, 72-degree FOV, physical rim opening, sectioned foreground rim/net fading, fixed dunk direction and body/hand contact contract remain the established presentation interfaces. Camera changes are not used to hide terrain or architecture differences.

## Verification state

New `tests/terrain_v11.gd` samples the shared surface and compares it with production Sim, measures green-pocket coverage, checks physical route running/rebounds, launcher departures and real jumping dunks at both goals. Existing `tests/arena_review.gd` supplies the same nine camera fixtures, actual mesh/physics height agreement, upward terrain fronts, triangle clipping against the playable rectangle, basket opening rays and foreground occlusion rays.

Initial source-only arena probe: 59,752 terrain triangles, versus 103,936 in the retained 0.10 native report. Inspectable scenery has no boundary intrusion, no collision bodies, both basket openings have 0/9 blocked rays and the four special body/ball sightline fixtures have 0/9 blocked rays. Headless MultiMesh transform readback is unavailable, so this does not replace the native clearance gate. After Sim delegation, the source arena probe passes all 36 checks: maximum actual mesh vertex mismatch is 0.000050 m and maximum sampled triangle-centroid deviation is 0.03925 m. The initial native nine-view probe also passed all 37 checks with actual crowd and trim instance transforms available. Its output is retained in `v11-source-arena-native/`. Pixel inspection revealed hard material threshold transitions that made route edges look jagged; continuous vertex-color blends and a dimmer thin crown line replace those thresholds. Final native captures of that material revision pass all 37 checks in `build/crown-court-evidence/v11-source-arena-final/result.json`. The worker inspected all nine actual output images: the material-class jaggies and blown-out crowns are reduced, shallow shoulders/open grass are visible and foreground basket fading preserves the actor and ball. These are fixed-camera source fixtures, not an exact-export or full-match acceptance claim.

The production terrain probe passes all 15 checks after Sim delegation, including five running shoulder routes with no airborne frames, physical rebounds, all four launcher departures and real jumping dunks at both hoops. Its sampled height query costs 2.20 microseconds per call on this local uncontrolled run; this is CPU timing, not a GPU or household performance benchmark. Receipts are in `build/crown-court-evidence/terrain-v11/result.json` and `v11-source-arena-headless/result.json`. Native fixed-camera comparison, exact-export verification and full gameplay integration must pass before acceptance. Automated local probes cannot establish the user's second-PC compatibility, physical controllers, household enjoyment or real cross-home play. Private Crown Jam constants remain unknown.

The focused production pose probe `tests/presentation_v11.gd` passes 45 checks. A single impact/recovery roll uses the remaining 0.65-second authoritative knockback timer instead of repeatedly wobbling on the world clock. Body/root aim and camera stay independent of that roll; braced hands and tucked feet support the impact. Dunk reach/slam presentation now uses the production reach/release phases and per-player duration. Fresh aim cannot rotate the committed axis; maximum carried-ball/hand midpoint gap is 0.0942 m. The native pose fixture passes the same 45 assertions and retains three inspected images of impact, peak roll and recovery in `build/crown-court-evidence/v11-source-impact-native/`. The images use the established player-follow camera and 72-degree FOV; root aim and camera do not rotate with the body. They are controlled timer/position fixtures, not a natural hit sequence or human-play claim. The final integration recording remains necessary.

## Source receipts and remaining integration

Final checked world SHA256: `A75C029897734F664C17FA5AB5A51F4AEF0A79703CD13D1391FBEBC7E392C452`.
Shared layout SHA256: `428279A7684A6991B3CDDA4B4ACF8C6DD0D173D278D4DD366DB1DD374263E157`.
Terrain probe SHA256: `D68459EF047FBE4E00FF7EDF2D9A27E99B19A8E6AACC44EF7BCD1DA2CBFE127D`.
Pose probe SHA256: `002FB6F759AC51498DD837102D397646D9EE3308F5F95300D43BAF3B962A71FF`.
Production Sim SHA256 at final native capture: `D53F38A0F6946B284682366AEEED0B2A5F86E74C6B343757786031968043BC43`.

The final native construction sample reports 899 scene nodes, 748 unique meshes, 362 override materials and 2,287,772 instanced triangles including the retained crowd. The sample records 1,302 median draw calls; the independently running user-owned download executable was not controlled. These values are descriptive engine counters and uncontrolled CPU/process timers, not a clean performance comparison. New arch and step trim uses the existing instanced tube helper to bound draw-node growth.

Include `arena_layout.gd` in every runtime export. Run `terrain_v11.gd`, `presentation_v11.gd` and the unchanged `arena_review.gd` on the final exact pack; the old `terrain_v10.gd` deliberately asserts obsolete 3 m crowns and is not a valid dimension gate for this revision. Complete normal-input offline/network matches, inspect action footage and preserve exact-build receipts. The arena worker made no export, Git, publication or sibling-game edits.

## Game Development Studio sealed comparison
Game Development Studio CLI 1.5.0 imported the existing native PNG/report bytes on CPU through the preserved `import-arena-review` scenario. Two explicit additional phases, `v11-release-baseline` and `v11-source-candidate`, dispatch to `tests/capture_v11.mjs`; earlier phase mappings and sealed runs remain intact. Both plans required only local execution confirmation. No GPU or hardware-performance flags were supplied. The generic-capture doctor checks pass.
The importer checks all nine image digests, 1280�800 PNG dimensions, equal camera position/target/FOV, the same arena fixture script digest, passing native reports and available actual MultiMesh transform readback. It also verifies the retained 0.10 executable against the baseline report digest. Original native stdout/stderr files are absent from these two capture directories; provenance states this limitation explicitly. The new run stdout/stderr belong to the CPU importer and are not represented as native engine logs.
- Baseline run: `.game-dev/evidence/.game-dev/runs/run_1791793950717_cacda0e10ad643c1b254671431c9d19e/`; run-manifest SHA256 `488B4195F4E5706F80778506CAD160B77241B6F925342F97A254FA3C0D91CE73`.
- Candidate run: `.game-dev/evidence/.game-dev/runs/run_1791793961486_da0a992ed1f14ecd81583f9909fc1cee/`; run-manifest SHA256 `C14783EE513BD7AC8D988835184A9494CE0F043A222271009FB576CA655B85AB`.
- Comparison: `.game-dev/comparison/v11-v10-final-f349662d/comparison.json`, SHA256 `D5B02343587AE2C9FB9599F8283665AF205CF944DCA6C8C96EC1A54F4B27F153`; this new directory also contains the report HTML and nine heatmaps.
Both `capture verify` results confirm a closed and hash-verified artifact roster, valid capture contract and decoded raster bytes. Both `visual analyze` runs complete successfully on all nine color rasters. The threshold-0, antialias-tolerance-0 comparison matches all nine pairs with no unmatched frames and returns `changed`, as expected for an intentional geometry/material reconstruction. The custom native-report/provenance attachments are sealed and verified, but are not semantic object-ID/depth/normal rasters.
| Matched view | Changed pixels at threshold 0 | Mean absolute channel error | Mean luminance delta |
| --- | ---: | ---: | ---: |
| 01-overview | 6.69% | 0.01029 | -0.00527 |
| 02-raised-routes | 55.21% | 0.10330 | -0.08623 |
| 03-padded-rotor | 69.34% | 0.04901 | +0.00554 |
| 04-open-basket | 61.18% | 0.11351 | -0.03746 |
| 05-player-follow | 64.60% | 0.03951 | -0.00372 |
| 06-rear-rim | 63.21% | 0.12772 | -0.00288 |
| 07-giant-rear-rim | 71.11% | 0.11051 | +0.00159 |
| 08-through-backboard | 71.65% | 0.10495 | +0.02610 |
| 09-outside-goal-shell | 49.64% | 0.08311 | -0.06193 |

The worker inspected the road-view and player-follow heatmaps in addition to the previously inspected native images. Pixel-change fractions include small channel differences, not only visibly different structures. These statistics and heatmaps establish changed raster bytes; they do not establish causality, artistic quality, improved play, GPU performance or human enjoyment. The baseline is an exact retained 0.10 export, while the candidate is the recorded source arena revision with the source digests declared in its native report. Later review fixes or final exports are outside this comparison until separately checked.
Importer SHA256: `3E6643950589B0F6C07177C6983A5AD0A4A198C0537413A2EA35D835DD300BC8`. Existing dispatch-wrapper SHA256 after the scoped addition: `CD51CBFF8E865728F0A004339AA53B0785E043626CAB6DB476D44A56638E58F0`. CLI plan notes that an imported JavaScript module is not bound by the wrapper executable digest alone; source/runtime freshness and the sealed output bytes are distinct evidence.

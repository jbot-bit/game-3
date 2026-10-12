# Arena review, 0.10

The corrected source arena passes this controlled visual and geometry review. All nine native images were inspected independently. It has substantially stronger route, goal and stadium landmarks than the retained 0.9 build without changing the eight paired camera transforms or their 72-degree FOV. This is permission to continue release testing, not acceptance of an exported package or proof of household play.

## Evidence and scope

- Before: [v10-arena-before-clean](../build/crown-court-evidence/v10-arena-before-clean/result.json), exact 0.9 executable SHA256 `9120C048816C600EB2EE5BD0C9DF0B15056E99EA50655827E2460E785EC149BB`. Its 27 checks passed with empty stderr and eight native images.
- Corrected source: [v10-arena-corrected](../build/crown-court-evidence/v10-arena-corrected/result.json), **37/37 checks**, empty stderr and nine native images. Every image hash was checked; the first eight camera positions, targets and FOVs equal the baseline records.
- The ninth view specifically places the camera outside the north goal shell, looking through it toward a player on the kickoff deck. It has no paired 0.9 image and is an added clearance case.
- The fixture constructs the real World and Sim with one controlled player and held ball. It does not change preferences or inventory, simulate a full match, or establish controller/network behavior.

Source versions in the corrected capture:

| File | SHA256 |
| --- | --- |
| `world.gd` | `C15BB6C966A6BA277813D32283D6C870CC076846E480A0CE7F4A65A14DC8A25F` |
| `sim.gd` | `1E6263A850BD23814EFCB291C38DAF86028937CBF21597878B3BBD51A17F0160` |
| `tests/arena_review.gd` | `4F77192F793AB4AC787B3EFC073DC61F6B0AF60E384459012DB99A13A6635604` |

The archived baseline probe hash is `98B7C458A6B2EC0382958598EAFC29B4648063CF3FCAF7B7BC7C2185E91FFA6E`. Later test additions strengthened geometry checks and added the ninth view; they did not alter the original eight camera fixtures. Source copies are retained beside the corrected result. Any later production change needs its own exact-package gate.

## Image review

The [overview](../build/crown-court-evidence/v10-arena-corrected/01-overview.png) now shows connected winding crowns, recessed turf pockets and curved basket approaches. Three tiers of crowd, continuous colored fascia, substantial goal ends and four elevated original mascots establish a surrounding stadium. This addresses the three observed 0.9 gaps: shallow straight routes, isolated hoops and an empty horizon.

The [ordinary follow view](../build/crown-court-evidence/v10-arena-corrected/05-player-follow.png) keeps exactly the baseline camera and player position. The player and held ball remain distinct against the turf; the far rim is still visible above the raised transverse route. The two mascot silhouettes enter the upper frame. Their full height is visible in the oblique route, rotor and basket views; the ordinary follow camera does not tilt upward to display them.

The [raised-route](../build/crown-court-evidence/v10-arena-corrected/02-raised-routes.png), [rotor](../build/crown-court-evidence/v10-arena-corrected/03-padded-rotor.png) and [basket](../build/crown-court-evidence/v10-arena-corrected/04-open-basket.png) images keep the navigable crowns, low turf, rotor silhouettes and open scoring area distinguishable. Some close bank edges retain a visibly faceted color boundary, and sunlit road tops are bright; neither produced a missing walk surface or blocked target in these views.

Rear-rim, Giant, through-backboard and [outside-shell](../build/crown-court-evidence/v10-arena-corrected/09-outside-goal-shell.png) views preserve the followed body and ball. Existing selective occlusion transparency remains active. The test verifies that it does not move the prescribed camera.

These comparisons use the retained public reference images for layout and visual hierarchy, not recovered original geometry, dimensions or camera settings. Reference images are not shipped assets.

## Reproduced failures and repairs

The first source images were rejected. [v10-arena-facing-red](../build/crown-court-evidence/v10-arena-facing-red/result.json) records **57,344 incorrectly facing terrain triangles**: mesh vertices matched physics, but clockwise front-face winding was wrong, making the playable top disappear. The new winding check catches this independently of authored normals. The repaired native mesh has **zero wrong fronts across 103,936 triangles**.

The initial new terrain also deviated from its analytic surface by **0.418m** at the worst tested triangle centroid. Selective refinement reduced that to **0.04345m**, below the old arena's **0.10414m**. All mesh vertices remain within **0.000051m** of the actual physics height. Centroid error is a measurement, not a proof that every point on every triangle has that maximum error; no permissive threshold was added to conceal the first failure.

The first baseline attempt, `v10-arena-before`, had a fixture initialization error and is excluded. `v10-arena-before-clean` is the accepted comparison.

## Clearance and rendering cost

Both scoring openings have zero blocked rays out of nine. Each of the four rear/occlusion cases has zero blocked body and ball rays out of nine after normal occlusion processing. Snapshot byte checks confirm that rendering leaves authoritative state unchanged.

New scenery has zero collision bodies and no triangle footprint entering the playable rectangle. This checks actual transformed mesh triangles after an AABB broad phase, including nondegenerate vertical faces; it does not reject the enclosing bowl merely because its whole-mesh AABB encloses the field. Native MultiMesh readback is verified by a known-transform roundtrip, with **zero unavailable instances**.

The same roundtrip returns identity under Godot's headless renderer. Headless results explicitly omit 15,600 unavailable crowd instances and cannot establish full scenery clearance. The build must use the native gate for this claim. No production metadata or hidden collision was added to work around that test limitation.

| Measured component | Exact 0.9 baseline | Corrected 0.10 source |
| --- | ---: | ---: |
| Arena construction, one run | 2,910.812ms | 5,939.642ms |
| Scene nodes before player construction | 600 | 993 |
| Mesh instances, including MultiMesh entries | 5,231 | 17,133 |
| Instanced triangles | 1,370,556 | 2,298,884 |
| Unique meshes | 490 | 848 |
| Material overrides | 190 | 458 |
| Follow-view draw calls, median | 931 | 1,397 |
| `present` CPU median / p95 | 0.705 / 0.798ms | 0.907 / 1.005ms |
| Process-frame gap median / p95 | 8.402 / 11.082ms | 8.342 / 14.864ms |

The 75 warmed samples exclude screenshot readback. These are uncontrolled single-run CPU component timers, process scheduling intervals and engine draw counters. They are not GPU timings, matched load experiments or a complete-match performance claim. The denser stadium has a real construction/draw cost; the final package and longer recordings must retain that context.

## Remaining gates

No further blocker was found in the corrected nine-view source review. Continuous movement over the new banks, bots, passing, rebounds, scoring and all camera trajectories are outside this static fixture. The simulation owner separately tests those mechanics. Complete the exact-package native gate, affected mechanics/network checks and normal-input recordings before packaging. Physical controllers, three separate household PCs, public Internet service and human enjoyment remain unverified by this review.

## Exact-package closeout

The build's embedded native arena gate subsequently passed **37/37** with empty stderr on executable SHA256 `0B601D55B3EC358404463A536443DD7EAAC575B321DAB83DF252CA3F4D0D9930`. All nine PNGs are byte-identical both to the independently inspected corrected images and to the final source gate. Their cameras and recorded image hashes also verify. No duplicate native run was needed. [Independent package receipt](../build/crown-court-evidence/v10-final-pack-arena_review/independent-review.json).

The packaged run retains zero wrong terrain fronts, zero unavailable MultiMesh transforms, zero scenery intrusions and the same 0.04345m centroid measurement. Its construction timer was 5,679.635ms; warmed `present` median/p95 was 0.885/0.941ms with 1,397 median draw calls. The same component-timing limitations apply. Network and complete-match gates remain separate from this arena receipt.

## Final executable after gameplay repairs

The earlier executable remains before evidence. The final rebuilt executable is SHA256 `12BB9FF780BD9F273E9DF3D10ED0F0295C71C09C5614980C3B0C9B855044AC6B`. Its embedded native arena gate passed **37/37**, with empty stderr. Independent file-hash comparison confirms that all nine images remain byte-identical to the reviewed corrected-source and earlier package views, with unchanged camera positions, targets and FOV. [Final independent receipt](../build/crown-court-evidence/v10-release-pack-arena_review/independent-review.json).

Actual renderer transform readback remains available for every scenery instance; intrusion and reversed-face counts remain zero. Geometry measurements are unchanged. The new run measured construction at 5,548.031ms and warmed `present` median/p95 at 0.914/1.017ms, with 1,397 median draw calls. These remain uncontrolled CPU component measurements, not evidence of a performance change. The fixed dunk direction and deck-edge prediction have separate physical/presentation regressions; this static arena acceptance does not replace their exact-package or full-match checks.

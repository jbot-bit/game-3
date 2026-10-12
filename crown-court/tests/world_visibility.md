# 0.8 visibility revision ledger

Approved scope: `world.gd`, focused visibility fixtures and CPU artifact import. No Sim, input, audio or camera-trajectory retune.

- [x] Inspect retained 0.7 offline rear-rim frame near movie98.81s and room contested-goal frames939/942.
- [x] Preserve exact0.7 pack identity and before source; reproduce opaque rim/net hiding the local torso and carried ball.
- [x] Split existing TorusMesh triangles/normals and existing net/base strands into8 angular sections. Fade only sections whose cached bounds cross the rendered torso or held-ball sightline. Keep the original backboard/deck behavior.
- [x] Native final baseline:4 failures/9 checks. Candidate:9/9. Rear view goes from9/9 torso and8/9 ball rays blocked by opaque arena geometry to0 each;62.5% of the rim stays fully opaque.
- [x] Direct native before/after inspection for normal/Giant rear rim, camera at backboard and clear approach. Clear-approach raster delta is below0.01%.
- [x] Existing13 feel,8 polish and10 actual throw/dunk regression cases pass.
- [x] Game Development Studio CPU import/seal, capture verify, visual analyze and matched raster comparison pass.
- [x] Exact compiled0.8 package repetition:9/9 checks and all4 PNGs byte-identical to inspected source captures.
- [ ] Full-match integration review after release-owner recording.

Run `tests/world_visibility.gd` headless with `--evidence-dir=<unique-folder>`. Add `--capture` without `--headless` for four native frames. When using `--main-pack`, pass `--pack-source=<exe>` after `--`; compiled baseline identity comes from that file SHA. The test's CPU triangle intersection checks and cached mesh extraction are diagnostic only; the production renderer uses cached section bounds.

Final world SHA256: `FCE222C666ACF83AF08271B1BCF3F34F89484DDC7F26704FA80EF6344A65AC8E`. Evidence: `build/crown-court-evidence/v8-world-visibility-final-{before,after}` and `v8-world-visibility-cli`.

Tradeoff: sectioning adds56 small geometry submissions across both baskets. Triangle and net-strand counts are unchanged. No performance improvement is claimed. The camera and authority snapshots are unchanged. Temporary transparency is deliberately confined to obstructing sections; it can be visible as gaps/ghosted foreground structure during close goal views.

Compiled package SHA256: F64672B2B8520728827B2D64C746B7FC8113D99280A98C38F33EB8622FE1822D. Independent image/file verification receipt: build/crown-court-evidence/v8-release-world-visibility-render/source-comparison.json.


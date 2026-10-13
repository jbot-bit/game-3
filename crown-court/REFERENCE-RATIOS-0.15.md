# Crown Jam reference proportions — 0.15

This is a read-only comparison of retained primary gameplay frames and local source/GLB geometry. It recovers no original game constants. The 5.8-unit candidate hoop is an authored response to the user's request for a higher hoop and restores the former local bean-to-rim proportion for the taller family characters.

## Exact local geometry

The baseline simulation in `C:/game-3/crown-court/sim.gd` declares HOOP_Y=4.6, RIM_RADIUS=1.65, RIM_TUBE=0.28 and BALL_RADIUS=0.52. The rim is centered at z=+/-48; the terrain at the basket center is zero. `world.gd` constructs the visible ring from those radius/tube values.

The default bean body's top is y=1.70: center y 0.97 plus half of the 1.46-unit capsule height (`world.gd`, `_make_actor`). The small cap reaches about 1.73. Idle squash, steps, costumes and Giant form can change the current silhouette; the table uses an ordinary standing body without raised arms or accessories.

Family GLBs are attached directly beneath the existing rig with no identity scale multiplier (`family_visual.gd`, `apply`). Read-only GLB JSON measurement transformed the eight corners of each mesh POSITION accessor's min/max box through its node hierarchy, including translation, rotation and scale. Results are nominal mesh bounds, not a native animated-pose measurement. Shared procedural shoes are separate and bring the stance down to approximately y 0; the identity-only GLBs begin at y 0.20.

| Character | GLB file | Identity top above player origin | Baseline rim / top | Candidate 5.8 rim / top |
|---|---|---:|---:|---:|
| Evie | C:/game-3/crown-court/assets/characters/evie.glb | 2.163983 | 2.1257 | 2.6802 |
| Tyler | C:/game-3/crown-court/assets/characters/tyler.glb | 2.157110 | 2.1325 | 2.6888 |
| Dad | C:/game-3/crown-court/assets/characters/dad.glb | 2.155772 | 2.1338 | 2.6905 |
| Default bean | Procedural capsule | 1.700000 | 2.7059 | 3.4118 |

Thus the taller family cosmetic bodies reduced visible rim-to-body ratio by about 21.5% while simulation dimensions stayed unchanged. The 5.8 candidate restores roughly 2.7 times standing family height; it makes the same rim about 3.4 times default bean height. The latter is a conscious mixed-character tradeoff, not a uniform ratio across all avatars.

## Original footage and bounded estimates

Primary gameplay: [Raks, Game 1, no commentary](https://www.youtube.com/watch?v=4IdjAgwrwgc), especially 159.5 seconds; [Tocanscenes, Unreal Rank Gameplay](https://www.youtube.com/watch?v=ZU24J-EkOVQ), retained in the reference directory. Existing REFERENCE.md and REFERENCE-0.5.md establish provenance. No new footage was downloaded and no GPU process was run for this comparison.

Strongest retained near-ground comparison:

- `C:/game-3/crown-court/reference/v5-raks-dunk-two.png`, first tile, labelled Raks 159.5s. A grounded bean is adjacent to the basket, before the subsequent assisted dunk. In this 640px-wide tile, the rim centerline is roughly y 155–165 and local ground around y 265–275. Bean sole is near y 272 and body top around y 220, excluding the carried/nearby ball and head accessory. Rough apparent rim-height/body-height ratio is about 2.0–2.3. The exact body boundary is partly overlaid and the player and basket are not at the same depth; a cautious plausible interval is approximately 2.0–2.8, not a confidence interval or calibration.
- `C:/game-3/crown-court/reference/raks-detail-123.7.png` and `raks-dunk-2.png` corroborate the basket being substantially above standing head level and a distinct assisted ascent. The local carrier is already airborne, so dividing rim height by that player's current ground gap would be invalid.
- `C:/game-3/crown-court/reference/raks-detail-124.4.png` gives the clearest close ball/rim view, but the camera is tilted and the ball is above/in front of the rim. Estimating along the ring's major axis gives a rough outer-rim/ball image ratio of about 4–5 and opening/ball ratio about 3; uncertainty from depth and partial cropping is substantial. The 159.5s tile yields a larger apparent outer ratio, demonstrating why these should not be treated as exact dimensions.

Local exact ratios are outer rim diameter/ball diameter = 2*(1.65+0.28)/1.04 = 3.712, opening diameter/ball diameter =2*(1.65-0.28)/1.04 = 2.635. Footage permits an impression of a somewhat wider opening but does not establish a reliable mismatch large enough to justify changing radius alongside height. Keep the radius for this bounded correction and verify the raised hoop's shooting/dunk reach and framing.

Conclusion: source footage does not establish that 2.13 is an incorrect Crown Jam ratio. The strongest quantitative reason to raise this project's hoop is the measured local change from a 1.70-unit bean to approximately 2.16-unit family silhouettes. Choosing 5.8 is explicitly authored proportion restoration, not an assertion that Crown Jam uses that height or ratio.

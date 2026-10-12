# Arena rebuild, 0.10

The goal is a court that reads and plays like a rounded obstacle-sport stadium. Increasing a flat rectangle's dimensions did not satisfy the user's reference. Keep the completed ball, power and multiplayer work, but replace the arena's shallow rectangular visual structure.

## Observed reference

The retained `reference/official-overhead.jpg`, `v9-source-35.png`, `fullmatch-1.png` and `match-detail-155.png` show broad pale raised routes, strong colored sides, recessed turf, curved approaches to the baskets, large team-colored goal-end structures, layered crowd stands and large mascot silhouettes. These fill the gameplay horizon. The 0.9 player-camera image instead shows low straight stands, shallow narrow ridges and large unbroken turf areas. No camera or FOV change is justified just to conceal that gap.

This is reconstruction from public visual evidence. Original dimensions, collision meshes and private implementation are not available. The following dimensions are authored choices, not recovered constants. Reference imagery is research material and is excluded from the shipped game.

## Physical layout

- Preserve the 64x112 boundary, goals at Z +/-48 and Y 4.6, kickoff decks, ordinary running/jump/gravity, shot solver and booster positions.
- Raise route crowns to 3m. Each crown is 6m wide, with a 2.4m eased bank on each side. Turf remains at Y 0 relative to the raised roads; central hazards retain level ground.
- Mirror the side route in X and Z. Its positive-X center follows `(abs(Z), X)` knots `(0,21), (10,22), (20,18), (29,21), (42,14)`, with eased joins and a terminal fade to Z 47. The first trial bent from X18 to10 over Z38 to42; a real running test found 17 airborne frames and 0.885m clearance on its steep bank. The wider final bend replaces that failed geometry without changing movement physics or adding expensive nearest-spline searches.
- Transverse routes bow toward each end: `abs(Z)=20+4*(1-smoothstep(0,18,abs(X)))`. They join the side routes around X +/-18.
- Front approach loops have radius 11 around the basket centers. Leave the inner goal pocket low and the complete scoring opening clear. Retain the existing outer banks and physical boundary.
- Implement cheap scalar terrain helpers shared by simulation, forecast and world construction. Avoid per-query path allocations or full spline scans. Conservative forecast bounds must account for the new maximum height.

These paths should offer useful choices: take a raised flank route for a launch, cut over a transverse bank, or approach the low basket pocket. They must support walking, jumps, real ball rebounds and the existing physical score crossing.

## Arena appearance

Use rounded contrasting road edges, distinct raised crowns and bank faces, turf variation, large original team emblems and clearly framed boosters. Keep the center readable and passing lanes open. The environment should have depth: curved layered crowd tiers, a continuous upper fascia, substantial team end shells and large original mascot structures outside the playable boundary. Do not copy reference branding or place decorative objects where they imply unsupported collision or walkable surfaces.

New structures must preserve the player's view of the ball and rim. Inspect the existing camera from each goal pocket, raised side route, midpoint and kickoff, including behind-hoop and high-jump positions. Add presentation occlusion handling where necessary instead of retuning camera framing to hide defects.

## Acceptance

Keep fixed-camera before/after captures; use shared terrain for visuals and physics; test bank walking and rebounds, jump/launch/dunk access, both scoring openings and camera clearance. Re-run affected source checks and the exact exported pack. Complete normal-input offline and three-client matches with rewards/results, then inspect the recordings. Software and local network tests do not establish human enjoyment, physical controllers or real cross-home connectivity.

0.9 is a held comparison build. Its final executable hash is `9120C048816C600EB2EE5BD0C9DF0B15056E99EA50655827E2460E785EC149BB`; its complete network suite passed before the user rejected the map. Preserve its evidence rather than presenting it as acceptance of 0.10.

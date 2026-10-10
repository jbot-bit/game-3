# Counterweight: a second Hands Full course

The user requested a distinct, short cooperation challenge using existing mechanics, preserving smooth performance, saved powers and LAN play. They delegated design and implementation decisions and asked for a tested Windows package. Their subsequent physics/engine question reinforces testing control quality, not changing engines without an observed need.

## Design decisions

Keep Godot 4.7.2, built-in Jolt, the existing puppet motor, two grabbing hands, movable blocks/planks, hinged board, reversible fan and recovery. The second course, **Counterweight**, puts weight transfer before a compact wind-exposed crossing. Friends can steady the tilting route; blocks must offer a practical solo substitute and let the last helper leave. No exact stacking, mandatory permanent attendant, new inventory/resource, currency or character progression system.

Target a small footprint with a clear approach, useful checkpoint and shared finish. Test the actual physical effect of bodies/blocks, not only geometry bounds. A practiced traversal target of roughly 45–90 seconds guides layout without padding it with empty walking. Measured pace and deviations must be reported honestly.

Host selection offers **First Crossing** (`crossing`) and **Counterweight** (`counterweight`). The completed-run menu offers replay or the next course. Pause restart replays the current course. Only the host can advance, and only after completion; an unsuccessful save must be retried before advancement. Existing collected powers and clear counts apply across both courses, with no save migration or separate rewards.

Host-authoritative state carries the course ID and run ID. Clients must create the correct world before displaying poses. Changing courses releases all grabs, clears presentation history and resets the crew at the new spawn. Late joins, stale packets, leave/rejoin and repeated transitions must not retain old geometry or award duplicate clears.

## Validation and limits

Validate actual grab/weight interactions and solo/crew routes; preserve baseline controller tests. Include heavyweight/feather cases where mass changes matter. Check full digital press/release input for handling; clearly label analog bot navigation or setup fixtures. Inspect rendered play and menus. Measure a native three-puppet scene independently of network tests. Re-run three-process source and exact exported-pack LAN checks across course transitions, saved power selection and disconnect. Smoke-test the actual standalone executable and preserve the previous package.

No automated result is a human fun rating or proof of the other household PCs' Wi-Fi performance. If the counterweight idea proves awkward, simplify its layout using existing mechanics before adding a system to compensate.

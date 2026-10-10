# Hands Full: implementation checkpoint

This follows the user's explicit request to research, fetch and reuse open-source foundations for a complete change of direction. The selected direction is co-op physical adventure with random power choices. No approval gate is imposed.

## Concrete deliverable

An independently launchable Windows LAN experiment: three physical puppets, independent hand grabs, one compact cooperative course, a reversible fan, three random power offers from five, replay and separately saved course-clear records. This is not a completed RPG or a claim of Human Fall Flat-equivalent quality.

## Work and validation

1. Fetch and pin PiCode's active-ragdoll experiment, CBerry's physical-animation example, Netfox/Forest Brawl and Pali. Inspect source and license files. Keep unselected code outside the game import/export tree.
2. Run PiCode's original controller on both physics engines in the bundled Godot version. Separate compatibility observations from judgments of fun.
3. Adapt only the MIT character/model: fixed-step host simulation, per-player input, edge-triggered jump, current-overlap hand grabs, selective release, recovery and separate visual skeleton interpolation.
4. Build a small course around those actions. No money, fish, repairs, crafting or inventory grid. Use original geometry and clear silhouettes, with shadows disabled.
5. Give this experiment its own LAN protocol/port, input bounds, stale-control timeout, sequenced bounded pose transport and authoritative power/lever/completion rules. Preserve the old game and save.
6. Make the power screen and controls readable at 1280x720 and 960x540. Save completed run identities exactly once; report and retry failed writes without pretending a clear was saved.
7. Verify real three-process loopback joins, movement, powers, shared lever state, completion/save, replay and disconnect. Label position fixtures explicitly; they are not ordinary course completion.
8. Test physical hands against a real prop and another puppet, including selective cleanup and unrelated-grip preservation. Test recovery across physics/render frame boundaries.
9. Inspect native rendered views and time a bounded scene with three simulated puppets. Do not extrapolate this GPU's result to the weakest family laptop.
10. Export a separate executable/ZIP, inspect its embedded resources, retain PiCode/Godot notices and run the actual executable from its output folder. The old fishing package remains untouched.

## Acceptance limits

A passing engineering checkpoint establishes a working experiment. It does not establish comfortable physical controls, a naturally solvable/fun course, robust Wi-Fi responsiveness, balanced powers, compelling saved RPG unlocks or enough content for a finished game. Those must be reported as unproven or not implemented, rather than hidden behind passing tests.

The next design decision comes from the physical actions: retain and improve the ones the family deliberately repeats. Add progression/content only around those demonstrated actions. Do not turn this into both a large card RPG and a physics campaign.

## Developer playtest pass: 0.1.1

The user requested improvements before household play. Three parallel agents covered controller contacts, actual course traversal and an independent usability review; the parent integrated input, UI, networking and packaging.

- Reproduce floor-stealing grabs, missed landing/ledge jumps and taps lost between network samples, then correct the input/contact handling without replacing the movement motor.
- Use the existing planks as ready movable bridges and the seesaw as the second crossing. Prove actual moving-surface contacts and a settled finish with ordinary controller inputs.
- Check all five powers with both wind directions. Investigate failures as physical evidence; do not slow only the bot to disguise a keyboard-control problem.
- Make an intentionally ruined course recoverable from the host menu without losing saved powers; detach a held falling prop before it teleports home.
- Check concise menus at the smallest supported viewport, then repeat native rendering/performance, three-process ENet and exact exported-pack checks. Preserve the previous package.

This pass adds no progression system, paid assets, rendering framework or new gameplay resource. Current measurements and remaining scope limits live in `docs/playtest/HANDS_FULL_STATUS.md`.

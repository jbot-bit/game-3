# One More Cast 0.4.0

The family adventure loop is catch, collect, explore, improve gear, and bring the crew home. This release restores the fishing game as the default, with block characters, a coastal palette, clearer rewards and a one-button fishing minigame.

Hold left mouse to move the control bar right; release to move it left. Catch progress rises while the fish line is inside the bar and falls outside it. Walking or X cancels. Directional countersteering, tension and surge-release rules have been removed. Rods and the Angler outfit now change control-bar width or catch speed. Existing saved equipment IDs remain compatible.

The outing review also corrected banking priority when carrying a power cell, made the refuge-return key visible at Moth, named earned gear with equip guidance, and added persistent night/shelter and empty-lantern guidance.

## Verification on 10 October 2026

- Exact isolated release source: 349 GUT tests, 4,564 assertions passed.
- Real mouse-event integration covers hold/right, release/left, failed-cast cleanup, landing and banking once.
- Display-driven tests use the actual interpolated rail, normal input cadence and authoritative snapshots. Standard-rod ordinary fish take 5.8 seconds; both rare fish take about 10.2 seconds with good tracking. Every rod completes the tested species. These are automated timings, not a promise for every player.
- A discovered feedback delay was corrected by publishing fishing state at 20 Hz while casting; quiet exploration retains 5 Hz. The real controller cadence is tested. No client catch/progress authority was added.
- Real ENet loopback: three-process cooperation probe passed 191 checks; the new two-process remote fishing probe passed 32 checks, including exact replicated states, one bank reward, duplicate rejection, reconnect and independent save reload. The latest remote catch took 9.39 wall seconds, including roughly two game seconds outside the bar. Separate physical PCs and Wi-Fi latency remain untested.
- Native Windows preview checked the bar, catch reveal, night and rescue UI at 1280x720 and 960x540. A normal-input rendered loop walks, fishes, banks, finds the rod, equips it and retires the guide.
- A normal-speed rendered automated outing completed day, dusk, night and retreat in 395.4 seconds: 26 catches, eight discoveries and 339 banked coins. The test player remained near Reeds after its temporary shelter expired and lost three unbanked catches; saved progress remained. This run used the final fishing rules before the last snapshot-cadence improvement. The final cadence has separate display, controller, ENet and native-loop verification. This outing did not reach the storm or establish human enjoyment.

Build identity is `0.4.0-tide`; all joining PCs need the same build. The release is built from an isolated branch. Unfinished Hands Full and Nightfall changes are excluded. The Windows export excludes all prototypes, Nightfall and development resources, and its embedded pack is inspected before publication.

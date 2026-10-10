# Hands Full — quick handover

**The game:** three people on Windows LAN help or mess with each other through two short physics courses. Each hand grabs independently. Move planks and blocks, balance the seesaw, reverse the fan, get everyone across. Falling and F recover you.

**Progress:** pick one of three random powers. A successful clear saves the powers everyone used. They become permanent choices for future runs. Five powers total; no coin grind or inventory tree.

**Start:** `build/hands-full/HandsFull.exe`. Pick a course and host; Esc shows the join address. The other PCs join it. After a clear the host chooses Play again or Next course. Keep using the same host for the shared save. Full controls: `prototypes/physics_party/README.md`.

**Edit:** open `project.godot` in Godot 4.7.2. Current code is `prototypes/physics_party/`: `puppet.gd` controls the body/hands; `party_world.gd` builds First Crossing and shared prop behavior; `party_counterweight_world.gd` builds Counterweight; `party_courses.gd` holds course IDs/names; `main.gd` joins everything; `party_session.gd` handles LAN; `party_rules.gd` saves progress; `party_hud.gd` draws menus. The old `game/` fishing code is preserved and inactive by default.

**Priority:** make movement, grabbing and helping fun before adding content. Test changes on all three PCs. Clients show host physics, so don't judge network feel from the host alone. Keep the 60 FPS target and the simple menus. This is two short courses with light progression.

**0.1.1 improvements:** ready movable bridges and a seesaw route; hands prefer props/friends over overlapping floor; jump buffering and ledge grace; short taps survive network sampling. Host **Esc → Restart course** restores a ruined course without losing collected powers. Menus keep the world live.

**0.2.0 addition:** Counterweight uses an off-centre board: a friend or block steadies the long end, then blocks let the helper follow. The checkpoint saves repeating the loading section after a fall. Two perpendicular loose planks finish the route. Host-only course transitions retain the shared collection, release old grips and discard stale poses; failed saves must succeed before advancing.

**Verification:** `HANDS_FULL_STATUS.md` records exactly what was checked. Build with `tools/build_hands_full.ps1 -RenderSmoke`; run `tests/integration/run_physics_party_network_probe.ps1` after networking or gameplay-state changes. The save is `%APPDATA%\OneMoreCast\physics_party\progress.json`; don't replace it with a test fixture.

**Next prompt:** “Read the current Hands Full handover and verification report. Use our three-PC playtest feedback to identify the biggest movement, grabbing or pacing problem, then fix that problem and rebuild. Keep the saved collection and multiplayer working. Add no new system unless the observed problem requires it.”

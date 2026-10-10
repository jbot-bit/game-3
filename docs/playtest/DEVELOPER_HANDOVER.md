# Hands Full — quick handover

**The game:** three people on Windows LAN help or mess with each other through a short physics course. Each hand grabs independently. Move planks and blocks, balance the seesaw, reverse the fan, get everyone across. Falling and F recover you.

**Progress:** pick one of three random powers. A successful clear saves the powers everyone used. They become permanent choices for future runs. Five powers total; no coin grind or inventory tree.

**Start:** `build/hands-full/HandsFull.exe`. Host once; Esc shows the join address. The other PCs join it. Keep using the same host for the shared save. Full controls: `prototypes/physics_party/README.md`.

**Edit:** open `project.godot` in Godot 4.7.2. Current code is `prototypes/physics_party/`: `puppet.gd` controls the body/hands; `party_world.gd` builds the course; `main.gd` joins everything; `party_session.gd` handles LAN; `party_rules.gd` saves progress; `party_hud.gd` draws menus. The old `game/` fishing code is preserved and inactive by default.

**Priority:** make movement, grabbing and helping fun before adding content. Test changes on all three PCs. Clients show host physics, so don't judge network feel from the host alone. Keep the 60 FPS target and the simple menus. The first release is one course, not a long campaign.

**0.1.1 improvements:** ready movable bridges and a seesaw route; hands prefer props/friends over overlapping floor; jump buffering and ledge grace; short taps survive network sampling. Host **Esc → Restart course** restores a ruined course without losing collected powers. Menus keep the world live.

**Verification:** `HANDS_FULL_STATUS.md` records exactly what was checked. Build with `tools/build_hands_full.ps1 -RenderSmoke`; run `tests/integration/run_physics_party_network_probe.ps1` after networking or gameplay-state changes. The save is `%APPDATA%\OneMoreCast\physics_party\progress.json`; don't replace it with a test fixture.

**Next prompt:** “Read the current Hands Full handover and verification report. Use our three-PC playtest feedback to identify the biggest movement, grabbing or pacing problem, then fix that problem and rebuild. Keep the saved collection and multiplayer working. Add no new system unless the observed problem requires it.”

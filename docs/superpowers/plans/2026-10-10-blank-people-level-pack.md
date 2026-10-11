# Blank people and 20-level pack

**Goal:** Replace costumed avatars with featureless humanoids and ship 20 playable, selectable Hands Full levels.

**Architecture:** Keep the physical rig, motor, powers, save format and host authority. Retain the first two worlds; build 18 authored layouts through one shared world subclass. Stable catalog IDs drive menu selection and sequential multiplayer transitions. The course number is separate from the saved crew level.

**Stack:** Godot 4.7.2, GDScript, Jolt, GUT, existing Windows builder.

**Constraints:** No changes to the separately maintained fishing game or household saves. Plain matte player colours distinguish teammates. All levels available in the host menu; course 20 wraps to course 1 after a saved clear.

**Review focus:** Real route accessibility, checkpoint/finish support for three people, finite props and poses, client geometry consistency, stale snapshot rejection and small-window UI.

- [x] Replace costume visuals with the original continuous, featureless humanoid; run host/remote puppet checks.
- [x] Author 18 distinct level layouts, deterministic route data and catalog tests.
- [x] Integrate the world factory and numbered 20-course UI; test host selection and client reconstruction.
- [x] Drive real physics traversal through each new course; fix failed routes.
- [x] Exercise progression across all 20 levels with three network processes and isolated saves.
- [x] Inspect native screenshots, run regression tests, build 0.5.0 and verify the exact exported pack.
- [x] Open the Windows game for the user's requested immediate playtest.

User feedback after opening 0.5.0: the first level can be crossed in about four seconds, so route feasibility is insufficient. Follow-up scope is mandatory three-player obstacles, substantially longer multi-stage play, and RNG cosmetic surprise bags with rarity tiers. See the follow-up plan; leave the current test executable running while developing.

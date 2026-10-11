# Hands Full visual overhaul

10 October 2026. User asked to replace the characters, colour scheme and overall appearance. The chosen default direction is a scrappy sci-fi crew in an industrial obstacle yard.

The presentation has three coordinated parts: rounded helmeted crew with dark visors and cyan eyes; steel platforms with deck seams, cargo frames, hazard bands, crane targets and distant yard silhouettes; and a navy interface with orange actions, cyan equipment feedback and off-white text. The playing surfaces remain readable against a cool dusk horizon. Original meshes are authored procedurally in project code; the existing licensed rig and animations still drive them. No outside artwork or fonts were downloaded.

Character costume nodes attach to the displayed skeleton, so authoritative physics and remote interpolation use the same costume. The overhaul introduces no collision bodies or joints. World decorations are visual children and preserve the seven replicated props, original static colliders and course dimensions. The existing physics and course checks remain applicable.

## Engine references applied

- [Godot 4.7 rendering architecture](https://docs.godotengine.org/en/4.7/engine_details/architecture/internal_rendering_architecture.html): Compatibility supports directional shadow maps. The redesign uses one shadowed directional light instead of requiring a different renderer or screen-space effects.
- [Godot lights and shadows source documentation](https://github.com/godotengine/godot-docs/blob/master/tutorials/3d/lights_and_shadows.rst): shadowed Compatibility lights render in sRGB and can look different from unshadowed lighting. Native captures showed clipped highlights; reducing light energy restored orange and crew colours. Bias was also checked in the actual renderer.

Visual inspection caught coincident deck overlay faces causing interference patterns; the visible finish surface is now separated from the original mesh. Native screenshots cover the actual three-player scene, front-facing crew, menus, equipment draft, grapple aiming and the minimum 960×540 HUD. These are rendered scripted fixtures, not a human playtest. Final performance and release evidence live in `docs/playtest/HANDS_FULL_STATUS.md`.

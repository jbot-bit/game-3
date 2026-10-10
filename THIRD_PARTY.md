# Third-party components and provenance

Verified locally on 2026-10-10 (Australia/Brisbane). The Windows release uses Godot's standard native x86_64 template, Compatibility rendering, and the engine's built-in Jolt/ENet. There are no runtime addons.

## Godot Engine 4.7.2 stable

The local console editor reports `4.7.2.stable.official.ed1daf0bf`. Editor and export templates come from the same [official 4.7.2 release](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable).

| Input | Official source | SHA-256 of local archive |
| --- | --- | --- |
| Standard Windows editor | [Godot_v4.7.2-stable_win64.exe.zip](https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_win64.exe.zip) | `731980f9608d61333e5baf54a2ef17210acc7a538446c0cb9969f002aca1e953` |
| Matching templates | [Godot_v4.7.2-stable_export_templates.tpz](https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz) | `f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011` |

Both archive SHA-512 hashes were recomputed and matched the relevant entries in `.tools/downloads/SHA512-SUMS.txt`. That local manifest was compared with a fresh response from the [official release checksum file](https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/SHA512-SUMS.txt) and matched exactly after trimming outer whitespace. The extracted release template `.tools/templates/windows_release_x86_64.exe` has SHA-256 `d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562`; hashing `templates/windows_release_x86_64.exe` directly from the verified TPZ archive produced the same hash.

Godot uses the MIT license. The engine also contains libraries with their own compatible notices, including Jolt, ENet and fonts. Keep both of these unmodified notices with the executable:

- `LICENSES/Godot-4.7.2-LICENSE.txt`, copied from the [tagged engine license](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/LICENSE.txt).
- `LICENSES/Godot-4.7.2-COPYRIGHT.txt`, copied from the [tagged complete copyright and license inventory](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/COPYRIGHT.txt).

See Godot's [license compliance instructions](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html). These notices describe the engine and its dependencies, not a license grant for original game content.

## GUT 9.7.1 — development only

Source: [bitwes/Gut tag v9.7.1](https://github.com/bitwes/Gut/tree/v9.7.1), [tag archive](https://github.com/bitwes/Gut/archive/refs/tags/v9.7.1.zip). The existing `.tools/downloads/gut-v9.7.1.zip` expands under `Gut-9.7.1`; the installed `addons/gut/plugin.cfg` declares version `9.7.1`. Its local archive SHA-256 is `14969aa46adc84aa08cdd21b9f6d1a64addd92ae60b36f02d0521ed305aa4086`. This is a recorded local hash, not a claim of an upstream signed checksum.

GUT is MIT, copyright 2018 Tom "Butch" Wesley. `LICENSES/GUT-9.7.1-LICENSE.md` is copied from the installed addon and agrees with the [tagged upstream notice](https://raw.githubusercontent.com/bitwes/Gut/v9.7.1/addons/gut/LICENSE.md). GUT runs the local tests and is excluded from the game executable. Its notice is included here for the development source distribution and provenance.

## Curated Kenney art — CC0

The graphics revision uses 23 selected GLB models and two palette textures from official Kenney packs. Only that subset is shipped under `assets/kenney`; full source archives stay in the ignored development tools directory. The included per-pack License.txt files explicitly permit personal, educational and commercial use under CC0.

| Pack | Official source | Recorded archive SHA-256 |
| --- | --- | --- |
| Nature Kit 2.1 | [Nature Kit](https://kenney.nl/assets/nature-kit) | `fa7974a0d342bfe63c38664ba9f8ec1a4aab8ea25f099bdc56870e33588c4d9d` |
| Survival Kit 2.0 | [Survival Kit](https://kenney.nl/assets/survival-kit) | `c3586341b5932c87eb43d75d915434f47daed168b17ed36a03e8ca9977c7443e` |
| Watercraft Kit 2.1 | [Watercraft Kit](https://kenney.nl/assets/watercraft-kit) | `cd1470c1cf441c7f46d0944ae6d0d897242365dc97677c5079b3238965d659f3` |

These are locally recorded hashes, not upstream signatures. Assets are scaled and arranged in the authored island. Fish, water treatment and gameplay remain project-specific.

## KayKit animated crew — CC0

The character uses Kay Lousberg's [official Adventures pack](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0), pinned to publisher commit `672074b73ba276876a19e8816ecdc5241817ab47`. Only `Rogue.glb` is shipped. Its SHA-256 is `e825437cd4d2ee9c1960b517a74a69101e33eb409ae7fa8cedc7134a998fbb7d`. The source file is unchanged; the runtime adapter removes weapons/cape, selects authored movement/action animations and recolours cloth for crew identity and earned outfits. Full provenance is in `assets/kaykit/PROVENANCE.md`; the publisher's CC0 notice ships in `LICENSES/KayKit-CC0.txt`.

## GDQuest movement reference — MIT code only

Ground acceleration and retained facing adapt the code pattern in [GDQuest's third-person movement controller](https://www.gdquest.com/library/character_movement_3d_platformer/), version 1.1.0. Its MIT code notice ships in `LICENSES/GDQuest-Movement-MIT.txt`. No GDQuest art, audio or noncommercial assets are included. The game's collision, networking and camera presentation remain integrated with the existing controller.

## Project content and export boundary

The runtime scripts, original geometry, materials and synthesized cues under `game/` were implemented for this project, with the attributed movement adaptation above. Kenney and KayKit are the external art sources. No fishing-game template, PhantomCamera, GLoot or other runtime addon was imported.

The Windows preset embeds the runtime PCK in `OneMoreCast.exe`. It excludes `addons`, `tests`, `docs`, `tools`, `.tools`, `.superpowers`, `.git`, `logs`, `build`, source documentation and local development artifacts. `tools/build_windows.ps1` inspects the actual embedded resource filesystem and copies this file, the README and `LICENSES` beside the executable. Saves are created under the player's Godot user-data directory, never copied into the package. The build is unsigned; no certificate or distribution service is required for this private LAN package.

## Hands Full reuse and camera review

The current Hands Full export additionally includes the adapted MIT [PiCode9560 active ragdoll](https://github.com/PiCode9560/Godot-4-Active-ragdoll), pinned at `e762f613ddb4e5a93cfeeace6430b7c3d21309b6`. Its character model, rig and controller approach are covered by the retained upstream notice in `prototypes/physics_party/vendor/picode/LICENSE`. The family ZIP includes that notice and the Godot license/copyright notices. Original procedural sound cues and original UI/course code do not add third-party runtime dependencies. Earlier fishing-game asset entries below/above do not imply those assets are present in the Hands Full export; its embedded pack is inspected by `tools/build_hands_full.ps1`.

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

## Project content and export boundary

The runtime scripts, primitive block geometry, materials and synthesized cues under `game/` were implemented for this project. No Kenney assets, fishing-game templates, PhantomCamera, GLoot or other runtime addon was imported. Research links in `docs/` are references, not shipped dependencies.

The Windows preset embeds the runtime PCK in `OneMoreCast.exe`. It excludes `addons`, `tests`, `docs`, `tools`, `.tools`, `.superpowers`, `.git`, `logs`, `build`, source documentation and local development artifacts. `tools/build_windows.ps1` inspects the actual embedded resource filesystem and copies this file, the README and `LICENSES` beside the executable. Saves are created under the player's Godot user-data directory, never copied into the package. The build is unsigned; no certificate or distribution service is required for this private LAN package.

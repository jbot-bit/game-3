# Development setup

Players only need the standalone CrownCourt.exe from the release. The following tools are for source development and verification.

Use Godot 4.7.2 with matching Windows export templates. The source project is crown-court/project.godot. Windows scripts use PowerShell 7 and expect this layout at the repository root:

- .tools/godot/Godot_v4.7.2-stable_win64_console.exe and its companion Godot executable
- .tools/templates/windows_debug_x86_64.exe
- .tools/templates/windows_release_x86_64.exe

Place the matching official engine and export-template files there, or adjust harness.ps1 and export_presets.cfg for your installation. These binaries and generated build files are intentionally excluded from Git.

Run crown-court/build.ps1 to export and run source/embedded-package gates. Network and room verification scripts are in the same directory; see VERIFICATION.md for the exact release scope and evidence labels. Packaging requires the matching completed receipts and recordings, rather than assuming a new export is verified.

Recording requires FFmpeg. Both recording scripts accept -Encoder, otherwise use ffmpeg from PATH or an installed current-user WinGet FFmpeg package. The optional Python audio preparation tool accepts --ffmpeg or FFMPEG, then the same discovery order. Runtime audio is already committed; normal play/builds do not regenerate it.

The optional room relay uses Node.js 22 or later. See relay/README.md for local tests and deployment. A blank internet.cfg is deliberate: public hosting has not been deployed. Do not mistake local relay verification for an available Internet service.

Game Development Studio is optional. Machine-local adapters, captured evidence and downloaded reference media are excluded from the repository; native Godot verification scripts remain available. Historical review documents retain evidence paths from the development workspace, which are not promised to exist in a fresh clone.
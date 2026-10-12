# World presentation probe

`world_polish.gd` runs eight fixture checks and optionally saves eight native PNGs. It uses the real simulation for a dunk and bank/deck descent, while placing actors deliberately to isolate presentation problems. It does not host a network match or claim human playtesting.

```powershell
& C:/game-3/.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path C:/game-3/crown-court --script res://tests/world_polish.gd -- --evidence-dir=C:/game-3/build/crown-court-evidence/UNIQUE-headless
```

For a native capture, omit `--headless`, reserve the GPU slot with the other workers, add `--resolution 1280x800`, and pass `--capture` after `--`. For an exact exported pack, add `--main-pack C:/path/CrownCourt.exe` before `--`; use `--pack-source=C:/path/CrownCourt.exe` after it to record the executable SHA. Use a new evidence directory for every retained run.

The checks cover nearby name visibility and projected minimum height, local-name removal, congested name/ball separation, physical dunk/hand continuity, airborne catch reach, controlled camera continuity, and byte-identical authoritative input. The label-height metric estimates capital height from the font em; inspect native pixels as well. The camera fixture deliberately records fixed pitch, yaw, time step and focus target. A passing controlled fixture does not explain every camera discontinuity in an earlier full match.

Final 0.6 source evidence: `build/crown-court-evidence/v6-polish-candidate/REVIEW.md`. The same probe against the retained 0.5 package is in `v6-polish-baseline`. Earlier `v6-world-*` folders are intermediate diagnostics. The `import-polish-review` Game Development Studio scenario only seals those existing PNGs and verifies retained image/source/pack/probe hashes. CPU receipts live in `v6-polish-cli`; the importer never launches Godot.

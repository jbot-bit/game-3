# Crown Court 0.16.0 verification

13 October 2026. One standard 64-bit Windows release, Godot 4.7.2 Compatibility renderer. [Previous verification](VERIFICATION-0.15.2.json).

## Exact artifact

CrownCourt.exe: **114772072 bytes**, SHA-256 **3F3E75AFF9B6B7969F5FEDCBF49DE15A87A6DE825A92234757E002B6B6CF7416**. Version 0.16.0; embedded resources; independent startup passed.

## What ran

build.ps1: 74 source test scripts, import/export, 74 pack test scripts against the exact executable, native arena review, input render, audio render, feel input and route, controller input, exported startup: 154 PASS, 0 failures. New: tests/shot_assist.gd (assist, contact pickup, stats, intro, final celebration) and tests/presentation_capture.gd (native cutscene captures, evidence in build/crown-court-evidence/v160-presentation). Fixtures updated for the shared Hype constants, contact pickup and the new banner text; --script sessions skip the intro and cinematic camera.

## Limits

Automated checks do not establish household enjoyment, physical controllers, three-PC play or Crown Jam parity. The assist, cutscene pacing and arena dressing were reviewed from native captures, not a family playtest. Hosting remains undeployed.

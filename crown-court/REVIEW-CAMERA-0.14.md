# Camera review — 0.14

Retained confirmed match telemetry identifies an avoidable stadium-clearance cut: at 44.35 seconds the camera moves 5.67 m despite zero authoritative player step and zero yaw change. Surrounding 10 Hz samples show an airborne player descending beside z=-55.5 while the camera retracts from approximately z=-61 to z=-56. At 69.30 seconds a similar cut measures 4.64 m. These are not score-reset teleports. Retained first-run evidence also contains 4.28/4.23 m cuts during reset at 271.72/271.73 seconds with substantial yaw changes; those are not sufficient evidence of this same defect. General network corrections and intended long kickoff relocations remain distinct.

Cause: the stadium boom envelope previously opened instantly at roof heights 10.9, 19.4 and 29.5. Descending through a tier threshold therefore required an immediate multi-metre inward retraction. The existing world_polish fixture covered forward deck descent but did not descend looking outward beside the back wall.

Change: replace the staircase envelope with a continuous conservative slope starting at the first roof. The slope remains inside every original tier clearance, so retraction starts before the camera reaches a roof edge. Immediate manual yaw, target tracking, ball framing, teleport reset detection, and outward boom recovery are unchanged. The intentional tradeoff is a closer view near the bowl at altitude, rather than using all empty space above each roof.

Evidence:

- New tests/camera_v14.gd deterministic back-wall descent fails before the change at 5.546 m/frame; passes after at 0.507 m/frame (60 Hz).
- 95,040 sampled points across 33 heights and 72 yaw directions remain inside the original stadium envelope.
- Immediate manual yaw, 18 m overhead-ball framing (ball y=129 px, feet y=696 px in an 800 px viewport), and long kickoff reset checks pass.
- Existing world_polish passes all eight checks headless and native. Its forward deck descent remains 0.312 m/frame maximum.
- Native captures retained under build/crown-court-evidence/camera-v14-native; deck-drop and dunk-rise images inspected. Existing mesh/hoop occlusion remains outside this bounded camera change.
- All processes used harness.ps1 ProfileScope camera-v14; household save locations were not used.

Logs: build/crown-court-evidence/camera-v14-before.stdout.log, camera-v14-after.stdout.log, camera-v14-world-polish.stdout.log, camera-v14-native.stdout.log.

This is source and bounded native-fixture verification. No full post-change network match, packaged-build verification, household playtest, commit, push, or rebuild was performed by this camera review.

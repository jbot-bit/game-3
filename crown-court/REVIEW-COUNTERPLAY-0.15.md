# Crown Court 0.15: dunk counterplay discoverability

A firsthand [Crown Jam discussion](https://www.reddit.com/r/FortNiteBR/comments/1qma1d6/people_thought_it_would_be_bad_but_after_playing/) contains a request to remove easy dunking, a reply explaining jump/tackle blocks, and another player saying they had not known how to block. This supports a discoverability improvement; it does not establish community consensus or original-game physics parity.

Crown Court already supports tackling an airborne dunker. The HUD previously showed only the generic tackle prompt. It now offers `Jump + tackle to block`, with active keyboard/controller button labels, near an opponent committing a dunk. F1 controls also explain jumping toward the dunker then tackling. No physics, scoring or rewards changed.

The contextual cue requires: opponent possession and opposing team; no target guard; at least 0.25 seconds before authored dunk release; horizontal distance under 3.5 metres and vertical offset between -1.5 and 3.5 metres; local tackle ready and a jump available. It is suppressed during local stun, dunk, dive, reset, pause or results. Own-ball and recovering priorities remain intact. This signals an available opportunity, not a guaranteed block or a prediction of future opponent movement.

The initial test reproduced four missing-cue/help failures. Final `tests/dunk_counter_hint.gd` passes 20 checks, including a real authoritative opponent dunk action, keyboard/generic-controller labels, airborne spare jump and unavailable-action/priority cases. All launches use `harness.ps1` with isolated `counterplay-v15` user data. Red evidence: `build/crown-court-evidence/counterplay-v15-before.*`; final evidence: `counterplay-v15-final.*`.

The first green attempt caught a test expectation error: a generic controller intentionally uses `Bottom` and `R trigger`, not Xbox `A`/`RT`. The test was corrected to the current input-family labels; production button mappings were unchanged.

Existing regression suites also pass: feedback_test (17 checks), controller_input, and dunk_aim (64 checks). Logs use counterplay-v15-feedback_test, counterplay-v15-controller_input, and counterplay-v15-dunk_aim labels. Packaged and visual verification remain the parent task's release checks.

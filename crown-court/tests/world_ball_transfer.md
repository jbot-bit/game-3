# Catch/pass and arena presentation regression

`world_ball_transfer.gd` uses controlled initial conditions but real Sim catch/pass commands and physics steps. Six normal/Giant cases cover immediate, two-frame and completed gathers. It checks release continuity, no renderer-induced reverse flight, convergence after300ms, and an explicit200ms frozen input with nonzero velocity. World receives immutable snapshots.

`world_court_v9.gd` verifies visible rotor endpoints against the authoritative helper, unchanged inputs, canonical dimensions/boosters and an unobstructed visual scoring opening. Four optional native shots cover overview, connected routes, a rotor and the basket.

Both accept `--evidence-dir=<unique-directory>`, `--capture`, and `--pack-source=<exact-exe>`. Use the matching console engine with `--main-pack <exact-exe>` for embedded-package checks. Never reuse a retained baseline directory. Native capture requires the coordinated GPU slot.

0.9 source evidence and review: `../../build/crown-court-evidence/v9-ball-transfer-final-native/REVIEW.md`. Final world SHA: `D5C88597B2BF12C1205888B4FF6351858652BF70B6716483A04573E034798FB6`. The six old exact0.8 cases contain four expected failures; final source has seven passing checks including starvation. The new arena probe has five passing checks. GDS `import-v9-review` seals existing images on CPU; its whole-image comparison is explicitly exploratory because the arena and pass physics also changed.

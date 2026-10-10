# Physics and card-game reuse review

Reviewed 2026-10-10 from the downloaded source trees below. These are reference checkouts, not installed game dependencies. This review inspected source, project settings and license files; it did not run the demos or measure their multiplayer performance.

## Decision

Use PiCode's active-ragdoll demo as an isolated candidate for the physical character experiment. Use Forest Brawl to study short action rounds, knockback, temporary powers and rapid respawn. Keep the existing LAN session/save infrastructure until a replacement demonstrates a concrete improvement. Use cards to choose powers between rounds; do not import an entire trading-card game to display three choices.

None of these repositories is a finished, three-player, networked Human Fall Flat replacement. The useful parts are complementary: PiCode supplies physical-body and hand-joint techniques; Forest Brawl supplies a networked party-game example; Pali supplies a small card presentation/data example. Combining them still requires integration, a game design and playtesting.

## Downloaded revisions

`git rev-parse HEAD` and `git remote get-url origin` were read in each local checkout. Keep these revisions with any copied material rather than relying on a moving default branch.

| Upstream | Local checkout | Verified revision | Local license finding |
| --- | --- | --- | --- |
| [PiCode9560/Godot-4-Active-ragdoll](https://github.com/PiCode9560/Godot-4-Active-ragdoll) | [picode-ragdoll](C:/game-3/.tools/research/picode-ragdoll) | `e762f613ddb4e5a93cfeeace6430b7c3d21309b6` | [MIT, copyright 2024 PiCode9560](C:/game-3/.tools/research/picode-ragdoll/LICENSE) |
| [CBerry22/Active-Ragdoll---Physics-Animations-in-Godot-4.0](https://github.com/CBerry22/Active-Ragdoll---Physics-Animations-in-Godot-4.0) | [cberry-ragdoll](C:/game-3/.tools/research/cberry-ragdoll) | `b0f45480821be0f38d7aa689b1d9143aa3cf5ea5` | [MIT, copyright 2023 Craig Berry](C:/game-3/.tools/research/cberry-ragdoll/LICENSE.md) |
| [rametta/Pali](https://github.com/rametta/Pali) | [pali-cards](C:/game-3/.tools/research/pali-cards) | `bcea2eb2b3c49c90a7d4616dd80e5f7570dbcd42` | [Apache 2.0, copyright 2023 Jason Rametta](C:/game-3/.tools/research/pali-cards/LICENSE); separately credited assets below |
| [foxssake/netfox](https://github.com/foxssake/netfox) | [netfox](C:/game-3/.tools/research/netfox) | `cf5189d18e98766022c8c1c5e637a6a30c4c3703` | [MIT](C:/game-3/.tools/research/netfox/LICENSE); Forest Brawl has its [own MIT notice](C:/game-3/.tools/research/netfox/examples/forest-brawl/LICENSE) |

Netfox was fetched with selected `addons`, `examples/forest-brawl` and `docs` material. Downloading a repository does not imply that all of its assets or plugins should be included in the Windows build.

## PiCode: the strongest physical-character experiment

The [README](C:/game-3/.tools/research/picode-ragdoll/README.md) identifies the Godot 4.3 version and explicitly describes it as an experiment. The [character script](<C:/game-3/.tools/research/picode-ragdoll/Godot 4 Active Ragdoll/Scripts/character.gd>) drives a physical skeleton toward an animated skeleton using spring/damping torque. The [character scene](<C:/game-3/.tools/research/picode-ragdoll/Godot 4 Active Ragdoll/Scenes/character.tscn>) defines ten physical bones and two `PinJoint3D` grab joints.

What it already does:

- Independent left/right arm activation and joint attachment to a contacted `PhysicsBody3D`.
- Releases a hand joint when its button is released or limp mode is enabled.
- Foot shape casts for grounding, a jump cooldown, a camera-relative movement target and a ragdoll toggle.
- Limits the applied spring torque rather than applying an unlimited correction.

Concrete adaptation work:

- [Input handling](<C:/game-3/.tools/research/picode-ragdoll/Godot 4 Active Ragdoll/Scripts/character.gd:54>) reads global local-player Input. It must become per-player input before multiple controlled characters can share a server simulation.
- [Grab callbacks](<C:/game-3/.tools/research/picode-ragdoll/Godot 4 Active Ragdoll/Scripts/character.gd:137>) attach on `body_entered` only while the hand is already active. A player who presses grab after contact is not explicitly handled by this code. Check existing overlaps when activating a hand in the experiment.
- Joint targets use scene `NodePath`s. They need stable object/player identities, server ownership decisions and disconnect/release cleanup for LAN play.
- [Movement](<C:/game-3/.tools/research/picode-ragdoll/Godot 4 Active Ragdoll/Scripts/character.gd:101>) applies a fixed per-physics-tick damping multiplier and a large vertical impulse. Retune against our scene scale and physics tick; do not copy these constants into the current controller.
- Replicating the avatar root alone cannot reproduce independent limb and hand-joint state. Choose and test an explicit server simulation/presentation scheme.

A source search found no `rpc`, `multiplayer`, `ENet` or `peer` references in this checkout's GDScript. The scene is therefore evidence of a local technique, not evidence of working networked climbing, two people dragging each other, or stable three-player piles. Those cases require actual tests.

**Selected:** the small character experiment and grab/spring techniques, with its MIT notice. **Not selected:** immediate replacement of the established production controller, copied wholesale scenes, or a promise of full Human Fall Flat handling based on the demo name.

## CBerry: useful spring code, expensive source bundle

The [project](C:/game-3/.tools/research/cberry-ragdoll/project.godot) targets Godot 4.0 and Forward+. Its [physical animation script](C:/game-3/.tools/research/cberry-ragdoll/scenes/physical_animation.gd:1) applies linear and angular springs to physical bones. It also snaps a displaced bone to its animation target when the squared positional error exceeds one. This is useful to study as a recovery mechanism, but that snap should not be assumed suitable for a visible multiplayer avatar.

The local recursive file total, **including `.git`**, was **548,098,905 bytes**. The `assets` subtree alone was **254,311,135 bytes**. Three sky EXRs account for roughly 222 MB; two text scene files are about 24.8 MB each. This is not a 548 MB reusable controller. Copying the whole checkout would carry a large amount of unrelated art and demo scene data.

Only the root MIT license was found in the inspected license/credit/text-file inventory. The review did not establish individual provenance for its HDR/EXR skies or model files. Keep the source notice for any adapted code, and leave these art assets out of the game unless their source-specific notices are separately established.

**Selected:** spring/damping and recovery reference. **Not selected:** full project import, environment art, engine/renderer migration, or its 4.0 scene structure as the new game foundation. No network code was found by the same GDScript search used for PiCode.

## Netfox / Forest Brawl: best action-game reference, substantial network migration

The downloaded [plugin configuration](C:/game-3/.tools/research/netfox/addons/netfox/plugin.cfg) reports **1.49.4**. Its [README](C:/game-3/.tools/research/netfox/README.md:90) supports Godot 4.x but describes the examples as written against 4.1, with compatibility on other versions not guaranteed.

Forest Brawl's [controller](C:/game-3/.tools/research/netfox/examples/forest-brawl/scripts/brawler-controller.gd:1) is a `CharacterBody3D`, not an active ragdoll. It uses a `RollbackSynchronizer`, a network tick callback, mass-dependent shove, jump and four-second respawn. Its [effects directory](C:/game-3/.tools/research/netfox/examples/forest-brawl/scripts/effects) separates speed, mass and repulsion effects. These are useful examples of powers that visibly change an action instead of merely increasing a currency payout.

The important limitation is in the actual [physics guide](C:/game-3/.tools/research/netfox/docs/netfox.extras/guides/physics.md:1): it says rigid-body rollback needs explicit physics stepping through a custom Godot build, Rapier or Blazium. The guide also requires physics logic to move into rollback callbacks. This review has not independently established whether a newer stock engine removes that restriction; the inspected package documentation does not demonstrate stock-Jolt active-ragdoll rollback. Do not describe installing Netfox as solving that problem.

Replacing the existing transport/timing/prediction layer would require revisiting per-player inputs, authoritative actions, snapshots, physics ownership, joining, reconnecting and presentation. For three PCs on one LAN, this migration needs a measured benefit before it earns a place in the game.

The root and example licenses are MIT and identify Galffy Tamas. The README explicitly separates third-party asset licenses. One verified asset notice is [Kenney Platformer Kit 2.2](C:/game-3/.tools/research/netfox/examples/forest-brawl/models/kenney-platformer-kit/License.txt), marked CC0. This does not establish the license of every other example asset.

**Selected:** inspect/adapt narrowly scoped knockback, temporary-power, round and respawn ideas; retain notices if copying code. **Not selected:** wholesale Netfox migration, online relay services, all bundled plugins/assets, or claiming Forest Brawl supplies networked ragdolls.

## Pali: card presentation reference, wrong multiplayer/game structure

The [project settings](C:/game-3/.tools/research/pali-cards/project.godot) target Godot 4.1 with GL Compatibility. The [README](C:/game-3/.tools/research/pali-cards/README.md) describes a turn-based, two-player hand-scoring game with no time limit. That structure differs from three people playing short physical action rounds together.

This is a source-level constraint, not just a README warning: [Manager.gd](C:/game-3/.tools/research/pali-cards/Scenes/Manager/Manager.gd:53) creates a server with two peer connections, [starts a world with two explicit player IDs](C:/game-3/.tools/research/pali-cards/Scenes/Manager/Manager.gd:79), and [starts after two peers arrive](C:/game-3/.tools/research/pali-cards/Scenes/Manager/Manager.gd:112). [World.gd](C:/game-3/.tools/research/pali-cards/Scenes/World/World.gd:5) has two player identities, two hands and alternating turns throughout. Changing the connection limit to three would not make it a three-player game.

The small [CardResource](C:/game-3/.tools/research/pali-cards/Cards/CardResource.gd) and [selectable card](C:/game-3/.tools/research/pali-cards/Scenes/Card/Card.gd) are reasonable examples of keeping card data separate from its visible object. They are not needed as runtime dependencies for a three-choice power screen.

Local notice findings:

- Root code license: Apache 2.0, Jason Rametta. If source is adapted, preserve the license/attribution and identify the modified files as required by the included license. No separate `NOTICE` file was found in this checkout.
- Noto Sans: an [OFL 1.1 notice](C:/game-3/.tools/research/pali-cards/Fonts/Noto_Sans/OFL.txt) is included, copyright Google LLC.
- [README credits](C:/game-3/.tools/research/pali-cards/README.md:43) name Kay Lousberg furniture assets, Freesound card sounds and Layer-generated card images. The checkout's license/text inventory contains the root license and the font OFL, but no individual Freesound recording IDs/licenses or furniture-pack notice. A generic Freesound link does not identify the terms for `card-flip.wav` and `card-flip-2.wav`.
- The generated card-image attribution is stated; the checkout does not provide generation terms or a separate image license record. None of these presentation assets is necessary for our power choices.

**Selected:** data/presentation separation and concise card-selection reference. **Not selected:** Pali's server/world, hand-scoring rules, copied card imagery/sounds or a full trading-card framework. Use original power art and existing verified game assets.

## Other upstream checks

[Godot Jolt](https://github.com/godot-jolt/godot-jolt) says the integration is built into Godot from 4.4 and the extension is in maintenance mode. The game already uses built-in Jolt; adding the old extension supplies no established benefit here.

[Official Godot demo projects](https://github.com/godotengine/godot-demo-projects) are MIT. `3d/platformer` and `3d/physics_tests` are useful targeted references if required. They were researched but are **not one of the four local checkouts verified in this report**. Do not claim they were fetched or run.

## Reuse boundary and next proof

Keep the downloaded references outside the game's imported/shipped content. For anything actually copied, record upstream URL, revision, source path and adaptation in the project's existing `THIRD_PARTY.md`/license records. Preserve upstream copyright text; use separate verified notices for assets. This report records file findings rather than treating a repository-wide badge as proof for every bundled asset.

Before committing the new game to active ragdolls, the isolated character must demonstrate ordinary movement, one- and two-hand grabs, releasing after a fall, picking up from existing contact, bounded impacts and recovery. Then run host plus two clients through mutual grabbing and disconnect cleanup. Measure frame time and visible correction. A local demo opening successfully cannot establish those results, and neither source inspection nor automated checks establish whether the family enjoys the handling.

The design recommendation is a short physical party adventure with random power picks and optional friendly rivalry. Saved progression should expand choices and identity; it should not make a higher-level family member permanently stronger in versus rounds. This is a design judgment to test, not a popularity or fun claim established by these repositories.

## Final camera/plugin check (10 October 2026)

[Phantom Camera](https://github.com/ramokz/phantom-camera) is credible MIT camera authoring tooling; its [v0.11.0.3 release](https://github.com/ramokz/phantom-camera/releases/tag/v0.11.0.3) lists a Godot 4.7.1 fix. Its [third-person mode](https://phantom-camera.dev/follow-modes/third-person) provides spring-arm and damping controls. It is not a replacement for ragdoll networking. [Lawnjelly smoothing-addon](https://github.com/lawnjelly/smoothing-addon/tree/4.x) recommends engine interpolation where available; installing it would duplicate the chosen presentation path. Neither add-on was installed or claimed as benchmarked here.

The direct defects were a camera following raw physics while the mesh was interpolated, delayed mouse orbit, camera collision against teammates/held props, and differing arrival-dependent smoothing for bones and props. The game now follows the rendered torso, applies mouse orbit immediately, excludes crew/props from camera obstruction and samples a common 67 ms source-time buffer for remote bodies and props. The camera treatment follows [Godot's advanced interpolation guidance](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/advanced_physics_interpolation.html). No prediction or internet-ready rollback is claimed. Current measured results belong in `docs/playtest/HANDS_FULL_STATUS.md`.

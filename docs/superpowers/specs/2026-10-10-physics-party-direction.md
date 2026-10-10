# Physics party overhaul: research and first engineering checkpoint

Date: 10 October 2026. Status: the co-op physics direction below is now the working release, following the user's instruction to finish and ship with agents. The comparison records the research that led to it. See `docs/playtest/HANDS_FULL_STATUS.md` for measured results and remaining limits.

The user authorizes a substantial redesign, rejects compulsory fishing for money, and prioritizes smooth play, physical comedy, excitement, random discoveries and meaningful progress for three family members on Windows LAN. Their latest wording leans toward their own Human Fall Flat-style game with improvements. This document does not lock them into a combat arena or describe an overhaul as complete.

## What the existing design got wrong

The fishing bill made a largely separate activity compulsory, while carrying, throwing and rescuing were optional. Adding random treasure instead of fish would preserve that weakness if players still spend most of their time commuting or opening menus. The replacement needs enjoyable actions before a reward economy.

## Three credible directions

| Direction | Actual play | Strength for this family | Main cost or risk |
|---|---|---|---|
| Co-op physics adventure | Clamber over a compact obstacle course; grab friends, move objects and improvise a route to the exit. Discover a few tools that change the available solutions. | Closest to their stated Human Fall Flat enjoyment; three players naturally help, hinder and rescue each other. | Needs convincing hands, body weight and authored obstacles. A weak controller cannot be hidden by content. |
| Physics competition with card modifiers | Short contests using the same hands and props: cross a course, control a platform or move a shared object. Draft one modifier between rounds. | Fast rematches, visible build changes and room for rivalry without a long campaign. | Three-player free-for-all permits teaming and kingmaking. Cards multiply interactions and must remain legible. |
| Card-first RPG battles | Make turn-based tactical choices, build a deck and improve a character between battles. | Easier to keep rendering smooth; clear progression and controlled random choices. | Least connected to the family's physical-comedy preference; requires a new combat model, balancing and substantial card UI. |

Recommendation: build the shared physics foundation first, with co-op adventure as the leading direction. Keep competition as a branch supported by the same verbs. Cards should modify physical play rather than introduce a second full combat/inventory game. Do not combine all three directions into one project.

## Primary-source lessons

- [Human Fall Flat's developer/publisher description](https://store.steampowered.com/app/477160/Human_Fall_Flat/) emphasizes multiple routes, physical puzzles and multiplayer interactions with objects. The transferable idea is a space with several physical solutions, not merely a floppy-looking character.
- [PEAK's developer page](https://landfall.se/peak) connects traversal, helping friends, useful survival items and a shared rescue goal. Badges and cosmetics provide lasting recognition. We should borrow that coherence, not its entire injury/food/climbing stack.
- [ROUNDS' developer page](https://landfall.se/rounds) describes a 1v1 contest where the losing player gains an upgrade to counter the opponent. The transferable idea is a meaningful choice after a short contest; its two-player format is unsuitable unchanged for this family.
- [Stick Fight's developer page](https://landfall.se/stickfightthegame) presents physics-based fights against friends as the central activity. That supports testing direct interaction before attaching a campaign.
- [Gang Beasts' developer physics report](https://gangbeasts.game/posts/2017/5/24/information-on-server-configuration-modifications-to-address-issues-with-physics-stability) documents separate local and online stability problems. A locally impressive ragdoll demo does not establish multiplayer readiness.

These sources describe existing games. They do not prove that the proposed combination is fun, popular or achievable at the same quality. Repository licenses and exact versions require separate verification before reuse; marketing pages grant no code or asset permissions.

## Shared foundation: hands, weight and recovery

Use four understandable verbs: move/jump, grab, release/toss, and help another player up. Grabbing a plank, another player and a ledge should follow a consistent rule where feasible.

Players need enough control to attempt something deliberately, with enough physical response for mistakes to become recoverable stories. A good jump is dependable; a loaded seesaw is amusing because the players can understand its motion. Full-body simulation earns its cost only if holding, dragging, balancing or rescuing feels better because of it.

No fishing economy, gathering quota, hunger, durability, crafting tree or mandatory repair checklist belongs in this foundation. Do not spend the first minute explaining menus.

## First feel-test scene

Build one small, bright test space with three differently colored puppets, one seesaw, two loose planks, a handful of grabbable blocks, a low ledge, one short gap and forgiving recovery below it. Use clear collision shapes and a camera that keeps hands and landing spots visible. Start all three together.

Within the first minute a player should be able to:

1. Move, turn, jump and land intentionally.
2. Lift a plank, drop or toss it and see a predictable response.
3. Change the seesaw by standing on it or moving a block.
4. Grab or help a friend without locking either person in a broken state.
5. Recover from a fall quickly and try a different approach.

This is a concrete engineering checkpoint, not a user approval gate. Implement and measure it, then improve the largest observed control or stability problem before adding content. Preserve the existing playable build while evaluating the replacement.

## Turn the same scene into a game after feedback

For co-op: put the exit beyond a broken crossing. Players can position the planks, use the seesaw or help one another over a ledge. Later stages add one understandable obstacle at a time. A player-operated lever may open a shortcut while making another route harder, with a visible and reversible consequence for the crew.

For competition: use a brief course race or shared-platform contest with quick recovery, rather than eliminating one player for minutes. Any player's physical switch affects the arena. Avoid implementing a separate shooter merely because the old project already has an aim direction.

Target an approximately 6-10 minute complete session with an obvious ending and immediate replay. This is a pacing target to measure, not a timer that forces players to wait. Do not build both full modes before discovering whether the shared movement is enjoyable.

## Randomness and progression that change play

Offer a small choice of physical modifiers at a checkpoint or between rounds: stronger grip with slower carrying, spring boots with lighter body weight, or a heavier body that resists pushes but jumps less far. Begin with a few carefully tested combinations. Each modifier needs a visible effect and a short description.

For co-op, discovered tools can invite an immediate decision about who should carry them. Give the crew a useful baseline solution, so a random draw cannot make the route impossible. For competition, offer comparable choices to everyone and give trailing players draft priority; do not let permanent stats decide a match before it starts.

Saved progress should unlock alternative starting equipment, appearance changes, completed challenges and records. The family shares access to competitive unlocks in its lobby. A saved level can celebrate mastery without becoming an endless numerical damage advantage. Random outcomes supply variety; player choices must remain the main reason something succeeds.

## Deterministic checks and honest limits

- Reproduce jump height, landing, pickup/release, two players touching the same prop, disconnect while grabbing, recovery and restart under fixed inputs. Assert bounded velocity and no permanently trapped ownership.
- Repeat the same sequence with three network peers. Check object agreement, who controls a grab and whether a join or disconnect leaves dangling constraints.
- Measure native rendered frame times while all three puppets and the scene's props are active. Use a sustained 60 FPS target on the weakest family PC, with shadows off initially; inspect slow-frame spikes rather than citing average FPS alone.
- Separate render interpolation from physics ticks, and bound active props and joint counts. Do not add expensive effects to hide unsolved movement.
- Seed draft and layout tests to reproduce an interaction. Seeded tests establish repeatability, not that random choices are balanced or enjoyable.
- A one-machine three-process test is useful for correctness but does not establish performance on three different PCs or the home Wi-Fi.
- Record observed friction from actual family play: time to first intentional success, unclear controls, unrecoverable mistakes, waiting, frame spikes and whether players voluntarily retry. Automated agents and source research cannot certify fun.

The immediate deliverable is a verified, physically interactive three-player scene and an evidence-backed direction choice. It is not yet a completed replacement game or a claim of a tenfold improvement.

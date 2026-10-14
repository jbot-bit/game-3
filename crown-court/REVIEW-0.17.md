# Claude review and replayability pass — 14 October 2026

Reviewed Claude's 0.16 changes in commits be105053 and 6f3f3bfc against 05bf0a89. Kept contact pickup, optional assist, authored stadium, cutscenes and faster Hype. Source is public by the user's existing authorization. Household data is backed up separately and tests use process-isolated profiles.

## Observed baseline

Native ordinary-input driver, full presentation enabled, Evie, Easy co-op: 4–0 in 140.38 driver seconds; 542 captured frames, 15 local possessions, five passes, four charged shots, three dunk actions and four tackle actions. All action categories were covered; zero focus recovery or match-state mutations. First goal at 95.03 seconds, subsequent goals at 105.30, 119.90 and 134.87. This is one automated strategy, not evidence of household enjoyment. Screens inspected across intro, loose-ball play, pressure, aerial carry and final result. Raw evidence: build/crown-court-evidence/v17-baseline.

The result gave a scoreless bot MVP and labelled 18 impacts as steals. The four-goal human was below it. Separate deterministic all-bot observations also show repeated tackle/recovery/dunk cycles. A single Easy win is insufficient reason to retune everyone's movement or force longer matches.

## Repairs

- Global time scale previously depended on the viewing player's involvement and presentation settings. This affected authority, charge timing and network send cadence. Local presentation now has its own scale; simulation, input and networking stay at normal time. Six authority scenarios check clocks, cooldowns, charging and send cadence.
- Stale release metadata awarded phantom steals after a pass was caught, tackled loose and recovered. Consume release credit on possession, dislodging tackle and score. Real interceptions still count.
- Display hits separately from steals. Weight a hit below a basket, assist or real steal for MVP.
- Earlier scripted capture tests silently disabled cinematic cameras. Full-presentation tests now opt in explicitly and assert actual camera kind and simulation stage for every image, with bounded waits.

## Replay choice

An optional best-of-three runback counts the just-finished team match as round one. A series adds a comeback/deciding-round goal without stretching the four-point match rule. Each player can pick a different existing Hype power between rounds; the host can change bot difficulty. Ordinary Rematch remains available. Series state is host-owned, replicated and session-only. Each match retains its own reward ID, so repeated snapshots cannot mint extra bags. There is no new save format or series reward.

## Player research and alternatives

[Firsthand Crown Jam discussion](https://www.reddit.com/r/FortNiteBR/comments/1qkvg6w/i_was_fully_prepared_to_clown_on_crown_jam_but/) contains both families enjoying it and complaints about repetitive, short easy wins or unhelpful teammates. One commenter wanted maps/perks for variety; another enjoyed stronger opponents with friends. [A second discussion](https://www.reddit.com/r/FortNiteBR/comments/1qm2s9f/hot_take_fall_guys_crown_jam_is_really_fun/) likewise mixes enthusiasm and repetition complaints. These are anecdotes, not a representative survey. [Epic's description](https://www.fallguys.com/news/the-beans-slam-dunk-in-fortnite-for-a-limited-time-crown-jam) establishes the 3v3 physics sport reference, not exact tuning constants.

Considered a longer clock, new courts/modifiers, or a session rivalry with tactical choices. Chose the smallest tested loop with immediate stakes and existing powers. Longer clocks alone can prolong repetition; a new court needs its own navigation, proportions and camera review. Further work should follow family feedback on rematch choice, ball control, meaningful possessions and whether Normal bots make a better contest. Do not claim retention is solved or proprietary physics recovered.

Exact final package, multiplayer, recorded-series and save verification are recorded in VERIFICATION.md.

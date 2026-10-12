# Ball, arena and Hype comparison

12 October 2026. Scope: public gameplay observations and our reproducible production behavior. No proprietary code or art was extracted. The installed reverse-engineer-anything instructions were consulted; REA MCP/CLI and an installed Fortnite artifact were not available. The native control helper still fails before initialization. Playwright successfully reopened actual gameplay and retained browser-rendered frames; the game's own input/render tools remain usable. These are ordinary source/browser/runtime observations, not REA Evidence IDs.

## Reference evidence

- [Tocanscenes full match](https://www.youtube.com/watch?v=ZU24J-EkOVQ): newly retained `reference/v9-source-35.png` and `v9-source-pass-154.75-native.png` show raised connected routes, recessed grass, wide side approaches, distant marked teammates, a curved outgoing pass and a ready Hype icon. The latter file is a 1105x622 browser rendering of a 1280x720 video, despite its historical filename suffix. Existing inspected `reference/action-154.png` samples the actual pass every .25 seconds. Release around154.75 and reception/PASS feedback around157.75 support a long lofted pass, with exact catch timing uncertain. This does not reveal the original targeting algorithm.
- [Epic's gameplay description](https://store.epicgames.com/news/fall-guys-crown-jam-slams-into-fortnite?lang=en-US), freshly checked: shots are possible from one's own half; passes, assists, tackles and baskets earn Hype; the three abilities are Giant, deployable bounce pad and a homing attack; the court contains side launchers, ledges, dips and rotating hazards.
- The retained official overhead establishes connected road/grass topology and large raised ends, not calibrated dimensions. Exact original length, width, gravity, pass guidance and input response remain unknown. Enlarging our arena is a direct response to play feedback, not a claim that original world units were recovered.

## Reproduced local gaps

| Behavior | Exact 0.8 evidence | Repair direction |
| --- | --- | --- |
| Running receiver | Accepted16m pass misses by4.494m; stationary receiver catches | Forecast receiver motion through the whole flight and release a physical, interceptable ball |
| Aim/range threshold | .114 degrees changes launch velocity9.973m/s;2cm changes5.698m/s | Continuous charge/angle/range assistance, with actual misses and long shots |
| Catch then immediate pass | Stale loose position and catch-gather correction produce a backward rendered frame | Atomic possession position and flight-bounded presentation correction |
| Hoop geometry | Board1.25m behind center intersects rim radius1.65+tube.28 | Separate visible and physical board behind the complete rim |
| Arena | 40x72; hoops62m apart; no rotating hazards | 64x112; hoops96m apart; wider routes, relocated boosters, four physical sweepers |
| Power feedback | Selected power name hidden below100%; no active lifetime; no assist Hype | Always identify ability and charge; concise ready/active feedback; actual assist credit |

Preserve no-homing ball flight: players can change direction, intercept, block and miss. Wider shot range is not automatic score credit. The original's exact pass guidance remains unknown. Ordinary running/jump/gravity are retained; the larger arena gets a longer kickoff launch and larger team support routes. Rotating padded bars are an authored realization of the officially described hazard class, not a claimed exact obstacle reconstruction.

## Acceptance

Demonstrate moving and airborne pass receptions, interceptions, short/long shots, overcharge/undercharge/aim misses, rim and board rebounds, catch-to-release continuity, boosters, jumpable physical hazards, all three powers, assist credit, scoring/reset, rewards/rematch and network agreement. Source fixture passes establish mechanics; fresh complete input-driven matches and native footage establish integration. Physical controllers, WAN conditions and human fun remain household tests.

# Island Campaign — release evidence and family acceptance

10 October 2026 · build `0.2.0-campaign` · protocol 1 · save schema 1.

The bounded campaign is implemented. Physical three-PC play, weakest-laptop performance and whether the family wants another outing remain unobserved. This status does not claim those acceptance gates are complete.

## Delivered

- Native Windows host/join for three people on the same LAN, with one persistent household and separate saved crew loadouts.
- Twelve original block fish across five fishing pockets, three reeling behaviours, exclusive Oversized/Moonlit/Stormmarked traits, visible chances, rare protection and permanent specimen records.
- Four rods, two lanterns, and three role alternatives unlocked by collection/repairs. Found equipment, short crafting recipes and shared ownership; no daily gates or maintenance jobs.
- Reliable player movement with shared oversized-fish grab, carry, pass, toss, receive, pack, water recovery and whole-delivery rewards.
- The nightly shared battery decision, warning/chase/rescue loop, ordinary refuge departures and persistent dawn returns.
- Workshop, two physically walkable shortcuts, beacon and Moth repairs. Guaranteed story parts are separate from optional gear materials; 320 coins pay for the campaign repairs.
- Final mission: arm Moth at night, signal from the repaired beacon, return and ready together, cross the actual water channel, save the ending and rewards together. Continue Island preserves everything.
- Boarding locks admission until the next outing. A client disconnect after departure preserves already-boarded cargo; ordinary on-island disconnects retain the established pouch-forfeit rule.
- Confirmed New Island with verified archival copies, interrupted-reset recovery, legacy save loading, saved local settings and remapped keyboard controls. No host migration or gamepad support.

## Verification

| Evidence | What it establishes |
|---|---|
| `logs/campaign-full-suite-final.log` | 155/155 GUT tests, 1,560 assertions across 24 scripts, Godot exit 0, no engine errors/warnings. Rules, actual controller integration, UI, Jolt bodies, real disk writes, legacy/default handling and reset rollback |
| `tests/integration/test_campaign_flow.gd` | Real controller intents for all caches/repairs/crafting/tools; final night range/signal/readiness gates; saved ending, independent reload, Continue; deliberately failed final write retries exactly once. Earned-wallet/time/travel fixtures isolate these gates, so this is not an economy-duration test |
| `logs/campaign-reel-flow.log` | 13 checks: actual reel input earns fish/30 coins, banks, finds/crafts/equips, repairs, votes, departs, saves and reloads. Accelerated ticks/authored movement; not manual play |
| `logs/campaign-world-probe.log`, `logs/campaign-effects-probe.log` | Ground/navigation support and snapshot-driven cast/role/cargo/boat presentation contracts. Dedicated capsule sweep reproduces and fixes the shortcut-junction collision |
| `logs/campaign-render.stdout.log`, `logs/campaign-*.png` | Seven actual main-scene renders at 1280×720: new pockets, homeward trail, sea crossing and ending. OpenGL 3.3/NVIDIA RTX 4070 Laptop, exit 0, empty stderr. Poses/progression were seeded fixtures |
| `.tools/hud-preview/` | Rendered menu/journal/collection/workshop/settings/ending layouts and actual rapid-recast camera regression; layout fixtures are not progression evidence |
| Three-process ENet: `.tools/network-probe/20261009T222931131_26be0ce7/summary.json` | 191 checks: host 53/client 1 70/client 2 68. All natural exits 0, no forced stops/errors/warnings. Movement/cargo, simultaneous disconnect/rejoin, actual arm/signal/ready RPCs, departing carrier disconnect, protected whole payout, real sailing-time join rejection, saved ending, disk reload, Continue and normal rejoin, actual host exit. Three loopback processes, not three physical PCs |

A repeated network run exposed a stale comparison in the test after a player rejoined: the recreated avatar was compared with a pose from its departed connection. Stage barriers now wait for fresh host authority and two subsequent packets. The original 0.3 m assertion remains. The corrected check passed again during the root agent's concurrent release build; this is test synchronization, not a relaxed movement requirement.

## Windows package

- `C:\game-3\build\OneMoreCast-windows.zip` — 39,438,976 bytes. Copy the same ZIP to each PC and extract it.
- `C:\game-3\build\windows\OneMoreCast.exe` — 109,345,744 bytes, embedded runtime data; no editor/browser/account required.
- Release evidence: `build/evidence-20261009T222911120/`. Import, release export, inspection of 67 embedded resources with no development directories, clean-folder headless startup and native OpenGL startup all passed.
- Executable SHA-256: `a60ae5067df47d35b8d1ab9a3eb84f0e4a6f436b7f90463409b867c3544a0d87`.
- ZIP SHA-256: `e8c59384bfb51787f2b88be8916544c1fc71f499e56e581c5359ebbfe7a31d84`.
- Previous output remains in `build/windows-previous-20261009T222911120/`; previous ZIP is `build/OneMoreCast-previous-20261009T222911120.zip`, verified against its original `f29957b7acea9789c688154d3fa9d9a01e2e6ff938e6ec5c0bab7cebab64aea0` hash.

The exported executable was tested for startup from its clean folder. The 191 networking checks and automated campaign gameplay used the source project's Godot runtime; they are separate claims. Physical three-PC acceptance of the packaged executable is pending.

## Review findings resolved

Independent review plus actual rendering corrected: a shortcut railing blocking the hunter; hidden Continue after closing the ending; inaccessible eight-metre rescue targeting; consuming a rescue cooldown on an already-assisted catch; stale rapid-recast line/camera targets; fishing announcements obscuring the bobber; refuge wording during the final escape; late joining during a crossing; and confirmed New Island silently failing after a rejected join. The release script now preserves both the previous output folder and ZIP.

## Play together next

1. Copy the same ZIP to all three PCs, extract it, and follow the README's Host/Join steps. Use the same host and crew slots when reconnecting.
2. Spend five minutes passing, missing and recovering a whole fish. Check camera comfort and whether catching a pass is readable.
3. Play two ordinary outings. Make different battery choices, try a rescue, acquire gear, and check that discoveries/repairs remain after a host restart.
4. Continue the repairs toward the final escape. Watch whether 320 coins feels too quick, too slow or forces boring repetition; do not assume the old eight-to-twelve-outing estimate was correct.
5. Each person separately names a favourite moment, biggest frustration, equipment/teammate choice that mattered, and whether they would choose another outing. Fix the largest observed obstacle before adding systems.

Known acceptance limits: actual Windows firewall/LAN conditions, network latency, the weakest laptop, free-play camera/collision surprises, balance, difficulty and enjoyment. These cannot be certified by automated logic or a render capture.

![Actual main-scene casting on the expanded island](campaign-cast.png)

![Actual main-scene final channel crossing](campaign-escape.png)

Both images are from the running engine, with authored test poses/progression; neither is concept art or a family playtest.

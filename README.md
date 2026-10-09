# One More Cast

A standalone Windows LAN fishing adventure for three. **Build 0.2.0 — Island Campaign** includes the repair-and-escape story, saved RPG equipment and collection, and continued play after the ending. Physical three-PC and family acceptance testing are still pending.

## Play together

1. Extract the complete `OneMoreCast-windows.zip` to each PC and open `OneMoreCast.exe`. No Godot installation, browser or account is needed.
2. On the PC that will keep your island, enter a name and choose **Host / Continue**. Use this same PC as host each evening.
3. The host's LAN address appears at the top of the game. Enter that address on the other two PCs, choose Crew 2 / Crew 3 (or an available slot), and Join. Use the same profile when reconnecting.
4. If Windows asks, allow the game on your **private home network**. The game uses UDP 24563. Guest Wi-Fi/client isolation can prevent joining; all three PCs must be able to reach one another. No port forwarding is required.

The host owns the household save. Clients do not carry separate island saves. Host leaving ends the session; unbanked cargo is transient. Discoveries and confirmed purchases/repairs save immediately. Bank before quitting.

## First evening

Follow the pale path to Jetty and catch fish. Return to Moth's boarding dock to bank them. The journal tracks your next island objective, actual fish odds, discoveries and records. There are twelve species across Jetty, Reeds, the Lido terraces, Tide Pools and Beacon, with darting, heavy and surging behaviour. Release the reel during a surge. Moonlit, Stormmarked and Oversized are exclusive specimen traits; the journal shows when to find them and how rare protection works.

Find the lido workshop cache for tools, a lens and lantern recipe; the shore cache for a Soft-tip Rod; the brass fitting near Jetty for the broken walkway. The Surveyor Lantern costs **30 coins + one lens**: longer reach, narrower beam, half the battery. Find the reel kit on the south-east shore to craft a **Braced Reel for 35 coins + one cord spool**. Discover six species to unlock the Drift Rod. Four rods offer different behaviour tradeoffs, not a single best rod. Unlocks are shared; each player equips separately at Moth.

Ordinary catches go straight into your pouch. An Oversized catch lands as one physical fish: carry it alone, pass it to a waiting teammate, or toss it near Moth for twice the species' base value. Pack it when danger makes carrying inconvenient; packing gives the usual Oversized value instead. Dropped fish recover from water. Healthy players cannot be launched by them.

Before dusk, vote for Jetty or Reeds to keep power after sunset. Reeds offers the night-only Lantern Eel, with fishing beyond its shelter. Lights buy space; the hunter warns before chasing. Rescue a fallen teammate or regroup at Moth. Each run lasts at most 10½ minutes plus its recap, or everyone can ready at Moth for a 20-second refuge crossing. Dawn starts another day with saved gear, records, opened caches and repairs intact.

Restore the workshop (40 coins), return walkway (brass fitting), ridge shortcut (60 coins), beacon (100 coins), and Moth's engine (120 coins). Story parts come from guaranteed marked caches. Use the journal for locations and prerequisites. These upgrades change the island permanently. Collection and repairs unlock three optional role tools: Scout's homeward Trail Mark, Keeper's smaller longer-lasting Steady Glow, and Rigger's longer-reaching Long Line. All three trade against the standard tool; descriptions show their effects and cooldowns.

For the ending, finish all repairs, then **at night arm the escape at Moth**, signal from the repaired beacon, and bring everyone back to board and ready. Moth crosses the sea channel; rewards and the ending save together. **Continue Island** keeps your gear, collection and repairs. You can reopen the ending through the journal if you close it. No real-time waiting, daily chores, equipment decay or rare story-item grind.

## Controls

| Control | Action |
|---|---|
| WASD | Move; W/S also leave a fishing cast |
| Hold right mouse + move mouse | Turn camera |
| Left mouse | Cast, hold to reel, or toss a held fish |
| A / D while fishing | Oppose the indicated pull; release reel to lower tension |
| T | Switch hold/toggle reeling |
| X | Cancel cast |
| E | Context action: grab, drop, bank, open cache, repair |
| Hold E | Receive a thrown fish; revive a nearby downed teammate for 3 seconds |
| Hold P | Pack your held fish |
| F | Toggle your lamp; recharge beside Moth |
| Q | Role ability: Scout reveal / Keeper brief shelter / Rigger rescue line |
| R | Help a nearby teammate's catch |
| V | Battery ballot; initiate near the battery console before dusk |
| B | Ready aboard Moth; refuge normally, final escape after arming and signalling |
| K / J | Workshop / catch journal |
| Escape | Pause/menu; host pauses everyone, clients open their own menu |
| F8 | Host's secret Lake Office: fog, Odd Catch, sighting, clear, safe return |

Role changes and gear selection happen at Moth. All keyboard bindings can be changed in Settings; prompts follow your mapping. Settings also include master/threat volume, camera sensitivity, inverted vertical camera, windowed/borderless/fullscreen, and reduced effects/shadows. Mouse buttons retain their cast/reel/camera functions. The threat is non-graphic. Keyboard and mouse are supported; gamepads are not yet implemented.

## Saves and recovery

Host save: `%APPDATA%\OneMoreCast\household.json`. The adjacent `.bak` holds the previous valid commit. Existing build 0.1 saves load without a reset. A failed catch/bank/departure write pauses play; Escape → Resume retries. If both files are corrupt, hosting refuses to overwrite them. Keep both files when diagnosing problems. **New Island** requires confirmation and verifies dated archival copies of existing saves before starting over; failure preserves the old files. Local settings live beside the save in `settings.json`.

Rejoin the same crew slot to restore your loadout. Disconnecting during normal play forfeits your pouch; whole fish stay for the crew. Once Moth departs, boarded cargo is protected even if a client disconnects. Joining during a crossing is temporarily blocked: retry after dawn, or after the host chooses Continue Island at the ending. There is no host migration.

## Build and verification

Godot **4.7.2 standard**, matching Windows templates; built-in Jolt and ENet. GUT **9.7.1** is for development only. No runtime add-ons. See `THIRD_PARTY.md` for source and license records.

Local tool locations and build: `powershell -ExecutionPolicy Bypass -File tools\build_windows.ps1`. The build script expects the verified tools under `.tools`. Unit/integration command:

```powershell
& .tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://addons/gut/gut_cmdln.gd -gconfig= -gdir=res://tests/unit,res://tests/integration -ginclude_subdirs -gexit
powershell -ExecutionPolicy Bypass -File tests\integration\run_network_probe.ps1
```

Current test evidence and remaining acceptance gates live in `docs/playtest/CAMPAIGN_STATUS.md`. The older `FIRST_PLAYABLE_STATUS.md` records build 0.1 history. Local multi-process checks are not three physical PCs, weakest-laptop performance, or proof of fun. Treat campaign length, equipment balance and camera comfort as family-playtest questions before adding more systems.

# One More Cast

A standalone Windows LAN fishing adventure for three. This is the **first playable slice, build 0.1.0**, with persistent equipment and island progress. It is not the completed campaign.

## Play together

1. Extract the complete `OneMoreCast-windows.zip` to each PC and open `OneMoreCast.exe`. No Godot installation, browser or account is needed.
2. On the PC that will keep your island, enter a name and choose **Host / Continue**. Use this same PC as host each evening.
3. The host's LAN address appears at the top of the game. Enter that address on the other two PCs, choose Crew 2 / Crew 3 (or an available slot), and Join. Use the same profile when reconnecting.
4. If Windows asks, allow the game on your **private home network**. The game uses UDP 24563. Guest Wi-Fi/client isolation can prevent joining; all three PCs must be able to reach one another. No port forwarding is required.

The host owns the household save. Clients do not carry separate island saves. Host leaving ends the session; unbanked cargo is transient. Discoveries and confirmed purchases/repairs save immediately. Bank before quitting.

## First evening

Follow the pale path to Jetty and catch fish. Return to Moth's boarding dock to bank them. Find the workshop cache at the old lido for a lens and lantern recipe, the shore cache for a Soft-tip Rod, and the brass fitting near Jetty for the broken return walkway. The Surveyor Lantern costs **30 coins + one lens**: longer reach, narrower beam, half the battery. The Soft-tip Rod eases tension but takes longer with Bellgill. Both are shared unlocks; each player equips separately.

Ordinary catches go straight into your pouch. An Oversized catch lands as one physical fish: carry it alone, pass it to a waiting teammate, or toss it near Moth for twice the species' base value. Pack it when danger makes carrying inconvenient; packing gives the usual Oversized value instead. Dropped fish recover from water. Healthy players cannot be launched by them.

Before dusk, vote for Jetty or Reeds to keep power after sunset. Reeds offers the night-only Lantern Eel, with fishing beyond its shelter. Lights buy space; the hunter warns before chasing. Rescue a fallen teammate or regroup at Moth. Each run lasts at most 10½ minutes plus its recap, or everyone can ready at Moth for a 20-second refuge crossing. Dawn starts another day with saved gear, records, opened caches and repairs intact.

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
| B | Ready for refuge at Moth; moving away cancels readiness |
| K / J | Workshop / catch journal |
| Escape | Pause/menu; host pauses everyone, clients open their own menu |
| F8 | Host's secret Lake Office: fog, Odd Catch, sighting, clear, safe return |

Role changes and gear selection happen at Moth. The pause menu includes audio mute. The threat is non-graphic; no camera shake or loud jump-scare track is used.

## Saves and recovery

Host save: `%APPDATA%\OneMoreCast\household.json`. The adjacent `.bak` holds the previous valid commit. A failed catch/bank/departure write pauses play; Escape → Resume retries. If both files are corrupt, hosting refuses to overwrite them. Keep both files when diagnosing problems. For an intentional fresh island, close the game and move both files into a backup folder first.

## Build and verification

Godot **4.7.2 standard**, matching Windows templates; built-in Jolt and ENet. GUT **9.7.1** is for development only. No runtime add-ons. See `THIRD_PARTY.md` for source and license records.

Local tool locations and build: `powershell -ExecutionPolicy Bypass -File tools\build_windows.ps1`. The build script expects the verified tools under `.tools`. Unit/integration command:

```powershell
& .tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://addons/gut/gut_cmdln.gd -gconfig= -gdir=res://tests/unit,res://tests/integration -ginclude_subdirs -gexit
powershell -ExecutionPolicy Bypass -File tests\integration\run_network_probe.ps1
```

Actual test evidence and remaining gates live in `docs/playtest/FIRST_PLAYABLE_STATUS.md`. Local multi-process checks are not three physical PCs or proof of fun. The full campaign, expanded fishing collection, final beacon/boat escape, controller support and broader settings remain later work after the family playtest.

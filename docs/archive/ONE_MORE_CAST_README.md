# One More Cast

**Windows · 3 players · same home network · Build 0.3.0-coast**

Find the parts. Fix the boat and beacon. Get everyone home. Fish fund your repairs and gear; oversized catches offer an optional bigger payday.

## Play together

1. Extract the same `OneMoreCast-windows.zip` on each PC. Open `windows/OneMoreCast.exe`.
2. One person chooses **Host**. Keep using this PC as host: it stores the island and everyone's equipment.
3. The host opens Pause to find the **join address**. The others choose **Join** and enter it. Choose the same crew slot when reconnecting.
4. If Windows asks, allow access on your **private network**. The game uses UDP 24563. Guest Wi-Fi isolation can block joining; no port forwarding is needed.

No Godot installation, browser or account is required. Bank your catch before the host quits.

## Your first outing

Follow the path to Jetty. Click to cast; hold to reel and release when tension rises. A/D counter the fish's pull. Return to the boat, Moth, to bank your catch.

Small fish go into your pouch. Oversized fish can be carried or thrown to a teammate for a better whole-fish payout. Hold **P** to pack one if you need to run. Missed throws recover from water.

Before sunset, one player can pull the dock battery switch for everyone: power Jetty or Reeds, leaving the other shelter dark. The choice lasts until dawn; its power lasts 150 seconds after dark. Two spare cells can each add 90 seconds to either shelter. Moth is always safe. Everyone can revive a fallen teammate, or carry them to safety first.

An outing lasts up to 10½ minutes. Everyone boarding and readying at Moth ends it early. The journal shows the next repair and records. Confirmed discoveries, gear and island repairs survive the night.

## Controls

| Control | Action |
|---|---|
| WASD | Move; A/D counter a fish's pull |
| Hold right mouse | Turn the camera |
| Mouse wheel | Zoom in / out |
| Left mouse | Cast / hold to reel |
| Hold then release left mouse with cargo | Aim and throw; longer hold throws farther |
| E | Nearby action / drop cargo |
| Hold E | Receive a throw / revive for 3 seconds |
| R | Carry a fallen teammate / help a teammate's catch |
| Hold P | Pack a whole fish |
| F / Q | Lantern / role tool |
| B | Ready aboard Moth |
| K / J | Equipment / journal |
| V | Dock battery |
| T / X | Toggle reel mode / cancel cast |
| Escape | Pause/menu; only the host pauses everyone |
| F3 | Local FPS/debug overlay |

Settings contains key rebinding, sound, camera and window options. Shadows are off by default for smoother play. Reduced effects also removes extra motion. Keyboard and mouse are supported; gamepads are not implemented.

The host's optional **Lake Office** is inside Pause (also F8): fog, unusual fish, a monster sighting and safe return.

## Progress that stays

The household shares discoveries, found recipes and crafted equipment. Each crew member equips separately at Moth. Four rods, two lanterns and three earned outfits change fishing, carrying or lamp life. Outfits are complete sets with one clear benefit; there is no item durability or separate clothing grind.

Find the beacon coil and engine part in marked caches. Repairing the beacon and Moth's engine costs 120 shared coins in total. Workshop and route repairs are optional and use found parts. At night, arm Moth, signal from the beacon, and bring everyone aboard for the escape. **Continue Island** preserves gear, discoveries, records and repairs, so you can chase new catches or attempt another night crossing.

## Saves

The host saves to `%APPDATA%\OneMoreCast\household.json`; `.bak` keeps the previous valid commit. Earlier saves remain compatible. Local settings are separate in `settings.json`.

A failed save pauses play. Host: Pause → Resume retries. If both save files are corrupt, hosting preserves them and refuses to overwrite them. **New Island** requires confirmation and archives existing saves first.

Disconnecting on the island loses your unbanked pouch; whole fish remain for the crew. Cargo already aboard a departing boat is protected. Joining is blocked while the boat crosses: retry after dawn or Continue Island. There is no host migration.

## Development and verification

Godot 4.7.2, built-in Jolt/ENet and Compatibility rendering. GUT 9.7.1 is development-only. Curated Kenney environment and KayKit crew assets are CC0; fish and game code are project-specific, with credited MIT movement inspiration. See `THIRD_PARTY.md` and `LICENSES`.

Build: `powershell -ExecutionPolicy Bypass -File tools\build_windows.ps1 -RenderSmoke`.

Current verification and limitations: `docs/playtest/CAMPAIGN_STATUS.md`. Automated tests and rendered reviews do not establish family enjoyment, performance on the weakest laptop, or three physical PCs on your Wi-Fi.

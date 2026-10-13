# Crown Court

A 3D basketball game for one to three people, with LAN play and a native room transport awaiting public hosting. Original procedural models and a CC0 sample sound bank, built with Godot 4.7.2.

## 0.15.2 - higher hoops, movement and counterplay

Hoops now stand 5.8 units high, approximately 2.7 times the family characters' standing height. This restores their earlier bean-to-rim proportion; exact Crown Jam dimensions remain unknown. The camera keeps nearby rims below the scoreboard without changing your aim. A contextual jump-and-tackle hint teaches dunk defence. This update also removes direction-dependent air control and phantom momentum into walls, while retaining the authored running, sliding and knockback tuning. Camera clearance retracts progressively near walls and stays stable through corner turns. Bot release-origin and final-screen fixes from 0.14 remain.

Released runs coast briefly; dives carry into a low recovery slide; knockback lands into a skid instead of abruptly braking. Straight and diagonal impacts now retain the same momentum. Camera clearance, score/lead/tie celebrations, late-clock cues and Hype-ready feedback are improved.

In **Wardrobe > Character**, choose **Fresh Bean**, **Evie**, **Tyler** or **Dad**, then equip your owned clothes and accessories. Existing unlocks and bags are preserved. Use **0.15.2 on every PC**. Family likeness and physical controller/three-PC feel remain household checks. Hosting stays undeployed.

## Start

Download [CrownCourt.exe for 64-bit Windows](https://github.com/jbot-bit/game-3/raw/refs/heads/main/CrownCourt.exe) and double-click it. The executable contains the game and its assets; no installer, extraction, Godot installation or extra files are required for practice and LAN. Use version 0.15.2 on every PC. This release updates only the standard 64-bit build; the retained older 32-bit executable is not a matching release. Saves are stored separately in your Windows user profile, so moving or replacing the EXE keeps your wardrobe.

Practice and LAN need no account. Version 0.11.0 includes native room connections; the public room service is not deployed yet, so Internet buttons stay unavailable. See INTERNET_PLAY.txt. The earlier portable ZIP remains usable, but the standalone EXE is the direct play download.

Enter your name, choose a mode, bot difficulty and Hype power, then select **Practice**, **Host**, or **Join**. Use a controller or mouse/keyboard for menus and gameplay. The first available controller is selected; it stays selected until disconnected.

Easy bots are the default. Normal and Hard increase reaction speed and accuracy. Bots settle possession and visibly wind up before shooting.

## Modes

- **3 vs bots:** One to three humans on the same team. Bots fill empty human seats, making a 3v3 match.
- **Custom teams:** Two humans default to 1v1; three default to 2v1. The host chooses each player's side. **Balance teams with bots** adds a bot to the lone player's side in 2v1; turn it off for an unbalanced game. Each side supports up to three players.
- **Free-for-all:** Three scoring players, with bots filling empty seats.

Team games last five minutes or end when a team leads by four points. Free-for-all lasts three minutes or ends at seven points. Every basket and dunk scores one point. Play begins after a three-second countdown. The clock stops during the reset after a basket. Tied games continue until the next score.

## Controls

| Action | Keyboard / mouse | Xbox | PlayStation |
| --- | --- | --- | --- |
| Move / look | WASD / mouse | Left / right stick | Left / right stick |
| Jump, then double jump | Space twice | A twice | Cross twice |
| Catch without ball / pass while holding | Left mouse | X | Square |
| Tackle without ball / charge and release a shot while holding | Right mouse | RT | R2 |
| Dunk near the hoop while airborne | F | B | Circle |
| Explicit catch | E | X when empty | Square when empty |
| Explicit tackle | Shift | RT when empty | R2 when empty |
| Ball camera | Ctrl | LB | L1 |
| Recenter camera | R | Right stick press | R3 |
| Hype power, when full | Q | Y | Triangle |
| Request a pass | Middle mouse | RB | R1 |
| Controls / pause menu | F1 / Esc | Start | Options |
| Fullscreen / sound | F11 / M | — | — |

Menus use the D-pad or left stick, the bottom face button to confirm and the right face button to go back. Nintendo labels follow physical B/A/Y/X positions; unknown controllers show physical button positions. Select a name, address or room code to open the controller keyboard. Disconnecting during play cancels a held shot and opens the pause menu; release controls after reconnecting before resuming. Hardware controller testing is pending.

Shots follow your actual horizontal aim and camera-controlled loft. Adjust aim and charge using the trajectory dots; there is no basket correction. Release a shot before the meter turns red. More charge reaches farther, including long lobs from your own half. Overcharging changes the actual flight path; there is no random make/miss roll. Dunking uses its own button. Team passes lead the receiver's movement and can be intercepted. Choose **Giant**, **Jump pad**, or **Homing ball** before joining or starting. The Hype meter always names your power and shows its charge, readiness and active duration.

Practice pauses when its pause menu opens. A network match continues for the other players.

Moving the mouse or right stick releases ball camera. E and left click both allow a catch pressed just before the ball arrives. Aim dots and the highlighted pass target follow your current aim.

The court is 64 × 112 metres, with hoops 96 metres apart. Narrow winding roads rise 1.15 metres above the turf and loop toward the baskets. Use the raised flank routes, cross a bank, or cut through the low goal pocket. Teams launch from rear decks after the countdown, with one extra jump available. Free-for-all keeps its ground start. Chevron strips give a forward speed boost; round launch pads send you high into the air. Steer the arc and use the extra jump without losing upward speed. Jump over the four rotating sweepers: a hit knocks you off balance and drops your ball, while loose balls rebound from them. Near the hoop, jump and press F/B; a slightly early dunk press is remembered. The dunk gathers beside the rim, winds up, slams, and finishes before the kickoff reset.

Build Hype by catching, passing, tackling, assisting and scoring. Giant lasts seven seconds and can stride through sweepers. A deployed jump pad lasts fourteen seconds and launches anyone who crosses it. Homing ball pursues an opponent and knocks them down on an unguarded hit. A completed pass followed by the receiver's basket within eight seconds earns the passer extra assist Hype.

## LAN

1. Connect the PCs to the same Wi-Fi or Ethernet network.
2. On one PC, choose **Host**. Its lobby displays its IPv4 address.
3. On the other PCs, enter that address and choose **Join**.
4. The host chooses **Start**. Players may join during a match; bots take over disconnected seats. The host starts rematches.

The game uses UDP port **28888**. If Windows Firewall asks, allow the game on **Private networks**. If joining fails, check the lobby address, that the host is still open, and that the PCs share the same local network. Closing the host ends the session.

Use the same **0.11.0** build on every PC.

## Internet

The new flow is **Host room → Copy room code → Join room**. Players use the game alone, with no VPN or router forwarding. The host runs the match simulation; a secure WebSocket relay carries game packets. Random private room codes support up to three people. Closing the host closes the room.

The relay and three-client flow are implemented and tested locally. A public service still needs deployment approval and a configured `wss://` endpoint in `internet.cfg`. This local release leaves it blank and cannot yet connect separate homes. Relay source and deployment instructions are in `relay/`; players do not need Node or development tools. Check-Internet.cmd checks the configured service without changing settings. Actual separate-home play remains unverified.

## Wardrobe and bags

Players start with a blank outfit and no accessory. Winning humans present at the final whistle earn one free bag each. Losing players and players who join an already finished round do not receive that round's reward.

Open bags in **Wardrobe** or after a win. There are 11 unlockable cosmetic items; outfits and accessories do not change player stats. Starting rarity chances are Common 50%, Rare 30%, Epic 15%, and Legendary 5%. Completed rarity tiers are rerolled, and owned items are excluded. Once the collection is complete, bags are retained. There are no purchases.

If a reward cannot be saved, keep the game open while resolving the save-folder problem. It retries automatically, including from the menu. Unsaved rewards are lost if the app closes.

Windows saves are in `%APPDATA%\CrownCourt\`:

- `closet.json`: Inventory, equipped items, pending bags, and redeemed match rewards.
- `settings.cfg`: Name, last host address, Hype power, and sound preference.

Saves belong to the Windows user on that PC. Copy the save folder when moving your wardrobe to another PC.

## Source and limits

Open `project.godot` with Godot 4.7.2 to run the source project. Physics and game feel use local tuning informed by full-match reference footage; they are not values extracted from the reference game's implementation. Models, court geometry and cosmetics are original. The sound bank uses adapted CC0 samples; source credits and hashes are in assets/audio/.

Physical three-PC play, hardware controller behavior, and whether matches are fun still require a household playtest. Automated or same-PC multi-process checks do not establish those results. Game Development Studio 1.5.0 was installed locally and used to seal, verify and compare the native Godot visual captures. It is a development tool; players do not need it installed.


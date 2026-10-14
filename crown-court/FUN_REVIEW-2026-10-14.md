# Family game decision — 14 October 2026

The user chose all three avenues: find an established game, develop grabbing comedy, and improve Crown Court. The immediate objective is enjoyable three-person play across Windows and an unidentified iMac. A test-suite pass is not evidence that a game is fun. Existing saves and published builds must remain intact.

**Latest decision:** the user subsequently chose Gang Beasts and explicitly asked not to lose Crown Court. Gang Beasts setup is now the priority. The custom-game experiments below are retained research, not active implementation instructions. Preserve Crown Court source, packages and household saves; do not replace it with Hands Full or cancel its hosting implicitly.

## What we actually have

- Crown Court is our own Godot basketball prototype. We have not recovered Crown Jam's proprietary physics or established equivalent feel.
- Epic announced Crown Jam as a Fortnite mode running January 23–February 9, 2026. Searches of Epic/Fall Guys news and current public listings did not establish a return. This is a bounded search, not an authenticated check of the Fortnite client.
- A separately authored Fortnite island, **FALL GUYS BASKETBALL**, has a public listing (9793-7307-3362). It is not Crown Jam; its gameplay, current matchmaking and this household's Mac access have not been tested.
- REA can inspect an available artifact or runtime. There is no accessible Crown Jam artifact/session here to inspect. Our complete source is better inspected directly, as the REA skill itself instructs.

## 1. An established game for family play

**First choice: Gang Beasts on Steam**, based on the requested grabbing, lifting, ridiculous fights and hazardous environments. Its developer lists Windows and macOS, and its store lists online multiplayer. Use the Steam edition consistently; console/Microsoft Store crossplay is a separate compatibility question. The exact iMac and its ability to run the current Steam client/game remain unknown. No purchase or installation was made.

**Cooperative alternative: Human: Fall Flat on Steam.** Already matches the family's stated taste, lists Windows/macOS and up to eight online players, and offers community-created levels. Its Mac graphics requirements must not be assumed satisfied by every iMac.

**Different repeatable competitive loop: Ultimate Chicken Horse.** Windows/macOS, up to four online players, with players changing the obstacle course between attempts. It offers variety through player decisions but does not supply the requested physical grabbing.

Steam's Australian appdetails price response checked on 14 October: Gang Beasts A$11.80, Human: Fall Flat A$28.95, Ultimate Chicken Horse A$9.87 per copy. Three copies would be A$35.40, A$86.85 and A$29.61 respectively; prices can change. None appears installed in the primary local Steam library. This does not establish account ownership.

**Cheapest first trial: Gang Beasts Remote Play Together.** The store lists this feature, and Valve documents one owner running the game for up to four participants. Dad's Windows PC would render it and the kids would receive the stream on Steam/Steam Link, which supports macOS. This avoids requiring the iMac to render the game natively. Prefer distinct gamepads: Remote Play shares a keyboard/mouse, not three independent keyboard devices. The children having suitable controllers, Mac client compatibility and acceptable streaming latency still need confirmation. One copy would currently cost A$11.80; no purchase, installation, invitations or household stream test has occurred. Launch locally, then use the Steam overlay's Remote Play Together invitation for each friend. Do not confuse this with native online matchmaking.

Actual household launch/join is required before calling any option verified for this family. The rented Crown Court server is not needed for this Remote Play Together route, and is not a reason to prefer our prototype over an established game. Its paid subscription remains separate and unchanged.

Valve's current Steam support page requires macOS 12 or newer for future client versions. The Steam Link Mac App Store listing gives macOS 10.13 or newer, offering a possible older-Mac streaming route. An unknown iMac cannot be called compatible merely because the game store has a Mac icon. Internet invitations, distinct controller inputs and latency must be tested at both houses.

## 2. Reuse Hands Full for grabbing comedy

Existing `prototypes/physics_party` contains real host-simulated physical bones and hand PinJoint3D attachments. The grab filter excludes the player's own skeleton but permits other players' physical bones (`puppet.gd`, around 268–282). Co-op already enables these interactions; competitive modes disable them.

This is a better starting point than another new project. First experiment: one existing cooperative space where three players can carry something together, catch/rescue a dangling friend and recover quickly from a failed attempt. This is a proposed experiment, not a newly implemented or playtested mode.

Known blockers: direct-address ENet LAN transport (`party_session.gd:46–68`), Windows-only export preset, unverified internet grabbing latency. Reuse lobby concepts with separate game/protocol identity; do not blindly replace unreliable pose packets with reliable TCP or mix the games' rooms/saves.

Reject the experiment if grabbing mostly immobilizes others, remote input makes rescue uncontrollable, or the players want to stop after a few minutes. Produce more courses only after the interaction is enjoyable.

## 3. A bounded Crown Court experiment

Observed source facts:

- Court is 64 by 112 units; hoops are 96 units apart; normal speed is 9.5 units/second. Ideal straight hoop-to-hoop travel is about 10.1 seconds, excluding acceleration and terrain.
- `grab` catches the ball, not another player. Tackles produce impulses/stun; sustained holding, tugging and rescuing are absent.
- Every basket scores one point. Dunks use a committed interpolated path. Bot offense repeatedly selects advance/dunk/pass/shot within distance bands.
- REVIEW-0.17.md already documents repetitive tackle/recovery/dunk cycles. Best-of-three adds a session structure but does not prove replayability.

Hypothesis: a shorter court increases useful encounters. First A/B candidate: shorten the court length by 20%, moving hoops, terrain, spawns, pads and camera bounds consistently, while preserving speed and momentum. This value is an experimental choice, not a recovered Crown Jam ratio. Measure dead travel, touches per player, contested possessions, visible confusion and voluntary rematch preference. Reject if it creates stun piles or reduces the children's involvement.

Only then compare scoring/shot incentives. Increasing speed, shrinking geometry and adding grabs simultaneously would obscure which change helped. Importing a full ragdoll into the basketball simulation is a substantial physics/network project, not cosmetic polish.

## Research interpretation

Crown Jam community discussions mix enthusiasm for playing with friends/family with complaints about repetitive wins and requests for maps/perks. These are anecdotes, not a representative survey. Human: Fall Flat's creator describes players inventing their own actions and getting unexpected but believable physics outcomes. This supports testing expressive interactions, not assuming more rewards or longer matches create enjoyment.

## Sources

- [Epic's Crown Jam announcement](https://www.fortnite.com/news/crown-jam-a-limited-time-fortnite-mode-from-the-fall-guys-world)
- [Community basketball island listing](https://www.fortnite.com/@el3ktromaps/9793-7307-3362)
- [Gang Beasts developer FAQ](https://gangbeasts.game/faq)
- [Gang Beasts Steam listing](https://store.steampowered.com/app/285900/Gang_Beasts/)
- [Valve Remote Play Together](https://store.steampowered.com/remoteplay)
- [Valve macOS client support](https://help.steampowered.com/en/faqs/view/659D-A19E-018A-81A6)
- [Steam Link for Mac](https://apps.apple.com/us/app/steam-link/id1246969117?platform=mac)
- [Human: Fall Flat Steam listing](https://store.steampowered.com/app/477160/Human_Fall_Flat/)
- [Ultimate Chicken Horse Steam listing](https://store.steampowered.com/app/386940/Ultimate_Chicken_Horse/)
- [Interview with Human: Fall Flat creator Tomas Sakalauskas](https://www.fanatical.com/en/blog/human-fall-flat-stumbling-upon-a-physics-based-gem)
- [Crown Jam player discussion](https://www.reddit.com/r/FortNiteBR/comments/1qkvg6w/i_was_fully_prepared_to_clown_on_crown_jam_but/)

This document records research and next experiments. It does not claim either experiment has been built, that commercial games are installed, or that physical household Mac/PC play has passed.

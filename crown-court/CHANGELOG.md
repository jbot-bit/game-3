# 0.15.2

- Raise hoops from 4.6 to 5.8 units and extend supports, restoring roughly 2.7 times the taller family character height. Preserve rim opening and ball size; exact Crown Jam ratios remain uncertain.
- Frame nearby hoops below the scoreboard while keeping the player visible; blend the adjustment on approach and when turning away, without changing manual aim.
- Teach jump-and-tackle dunk defence with a contextual cue and F1 guidance, informed by firsthand Crown Jam feedback.
- Publish one standard 64-bit Windows build; retain the older 32-bit artifact only as legacy history.

- Direction-independent air steering, braking and boost acceleration using existing tuning constants.
- Walls cancel blocked outward momentum; wall gliding and inward retreat remain responsive. Client prediction and pass forecasts use the same boundary handling.
- Progressive camera clearance at grazing wall angles and stable in-court look-ahead through corner turns.
- New movement stress, client-wall and camera regressions with native captures and ordinary-input match review. Save formats and unlocks unchanged.

# 0.14.0

- Anticipate stadium tiers while descending: retain a clear camera view without the previous abrupt inward cuts.
- Bots solve shots from the actual release hand after braking. Windup/reaction delays and difficulty errors remain; ordinary human shots still follow literal aim.
- Completed matches read FINAL / Full time. Result panels replace temporary score announcements and hide obsolete action hints; rematches restore live controls.
- Preserve 0.13 momentum, family characters, equipment, unlocks and isolated test saves. Hosting remains undeployed.
# 0.13.0

- Bounded ground slides after dives and knockback; brief run-release coast. Direction-independent impact friction and matching client prediction/pass forecast.
- Planted-foot coast, low dive recovery and landing brace; preserve family identities, held-ball/dunk alignment and boost pose.
- Follow camera stays out of foreground stadium walls, including wall/corner contact.
- Scorer, tie and lead-change celebrations; restrained clock milestones and Hype-ready animation/audio.
- Family characters and existing unlocks carried forward from 0.12; both Windows architectures retained. Hosting remains undeployed.

# 0.12.0

- Evie, Tyler and Dad character selection and authored meshes with existing clothes/accessories and unlock preservation.
- Loose-ball tackle release, mutual dive clashes, forward-only hits, body momentum transfer, defensive pursuit and aerial contest fixes.
- Source and character authoring files recovered and published on 12 October 2026.

# 0.11.0

- Easy/Normal/Hard bots, default Easy. Delayed decisions, settling possession and a contestable windup replace instant shooting. Difficulty controls reaction time and actual aim/power error.
- Removed basket correction from human shots. Mouse/right-stick elevation and yaw determine launch direction; charge determines speed. Preview uses that same physical flight.
- Stronger airborne tackle knockback, ball dislodging and a single impact/recovery animation.
- Faster dunk gather/release with a brief rim hang. Body, hands and release retain their committed axis while the camera moves.
- Shared shallow 1.15m court roads, narrower crossings, more open turf and curved stepped goal architecture. Boost pads and physical hazards remain.
- Fixed stale bot windup across human join/leave and stale charge across a loss/recatch hidden between snapshots.
- Matching standalone 64-bit and 32-bit Windows builds. Son's-PC compatibility still requires his test.
- Internet hosting and cost prepared. User chose not to deploy; public room endpoint remains empty.

# 0.10.0

- Replaced shallow straight ridges with broad winding raised roads, bowed cross routes and curved basket approaches. Turf pockets sit three metres below the road crowns; the visual surface and physical terrain share the same functions.
- Rebuilt the surrounding stadium with curved crowd tiers, tall fascia, large team end structures and original mascot silhouettes. Added contrasting bank edges, turf variation, team emblems and launcher surrounds.
- Bots judge loose-ball height from their own feet on raised ground. This prevents jumping away from a ball below a bank while preserving jumps for elevated catches.
- A committed dunk keeps the body, hands and release aligned with the rim even if the player turns the camera. Full-match review exposed uncancelled dunks missing because fresh aim moved the ball sideways during the animation; the new regression covers both baskets, all approach sides and Giant.
- Joining players fall continuously from the rear launch decks. A grounded network update just before the edge no longer pulls the predicted character down to the distant floor and then back up when the next update arrives.
- Carries forward the ball, Hype, sound-event, controls and network repairs below. The 0.9 executable and its verification remain a held comparison baseline; its arena was superseded before packaging.

# 0.9.0 (held test candidate; not packaged)

- Expanded the playable court from 40x72 to 64x112, with wider connected lanes, relocated boosters and four physical rotating sweepers. Hoops are 96m apart.
- Passes forecast running and airborne teammates over the full flight time. Released balls remain physical and interceptable. Catch-to-pass no longer jumps or reverses visually.
- Shots change smoothly with aim, distance and charge; long lobs can reach from your own half. Rim/backboard separation and visible hoop support leave the basket opening clear.
- The Hype meter always shows the selected ability. Added concise ready, earned-charge and active-duration feedback. Successful pass-to-score assists earn extra Hype.
- Homing power shots move between network updates with bounded prediction. Deleted or expired shots clear their effects, and joining an active bot seat keeps the inherited power timer visible.
- Includes the audio, charge-cancellation, foreground visibility and network-recovery repairs below. Previous releases and saves are retained.

# 0.8.0 (held test candidate; not packaged)

- Local throws, jumps and impacts survive other actions occurring between updates. Nearby catches are audible; distant activity fades out. Local cues take priority over ambient sounds without increasing the voice budget or cutting score cues.
- Losing the ball cancels a held shot. Recatching while the button is still held cannot fire the previous possession's charge; release and press again to shoot.
- Client players and held balls recover together from delayed snapshots. Physically consistent short delivery gaps use bounded catch-up; genuine relocations and action transitions retain immediate authoritative handling.
- Foreground rim/net sections fade when they obstruct the character or carried ball. Clear approaches and the opposite rim remain solid; hoop collision/scoring and camera orbit are unchanged.
- Previous releases, saves and the 0.7 traction/jump tuning are preserved. Public internet hosting and physical-controller play remain pending.

# 0.7.0

- Ground movement now builds speed and preserves directional momentum through a turn. A brief reversal skid and running-in-place animation make changing direction visible. Cardinal and diagonal acceleration follow the same traction model.
- Catches gather the ball into the hands over a short interval instead of snapping overhead. Delayed network ball updates use bounded presentation correction; possession, collisions and scoring remain authoritative.
- Replaced synthesized beeps with 21 short CC0 impact, footstep and swish samples. Repeated collisions are throttled and varied, score cues have a reserved voice, and the mix keeps headroom.
- Includes the team-play, presentation and HUD changes below. Version 0.6 was retained as a tested development baseline after further play feedback; it was not packaged for release.

# 0.6.0 development baseline

- Bots spread into moving passing lanes, choose open teammates under pressure and keep one player collecting a loose ball. A short bot receive cooldown prevents immediate return-pass loops; it never restricts human inputs.
- Aim-selected passes have a forward cone and a 34 m limit. The prompt names the selected teammate, and a missing target keeps the ball held. Both active and automatic catches now grant the same teammate Hype credit exactly once.
- New paneled ball, dark backboards, court surface detail, center emblem and clearer route accents. Player names have readable screen sizing and avoid each other and the ball. Nearby backboards/decks fade while the rim and net remain visible.
- Added catch reach/recoil and refined character materials. Preserved measured jump timing, court size, dunk physics and camera follow tuning.
- Smaller HUD with possession, remaining extra jump, controller-specific action cues, game-point/overtime rules and score announcements that survive newer events. Added layered rubber, air, impact, landing and countdown sounds.
- Headless peers skip invisible world animation while retaining result screens and saved rewards. Fixed-state replay measured lower script work; this does not establish faster rendering or resolve every scheduling hitch.
- Public internet hosting and physical controller testing remain pending. Previous builds are preserved.

# 0.5.0

- Compared actual Crown Jam matches and dunk sequences with local recordings. Team kickoffs now launch from elevated rear decks, with the extra jump preserved. The court remains 40 by 72 metres with jump pads and speed strips.
- Extended ordinary dunks to 1.5 seconds with a longer reach and hold. Raised the hanging body and kept the ball at the physical release height; high approaches, interruption and single-score checks cover both hoops and Giant transitions.
- Added a yellow pass trail that clears on catch. Client deck contact and shot previews share the simulation's one-way surface rule.
- Added native room-code hosting/joining through a bounded WebSocket relay. Friends need only the game once a public service is configured. This release has no deployed endpoint: practice and LAN work; public internet rooms remain pending deployment.
- Added Nintendo and generic positional controller prompts. Pad changes preserve held keyboard/mouse actions, and overlapping mouse/trigger holds charge once and release only when both are released. Physical controller testing is deferred at the user's request.
- Added exact-package room, controller, gameplay and network checks, and independent review. TCP stalls remain a measured limitation; no exact Crown Jam physics, physical-controller or cross-home play claim is made.

# 0.4.0

- Controllers operate menus, mode selection, name/address entry, wardrobe, rewards and rematches. Added a controller keyboard and PlayStation button labels.
- Stick deadzones and trigger hysteresis suppress drift and accidental shots. Disconnecting cancels held actions and opens pause; a reconnected controller must return to neutral before activating menus or play.
- Internet play through a private Tailscale connection: lobby shows VPN and LAN addresses separately, with a copy button for the internet address. Join accepts IPv4, computer names and optional ports. Included setup and read-only diagnostics.
- Larger state updates use four bounded packets in flight, retaining exact acknowledgements and stale-state protection. A simulated 100 ms RTT / 1% loss test reduced median oversized-update gaps from about 150 ms to 50 ms. Retransmission stalls can still occur.
- Added controller input/UI regressions and three-process delayed-network action, sustained load and blocked-connection tests. Physical controller and separate-home sessions remain explicit playtest steps.

# 0.3.0

- LAN tackles carry the current movement direction with the action, so a lost turn packet cannot send the dash the wrong way.
- A catch press stays a catch when a pass arrives before its possession snapshot. It no longer immediately throws the newly received ball away.
- Movement and actions identify their match; delayed inputs from a previous round cannot affect the rematch.
- Larger network updates use bounded reliable delivery instead of exceeding ENet's unreliable packet limit. Sequence checks prevent delayed updates from rewinding play, including across match starts.
- Carry-to-throw presentation preserves the release position and smoothly clears its small visual offset. Giant size transitions keep the hands and held ball together.
- One bot on each team pursues the loose ball directly while teammates may use launch routes, preventing both flank players from abandoning every kickoff.
- Recorded active-opponent input play and new adversarial three-peer networking regressions extend the previous isolated action tests.

# 0.2.0

- Court expanded from 24×44 to 40×72: 2.73 times the playable area, with broad crossing ridges, side lanes, four traveling launch pads and four ground speed strips.
- Launches carry forward; air steering and drag preserve momentum. The extra jump adds upward momentum instead of cutting the launch short. Normal jump timing is retained.
- Closer follow camera, forward framing, faster vertical tracking and a wider view during boosts. Ball camera frames a high ball and releases on manual look.
- Buffered catches on both inputs, landing-jump buffering, early dunk buffering, and quick shoot clicks that survive between physics ticks. Prompts use actual action eligibility; shot previews use current aim.
- Dunk approach follows incoming motion into an outside-rim reach, hang, physical release and landing. Scoring no longer teleports the dunker before the animation finishes. Giant expiry and raised-bank dunk clipping are fixed.
- Client first/second jump prediction and carried/loose ball presentation are checked separately from authoritative scoring. Body, hands and held ball share the same rendered motion.
- Smaller HUD, short initial control hints, readable boost routes, launch streaks, catch poses, articulated feet/hands and score effects.

Physics are locally authored values informed by actual match footage. Exact Crown Jam equivalence and household enjoyment are not established by automated checks. See REFERENCE.md and VERIFICATION.md for measurements and remaining playtest work.

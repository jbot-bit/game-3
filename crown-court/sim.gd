extends RefCounted

const Arena = preload("res://arena_layout.gd")

# Local tuning values, not claimed measurements of Epic's implementation.
const SPEED = 9.5
const ACCEL = 34.0
const START_ACCEL = 16.0
const TURN_ACCEL = 24.0
const BRAKE = 22.0
const SLIDE_TRACTION = 10.0
const SLIDE_RECOVERY = .52
const AIR_ACCEL = 18.0
const AIR_DRAG = 2.5
const JUMP_SPEED = 12.2
const DOUBLE_JUMP_SPEED = 11.5
const BOOST_SPEED = 18.0
const LAUNCH_SPEED = 26.0
const PLAYER_GRAVITY = 20.0
const BALL_GRAVITY = 18.0
const HALF_WIDTH = 32.0
const HALF_LENGTH = 56.0
const SIDE_BANK_START = Arena.SIDE_BANK_START
const END_BANK_START = Arena.END_BANK_START
const LANE_X = 21.0
const LANE_WIDTH = 4.8
const LANE_END = 40.0
const LANE_FADE = 48.0
const CROSS_LANE_Z = 19.0
const CROSS_LANE_WIDTH = 5.0
const CROSS_LANE_FADE_START = 26.0
const CROSS_LANE_FADE_END = 29.0
const ROAD_HEIGHT = Arena.ROAD_HEIGHT
const ROAD_HALF_WIDTH = Arena.ROAD_HALF_WIDTH
const ROAD_SHOULDER = Arena.ROAD_SHOULDER
const ROAD_GOAL_RADIUS = Arena.ROAD_GOAL_RADIUS
const MAX_TERRAIN_HEIGHT = Arena.MAX_TERRAIN_HEIGHT
const BALL_RADIUS = 0.52
const HOOP_Y = 4.6
const RIM_RADIUS = 1.65
const RIM_TUBE = 0.28
const BACKBOARD_Z = 50.4
const NORTH = Vector3(0, HOOP_Y, -48)
const SOUTH = Vector3(0, HOOP_Y, 48)
const DUNK_DURATION = .95
const DUNK_REACH_PHASE = .52
const DUNK_RELEASE_PHASE = .70
const DUNK_HOLD_HEIGHT = 1.10
const DUNK_RANGE = 4.8
const KICKOFF_Z = 54.0
const KICKOFF_Y = 7.5
const KICKOFF_HALF_WIDTH = 7.0
const KICKOFF_HALF_DEPTH = 1.5
const KICKOFF_UP = 22.0
const KICKOFF_SPEED = 20.5
const PASS_RANGE = 70.0
const PASS_CONE_DOT = 0.5
const RECENT_EVENT_LIMIT = 16
const RECENT_EVENT_TTL = .35
# Compact snapshot event tuple: [id, kind, position, source player, event clock].
const EVENT_ID = 0
const EVENT_KIND = 1
const EVENT_POS = 2
const EVENT_PLAYER = 3
const EVENT_CLOCK = 4
const PADS = [Vector3(-21,0,-29), Vector3(21,0,-29), Vector3(-21,0,29), Vector3(21,0,29)]
const SPEED_PADS = [Vector3(-21,0,-3), Vector3(21,0,-3), Vector3(-21,0,3), Vector3(21,0,3)]
const HAZARDS = [Vector3(-11,0,-10), Vector3(11,0,-10), Vector3(-11,0,10), Vector3(11,0,10)]
const HAZARD_RADIUS = 3.8
const HAZARD_HEIGHT = .7
const HAZARD_SPEED = .8

var players = {}
var ball = {}
var scores = {}
var mode = "coop"
var clock = 0.0
var time_left = 180.0
var winner = -1
var message = "GRAB THE BALL. OWN THE AIR."
var event_id = 0
var event_kind = "tip"
var event_pos = Vector3.ZERO
var event_player = 0
var event_clock = 0.0
var recent_events: Array = []
var grabs = 0
var throws = 0
var dunks = 0
var tackles = 0
var baskets = 0
var reset_time = 0.0
var celebration_time = 0.0
var bounce_cooldown = 0.0
var team_map = {}
var match_setup = {}
var power_pads = []
var power_balls = []
var power_serial = 0
var assist_player = 0
var assist_receiver = 0
var assist_until = 0.0
var bot_difficulty = "easy"
var bot_brains: Dictionary = {}

func set_difficulty(value: String) -> void:
	bot_difficulty = value if value in ["easy", "normal", "hard"] else "easy"
	bot_brains.clear()

func reset_bot(id: int) -> void:
	bot_brains.erase(id)
	if players.has(id): players[id].charge = 0.0

func set_shot_aim(id: int, direction: Vector3) -> void:
	if players.has(id) and direction.is_finite() and direction.length_squared() > .0001:
		players[id].shot_aim = direction.normalized()

static func bank_height(x: float, z: float) -> float:
	return Arena.bank_height(x,z)

static func road_center_x(z_abs: float) -> float:
	return Arena.road_center_x(z_abs)

static func road_cross_z(x_abs: float) -> float:
	return Arena.road_cross_z(x_abs)

static func road_profile(distance: float) -> float:
	return Arena.road_profile(distance)

static func road_weight(x: float, z: float) -> float:
	return Arena.road_weight(x,z)

static func floor_height(x: float, z: float) -> float:
	return Arena.floor_height(x,z)

static func floor_normal(x: float, z: float) -> Vector3:
	return Arena.floor_normal(x,z)

static func ball_above_arena(position: Vector3) -> bool:
	# Conservative forecast-only broad phase. Check both ends of a substep;
	# below this ceiling use the actual collider solver. The explicit terrain
	# bound stays valid when raised interior routes exceed the corner height.
	var highest = maxf(KICKOFF_Y,maxf(HOOP_Y+2.0,MAX_TERRAIN_HEIGHT+HAZARD_HEIGHT+.34))+BALL_RADIUS
	return position.y>highest and absf(position.x)<HALF_WIDTH-BALL_RADIUS and absf(position.z)<HALF_LENGTH-BALL_RADIUS

static func ball_clear_of_static_colliders(position: Vector3) -> bool:
	# Forecast-only broad phase; false means use ball_step, not a collision.
	# Sweeper bounds cover every rotation, and deck bounds also admit the area
	# beneath them conservatively because one-way contact needs previous height.
	if absf(position.x)>=HALF_WIDTH-BALL_RADIUS or absf(position.z)>=HALF_LENGTH-BALL_RADIUS: return false
	if position.y<=floor_height(position.x,position.z)+BALL_RADIUS: return false
	if absf(position.x)<=KICKOFF_HALF_WIDTH and absf(absf(position.z)-KICKOFF_Z)<=KICKOFF_HALF_DEPTH and position.y<=KICKOFF_Y+BALL_RADIUS: return false
	for target in [NORTH,SOUTH]:
		if absf(position.y-HOOP_Y)<=BALL_RADIUS+RIM_TUBE and Vector2(position.x-target.x,position.z-target.z).length_squared()<=pow(RIM_RADIUS+RIM_TUBE+BALL_RADIUS,2): return false
		var board_z = -BACKBOARD_Z if target.z<0 else BACKBOARD_Z
		if absf(position.x)<=2.6+BALL_RADIUS and position.y>=HOOP_Y-.4-BALL_RADIUS and position.y<=HOOP_Y+2.0+BALL_RADIUS and absf(position.z-board_z)<=BALL_RADIUS+.12: return false
	for center in HAZARDS:
		if Vector2(position.x-center.x,position.z-center.z).length_squared()>pow(HAZARD_RADIUS+.34+BALL_RADIUS,2): continue
		if absf(position.y-floor_height(center.x,center.z)-HAZARD_HEIGHT)<=BALL_RADIUS+.34: return false
	return true

static func hazard_angle(index: int, match_clock: float) -> float:
	return match_clock * HAZARD_SPEED * (1 if index % 2 == 0 else -1) + index * PI * .25

static func hazard_endpoints(index: int, match_clock: float) -> Array[Vector3]:
	var center: Vector3 = HAZARDS[index]
	center.y = floor_height(center.x,center.z) + HAZARD_HEIGHT
	var angle = hazard_angle(index,match_clock)
	var reach = Vector3(cos(angle),0,sin(angle))*HAZARD_RADIUS
	return [center-reach,center+reach]

static func segment_point(point: Vector3, start: Vector3, end: Vector3) -> Vector3:
	var axis = end-start
	return start+axis*clampf((point-start).dot(axis)/maxf(axis.length_squared(),.001),0,1)

static func surface_height(position: Vector3, previous_y: float) -> float:
	# Launch decks are one-way platforms: the court below the hoop stays open.
	if absf(position.x) <= KICKOFF_HALF_WIDTH and absf(absf(position.z)-KICKOFF_Z) <= KICKOFF_HALF_DEPTH and previous_y >= KICKOFF_Y-.02:
		return KICKOFF_Y
	return floor_height(position.x,position.z)

func reset(next_mode: String, setup: Dictionary = {}) -> void:
	mode = next_mode if next_mode in ["coop", "teams", "versus"] else "coop"
	set_difficulty(str(setup.get("bot_difficulty",bot_difficulty)))
	event_clock = 0.0
	recent_events.clear()
	players.clear()
	clear_assist()
	power_pads.clear()
	power_balls.clear()
	team_map.clear()
	match_setup = setup.duplicate(true)
	var ids = range(1, 7 if mode == "coop" else 4)
	if mode == "teams":
		ids = []
		for value in setup.get("active_humans", [1,2,3]):
			var id = int(value)
			if id in [1,2,3] and not ids.has(id):
				ids.append(id)
				team_map[id] = clampi(int(setup.get("teams", {}).get(id, 0 if id < 3 else 1)), 0, 1)
		var next_id = 4
		for side in [0,1]:
			for i in clampi(int(setup.get("bots", {}).get(side, 0)), 0, 3):
				ids.append(next_id)
				team_map[next_id] = side
				next_id += 1
	for id in ids:
		if not team_map.has(id): team_map[id] = id if mode == "versus" else (0 if id <= 3 else 1)
		players[id] = {"pos": Vector3.ZERO, "vel": Vector3.ZERO, "facing": Vector3.FORWARD,
			"move": Vector3.ZERO, "aim": Vector3.FORWARD, "grounded": true, "stun": 0.0,
			"guard": 0.0, "dive": 0.0, "cooldown": 0.0, "jump_count": 0, "dunk": 0.0,
			"charge": 0.0, "pad_cooldown": 0.0, "dunk_start": Vector3.ZERO, "dunk_target": NORTH, "team":team_map[id],
			"hype":0.0,"power":["giant","pad","blast"][(id-1)%3],"giant":0.0,"catch_time":0.0,"request_time":0.0}
	scores = {1: 0, 2: 0, 3: 0} if mode == "versus" else {0: 0, 1: 0}
	ball = {"pos": Vector3(0, 1.5, 0), "vel": Vector3.ZERO, "owner": 0,
		"last_touch": 0, "lock": 0.0, "pass_target": 0}
	clock = 0.0
	time_left = 180.0 if mode == "versus" else 300.0
	winner = -1
	reset_time = 3.0
	celebration_time = 0.0
	ball.lock = 3.0
	bounce_cooldown = 0.0
	grabs = 0
	throws = 0
	dunks = 0
	tackles = 0
	baskets = 0
	spawn_players()
	emit("tip", "GO", Vector3.ZERO)

func spawn_players() -> void:
	for id in players:
		var p = players[id]
		var teammates = []
		for other in players:
			if team(other) == team(id): teammates.append(other)
		p.pos = Vector3((teammates.find(id) - (teammates.size()-1)*0.5) * 5, KICKOFF_Y, KICKOFF_Z if team(id) == 0 else -KICKOFF_Z)
		if mode == "versus":
			p.pos = [Vector3(-4, 0, 3), Vector3(0, 0, -4), Vector3(4, 0, 3)][id - 1]
		p.vel = Vector3.ZERO
		if mode == "versus": p.pos.y = floor_height(p.pos.x,p.pos.z)
		p.move = Vector3.ZERO
		p.facing = Vector3.BACK if mode != "versus" and team(id) == 1 else Vector3.FORWARD
		p.aim = p.facing
		p.stun = 0.0
		p.guard = 0.65
		p.dive = 0.0
		p.dunk = 0.0
		p.grounded = true
		p.jump_count = 0
		p.cooldown = 0.0
		p.pad_cooldown = 0.0
		reset_movement_state(p)

func reset_movement_state(p: Dictionary) -> void:
	p.shot_aim = Vector3.ZERO
	p.knockback_time = 0.0
	p.slide_time = 0.0
	p.slide_kind = ""
	p.possession_since = -1.0
	p.hazard_cooldown = 0.0
	p.boost_time = 0.0
	p.boost_speed = BOOST_SPEED
	p.boost_direction = Vector3.ZERO
	p.jump_buffer = 0.0
	p.dunk_buffer = 0.0
	p.coyote = 0.1
	p.catch_time = 0.0

func launch_kickoff() -> void:
	if mode == "versus": return
	for id in players:
		var p = players[id]
		# Aim each lane into midfield without forcing the player's camera or input.
		var direction = Vector3(-p.pos.x*.3,0,-p.pos.z).normalized()
		p.vel = direction*KICKOFF_SPEED + Vector3.UP*KICKOFF_UP
		p.boost_direction = direction
		p.boost_speed = KICKOFF_SPEED
		p.boost_time = 2.5
		p.grounded = false
		p.jump_count = 1
		p.coyote = 0.0
		p.pad_cooldown = .8

func booster_direction(pad: Vector3, id: int) -> Vector3:
	return Vector3(-signf(pad.x)*.35,0,1 if mode != "versus" and team(id) == 1 else -1).normalized()

func team(id: int) -> int:
	return int(team_map.get(id, players.get(id, {}).get("team", id if mode == "versus" else (0 if id <= 3 else 1))))

func join_spawn_position(side: int) -> Vector3:
	var on_deck = reset_time > 0 and celebration_time <= 0
	var z = (KICKOFF_Z if on_deck else 24.0) * (1 if side == 0 else -1)
	for x in [0.0,-5.0,5.0]:
		var position = Vector3(x,KICKOFF_Y if on_deck else floor_height(x,z),z)
		var occupied = false
		for id in players:
			if players[id].pos.distance_to(position) < 2: occupied = true
		if not occupied: return position
	return Vector3(5,KICKOFF_Y if on_deck else floor_height(5,z),z)

func add_human(id: int, side: int) -> bool:
	if not id in [1,2,3] or not side in [0,1]: return false
	if players.has(id):
		reset_bot(id)
		return true
	var count = 0
	var replacement = 0
	for other in players:
		if team(other) == side:
			count += 1
			if other >= 4: replacement = other
	if count >= 3 and replacement == 0: return false
	if replacement:
		reset_bot(replacement)
		players[id] = players[replacement].duplicate(true)
		players.erase(replacement)
		team_map.erase(replacement)
		if ball.owner == replacement: ball.owner = id
		if ball.last_touch == replacement: ball.last_touch = id
		if ball.pass_target == replacement: ball.pass_target = id
		if assist_player == replacement: assist_player = id
		if assist_receiver == replacement: assist_receiver = id
		for missile in power_balls:
			if missile.owner == replacement: missile.owner = id
			if missile.target == replacement: missile.target = id
		for pad in power_pads:
			if pad.owner == replacement: pad.owner = id
	else:
		var position = join_spawn_position(side)
		players[id] = {"pos":position,"vel":Vector3.ZERO,"facing":Vector3.FORWARD if side == 0 else Vector3.BACK,
			"move":Vector3.ZERO,"aim":Vector3.FORWARD if side == 0 else Vector3.BACK,"grounded":true,"stun":0.0,"guard":.65,
			"dive":0.0,"cooldown":0.0,"jump_count":0,"dunk":0.0,"charge":0.0,"pad_cooldown":0.0,"dunk_start":position,"dunk_target":NORTH,
			"hype":0.0,"power":["giant","pad","blast"][(id-1)%3],"giant":0.0,"catch_time":0.0,"request_time":0.0}
	team_map[id] = side
	players[id].team = side
	reset_bot(id)
	if not players[id].has("boost_time"): reset_movement_state(players[id])
	return true

func ensure_balanced_teams() -> void:
	if mode != "teams": return
	var counts = {0:0,1:0}
	for id in players: counts[team(id)] += 1
	var target = mini(3,maxi(counts[0],counts[1]))
	for side in [0,1]:
		while counts[side] < target:
			var id = 4
			while players.has(id): id += 1
			var position = join_spawn_position(side)
			var aim = Vector3.FORWARD if side==0 else Vector3.BACK
			players[id] = {"pos":position,"vel":Vector3.ZERO,"facing":aim,"move":Vector3.ZERO,"aim":aim,
				"grounded":true,"stun":0.0,"guard":.65,"dive":0.0,"cooldown":0.0,"jump_count":0,
				"dunk":0.0,"charge":0.0,"pad_cooldown":0.0,"dunk_start":position,"dunk_target":NORTH,
				"hype":0.0,"power":["giant","pad","blast"][(id-1)%3],"giant":0.0,"catch_time":0.0,"request_time":0.0,"team":side}
			team_map[id] = side
			reset_movement_state(players[id])
			counts[side] += 1

func hoop(id: int) -> Vector3:
	return SOUTH if mode != "versus" and team(id) == 1 else NORTH

func emit(kind: String, text: String, at: Vector3, id: int = 0) -> void:
	event_id += 1
	event_kind = kind
	message = text
	event_pos = at
	event_player = id
	recent_events.append([event_id,kind,at,id,event_clock])
	prune_events()

func prune_events() -> void:
	while not recent_events.is_empty() and (recent_events.size() > RECENT_EVENT_LIMIT or event_clock - float(recent_events[0][EVENT_CLOCK]) > RECENT_EVENT_TTL):
		recent_events.pop_front()

func move_input(id: int, direction: Vector3, aim: Vector3) -> void:
	if not players.has(id) or not direction.is_finite() or not aim.is_finite(): return
	players[id].move = Vector3(direction.x, 0, direction.z).limit_length(1.0)
	var horizontal = Vector3(aim.x, 0, aim.z)
	if horizontal.length() > 0.01 and players[id].dunk <= 0: players[id].aim = horizontal.normalized()

func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

static func ground_velocity(velocity: Vector3, intent: Vector3, speed: float, dt: float) -> Vector3:
	# Traction responds immediately; speed and opposing intent determine the skid.
	# One horizontal vector keeps a diagonal cut equivalent to a cardinal cut.
	var horizontal = Vector3(velocity.x,0,velocity.z)
	var movement = Vector3(intent.x,0,intent.z).limit_length(1.0)
	var acceleration = BRAKE
	if movement.length_squared() > .0001:
		var running = horizontal.length()
		acceleration = lerpf(START_ACCEL,ACCEL,clampf(running/maxf(speed,.01),0,1))
		if running > 1.0:
			var alignment = horizontal.normalized().dot(movement.normalized())
			var hard_turn = clampf((.5-alignment)/1.5,0,1)
			acceleration = lerpf(acceleration,TURN_ACCEL,hard_turn)
	horizontal = horizontal.move_toward(movement*speed,acceleration*maxf(0,dt))
	return Vector3(horizontal.x,velocity.y,horizontal.z)

static func recovery_velocity(player: Dictionary, dt: float) -> Vector3:
	# Isotropic friction prevents diagonal impacts stopping earlier than axial ones.
	var velocity: Vector3 = player.vel
	var horizontal = Vector3(velocity.x,0,velocity.z)
	horizontal = horizontal.move_toward(Vector3.ZERO,(8.0 if player.grounded else 2.8)*maxf(0,dt))
	return Vector3(horizontal.x,velocity.y,horizontal.z)

static func movement_velocity(player: Dictionary, carrying: bool, dt: float) -> Vector3:
	# The live motor and release-time receiver forecast share one velocity rule.
	var velocity: Vector3 = player.vel
	var speed = SPEED * (.94 if carrying else 1.0) * (1.12 if player.giant > 0 else 1.0)
	if player.get("slide_time",0.0) > 0 and player.boost_time <= 0:
		# Regain traction progressively after the committed dive or knockdown.
		# Input can steer, but cannot instantly cancel the remaining momentum.
		var recovery = 1.0-clampf(float(player.slide_time)/SLIDE_RECOVERY,0,1)
		var traction = lerpf(SLIDE_TRACTION,BRAKE,recovery)
		var horizontal = Vector3(velocity.x,0,velocity.z)
		horizontal = horizontal.move_toward(player.move*speed,traction*maxf(0,dt))
		return Vector3(horizontal.x,velocity.y,horizontal.z)
	if player.grounded and player.boost_time <= 0:
		return ground_velocity(velocity,player.move,speed,dt)
	var target: Vector3 = player.move*speed
	var acceleration = AIR_ACCEL if player.move.length()>0 else AIR_DRAG
	if player.boost_time > 0:
		target=(player.boost_direction*.8+player.move*.35).normalized()*float(player.get("boost_speed",BOOST_SPEED))
		acceleration=AIR_ACCEL
	elif Vector2(velocity.x,velocity.z).length()>speed and player.move.dot(Vector3(velocity.x,0,velocity.z).normalized())>.7:
		target=player.move.normalized()*maxf(speed,Vector2(velocity.x,velocity.z).length()-AIR_DRAG*dt)
	velocity.x=move_toward(velocity.x,target.x,acceleration*dt)
	velocity.z=move_toward(velocity.z,target.z,acceleration*dt)
	return velocity

func pass_receive_position(id: int, duration: float) -> Vector3:
	# Forecast the current movement intent, traction and jump for the full flight.
	# Future input changes, tackles and newly encountered launch pads can still
	# beat the pass. Nothing changes the ball's direction after it leaves the hand.
	var forecast: Dictionary = players[id].duplicate(false)
	var remaining = clampf(duration,0,2.6)
	while remaining > .00001:
		var dt = minf(remaining,1.0/60)
		remaining -= dt
		forecast.boost_time = maxf(0,forecast.boost_time-dt)
		forecast.giant = maxf(0,forecast.giant-dt)
		forecast.slide_time = maxf(0,forecast.get("slide_time",0.0)-dt)
		forecast.stun = maxf(0,forecast.stun-dt)
		if forecast.dive>0: forecast.dive=maxf(0,forecast.dive-dt)
		elif forecast.stun > 0: forecast.vel=recovery_velocity(forecast,dt)
		else: forecast.vel=movement_velocity(forecast,false,dt)
		forecast.vel.y -= PLAYER_GRAVITY*dt
		var previous_y: float = forecast.pos.y
		forecast.pos += forecast.vel*dt
		forecast.pos.x = clampf(forecast.pos.x,-HALF_WIDTH+.5,HALF_WIDTH-.5)
		forecast.pos.z = clampf(forecast.pos.z,-HALF_LENGTH+.5,HALF_LENGTH-.5)
		var ground = surface_height(forecast.pos,previous_y)
		if forecast.pos.y<=ground or (forecast.grounded and forecast.vel.y<=0 and absf(forecast.pos.y-ground)<.4):
			forecast.pos.y=ground
			forecast.vel.y=0
			forecast.grounded=true
		else: forecast.grounded=false
	return forecast.pos+Vector3.UP*1.25

func can_dunk(id: int) -> bool:
	return players.has(id) and winner < 0 and reset_time <= 0 and players[id].stun <= 0 and players[id].dunk <= 0 and ball.owner == id and not players[id].grounded and players[id].pos.y > floor_height(players[id].pos.x,players[id].pos.z)+0.65 and flat_distance(players[id].pos, hoop(id)) < DUNK_RANGE

func can_catch(id: int) -> bool:
	return players.has(id) and winner < 0 and reset_time <= 0 and ball.owner == 0 and ball.lock <= 0 and players[id].stun <= 0 and players[id].dunk <= 0 and ball.pos.distance_to(players[id].pos + Vector3(0,1.1,0)) < 2.35

func jump(id: int) -> void:
	var p = players[id]
	p.vel.y = JUMP_SPEED if p.jump_count == 0 else maxf(DOUBLE_JUMP_SPEED,p.vel.y+2.2)
	p.jump_count += 1
	p.jump_buffer = 0.0
	p.coyote = 0.0
	p.grounded = false
	emit("jump", "", p.pos, id)

static func launch_velocity(origin: Vector3, target: Vector3, duration: float) -> Vector3:
	var t = maxf(0.1, duration)
	return (target - origin) / t + Vector3(0, BALL_GRAVITY * t * 0.5, 0)

func hand_position(id: int) -> Vector3:
	var size = 1.8 if players[id].get("giant",0) > 0 else 1.0
	var forward_reach = .7*size
	var hold_height = 1.95*size
	var direction: Vector3 = players[id].aim
	if players[id].dunk>0:
		direction = players[id].get("dunk_direction",direction)
		var t=1.0-players[id].dunk/float(players[id].get("dunk_duration",DUNK_DURATION))
		var reach = smoothstep(0,DUNK_REACH_PHASE,t)
		forward_reach=lerpf(forward_reach,float(players[id].get("dunk_reach",forward_reach)),reach)
		hold_height=lerpf(hold_height,DUNK_HOLD_HEIGHT*size,reach)
	return players[id].pos + Vector3(0, hold_height, 0) + direction * forward_reach

static func shot_flight_time(origin: Vector3, landing: Vector3, power: float) -> float:
	# Longer attempts need a genuine lob with enough descent to clear the rim.
	var distance = Vector2(landing.x-origin.x,landing.z-origin.z).length()
	var apex = maxf(origin.y,landing.y)+2.0+distance*.12+(1.0-clampf(power,0,1))*2.0
	return sqrt(2.0*(apex-origin.y)/BALL_GRAVITY)+sqrt(2.0*(apex-landing.y)/BALL_GRAVITY)

func throw_velocity(id: int, charge: float) -> Vector3:
	# Ordinary shots never consult a basket, target, distance or alignment cone.
	# The physical launch keeps the player's chosen yaw/elevation at every charge.
	var direction: Vector3 = players[id].get("shot_aim",Vector3.ZERO)
	if direction.length_squared() < .0001:
		var forward: Vector3 = players[id].aim
		direction = forward*cos(deg_to_rad(48))+Vector3.UP*sin(deg_to_rad(48))
	var power = clampf(charge,0.0,1.0)
	var overcharge = maxf(0,charge-1.0)
	return direction.normalized()*(lerpf(12.0,46.0,power)+overcharge*11.0)

func action(id: int, command: String, charge: float = 0.5) -> void:
	if not players.has(id) or winner >= 0 or reset_time > 0 or not is_finite(charge): return
	var p = players[id]
	if p.stun > 0 or p.dunk > 0: return
	match command:
		"request_pass":
			p.request_time = 2.5
			emit("pass_request", "PASS", p.pos, id)
		"catch":
			if ball.owner == 0:
				p.catch_time = .32
				action(id, "grab")
		"hype":
			if p.hype < 100: return
			p.hype = 0.0
			match p.power:
				"giant": p.giant = 7.0
				"pad":
					var pad = p.pos + p.aim * 1.8
					pad.x = clampf(pad.x,-HALF_WIDTH+1.3,HALF_WIDTH-1.3)
					pad.z = clampf(pad.z,-HALF_LENGTH+1.3,HALF_LENGTH-1.3)
					pad.y = floor_height(pad.x,pad.z)
					power_pads.append({"pos":pad,"time":14.0,"owner":id})
				"blast":
					var target_id = 0
					var best = INF
					for other in players:
						if team(other) == team(id): continue
						var distance = p.pos.distance_to(players[other].pos)
						if distance < best:
							best = distance
							target_id = other
					if target_id:
						power_serial += 1
						power_balls.append({"id":power_serial,"pos":p.pos+Vector3.UP*1.4,"vel":p.aim*15,"target":target_id,"owner":id,"time":4.0})
			emit("power", "", p.pos, id)
		"jump":
			if p.jump_count >= 2:
				p.jump_buffer = .14
				return
			jump(id)
		"grab":
			if can_catch(id):
				secure_ball(id)
		"throw":
			if ball.owner != id: return
			ball.pos = hand_position(id)
			ball.vel = throw_velocity(id, charge)
			ball.owner = 0
			ball.last_touch = id
			ball.lock = 0.22
			ball.pass_target = 0
			throws += 1
			emit("throw", "LET IT FLY", ball.pos, id)
		"dunk":
			if can_dunk(id): begin_dunk(id)
			elif ball.owner == id and flat_distance(p.pos,hoop(id)) < DUNK_RANGE: p.dunk_buffer = .22
		"pass":
			if ball.owner != id or mode == "versus": return
			var target_id = pass_target(id)
			if target_id:
				var nearest = p.pos.distance_to(players[target_id].pos)
				ball.pos = hand_position(id)
				var flight = clampf(nearest / 18, 0.3, 2.6)
				ball.vel = launch_velocity(ball.pos, pass_receive_position(target_id,flight), flight)
				ball.owner = 0
				ball.last_touch = id
				ball.pass_target = target_id
				ball.lock = 0.12
				p.bot_pass_after = clock + .8
				throws += 1
				emit("pass", "PASS", ball.pos, id)
		"tackle":
			if p.cooldown > 0: return
			p.dive = 0.34
			p.slide_time = .85
			p.slide_kind = "dive"
			p.cooldown = 0.85
			var direction = p.move.normalized() if p.move.length() > 0.1 else p.aim
			p.facing = direction
			p.vel.x = direction.x * 15
			p.vel.z = direction.z * 15
			emit("dive", "DIVE!", p.pos, id)

func begin_dunk(id: int) -> void:
	var p = players[id]
	p.dunk_buffer = 0.0
	p.boost_time = 0.0
	p.dunk_start = p.pos
	var reach = hoop(id)-p.pos
	reach.y = 0
	if reach.length()>.1: p.aim = reach.normalized()
	# The body target and hand release share one axis for the whole animation.
	# Camera movement or delayed movement/action input must not swivel the ball
	# away from a body path that has already committed to this side of the rim.
	p.dunk_direction = p.aim
	p.facing = p.aim
	var size = 1.8 if p.giant > 0 else 1.0
	# Align the carried ball with the release point so there is no hand-to-rim snap.
	var body_offset=RIM_RADIUS+RIM_TUBE+.58*size
	p.dunk_reach=body_offset-.4
	p.dunk_target = hoop(id)-p.aim*body_offset + Vector3.UP*(.65-DUNK_HOLD_HEIGHT*size)
	p.dunk_target.y=maxf(p.dunk_target.y,floor_height(p.dunk_target.x,p.dunk_target.z)+.24)
	p.dunk_velocity = p.vel.limit_length(20.0)
	p.dunk_duration = clampf(p.pos.distance_to(p.dunk_target)/12.0+.5,DUNK_DURATION,1.35)
	p.dunk = p.dunk_duration
	p.cooldown = 0.65
	dunks += 1
	emit("dunk", "DUNK", hoop(id), id)

func advance_dunk(id: int, dt: float) -> void:
	var p = players[id]
	p.aim = p.get("dunk_direction",p.aim)
	p.facing = p.aim
	var duration = float(p.get("dunk_duration",DUNK_DURATION))
	p.dunk = maxf(0,p.dunk-dt)
	var t = 1.0-p.dunk/duration
	var previous: Vector3 = p.pos
	var u = clampf(t/DUNK_REACH_PHASE,0,1)
	var tangent: Vector3 = p.get("dunk_velocity",Vector3.ZERO)*duration*DUNK_REACH_PHASE
	# Cubic reach starts in the incoming direction and eases into the rim hang.
	p.pos = (2*u*u*u-3*u*u+1)*p.dunk_start + (u*u*u-2*u*u+u)*tangent + (-2*u*u*u+3*u*u)*p.dunk_target
	if t>DUNK_REACH_PHASE and t<DUNK_RELEASE_PHASE: p.pos.y += sin((t-DUNK_REACH_PHASE)/(DUNK_RELEASE_PHASE-DUNK_REACH_PHASE)*PI)*.12
	if t>=DUNK_RELEASE_PHASE:
		p.pos.y -= smoothstep(DUNK_RELEASE_PHASE,1.0,t)*.22
	p.pos.y=maxf(p.pos.y,floor_height(p.pos.x,p.pos.z)+.02)
	if t>=DUNK_RELEASE_PHASE:
		if ball.owner == id:
			ball.pos = hand_position(id)
			ball.owner = 0
			ball.last_touch = id
			ball.vel = Vector3(0,-8,0)
			ball.lock = .5
	p.vel = (p.pos-previous)/maxf(dt,.001)
	if p.dunk<=0: p.vel = Vector3.DOWN*2.0

func celebrate(dt: float) -> void:
	celebration_time = maxf(0,celebration_time-dt)
	reset_time = maxf(0,reset_time-dt)
	for id in players:
		var p = players[id]
		if p.dunk>0:
			advance_dunk(id,dt)
			continue
		p.vel.x = move_toward(p.vel.x,0,16*dt)
		p.vel.z = move_toward(p.vel.z,0,16*dt)
		p.vel.y -= PLAYER_GRAVITY*dt
		var previous_y: float = p.pos.y
		p.pos += p.vel*dt
		p.pos.x = clampf(p.pos.x,-HALF_WIDTH+.5,HALF_WIDTH-.5)
		p.pos.z = clampf(p.pos.z,-HALF_LENGTH+.5,HALF_LENGTH-.5)
		var floor_y = surface_height(p.pos,previous_y)
		if p.pos.y<=floor_y:
			p.pos.y=floor_y
			p.vel=Vector3.ZERO
			p.grounded=true
	ball.vel.y-=BALL_GRAVITY*dt
	var previous_ball_y: float = ball.pos.y
	ball.pos+=ball.vel*dt
	for axis in [0,2]:
		var limit = (HALF_WIDTH if axis==0 else HALF_LENGTH)-BALL_RADIUS
		if absf(ball.pos[axis])>limit:
			ball.pos[axis]=clampf(ball.pos[axis],-limit,limit)
			ball.vel[axis]*=-.6
	var ball_floor=surface_height(ball.pos-Vector3.UP*BALL_RADIUS,previous_ball_y-BALL_RADIUS)+BALL_RADIUS
	if ball.pos.y<ball_floor:
		ball.pos.y=ball_floor
		ball.vel.y=absf(ball.vel.y)*.45
	if celebration_time<=0 and winner<0:
		ball.pos=Vector3(0,2,0)
		ball.vel=Vector3.ZERO
		ball.last_touch=0
		ball.lock=reset_time
		spawn_players()
		power_pads.clear()
		power_balls.clear()

func secure_ball(id: int) -> void:
	# Both catch paths complete the same transaction before clearing pass intent.
	var p = players[id]
	var passer = int(ball.last_touch)
	var received_pass = ball.pass_target == id and passer != id and players.has(passer) and team(passer) == team(id) and mode != "versus"
	if received_pass: players[passer].hype = minf(100,players[passer].hype+10)
	clear_assist()
	if received_pass:
		assist_player = passer
		assist_receiver = id
		assist_until = clock+8.0
	ball.owner = id
	ball.pos = hand_position(id)
	ball.last_touch = id
	ball.pass_target = 0
	ball.vel = Vector3.ZERO
	p.possession_since = clock
	p.catch_time = 0.0
	p.request_time = 0.0
	p.hype = minf(100,p.hype+4)
	# Decision cooldown only: an explicit human pass remains immediately usable.
	p.bot_pass_after = maxf(p.get("bot_pass_after",0),clock+1.0)
	grabs += 1
	emit("grab", "NICE CATCH" if received_pass else "BALL SECURED", p.pos, id)

func pass_candidate(id: int, other: int) -> bool:
	return other != id and players.has(other) and team(other) == team(id) and players[other].stun <= 0 and players[other].dunk <= 0 and players[id].pos.distance_to(players[other].pos) <= PASS_RANGE

func pass_target(id: int, direction: Vector3 = Vector3.ZERO) -> int:
	if not players.has(id) or mode == "versus": return 0
	var aim = players[id].aim if direction.length_squared()<.01 else direction.normalized()
	var best = 0
	var best_score = -INF
	for other in players:
		if not pass_candidate(id,other): continue
		var offset = players[other].pos - players[id].pos
		var flat = Vector3(offset.x,0,offset.z)
		var alignment = aim.dot(flat.normalized())
		if alignment < PASS_CONE_DOT: continue
		var score = alignment * 4.0 - flat.length() * 0.025
		if score > best_score:
			best = other
			best_score = score
	return best

func step(delta: float) -> void:
	var dt = minf(delta, 0.05)
	# Transient audio must age out even while the match clock is frozen.
	event_clock += maxf(0.0,dt)
	prune_events()
	if celebration_time>0:
		celebrate(dt)
		return
	if winner >= 0: return
	clock += dt
	bounce_cooldown = maxf(0, bounce_cooldown - dt)
	ball.lock = maxf(0, ball.lock - dt)
	if reset_time > 0:
		reset_time = maxf(0, reset_time - dt)
		if reset_time <= 0:
			launch_kickoff()
			emit("tip", "GO", ball.pos)
		return
	time_left = maxf(0, time_left - dt)
	for id in players:
		var p = players[id]
		for key in ["stun", "guard", "cooldown", "pad_cooldown", "giant", "catch_time", "request_time", "boost_time", "jump_buffer", "dunk_buffer", "hazard_cooldown", "knockback_time", "slide_time"]:
			# A held ball must not shrink below the rim midway through its dunk.
			if key=="giant" and p.dunk>0: continue
			p[key] = maxf(0, p.get(key,0.0) - dt)
		p.coyote = .1 if p.grounded else maxf(0,p.get("coyote",0.0)-dt)
		if not p.grounded and p.coyote <= 0 and p.jump_count == 0: p.jump_count = 1
		if p.dunk > 0:
			advance_dunk(id,dt)
			continue
		if p.dive > 0:
			p.dive = maxf(0, p.dive - dt)
		elif p.stun <= 0:
			p.vel = movement_velocity(p,ball.owner==id,dt)
			if ball.owner == id: p.facing = p.aim
			elif p.move.length() > 0.1: p.facing = p.move.normalized()
		else:
			p.vel = recovery_velocity(p,dt)
		p.vel.y -= PLAYER_GRAVITY * dt
		var previous_y: float = p.pos.y
		p.pos += p.vel * dt
		p.pos.x = clampf(p.pos.x, -HALF_WIDTH+.5, HALF_WIDTH-.5)
		p.pos.z = clampf(p.pos.z, -HALF_LENGTH+.5, HALF_LENGTH-.5)
		var ground = surface_height(p.pos,previous_y)
		if p.pos.y <= ground or (p.grounded and p.vel.y <= 0 and absf(p.pos.y-ground) < .4):
			p.pos.y = ground
			p.vel.y = 0
			p.grounded = true
			p.jump_count = 0
			var pads = PADS.duplicate()
			for extra in power_pads: pads.append(extra.pos)
			for pad in pads:
				if p.pad_cooldown <= 0 and flat_distance(p.pos,pad) < 1.25:
					p.boost_direction = booster_direction(pad,id)
					p.boost_speed = BOOST_SPEED
					p.boost_time = 1.15
					p.vel = p.boost_direction*BOOST_SPEED + Vector3.UP*LAUNCH_SPEED
					p.grounded = false
					p.jump_count = 1
					p.pad_cooldown = 0.8
					emit("jump", "", p.pos, id)
			if p.grounded:
				for pad in SPEED_PADS:
					if p.pad_cooldown <= 0 and flat_distance(p.pos,pad) < 1.6:
						p.boost_direction = booster_direction(pad,id)
						p.boost_speed = BOOST_SPEED
						p.boost_time = 1.0
						p.vel = p.boost_direction*BOOST_SPEED
						p.pad_cooldown = .8
						emit("boost", "", p.pos, id)
				if p.jump_buffer > 0 and p.stun <= 0: jump(id)
		else: p.grounded = false
		if p.dunk_buffer > 0 and can_dunk(id): begin_dunk(id)
	resolve_players()
	resolve_hazards()
	step_powers(dt)
	for id in players:
		if players[id].catch_time > 0 and ball.owner == 0: action(id,"grab")
	if ball.owner > 0:
		ball.pos = hand_position(ball.owner)
		ball.vel = players[ball.owner].vel
	else:
		# Substeps reduce tunnelling through the rim and backboards.
		for i in 3:
			ball_step(dt / 3.0)
			if reset_time > 0 or winner >= 0 or ball.owner > 0: break
	if time_left <= 0: check_clock_winner()

func step_powers(dt: float) -> void:
	for i in range(power_pads.size()-1,-1,-1):
		power_pads[i].time -= dt
		if power_pads[i].time <= 0: power_pads.remove_at(i)
	for i in range(power_balls.size()-1,-1,-1):
		var missile = power_balls[i]
		missile.time -= dt
		if missile.time <= 0 or not players.has(missile.target) or not players.has(missile.owner):
			power_balls.remove_at(i)
			continue
		var target = players[missile.target].pos + Vector3.UP*.9
		var direction = (target - missile.pos).normalized()
		missile.vel = missile.vel.lerp(direction * 18, 1.0-exp(-6*dt))
		missile.pos += missile.vel * dt
		if missile.pos.distance_to(target) < 1.1:
			if players[missile.target].guard <= 0: hit(missile.owner, missile.target)
			emit("power", "", missile.pos, missile.owner)
			power_balls.remove_at(i)

func resolve_hazards() -> void:
	# Shared match clock drives visible padded sweepers and authoritative contact.
	for index in HAZARDS.size():
		var ends = hazard_endpoints(index,clock)
		for id in players:
			var p = players[id]
			if p.get("hazard_cooldown",0)>0 or p.dunk>0 or p.giant>0: continue
			if p.pos.y>ends[0].y+.34 or p.pos.y+1.7<ends[0].y-.34: continue
			var center = Vector3(p.pos.x,ends[0].y,p.pos.z)
			var contact = segment_point(center,ends[0],ends[1])
			if center.distance_to(contact)>.94: continue
			var radial = contact-HAZARDS[index]
			radial.y = 0
			var tangent = Vector3(-radial.z,0,radial.x)*(1 if index%2==0 else -1)
			if tangent.length_squared()<.01: tangent = Vector3.RIGHT
			var direction = tangent.normalized()
			p.vel = direction*8.0+Vector3.UP*4.5
			p.stun = .35
			p.slide_time = .85
			p.slide_kind = "impact"
			p.dive = 0.0
			p.boost_time = 0.0
			p.grounded = false
			p.jump_count = maxi(1,p.jump_count)
			p.hazard_cooldown = 1.1
			if ball.owner==id:
				clear_assist()
				ball.pos = hand_position(id)
				ball.owner = 0
				ball.last_touch = id
				ball.pass_target = 0
				ball.vel = direction*7.0+Vector3.UP*6
				ball.lock = .22
			emit("hazard","",contact,id)

func resolve_hazard_ball() -> void:
	for index in HAZARDS.size():
		var ends = hazard_endpoints(index,clock)
		var contact = segment_point(ball.pos,ends[0],ends[1])
		var offset: Vector3 = ball.pos-contact
		var distance = offset.length()
		if distance>=BALL_RADIUS+.34: continue
		var normal = offset/distance if distance>.001 else Vector3.UP
		var radius: Vector3 = contact-HAZARDS[index]
		var surface_velocity = Vector3(-radius.z,0,radius.x)*HAZARD_SPEED*(1 if index%2==0 else -1)
		ball.pos = contact+normal*(BALL_RADIUS+.34)
		var relative: Vector3 = ball.vel-surface_velocity
		if relative.dot(normal)<0:
			ball.vel = relative.bounce(normal)*.75+surface_velocity
			bounce("BANK IT")

func resolve_players() -> void:
	for id in players:
		for other in players:
			if other <= id: continue
			var p = players[id]
			var q = players[other]
			if absf(p.pos.y - q.pos.y) > 1.5: continue
			var gap = Vector3(q.pos.x - p.pos.x, 0, q.pos.z - p.pos.z)
			var length = gap.length()
			var axis = gap / length if length > 0.001 else Vector3.RIGHT
			var contact = 1.75 if p.giant > 0 or q.giant > 0 else 1.32
			if length < contact and team(id) != team(other):
				# Resolve both intents before mutating either actor. A head-on clash
				# cannot award its winner according to dictionary/player-ID order.
				var p_hits = p.dive > 0 and p.stun <= 0 and q.guard <= 0 and p.facing.dot(axis) >= 0
				var q_hits = q.dive > 0 and q.stun <= 0 and p.guard <= 0 and q.facing.dot(-axis) >= 0
				if p_hits: hit(id, other)
				if q_hits: hit(other, id)
			if length < 1.03 and p.dunk <= 0 and q.dunk <= 0:
				# Soft body contact transfers momentum; separation alone let players
				# run through one another without any sense of weight or pressure.
				if p.stun <= 0 and q.stun <= 0 and p.dive <= 0 and q.dive <= 0:
					var closing = (p.vel-q.vel).dot(axis)
					if closing > 0:
						var inverse_p = .4 if p.giant > 0 else 1.0
						var inverse_q = .4 if q.giant > 0 else 1.0
						var impulse = minf(closing,18.0)*1.12/(inverse_p+inverse_q)
						p.vel -= axis*impulse*inverse_p
						q.vel += axis*impulse*inverse_q
				var shift = axis * (1.03 - length) * 0.5
				p.pos -= shift
				q.pos += shift
				p.pos.x = clampf(p.pos.x, -HALF_WIDTH+.5, HALF_WIDTH-.5)
				q.pos.x = clampf(q.pos.x, -HALF_WIDTH+.5, HALF_WIDTH-.5)
				p.pos.z = clampf(p.pos.z, -HALF_LENGTH+.5, HALF_LENGTH-.5)
				q.pos.z = clampf(q.pos.z, -HALF_LENGTH+.5, HALF_LENGTH-.5)

func hit(attacker: int, victim: int) -> void:
	var p = players[attacker]
	var q = players[victim]
	var dropped_ball = ball.owner == victim
	# Sample before cancelling a dunk: its live hand pose can be above the rim.
	var release = hand_position(victim) if dropped_ball else Vector3.ZERO
	var carrier_velocity: Vector3 = q.vel
	var direction = Vector3(q.pos.x-p.pos.x,0,q.pos.z-p.pos.z).normalized()
	if direction.length_squared() < .01: direction = p.facing
	q.stun = .65
	q.knockback_time = .65
	q.slide_time = 1.15
	q.slide_kind = "impact"
	q.guard = 1.4
	q.dunk = 0.0
	q.dive = 0.0
	q.boost_time = 0.0
	q.dunk_buffer = 0.0
	q.jump_buffer = 0.0
	q.charge = 0.0
	q.vel = direction * 11.5 + Vector3(0, 5.2, 0)
	q.grounded = false
	p.dive = 0.0
	if dropped_ball:
		clear_assist()
		ball.owner = 0
		ball.last_touch = attacker
		ball.pos = release
		ball.vel = direction * 8 + carrier_velocity*.20 + Vector3(0, 7, 0)
		ball.lock = 0.22
		ball.pass_target = 0
	tackles += 1
	p.hype = minf(100,p.hype+16)
	emit("tackle", "BALL LOOSE" if dropped_ball else "TACKLE", q.pos + Vector3(0, 0.9, 0), attacker)

func ball_step(dt: float) -> void:
	var previous = ball.pos
	ball.vel.y -= BALL_GRAVITY * dt
	ball.pos += ball.vel * dt
	resolve_hazard_ball()
	for id in players:
		if players[id].catch_time > 0 and can_catch(id):
			action(id,"grab")
			return
	for target in [NORTH] if mode == "versus" else [NORTH, SOUTH]:
		if previous.y > HOOP_Y and ball.pos.y <= HOOP_Y and ball.vel.y < 0:
			var t = (previous.y - HOOP_Y) / (previous.y - ball.pos.y)
			var crossing = previous.lerp(ball.pos, t)
			if flat_distance(crossing, target) < RIM_RADIUS - RIM_TUBE - BALL_RADIUS and ball.last_touch > 0:
				score_goal(target)
				return
		# Torus rim, whose circle lies horizontally in the XZ plane.
		var offset = ball.pos - target
		var flat = Vector3(offset.x, 0, offset.z)
		var radial = flat.length()
		if radial > 0.01:
			var nearest = target + flat / radial * RIM_RADIUS
			var difference = ball.pos - nearest
			var distance = difference.length()
			if distance < BALL_RADIUS + RIM_TUBE and distance > 0.001:
				var n = difference / distance
				ball.pos = nearest + n * (BALL_RADIUS + RIM_TUBE)
				if ball.vel.dot(n) < 0:
					ball.vel = ball.vel.bounce(n) * 0.78
					bounce("RIM RATTLE")
		# Padded solid backboard plane (both faces).
		var board_z = -BACKBOARD_Z if target.z < 0 else BACKBOARD_Z
		if absf(ball.pos.x) < 2.6 + BALL_RADIUS and ball.pos.y > HOOP_Y-.4 - BALL_RADIUS and ball.pos.y < HOOP_Y+2.0 + BALL_RADIUS:
			if absf(ball.pos.z - board_z) < BALL_RADIUS + 0.12:
				var side = signf(previous.z - board_z)
				if side == 0: side = -signf(ball.vel.z)
				ball.pos.z = board_z + side * (BALL_RADIUS + 0.12)
				if ball.vel.z * side < 0: ball.vel.z *= -0.72
				bounce("OFF THE GLASS")
	var floor_y = surface_height(ball.pos-Vector3.UP*BALL_RADIUS,previous.y-BALL_RADIUS)
	if ball.pos.y < floor_y + BALL_RADIUS:
		ball.pos.y = floor_y + BALL_RADIUS
		var normal = Vector3.UP if floor_y == KICKOFF_Y else floor_normal(ball.pos.x,ball.pos.z)
		if ball.vel.dot(normal) < -1.0:
			ball.vel = ball.vel.bounce(normal) * .72
			bounce("LOOSE BALL")
		else: ball.vel.y = 0
		ball.vel.x *= 0.985
		ball.vel.z *= 0.985
	for axis in [0, 2]:
		var limit = HALF_WIDTH - BALL_RADIUS if axis == 0 else HALF_LENGTH - BALL_RADIUS
		if absf(ball.pos[axis]) > limit:
			ball.pos[axis] = clampf(ball.pos[axis], -limit, limit)
			ball.vel[axis] *= -0.8
			bounce("BANK IT")
	if ball.pass_target > 0 and ball.lock <= 0:
		var receiver = ball.pass_target
		if can_catch(receiver) and ball.pos.distance_to(players[receiver].pos + Vector3(0, 1.1, 0)) < 1.5:
			secure_ball(receiver)
			return
	for id in players:
		if ball.lock > 0 and id == ball.last_touch: continue
		var center = players[id].pos + Vector3(0, 0.9, 0)
		var gap = ball.pos - center
		if gap.length() < 0.98 and gap.length() > 0.001:
			var n = gap.normalized()
			ball.pos = center + n * 0.98
			if ball.vel.dot(n) < 0: ball.vel = ball.vel.bounce(n) * 0.72 + players[id].vel * 0.35

func bounce(text: String) -> void:
	if bounce_cooldown <= 0:
		bounce_cooldown = 0.18
		emit("bounce", text, ball.pos)

func score_goal(target: Vector3) -> void:
	var side = team(ball.last_touch) if mode == "versus" else (0 if target.z < 0 else 1)
	scores[side] += 1
	if players.has(ball.last_touch) and team(ball.last_touch)==side:
		players[ball.last_touch].hype = minf(100,players[ball.last_touch].hype+30)
	if assist_player>0 and ball.last_touch==assist_receiver and clock<=assist_until and players.has(assist_player) and team(assist_player)==side:
		players[assist_player].hype = minf(100,players[assist_player].hype+20)
	clear_assist()
	baskets += 1
	emit("score", "SLAM!" if dunks > 0 and players[ball.last_touch].dunk > 0 else "BUCKET!", target, ball.last_touch)
	if (mode == "versus" and scores[side] >= 7) or (mode != "versus" and scores[side] - scores[1-side] >= 4):
		winner = side
		emit("win", "FULL TIME", target, ball.last_touch)
	ball.owner = 0
	ball.pass_target = 0
	ball.lock = 0.9
	reset_time = 3.0
	celebration_time = .85

func clear_assist() -> void:
	assist_player = 0
	assist_receiver = 0
	assist_until = 0.0

func check_clock_winner() -> void:
	var best = -1
	var highest = -1
	var tied = false
	for side in scores:
		if scores[side] > highest:
			highest = scores[side]
			best = side
			tied = false
		elif scores[side] == highest: tied = true
	if not tied:
		winner = best
		emit("win", "FINAL BUZZER", Vector3.ZERO)

func ball_chaser(id: int) -> int:
	# A committed pass keeps its receiver responsible for meeting the ball.
	var receiver = int(ball.get("pass_target",0))
	if ball.owner == 0 and players.has(receiver) and team(receiver) == team(id) and players[receiver].stun <= 0:
		return receiver
	var chaser = 0
	var closest = INF
	for other in players:
		if team(other) != team(id) or players[other].stun > 0 or players[other].dunk > 0: continue
		var distance = flat_distance(players[other].pos,ball.pos)
		if distance < closest or (is_equal_approx(distance,closest) and other < chaser):
			closest = distance
			chaser = other
	return chaser

func support_position(id: int, anchor: Vector3, collector: int) -> Vector3:
	var support = []
	for other in players:
		if other != collector and team(other) == team(id): support.append(other)
	support.sort()
	var lane = -1.0 if support.find(id)%2 == 0 else 1.0
	var forward = 1.0 if hoop(id).z > 0 else -1.0
	# Travel with the attack and remain a reachable wide outlet, not a rim camper.
	var width = LANE_X
	var end = absf(NORTH.z)-5.0
	return Vector3(clampf(anchor.x*.45+lane*width*.54,-width,width),0,clampf(anchor.z+forward*absf(NORTH.z)*.26,-end,end))

func opponent_clearance(id: int, position: Vector3) -> float:
	var nearest = INF
	for other in players:
		if team(other) == team(id) or players[other].stun > 0: continue
		nearest = minf(nearest,position.distance_to(players[other].pos))
	return nearest

func bot_pass_target(id: int) -> int:
	var p = players[id]
	if mode == "versus" or clock < float(p.get("bot_pass_after",0)): return 0
	var pressure = opponent_clearance(id,p.pos)
	var best = 0
	var best_score = -INF
	for other in players:
		if not pass_candidate(id,other): continue
		var receiver = players[other]
		var gap: Vector3 = receiver.pos-p.pos
		if gap.length() < 3: continue
		var aim = Vector3(gap.x,0,gap.z).normalized()
		# The exact same aim ranking will choose the receiver when action runs.
		# A nearer collinear, marked teammate must not intercept our own decision.
		if pass_target(id,aim) != other: continue
		var safety = opponent_clearance(id,receiver.pos)
		if safety < 3.5: continue
		var progress = flat_distance(p.pos,hoop(id))-flat_distance(receiver.pos,hoop(id))
		var requested = receiver.request_time > 0
		if not requested and not (pressure < 4.5 and safety > pressure+1.5) and progress < 8: continue
		var open_lane = true
		for opponent in players:
			if team(opponent) == team(id) or players[opponent].stun > 0: continue
			var along = clampf((players[opponent].pos-p.pos).dot(gap)/gap.length_squared(),0,1)
			if along > .12 and along < .9 and players[opponent].pos.distance_to(p.pos+gap*along)<1.6:
				open_lane = false
				break
		if not open_lane: continue
		var score = progress + minf(safety,10)*.5 + (12 if requested else 0)
		if score > best_score:
			best_score = score
			best = other
	return best

func bot_tuning() -> Dictionary:
	match bot_difficulty:
		"hard": return {"decision":.12,"defense_decision":.06,"reaction":.18,"hold":.65,"windup":.5,"yaw_error":1.8,"power_error":.018}
		"normal": return {"decision":.22,"defense_decision":.09,"reaction":.32,"hold":1.0,"windup":.7,"yaw_error":4.0,"power_error":.035}
	return {"decision":.32,"defense_decision":.12,"reaction":.5,"hold":1.4,"windup":.9,"yaw_error":7.0,"power_error":.06}

func bot_shot(id: int, tuning: Dictionary, attempt: int) -> Dictionary:
	# Bots choose a physical shot at release. The ball never homes in on
	# a basket. Aim/power error is stable during this attempt and changes next time.
	var offset: Vector3 = hoop(id)-hand_position(id)
	var flat = Vector3(offset.x,0,offset.z)
	var angle = deg_to_rad(52.0)
	var denominator = 2*cos(angle)*cos(angle)*(flat.length()*tan(angle)-offset.y)
	var speed = sqrt(BALL_GRAVITY*flat.length_squared()/maxf(.1,denominator))
	var error = sin(float(id*13+attempt*7)*1.731)
	var power_error = cos(float(id*19+attempt*11)*1.217)
	var direction = flat.normalized().rotated(Vector3.UP,deg_to_rad(tuning.yaw_error)*error)*cos(angle)+Vector3.UP*sin(angle)
	return {"direction":direction,"charge":clampf((speed-12)/34+tuning.power_error*power_error,0,1)}

func bot_command(id: int) -> Dictionary:
	var p = players[id]
	var tuning = bot_tuning()
	if not bot_brains.has(id):
		bot_brains[id] = {"next":0.0,"defense_next":0.0,"owner":ball.owner,"react_at":clock+tuning.reaction,"windup_until":-1.0,"attempt":0,"move":Vector3.ZERO,"aim":p.aim}
	var brain: Dictionary = bot_brains[id]
	if brain.owner != ball.owner:
		brain.owner = ball.owner
		brain.react_at = clock+tuning.reaction
		brain.next = 0.0
		brain.defense_next = 0.0
		brain.windup_until = -1.0
		p.charge = 0.0
	if p.stun > 0 or p.dunk > 0 or reset_time > 0 or winner >= 0:
		brain.windup_until = -1.0
		p.charge = 0.0
		return {"move":Vector3.ZERO,"aim":p.aim,"action":"","charge":0.0}
	# Recheck nearby contact windows without speeding up offensive decisions or
	# removing the difficulty's reaction delay after possession changes.
	var close_defense = ball.owner != 0 and team(ball.owner) != team(id) and flat_distance(p.pos,players[ball.owner].pos) < 7.0
	if clock < brain.next and (not close_defense or clock < brain.get("defense_next",0.0)):
		return {"move":brain.move,"aim":brain.aim,"action":"","charge":0.0}
	brain.next = clock+tuning.decision
	brain.defense_next = clock+tuning.defense_decision
	var destination = ball.pos
	var target = hoop(id)
	var command = ""
	var direct_ball_chase = false
	var charge = 0.0
	var aim = Vector3(target.x - p.pos.x, 0, target.z - p.pos.z).normalized()
	if ball.owner == id:
		if p.get("possession_since",-1.0) < 0: p.possession_since = clock
		var settled = clock-p.possession_since >= tuning.hold and clock >= brain.react_at
		destination = target
		if settled and can_dunk(id):
			command = "dunk"
			brain.windup_until = -1.0
			p.charge = 0.0
		elif settled:
			var receiver = bot_pass_target(id)
			if receiver:
				var offset: Vector3 = players[receiver].pos-p.pos
				aim = Vector3(offset.x,0,offset.z).normalized()
				command = "pass"
				brain.windup_until = -1.0
				p.charge = 0.0
			elif flat_distance(p.pos, target) < 5.0 and p.grounded: command = "jump"
			elif flat_distance(p.pos, target) < 16.0 and flat_distance(p.pos,target) > 5.0 and p.grounded:
				# A visible stop and windup leaves time for a defender to contest.
				destination = p.pos
				if brain.windup_until < 0:
					brain.attempt += 1
					brain.windup_until = clock+tuning.windup
				p.charge = clampf(1-(brain.windup_until-clock)/tuning.windup,0,1)
				if clock >= brain.windup_until:
					# Braking changes the release position during the windup. Keep this
					# attempt's error, but solve from the hand that actually releases it.
					brain.shot = bot_shot(id,tuning,brain.attempt)
					set_shot_aim(id,brain.shot.direction)
					charge = brain.shot.charge
					command = "throw"
					brain.windup_until = -1.0
					p.charge = 0.0
	elif ball.owner == 0:
		# Keep one teammate committed to collecting the loose ball. Sending every
		# flank spawn onto a launch pad can fly the whole side past the kickoff.
		var chaser = ball_chaser(id)
		direct_ball_chase = id == chaser
		if not direct_ball_chase: destination = support_position(id,ball.pos,chaser)
		if ball.pos.distance_to(p.pos + Vector3(0, 1, 0)) < 2.25: command = "grab"
		# Raised routes change world Y; jump only toward a ball above this bot.
		elif flat_distance(p.pos, ball.pos) < 2 and ball.pos.y > p.pos.y+2 and p.grounded: command = "jump"
	elif team(ball.owner) == team(id):
		destination = support_position(id,players[ball.owner].pos,ball.owner)
	else:
		# One defender pursues the ball; others mark their counterparts.
		var chaser = ball_chaser(id)
		var carrier: Dictionary = players[ball.owner]
		var distance = flat_distance(p.pos,carrier.pos)
		var height = carrier.pos.y-p.pos.y
		direct_ball_chase = mode == "versus" or id == chaser
		# A short lead closes the lane of a moving carrier. The pressure defender
		# stays on this route instead of taking a nearby launch/speed pad detour.
		var intercept: Vector3 = carrier.pos+Vector3(carrier.vel.x,0,carrier.vel.z)*minf(distance/15.0,.3)
		destination = intercept
		if not direct_ball_chase:
			var own_hoop = SOUTH if team(id) == 0 else NORTH
			destination = own_hoop.lerp(carrier.pos,.45) + Vector3((id%3-1)*3,0,0)
		if carrier.guard <= 0 and p.cooldown <= 0 and clock >= brain.react_at:
			var jump_reach = JUMP_SPEED*JUMP_SPEED/(2.0*PLAYER_GRAVITY)+1.3
			if p.grounded and distance < 4.6 and height > 1.2 and height <= jump_reach:
				command = "jump"
			elif distance < 2.4 and absf(height) <= 1.5:
				command = "tackle"
			if command != "":
				# action(tackle) uses movement before aim; markers must turn toward
				# the carrier when contesting rather than diving toward their post.
				# Close tackles face the current body: a fast approaching carrier's
				# predicted intercept can already lie behind this defender.
				destination = carrier.pos if command == "tackle" else intercept
				direct_ball_chase = true
				aim = Vector3(destination.x-p.pos.x,0,destination.z-p.pos.z).normalized()
	var flat = Vector3(destination.x - p.pos.x, 0, destination.z - p.pos.z)
	# Flank players use a nearby launch route when it advances the current play.
	if not direct_ball_chase and p.grounded and p.get("boost_time",0)<=0 and flat.length()>20:
		var nearest_pad = 12.0
		for pad in PADS:
			var to_pad = flat_distance(p.pos,pad)
			var onward = Vector3(destination.x-pad.x,0,destination.z-pad.z)
			if to_pad<nearest_pad and onward.length()>10 and booster_direction(pad,id).dot(onward.normalized())>.55:
				nearest_pad=to_pad
				flat=Vector3(pad.x-p.pos.x,0,pad.z-p.pos.z)
	if not direct_ball_chase and p.grounded and p.get("boost_time",0)<=0 and flat_distance(p.pos,destination)>12:
		for pad in SPEED_PADS:
			var to_pad=flat_distance(p.pos,pad)
			var onward=Vector3(destination.x-pad.x,0,destination.z-pad.z)
			if to_pad<7 and to_pad+onward.length()<flat_distance(p.pos,destination)+2.5 and booster_direction(pad,id).dot(onward.normalized())>.7:
				flat=Vector3(pad.x-p.pos.x,0,pad.z-p.pos.z)
				break
	if clock < brain.react_at: command = ""
	if command == "" and brain.windup_until < 0 and clock >= brain.react_at and p.hype >= 100: command = "hype"
	brain.move = flat.normalized() if flat.length() > 0.5 else Vector3.ZERO
	brain.aim = aim
	return {"move":brain.move,"aim":aim,"action":command,"charge":charge}

func snapshot() -> Dictionary:
	return {"players": players.duplicate(true), "ball": ball.duplicate(true), "scores": scores.duplicate(),
		"mode": mode, "bot_difficulty":bot_difficulty, "clock": clock, "time_left": time_left, "winner": winner, "message": message,
		"event_id": event_id, "event_kind": event_kind, "event_pos": event_pos, "event_player": event_player,
		"event_clock":event_clock,"recent_events":recent_events.duplicate(true),
		"grabs": grabs, "throws": throws, "dunks": dunks, "tackles": tackles, "baskets": baskets, "reset_time": reset_time, "celebration_time":celebration_time, "setup":match_setup,
		"power_pads":power_pads.duplicate(true),"power_balls":power_balls.duplicate(true)}

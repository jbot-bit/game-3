class_name RunController
extends Node

const PlayerScene=preload("res://game/player/player.gd")
const FishBody=preload("res://game/fishing/physical_fish.gd")
const Mission=preload("res://game/expedition/campaign_controller.gd")
const Campaign=preload("res://game/progression/campaign_rules.gd")
const Patrol=preload("res://game/survival/patrol_rules.gd")
const Supplies=preload("res://game/physics/supply_rules.gd")
const CellBody=preload("res://game/physics/supply_cell.gd")
const COLORS=[Color("62b9db"),Color("e67c61"),Color("a28ad6")]
var session: Session
var world: IslandWorld
var avatars: Dictionary={}
var fish_bodies: Dictionary={}
var supply_bodies: Dictionary={}
var supplies=Supplies.new()
var patrol=Patrol.new()
var trip_start: Dictionary={}
var trip_result: Dictionary={}
var station_warnings: Dictionary={}
var supply_run_id: String=""
var progression: Progression
var run=ExpeditionRules.new()
var fishing=FishingRules.new()
var cargo=CargoRules.new()
var choice=CrewChoice.new()
var lights=LightRules.new()
var abilities=AbilityRules.new()
var hunter_rules=HunterRules.new()
var director=Director.new()
var mission=Mission.new()
var hunter: CharacterBody3D
var hunter_visual: Node3D
var _presentation_run_id: String=""
var _hunter_presenting: bool=false
var _hunter_visual_from: Transform3D
var _hunter_visual_to: Transform3D
var _hunter_visual_elapsed: float=0.05
var hunter_target: String=""
var _hunter_route_left: float=0.0
var _hunter_route_mode: String=""
var _hunter_route_goal: Vector3=Vector3.ZERO
var _hunter_route_start: Vector3=Vector3.ZERO
var _hunter_waypoint: Vector3=Vector3.ZERO
var _hunter_route_repairs: int=-1
var hunter_slow_until: float=0.0
var keeper_position: Vector3
var inputs: Dictionary={}
var rolled: Dictionary={}
var notes: Array[Dictionary]=[]
var note_sequence: int=0
var snapshot_data: Dictionary={}
var active: bool=false
var rng=RandomNumberGenerator.new()
var catch_sequence: int=0
var send_time: float=0.0
var state_time: float=0.0
var grace_time: float=0.0
var vote_invited: bool=false
var next_day_at: float=-1.0
var pending_write: Dictionary={}
var deposits: Dictionary={}
var revive_holds: Dictionary={}
var pack_holds: Dictionary={}
var last_snapshot: Dictionary={}
var cosmetic_catches: Array[Dictionary]=[]
signal notice(text: String)

func configure(network: Session, island: IslandWorld) -> void:
	session=network
	world=island
	session.intent_received.connect(_intent)
	session.roster_changed.connect(_roster_changed)
	session.peer_left.connect(_peer_left)
	session.snapshot_received.connect(_snapshot_received)
	session.poses_received.connect(_poses_received)
	rng.randomize()

func prepare_host(path: String="user://household.json") -> Dictionary:
	var store=SaveStore.new(path)
	var loaded: Dictionary=store.load_or_recover()
	if not loaded.ok and loaded.code!="not_found": return {"ok":false,"code":"corrupt_save"}
	var state: Dictionary=loaded.state if loaded.ok else Progression.blank_state()
	if not loaded.ok and store.commit(state)!=OK: return {"ok":false,"code":"save_failed"}
	progression=Progression.new(store,state)
	return {"ok":true,"code":"ready"}

func start_day() -> void:
	if not session.is_host(): return
	for body in fish_bodies.values(): body.queue_free()
	fish_bodies.clear()
	for body in supply_bodies.values(): body.queue_free()
	supply_bodies.clear()
	supplies=Supplies.new()
	patrol=Patrol.new()
	trip_start=progression.snapshot()
	trip_result.clear()
	station_warnings.clear()
	fishing=FishingRules.new()
	cargo=CargoRules.new()
	choice=CrewChoice.new()
	lights=LightRules.new()
	abilities=AbilityRules.new()
	hunter_rules=HunterRules.new()
	director=Director.new()
	mission.reset()
	rolled.clear()
	inputs.clear()
	deposits.clear()
	revive_holds.clear()
	pack_holds.clear()
	pending_write.clear()
	cosmetic_catches.clear()
	hunter_slow_until=0.0
	hunter_target=""
	_hunter_route_left=0.0
	_hunter_route_mode=""
	vote_invited=false
	next_day_at=-1
	run.start(Crypto.new().generate_random_bytes(12).hex_encode(),_profiles())
	_spawn_supplies()
	session.admission_locked=false
	session.set_paused(false)
	for p in avatars:
		avatars[p].global_position=world.markers.spawn+Vector3((_slot(p)-1)*2.5,0,0)
		avatars[p].last_dry=avatars[p].global_position
		avatars[p].being_carried=false
		avatars[p].carrying_teammate=false
		avatars[p].use_local_presentation()
	if not is_instance_valid(hunter): _create_hunter()
	hunter.global_position=world.markers.hunter_spawn
	# Hosting after a server disconnect retains these nodes. Release the old
	# client presentation targets before host physics takes authority.
	_presentation_run_id=""
	_hunter_presenting=false
	hunter_visual.top_level=false
	hunter_visual.transform=Transform3D.IDENTITY
	active=true
	var saved: Dictionary=progression.snapshot()
	_note("Get the crew home: find engine and beacon parts. Fish pay for repairs. LMB casts at Jetty." if saved.discoveries.is_empty() else "Dawn. "+str(Campaign.status(saved).objective))
	_publish()

func _profiles() -> Array[String]:
	var result: Array[String]=[]
	result.assign(session.roster.snapshot().keys())
	return result

func _slot(p: String) -> int: return int(p.trim_prefix("crew_"))-1

func _roster_changed(data: Dictionary) -> void:
	for p in data:
		if not avatars.has(p):
			var avatar=PlayerScene.new()
			avatar.name=p
			avatar.setup(p,COLORS[clampi(_slot(p),0,2)])
			get_parent().add_child(avatar)
			avatar.global_position=world.markers.spawn+Vector3((_slot(p)-1)*2.5,0,0)
			avatar.last_dry=avatar.global_position
			avatars[p]=avatar
			if session.is_host() and active:
				run.players[p]={"downed":false,"down_left":25.0,"protection":3.0,"aboard":false,"ready":false}
	for p in avatars.keys():
		if not data.has(p):
			avatars[p].queue_free()
			avatars.erase(p)
	if session.is_host() and active: choice.roster_changed(_profiles())

func _peer_left(p: String) -> void:
	if not session.is_host(): return
	if run.phase in ["refuge","escape"]:
		# Boarding is a committed manifest. A lost connection cannot dump cargo
		# after the crew has already agreed to depart. Admission stays closed.
		inputs.erase(p)
		fishing.cancel(p)
		_note(p+" disconnected aboard Moth; boarded cargo stays safe.")
		return
	if pending_write.get("kind","")=="land" and pending_write.get("profile","")==p:
		pending_write.forfeit_pouch=true
	var dropped_cells: Dictionary=supplies.disconnect_profile(p)
	for id in dropped_cells.released_ids:
		if supply_bodies.has(id): supply_bodies[id].drop()
	var result: Dictionary=cargo.disconnect_profile(p)
	for id in result.released_ids:
		if fish_bodies.has(id): fish_bodies[id].drop()
	fishing.cancel(p)
	inputs.erase(p)
	var departed: Dictionary=run.disconnect_profile(p)
	_place_released(departed.get("released_ids",[]))
	_note(p+" disconnected; whole fish remain for the crew.")

func _input_for(p: String) -> Dictionary:
	return inputs.get(p,{"direction":Vector2.ZERO,"yaw":0.0,"reel":false,"pull":0.0,"lamp":true,"receive":false,"updated":0})

func _intent(peer: int, action: String, payload: Dictionary, request: String) -> void:
	var result: Dictionary=apply_intent(peer,action,payload,request)
	if not result.ok and result.code not in ["no_cast","not_holding","paused"]:
		_note(str(result.code).replace("_"," ").capitalize(),session.roster.profile_for_peer(peer))
		_publish()

func apply_intent(peer: int, action: String, payload: Dictionary, request: String) -> Dictionary:
	if not session.is_host() or not active: return _fail("inactive")
	var p: String=session.roster.profile_for_peer(peer)
	if not avatars.has(p): return _fail("unknown_sender")
	if action=="continue_island":
		if peer!=1: return _fail("not_host")
		if not mission.completed or not pending_write.is_empty(): return _fail("finish_escape_first")
		start_day()
		return {"ok":true,"code":"island_continued"}
	if action=="pause":
		if peer!=1: return _fail("not_host")
		if not pending_write.is_empty(): return _retry_write()
		_pause(bool(payload.get("paused",not run.paused)))
		return {"ok":true,"code":"paused"}
	if action=="host_event":
		var e: Dictionary=director.request(str(payload.get("event_id","")),run.elapsed_s,{"is_host":peer==1,"rescuing":_any_downed()})
		if e.ok and e.code=="safe_return":
			_place_released(run._clear_carries())
			for id in avatars:
				avatars[id].global_position=world.markers.boat+Vector3(-_slot(id)*1.2,0,0)
				avatars[id].last_dry=avatars[id].global_position
				avatars[id].velocity=Vector3.ZERO
				run.players[id].downed=false
			_note("Crew returned safely. Cargo still needs banking.")
		if e.ok: _note("Lake Office: "+str(e.code).replace("_"," "))
		return e
	if run.paused or run.terminal or run.crossing_left>=0: return _fail("paused")
	var actor: Angler=avatars[p]
	if run.players.get(p,{}).get("downed",false): return _fail("downed")
	var input: Dictionary=_input_for(p)
	var result: Dictionary={"ok":true,"code":"ok"}
	var now: float=float(Time.get_ticks_msec())/1000.0
	match action:
		"set_name": result=progression.set_profile(p,str(payload.get("name","")),progression.snapshot().profiles[p].role_id)
		"move":
			var d: Variant=payload.get("direction",Vector2.ZERO)
			if not d is Vector2 or not d.is_finite(): return _fail("invalid_input")
			input.direction=d.limit_length(1.0)
			input.yaw=float(payload.get("yaw",0))
			input.updated=now
			inputs[p]=input
			if d.length()>0.1: fishing.cancel(p)
		"reel":
			input.reel=bool(payload.get("held",false))
			input.pull=clampf(float(payload.get("pull",0)),-1,1)
			inputs[p]=input
		"toggle_lamp":
			input.lamp=bool(payload.get("enabled",true))
			inputs[p]=input
		"receive_fish":
			input.receive=bool(payload.get("held",false))
			input.receive_at=now
			inputs[p]=input
		"cast": result=_cast(p)
		"cancel_cast": fishing.cancel(p)
		"grab_fish":
			if _other_hands_full(p): return _fail("hands_full")
			var id: String=str(payload.get("catch_id",""))
			if not fish_bodies.has(id): return _fail("unknown_catch")
			result=cargo.grab(id,p,_touch(p,id))
		"drop_fish","toss_fish":
			result=_release(p,action=="toss_fish",float(payload.get("strength",0.0)))
		"grab_cell": result=_grab_cell(p,str(payload.get("cell_id","")))
		"drop_cell","toss_cell": result=_release_cell(p,action=="toss_cell",float(payload.get("strength",0.0)))
		"feed_station": result=_feed_station(p,str(payload.get("station_id","")))
		"carry_teammate": result=_carry_teammate(p,str(payload.get("target_id","")))
		"drop_teammate": result=_drop_teammate(p)
		"pack_fish":
			if _other_hands_full(p): return _fail("hands_full")
			var id: String=str(payload.get("catch_id",""))
			if not pack_holds.has(p) or pack_holds[p].id!=id: pack_holds[p]={"id":id,"start":run.elapsed_s,"last":run.elapsed_s}
			pack_holds[p].last=run.elapsed_s
		"bank": result=_bank(p)
		"open_cache":
			var id: String=str(payload.get("cache_id",""))
			var marker: String=IslandContent.cache_markers().get(id,"")
			if marker=="" or actor.global_position.distance_to(world.markers[marker])>3: return _fail("out_of_range")
			result=progression.open_cache(id)
			if result.ok: _note("Found "+str(IslandContent.cache(id).get("name",marker.replace("_"," ")))+". Saved for everyone.")
		"craft","equip_lamp","equip_rod","equip_outfit","set_profile","set_tool":
			if not _near_boat(p): return _fail("return_to_workshop")
			match action:
				"craft": result=progression.craft(str(payload.get("recipe_id","")),run.run_id+":"+request)
				"equip_lamp":
					result=progression.set_lamp(p,str(payload.get("lamp_id","")))
					if result.ok: lights.recharge(p,str(payload.lamp_id))
				"equip_rod": result=progression.set_rod(p,str(payload.get("rod_id","")))
				"equip_outfit": result=progression.set_outfit(p,str(payload.get("outfit_id","")))
				"set_profile": result=progression.set_profile(p,str(payload.get("name","")),str(payload.get("role_id","")))
				"set_tool": result=progression.set_tool(p,str(payload.get("mode","")))
			if result.ok: _note("Workshop: "+action.replace("_"," ")+" saved.",p)
		"repair":
			var id: String=str(payload.get("repair_id",""))
			var marker: String=IslandContent.repair_markers().get(id,"")
			if marker=="" or actor.global_position.distance_to(world.markers[marker])>3: return _fail("out_of_range")
			result=progression.repair(id,run.run_id+":"+request)
			if result.ok: _note(str(IslandContent.repair(id).name)+" complete. Saved for the crew.")
		"arm_escape":
			if not _near_boat(p): return _fail("return_to_boat")
			result=mission.arm(Campaign.status(progression.snapshot()).can_escape,run.elapsed_s)
			if result.ok:
				for id in run.players: run.players[id].ready=false
				_note("Escape armed. Signal the beacon, then return together and ready at Moth.")
		"signal_escape":
			if actor.global_position.distance_to(world.markers.beacon_repair)>3: return _fail("reach_the_beacon")
			result=mission.signal_beacon(run.elapsed_s)
			if result.ok: _note("Channel signalled! Bring everyone back to Moth and ready to escape.")
		"open_vote":
			if actor.global_position.distance_to(world.markers.vote)>4: return _fail("return_to_battery")
			result=choice.open(_profiles(),run.elapsed_s)
		"vote":
			if actor.global_position.distance_to(world.markers.vote)>4: return _fail("return_to_battery")
			result=choice.vote(p,str(payload.get("choice","")),run.elapsed_s)
			_commit_choice(result)
		"ready":
			if not _near_boat(p,5): return _fail("return_to_boat")
			run.set_ready(p,bool(payload.get("ready",true)))
			_note("Ready to escape." if mission.signalled else "Ready for refuge.",p)
		"revive":
			var target: String=str(payload.get("target_id",""))
			if not avatars.has(target) or not run.players[target].downed: return _fail("invalid_target")
			if run.carried_by(target)!="": return _fail("put_teammate_down_first")
			if actor.global_position.distance_to(avatars[target].global_position)>2.5 or not _line_clear(actor.global_position+Vector3.UP,avatars[target].global_position+Vector3.UP): return _fail("out_of_range")
			if not revive_holds.has(p) or revive_holds[p].target!=target: revive_holds[p]={"target":target,"start":run.elapsed_s,"last":run.elapsed_s}
			revive_holds[p].last=run.elapsed_s
			_release(p,false)
			_release_cell(p,false)
		"assist":
			if _hands_full(p): return _fail("hands_full")
			var target: String=str(payload.get("target_id",""))
			if not avatars.has(target) or actor.global_position.distance_to(avatars[target].global_position)>5: return _fail("out_of_range")
			result=fishing.assist(p,target,"generic")
		"use_ability": result=_ability(p,str(payload.get("target_id","")))
		"ping": _note(str(progression.snapshot().profiles[p].name)+": over here, "+_nearest_area(actor.global_position)+"!")
		_: return _fail("unknown_action")
	if action not in ["move","reel","receive_fish","revive","pack_fish"]: _publish()
	return result

func _cast(p: String) -> Dictionary:
	if _hands_full(p): return _fail("hands_full")
	var actor: Angler=avatars[p]
	var habitat: String=world.fishing_habitat(actor.global_position)
	if habitat=="": return _fail("find_a_fishing_spot")
	if habitat=="reeds" and actor.global_position.distance_to(world.markers.reeds)<8: return _fail("reeds_cast_from_beyond_the_lights")
	var state: Dictionary=progression.snapshot()
	var c: Dictionary=CatchTable.roll(habitat,run.phase,int(state.dry_streaks.get(habitat,0)),rng.randf(),rng.randf(),rng.randf())
	if not c.ok: return c
	catch_sequence+=1
	var id: String=run.run_id+":"+str(catch_sequence)
	var result: Dictionary=fishing.start(p,c.species_id,id)
	if result.ok:
		var toward: Vector3=world.fishing_focus(habitat)-actor.global_position
		if Vector2(toward.x,toward.z).length_squared()>0.0001:
			actor.rotation.y=atan2(-toward.x,-toward.z)
		c.merge({"catch_id":id,"run_id":run.run_id,"profile_id":p},true)
		rolled[p]=c
		fishing.configure_rod(p,state.profiles[p].rod_id)
		fishing.casts[p].tension_multiplier*=float(Equipment.outfit(str(state.profiles[p].get("outfit_id","harbour"))).get("tension_gain_multiplier",1.0))
		fishing.casts[p].habitat_id=habitat
		patrol.record_noise(actor.last_dry,run.elapsed_s)
		_note("Bite! Hold to reel; release before the line turns red.",p,"cast")
	return result

func _land(p: String) -> void:
	var c: Dictionary=rolled[p]
	var result: Dictionary=progression.record_specimen(c)
	if not result.ok:
		pending_write={"kind":"land","profile":p,"record":c}
		_pause(true)
		_note("Save failed. Crew paused; Esc → Resume retries the same catch.")
		return
	_add_landed(c)

func _add_landed(c: Dictionary,forfeit_pouch: bool=false) -> void:
	var mode: String="whole" if c.trait_id=="oversized" else "packed"
	var registered: Dictionary=cargo.register_catch(c,mode)
	if registered.state=="whole_loose":
		var body=FishBody.new()
		body.setup(c.catch_id,c.species_id,true,c.trait_id)
		get_parent().add_child(body)
		var at: Vector3=avatars[c.profile_id].last_dry if avatars.has(c.profile_id) else world.markers.boat+Vector3(-3,0,0)
		body.global_position=at+Vector3(0,1.2,-1)
		body.last_dry_position=at+Vector3.UP*0.8
		body.set_host_simulated(true)
		fish_bodies[c.catch_id]=body
	if forfeit_pouch or not avatars.has(c.profile_id): cargo.disconnect_profile(c.profile_id)
	var prefix: String=(str(c.trait_id).to_upper()+" ") if c.trait_id!="none" else ""
	var funny: bool=director.active=="odd_catch"
	if funny:
		director.active=""
	cosmetic_catches.append({"catch_id":c.catch_id,"profile_id":c.profile_id,"species_id":c.species_id,"trait_id":c.trait_id,"odd":funny})
	if cosmetic_catches.size()>6: cosmetic_catches.pop_front()
	_note(prefix+Species.catalog()[c.species_id].name+" · %.2f m%s"%[c.size," · suspiciously stylish!" if funny else ""],"","catch")
	rolled.erase(c.profile_id)

func _touch(p: String,id: String) -> Dictionary:
	var a: Vector3=avatars[p].global_position+Vector3.UP
	var b: Vector3=fish_bodies[id].global_position
	return {"active":not run.players[p].downed,"distance_m":a.distance_to(b),"line_of_sight":_line_clear(a,b)}

func _release(p: String,toss: bool,strength: float=0.0) -> Dictionary:
	if not is_finite(strength): return _fail("invalid_input")
	var actor: Angler=avatars.get(p) as Angler
	var body: PhysicalFish=fish_bodies.get(cargo.held_by(p)) as PhysicalFish
	var prior_yaw: float=actor.rotation.y if actor!=null else 0.0
	var prior_pose: Transform3D=body.global_transform if body!=null else Transform3D.IDENTITY
	if toss and actor!=null and body!=null:
		var aim_yaw: float=float(inputs.get(p,{}).get("yaw",prior_yaw))
		if not is_finite(aim_yaw): return _fail("invalid_input")
		actor.rotation.y=wrapf(aim_yaw,-PI,PI)
		# Rotate the held body only through its existing endpoint + swept world
		# clearance check. A blocked aim leaves both ownership and pose intact.
		if not body.set_carry_pose(actor.carry_transform(),actor.last_dry+Vector3.UP*0.6):
			actor.rotation.y=prior_yaw
			return _fail("not_enough_room_to_throw")
	var result: Dictionary=cargo.release(p,"toss" if toss else "drop")
	if result.ok and body!=null:
		if toss:
			body.toss(-actor.global_basis.z,clampf(strength,0,1))
			patrol.record_noise(actor.last_dry,run.elapsed_s)
			_note("Heads up!",p,"toss")
		else: body.drop()
	elif toss and actor!=null and body!=null:
		actor.rotation.y=prior_yaw
		body.global_transform=prior_pose
	return result
func _near_boat(p: String,distance: float=3.0) -> bool:
	return avatars.has(p) and avatars[p].global_position.distance_to(world.markers.boat)<distance

func _other_hands_full(p: String) -> bool:
	return supplies.held_by(p)!="" or run.carrying_teammate(p)!=""

func _hands_full(p: String) -> bool:
	return cargo.held_by(p)!="" or _other_hands_full(p)

func _spawn_supplies() -> void:
	var starts: Dictionary={"cell_1":world.markers.spawn+Vector3(4,0.8,-3),"cell_2":world.markers.tidepools+Vector3(-3,0.8,4)}
	for id in starts:
		var b=CellBody.new()
		b.setup_cell(id)
		get_parent().add_child(b)
		b.global_position=starts[id]
		b.last_dry_position=starts[id]
		b.set_host_simulated(true)
		supply_bodies[id]=b

func _grab_cell(p: String,id: String) -> Dictionary:
	if _hands_full(p): return _fail("hands_full")
	if fishing.casts.has(p): return _fail("cancel_cast_first")
	if not supply_bodies.has(id): return _fail("unknown_cell")
	var a: Vector3=avatars[p].global_position+Vector3.UP
	var b: Vector3=supply_bodies[id].global_position
	return supplies.grab(id,p,{"active":true,"distance_m":a.distance_to(b),"line_of_sight":_line_clear(a,b)})

func _release_cell(p: String,toss: bool,strength: float=0.0) -> Dictionary:
	if not is_finite(strength): return _fail("invalid_input")
	var actor: Angler=avatars.get(p) as Angler
	var body: PhysicalFish=supply_bodies.get(supplies.held_by(p)) as PhysicalFish
	var prior_yaw: float=actor.rotation.y if actor!=null else 0.0
	var prior_pose: Transform3D=body.global_transform if body!=null else Transform3D.IDENTITY
	if toss and actor!=null and body!=null:
		var aim_yaw: float=float(inputs.get(p,{}).get("yaw",prior_yaw))
		if not is_finite(aim_yaw): return _fail("invalid_input")
		actor.rotation.y=wrapf(aim_yaw,-PI,PI)
		if not body.set_carry_pose(actor.carry_transform(),actor.last_dry+Vector3.UP*0.6):
			actor.rotation.y=prior_yaw
			return _fail("not_enough_room_to_throw")
	var result: Dictionary=supplies.release(p)
	if result.ok and body!=null:
		if toss:
			body.toss(-actor.global_basis.z,clampf(strength,0,1))
			patrol.record_noise(actor.last_dry,run.elapsed_s)
			_note("Spare cell away!",p,"toss")
		else: body.drop()
	elif toss and actor!=null and body!=null:
		actor.rotation.y=prior_yaw
		body.global_transform=prior_pose
	return result
func _feed_station(p: String,station: String) -> Dictionary:
	if station not in ["jetty","reeds"]: return _fail("unknown_station")
	if avatars[p].global_position.distance_to(world.markers[station])>3 or not _line_clear(avatars[p].global_position+Vector3.UP,world.markers[station]+Vector3.UP): return _fail("reach_the_light_post")
	var id: String=supplies.held_by(p)
	if id=="": return _fail("bring_a_spare_cell")
	var result: Dictionary=lights.feed_station(station,id,run.elapsed_s)
	if result.ok:
		supplies.consume(id)
		supply_bodies[id].queue_free()
		supply_bodies.erase(id)
		station_warnings.erase(station)
		_note("%s recharged: %d seconds of night shelter."%[station.capitalize(),result.remaining],"","cell")
	return result

func _carry_teammate(p: String,target: String) -> Dictionary:
	if _hands_full(p): return _fail("hands_full")
	if not avatars.has(target): return _fail("invalid_target")
	var a: Vector3=avatars[p].global_position
	var b: Vector3=avatars[target].global_position
	var result: Dictionary=run.pickup_teammate(p,target,{"active":true,"hands_free":true,"distance_m":a.distance_to(b),"line_of_sight":_line_clear(a+Vector3.UP,b+Vector3.UP)})
	if result.ok:
		fishing.cancel(p)
		revive_holds.erase(p)
		_note("Crewmate on your shoulder. Move to cover, put them down, then revive.",p,"rescue")
	return result

func _drop_teammate(p: String) -> Dictionary:
	var target: String=run.carrying_teammate(p)
	var result: Dictionary=run.release_teammate(p)
	if result.ok: _place_released([target])
	return result

func _detach_rescue(p: String) -> void:
	_drop_teammate(p)
	var helper: String=run.carried_by(p)
	if helper!="": _drop_teammate(helper)

func _place_released(ids: Array) -> void:
	for p in ids:
		if not avatars.has(p): continue
		var actor: Angler=avatars[p]
		actor.being_carried=false
		actor.global_position=actor.last_dry
		actor.velocity=Vector3.ZERO

func _tick_rescue_attachments() -> void:
	for p in avatars:
		var target: String=run.carrying_teammate(p)
		if target=="" or not avatars.has(target): continue
		var helper: Angler=avatars[p]
		var passenger: Angler=avatars[target]
		var anchor: Transform3D=helper.rescue_transform()
		var query=PhysicsShapeQueryParameters3D.new()
		var shape=CapsuleShape3D.new()
		shape.height=1.9
		shape.radius=0.38
		query.shape=shape
		query.transform=Transform3D(Basis.IDENTITY,anchor.origin+Vector3.UP*0.95)
		query.collision_mask=1
		if not world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
			_drop_teammate(p)
			continue
		passenger.global_transform=anchor
		passenger.velocity=helper.velocity
		passenger.last_dry=helper.last_dry
		passenger.being_carried=true

func _active_rescue(p: String="") -> bool:
	for helper in revive_holds:
		var hold: Dictionary=revive_holds[helper]
		if p!="" and p not in [helper,hold.target]: continue
		if run.elapsed_s-hold.last<=0.25 and avatars.has(helper) and avatars.has(hold.target) and not run.players.get(helper,{}).get("downed",true) and run.players.get(hold.target,{}).get("downed",false) and avatars[helper].global_position.distance_to(avatars[hold.target].global_position)<=2.5 and _line_clear(avatars[helper].global_position+Vector3.UP,avatars[hold.target].global_position+Vector3.UP): return true
	return false

func _tick_supplies() -> void:
	for id in supply_bodies.keys():
		var item: Dictionary=supplies.snapshot()[id]
		if item.state=="free":
			var body: PhysicalFish=supply_bodies[id]
			if body.linear_velocity.length()<0.4: continue
			for p in avatars:
				var input: Dictionary=_input_for(p)
				if _hands_full(p) or run.players[p].downed or not input.get("receive",false) or Time.get_ticks_msec()/1000.0-float(input.get("receive_at",0))>0.25: continue
				var toward: Vector3=body.global_position-avatars[p].global_position-Vector3.UP
				if (-avatars[p].global_basis.z).dot(toward.normalized())<-0.1: continue
				if _grab_cell(p,id).ok:
					inputs[p].receive=false
					_note("Spare cell caught!",p,"catch")
					break
			continue
		if item.state!="held": continue
		var actor: Angler=avatars.get(item.carrier_id)
		if actor==null:
			_release_cell(item.carrier_id,false)
		elif not supply_bodies[id].set_carry_pose(actor.carry_transform(),actor.last_dry+Vector3.UP*0.6):
			_release_cell(item.carrier_id,false)

func _bank(p: String) -> Dictionary:
	if not _near_boat(p): return _fail("return_to_boat")
	var ids: Array[String]=[]
	for id in cargo.snapshot():
		var c: Dictionary=cargo.snapshot()[id]
		if (c.state=="packed" and c.pouch_profile_id==p) or (c.state=="whole_held" and c.carrier_id==p): ids.append(id)
	return _bank_ids(ids)

func _bank_ids(ids: Array[String]) -> Dictionary:
	var reservation: Dictionary=cargo.reserve_bank(ids,{"eligible_ids":ids})
	if not reservation.ok: return reservation
	var result: Dictionary=progression.bank(reservation.catches,reservation.delivery_modes)
	cargo.finish_bank(reservation.reservation_id,result.ok)
	if not result.ok:
		pending_write={"kind":"bank","reservation":reservation}
		_pause(true)
		_note("Save failed. Catch reserved safely. Esc → Resume retries.")
	else: _note("+%d coins banked for the crew."%result.awarded,"","bank")
	return result

func _ability(p: String,target: String) -> Dictionary:
	if run.carrying_teammate(p)!="": return _fail("put_teammate_down_first")
	var profile: Dictionary=progression.snapshot().profiles[p]
	var context: Dictionary={"tool_mode":profile.get("tool_mode","standard")}
	if profile.role_id=="rigger":
		if not avatars.has(target): return _fail("pick_a_teammate")
		if run.carried_by(target)!="": return _fail("put_teammate_down_first")
		context.merge({"distance":avatars[p].global_position.distance_to(avatars[target].global_position),"valid_path":_line_clear(avatars[p].global_position+Vector3.UP,avatars[target].global_position+Vector3.UP) and world._route_segment(avatars[p].last_dry,avatars[target].last_dry)})
		if not run.players[target].downed and not fishing.casts.has(target): return _fail("no_rescue_or_catch")
		if not run.players[target].downed and "rigger" in fishing.casts[target].assists: return _fail("already_assisted")
	var result: Dictionary=abilities.use(p,profile.role_id,context,run.elapsed_s)
	if not result.ok: return result
	_release(p,false)
	_release_cell(p,false)
	match profile.role_id:
		"keeper":
			keeper_position=avatars[p].global_position
			_note("Keeper light! %d seconds of breathing room."%int(result.duration))
		"scout": _note("Trail marked: follow the blue squares home." if context.tool_mode=="alternate" else "Scout: fish at the lit markers; Lifeguard "+_nearest_area(hunter.global_position)+".",p)
		"rigger":
			if run.players[target].downed:
				avatars[target].global_position=avatars[p].last_dry
				avatars[target].last_dry=avatars[p].last_dry
				avatars[target].velocity=Vector3.ZERO
				_note("Rescue line secured. Hold E to revive.")
			else: fishing.assist(p,target,"rigger",context.tool_mode=="alternate")
	return result

func _commit_choice(result: Dictionary) -> void:
	if result.has("committed_station"):
		lights.set_reserve(result.committed_station)
		var station: String=str(result.committed_station)
		var other: String="Reeds" if station=="jetty" else "Jetty"
		var who: String=str(progression.snapshot().profiles.get(str(result.get("decided_by","")),{}).get("name","The default switch"))
		_note("%s powered %s. %s goes dark at sunset. Spare cells can relight it."%[who,station.capitalize(),other],"","cell")

func _pause(value: bool) -> void:
	run.set_paused(value)
	cargo.set_paused(value)
	supplies.set_paused(value)
	session.set_paused(value)
	for b in fish_bodies.values(): b.set_game_paused(value or run.terminal)
	for b in supply_bodies.values(): b.set_game_paused(value or run.terminal)
	_publish()

func _retry_write() -> Dictionary:
	var pending: Dictionary=pending_write.duplicate(true)
	var result: Dictionary=_fail("save_failed")
	match pending.get("kind",""):
		"land":
			result=progression.record_specimen(pending.record)
			if result.ok: _add_landed(pending.record,bool(pending.get("forfeit_pouch",false)))
		"bank":
			var r: Dictionary=pending.reservation
			result=progression.bank(r.catches,r.delivery_modes)
			cargo.finish_bank(r.reservation_id,result.ok)
		"settle":
			result=progression.settle_run(run.run_id,pending.catches,pending.modes,bool(pending.get("complete_campaign",false)))
			if result.ok: _complete_settle(pending.reservation_id)
	if result.ok:
		pending_write.clear()
		_pause(false)
	return result

func _line_clear(a: Vector3,b: Vector3) -> bool:
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1)).is_empty()

func _any_downed() -> bool:
	for s in run.players.values():
		if s.downed: return true
	return false

func _nearest_area(at: Vector3) -> String:
	var best: String="boat"
	for id in ["boat","jetty","reeds","lens_cache","rod_cache"]:
		if at.distance_to(world.markers[id])<at.distance_to(world.markers[best]): best=id
	return "near "+best.replace("_cache","").replace("_"," ")

func _note(text: String,p: String="",kind: String="info") -> void:
	note_sequence+=1
	notes.append({"id":note_sequence,"text":text,"profile":p,"kind":kind})
	if notes.size()>8: notes.pop_front()
	notice.emit(text)

func _fail(code: String) -> Dictionary: return {"ok":false,"code":code}

func _physics_process(delta: float) -> void:
	if not active or not session.is_host(): return
	send_time+=delta
	state_time+=delta
	if next_day_at>=0:
		if not run.paused:
			next_day_at-=delta
			if next_day_at<=0: start_day()
	elif not run.paused and not run.terminal:
		for p in avatars: run.set_aboard(p,_near_boat(p,5.0))
		var before_phase: String=run.phase
		var step: Dictionary=run.advance(delta)
		if run.phase!=before_phase:
			if run.phase=="dusk": _note("Closing bell. One minute until dark. Carry a spare cell to a field light.","","warn")
			elif run.phase=="night": _note("Nightfall. The Lifeguard roams. Pack a heavy fish to run faster, or light the way together.","","warn")
			elif run.phase=="storm": _note("Storm warning. One minute to get your catch back to Moth.","","storm")
		_place_released(step.get("released_ids",[]))
		if step.code=="settle":
			_settle()
		elif step.code=="depart":
			session.admission_locked=true
			if mission.depart(run.elapsed_s):
				run.phase="escape"
				_note("Moth is leaving through the channel. Stay aboard — open sea ahead!","","escape")
			else: _note("Moth is leaving. Twenty seconds to the sheltered mooring.")
		elif run.crossing_left<0:
			_tick_players(delta)
			if run.paused: return
			_tick_cargo(delta)
			_tick_supplies()
			_tick_hunter(delta)
			for p in step.returned:
				cargo.disconnect_profile(p)
				_release_cell(p,false)
				avatars[p].global_position=world.markers.boat
				avatars[p].last_dry=world.markers.boat
				_note("Back at the boat. Pouch lost; saved gear is safe.",p)
			if run.elapsed_s>=150 and not vote_invited and not _any_downed() and fishing.casts.is_empty() and hunter_rules.state not in ["warn","chase"]:
				choice.open(_profiles(),run.elapsed_s)
				vote_invited=true
			_commit_choice(choice.tick(run.elapsed_s))
			director.tick(run.elapsed_s,{})
			for station in ["jetty","reeds"]:
				var remaining: float=lights.station_remaining(station,run.elapsed_s)
				if run.elapsed_s>=240 and remaining>0 and remaining<=30 and not station_warnings.has(station):
					station_warnings[station]=true
					_note(station.capitalize()+" light has 30 seconds left. Bring a cell or move to cover.","","warn")
	if send_time>=0.05:
		send_time=0
		session.publish_poses(_poses())
	if state_time>=0.2:
		state_time=0
		_publish()

func _tick_players(delta: float) -> void:
	var now: float=Time.get_ticks_msec()/1000.0
	var state: Dictionary=progression.snapshot()
	for p in avatars:
		var actor: Angler=avatars[p]
		var input: Dictionary=_input_for(p)
		var direction: Vector2=input.get("direction",Vector2.ZERO)
		if now-float(input.get("updated",0))>0.35: direction=Vector2.ZERO
		actor.downed=run.players[p].downed
		actor.fishing=fishing.casts.has(p)
		actor.carrying=cargo.held_by(p)!="" or supplies.held_by(p)!=""
		actor.carrying_teammate=run.carrying_teammate(p)!=""
		actor.being_carried=run.carried_by(p)!=""
		actor.advance(delta,direction,float(input.get("yaw",actor.rotation.y)),true)
		if _near_boat(p,4): lights.recharge(p,state.profiles[p].lamp_id)
		for station in ["jetty","reeds"]:
			if lights.station_powered(station,run.elapsed_s) and actor.global_position.distance_to(world.markers[station])<3: lights.recharge(p,state.profiles[p].lamp_id)
		var lamp_drain: float=float(Equipment.outfit(str(state.profiles[p].get("outfit_id","harbour"))).get("lamp_drain_multiplier",1.0))
		var battery: Dictionary=lights.drain(p,state.profiles[p].lamp_id,bool(input.get("lamp",true)) and run.elapsed_s>=240,delta*lamp_drain)
		actor.set_loadout(state.profiles[p],battery.remaining,bool(input.get("lamp",true)))
		if actor.fishing:
			var result: Dictionary=fishing.step(p,bool(input.get("reel",false)),float(input.get("pull",0)),delta)
			if result.code=="caught": _land(p)
			elif result.code=="line_broke":
				rolled.erase(p)
				_note("Line snapped. Try releasing earlier.",p)
		if revive_holds.has(p):
			var hold: Dictionary=revive_holds[p]
			if actor.downed or run.carried_by(hold.target)!="" or run.elapsed_s-hold.last>0.25 or not avatars.has(hold.target) or actor.global_position.distance_to(avatars[hold.target].global_position)>2.5 or not _line_clear(actor.global_position+Vector3.UP,avatars[hold.target].global_position+Vector3.UP):
				revive_holds.erase(p)
			elif run.elapsed_s-hold.start>=3:
				var result: Dictionary=run.revive(p,hold.target,run.elapsed_s-hold.start)
				if result.ok: _note("Crewmate rescued. Back on your feet!","","rescue")
				revive_holds.erase(p)
		if pack_holds.has(p):
			var hold: Dictionary=pack_holds[p]
			if run.elapsed_s-hold.last>0.25 or not fish_bodies.has(hold.id):
				pack_holds.erase(p)
			elif run.elapsed_s-hold.start>=0.5:
				var result: Dictionary=cargo.pack(hold.id,p,run.elapsed_s-hold.start,_touch(p,hold.id))
				if result.ok: _note("Packed. Bank it when you get back.",p)
				pack_holds.erase(p)
		if run.paused: return
	_tick_rescue_attachments()

func _tick_cargo(delta: float) -> void:
	var all: Dictionary=cargo.snapshot()
	for id in fish_bodies.keys():
		var b: PhysicalFish=fish_bodies[id]
		var c: Dictionary=all.get(id,{})
		if c.get("state","lost") in ["packed","banked","lost"]:
			b.queue_free()
			fish_bodies.erase(id)
			continue
		if c.state=="bank_pending":
			b.set_game_paused(true)
			continue
		if c.state=="whole_held":
			if avatars.has(c.carrier_id):
				var actor: Angler=avatars[c.carrier_id]
				if not b.set_carry_pose(actor.carry_transform(),actor.last_dry+Vector3.UP*0.6):
					_release(c.carrier_id,false)
			continue
		var candidates: Array[Dictionary]=[]
		for p in avatars:
			var actor: Angler=avatars[p]
			var to_fish: Vector3=b.global_position-(actor.global_position+Vector3.UP)
			var input: Dictionary=_input_for(p)
			var receiving: bool=bool(input.get("receive",false)) and Time.get_ticks_msec()/1000.0-float(input.get("receive_at",0))<0.25
			candidates.append({"profile_id":p,"distance_m":to_fish.length(),"active":not run.players[p].downed and not _other_hands_full(p) and not fishing.casts.has(p),
				"facing":(-actor.global_basis.z).dot(to_fish.normalized())>-0.1 and _line_clear(actor.global_position+Vector3.UP,b.global_position),"receiving":receiving})
		if b.linear_velocity.length()>0.4:
			var received: Dictionary=cargo.receive(id,candidates)
			if received.ok:
				inputs[received.carrier_id].receive=false
				_note("Nice catch!",received.carrier_id,"catch")
				continue
		if b.global_position.distance_to(world.markers.boat+Vector3.UP*0.5)<3.0 and b.linear_velocity.length()<1.2 and not b.recovering:
			deposits[id]=float(deposits.get(id,0))+delta
			if deposits[id]>=0.3:
				_bank_ids([id])
				deposits.erase(id)
		else: deposits.erase(id)
		if run.paused: return

func _create_hunter() -> void:
	hunter=CharacterBody3D.new()
	hunter.name="LastLifeguard"
	hunter.collision_layer=8
	hunter.collision_mask=1
	var collider=CollisionShape3D.new()
	var capsule=CapsuleShape3D.new()
	capsule.height=3.8
	capsule.radius=0.48
	collider.shape=capsule
	collider.position.y=1.9
	hunter.add_child(collider)
	hunter_visual=BlockArt.hunter()
	hunter.add_child(hunter_visual)
	get_parent().add_child(hunter)

func _safe(at: Vector3) -> bool:
	if at.distance_to(world.markers.boat)<7: return true
	for s in ["jetty","reeds"]:
		if lights.station_powered(s,run.elapsed_s) and at.distance_to(world.markers[s])<6: return true
	return run.elapsed_s<abilities.keeper_until and at.distance_to(keeper_position)<abilities.keeper_radius

func _tick_hunter(delta: float) -> void:
	var target: String=""
	var distance: float=34.0
	for p in avatars:
		var a: Angler=avatars[p]
		var d: float=a.global_position.distance_to(hunter.global_position)
		if d<distance and not run.players[p].downed and not _safe(a.global_position) and _line_clear(hunter.global_position+Vector3.UP*2,a.global_position+Vector3.UP):
			target=p
			distance=d
	var before: String=hunter_rules.state
	var pressure: Dictionary=hunter_rules.advance(delta,{"night":run.elapsed_s>=240,"target_visible":target!="","rescuing":_active_rescue(target) if target!="" else false})
	hunter.visible=run.elapsed_s>=180
	if before!="warn" and pressure.state=="warn": _note("Wet footsteps. The Last Lifeguard has spotted "+str(progression.snapshot().profiles.get(target,{}).get("name","the crew"))+"!","","warn")
	if target!="": hunter_target=target
	if pressure.state in ["warn","chase"] and avatars.has(hunter_target):
		var goal: Vector3=avatars[hunter_target].global_position
		var waypoint: Vector3=_hunter_route_to(goal,"chase",delta) if pressure.state=="chase" else goal
		var direction: Vector3=(waypoint-hunter.global_position)
		direction.y=0
		direction=direction.normalized()
		var speed: float=4.7 if pressure.state=="chase" else 0.0
		for p in avatars:
			var a: Angler=avatars[p]
			var to_hunter: Vector3=hunter.global_position-(a.global_position+Vector3.UP)
			if a.lamp.visible and to_hunter.length()<a.lamp.spot_range and (-a.global_basis.z).dot(to_hunter.normalized())>cos(deg_to_rad(a.lamp.spot_angle)):
				var effect: Dictionary=lights.handheld_effect("lifeguard",run.elapsed_s)
				if effect.ok: hunter_slow_until=effect.until
		if run.elapsed_s<hunter_slow_until: speed*=0.35
		hunter.velocity.x=direction.x*speed
		hunter.velocity.z=direction.z*speed
		if direction.length()>0.1: hunter.rotation.y=atan2(-direction.x,-direction.z)
		if pressure.can_attack and hunter.global_position.distance_to(goal)<1.7 and not _safe(goal) and not _active_rescue(hunter_target):
			var hit: Dictionary=run.down(hunter_target)
			if hit.ok:
				_place_released(hit.get("released_ids",[]))
				_release(hunter_target,false)
				_release_cell(hunter_target,false)
				fishing.cancel(hunter_target)
				hunter_rules.advance(0,{"night":true,"caught":true})
				_note("Crewmate down! Revive nearby, or shoulder them and move to cover.","","down")
	else:
		var speed: float=2.6 if run.elapsed_s>=180 and pressure.state=="patrol" else 0.0
		if speed>0:
			var goal: Vector3=patrol.next_goal(run.elapsed_s,hunter.global_position,[world.markers.reeds,world.markers.beacon,world.markers.terraces,world.markers.jetty,world.markers.spawn,world.markers.jetty,world.markers.terraces,world.markers.beacon])
			var direction: Vector3=_hunter_route_to(goal,"patrol",delta)-hunter.global_position
			direction.y=0
			direction=direction.normalized()
			hunter.velocity.x=direction.x*speed
			hunter.velocity.z=direction.z*speed
			if direction.length()>0.1: hunter.rotation.y=atan2(-direction.x,-direction.z)
		else:
			hunter.velocity.x=0.0
			hunter.velocity.z=0.0
			_hunter_route_left=0.0
	if not hunter.is_on_floor(): hunter.velocity.y-=22*delta
	else: hunter.velocity.y=0
	hunter.move_and_slide()
	if hunter.position.y<0: hunter.global_position=world.markers.hunter_spawn

func _hunter_route_to(goal: Vector3,mode: String,delta: float) -> Vector3:
	# Detection, attacks and movement still run every physics tick. The expensive
	# graph solve only needs a short refresh, or an immediate reaction to a turn,
	# changed target/repair, or a teleport. All cached segments were collision-tested.
	_hunter_route_left-=delta
	var repairs: int=int(world._repaired)+int(world._ridge_repaired)*2
	if _hunter_route_left<=0.0 or mode!=_hunter_route_mode or repairs!=_hunter_route_repairs or goal.distance_squared_to(_hunter_route_goal)>4.0 or hunter.global_position.distance_squared_to(_hunter_waypoint)<0.04 or hunter.global_position.distance_squared_to(_hunter_route_start)>16.0:
		_hunter_waypoint=world.route_step(hunter.global_position,goal)
		_hunter_route_goal=goal
		_hunter_route_start=hunter.global_position
		_hunter_route_mode=mode
		_hunter_route_repairs=repairs
		_hunter_route_left=0.25
	return _hunter_waypoint

func _settle() -> void:
	# This selection is frozen before any durable write; retries reuse it exactly.
	var eligible: Array[String]=[]
	var all: Dictionary=cargo.snapshot()
	for id in all:
		var c: Dictionary=all[id]
		if c.state=="packed" and run.players.get(c.pouch_profile_id,{}).get("aboard",false): eligible.append(id)
		elif c.state=="whole_held" and run.players.get(c.carrier_id,{}).get("aboard",false): eligible.append(id)
		elif c.state=="whole_loose" and fish_bodies.has(id) and fish_bodies[id].global_position.distance_to(world.markers.boat+Vector3.UP*0.5)<3: eligible.append(id)
	var reservation: Dictionary={"reservation_id":"","catches":[],"delivery_modes":{}}
	if not eligible.is_empty():
		reservation=cargo.reserve_bank(eligible,{"eligible_ids":eligible})
		if not reservation.ok: _note("Settlement blocked: "+reservation.code); return
	var records: Array[Dictionary]=[]
	records.assign(reservation.catches)
	var result: Dictionary=progression.settle_run(run.run_id,records,reservation.delivery_modes,mission.departing)
	if not result.ok:
		pending_write={"kind":"settle","catches":records,"modes":reservation.delivery_modes,"reservation_id":reservation.reservation_id,"complete_campaign":mission.departing}
		_pause(true)
		_note("Departure save pending. Esc → Resume retries; cargo is frozen safely.")
	else: _complete_settle(reservation.reservation_id)

func _complete_settle(reservation_id: String) -> void:
	if reservation_id!="": cargo.finish_bank(reservation_id,true)
	var lost: Array[String]=[]
	for id in cargo.snapshot():
		if cargo.snapshot()[id].state not in ["banked","bank_pending"]: lost.append(id)
	if not lost.is_empty(): cargo.mark_lost(lost)
	for b in fish_bodies.values(): b.set_game_paused(true)
	for b in supply_bodies.values(): b.set_game_paused(true)
	_place_released(run._clear_carries())
	mission.settled()
	next_day_at=-1.0 if mission.completed else 8.0
	var saved: Dictionary=progression.snapshot()
	var improved: int=0
	for species in saved.specimen_records:
		if float(saved.specimen_records[species].largest_size)>float(trip_start.get("specimen_records",{}).get(species,{}).get("largest_size",0)): improved+=1
	var outcome: String="escaped" if mission.completed else ("refuge" if run.phase=="refuge" else "retreat")
	trip_result={"outcome":outcome,"banked":int(saved.lifetime_banked)-int(trip_start.get("lifetime_banked",0)),"new_species":saved.discoveries.size()-trip_start.get("discoveries",[]).size(),"records":improved,"lost_count":lost.size(),"next_goal":Campaign.status(saved).objective}
	var message: String="You escaped Last Light together. The island is yours to return to." if mission.completed else ("Safe at the mooring. Gear, records and repairs saved. Dawn in eight seconds." if outcome=="refuge" else "The outing ended in retreat. Unbanked catch left behind; saved gear and discoveries remain. Dawn in eight seconds.")
	_note(message,"","escape" if mission.completed else "bank")
	_publish()

func _poses() -> Dictionary:
	var players: Dictionary={}
	for p in avatars:
		players[p]={"position":avatars[p].global_position,"yaw":avatars[p].rotation.y,"velocity":avatars[p].velocity}
	var fish: Dictionary={}
	for id in fish_bodies: fish[id]=fish_bodies[id].pose_snapshot()
	var cells: Dictionary={}
	for id in supply_bodies: cells[id]=supply_bodies[id].pose_snapshot()
	return {"run_id":run.run_id,"players":players,"fish":fish,"supplies":cells,"hunter":hunter.global_transform if is_instance_valid(hunter) else Transform3D.IDENTITY}

func snapshot() -> Dictionary:
	if not session.is_host(): return snapshot_data
	var lamp_enabled: Dictionary={}
	for p in avatars: lamp_enabled[p]=bool(_input_for(p).get("lamp",true))
	var campaign: Dictionary=Campaign.status(progression.snapshot())
	var rescue_progress: Dictionary={}
	for p in revive_holds:
		if _active_rescue(p): rescue_progress[p]={"target":revive_holds[p].target,"held_s":run.elapsed_s-revive_holds[p].start}
	return {"protocol":Session.PROTOCOL,"build_id":Session.BUILD_ID,"run":run.snapshot(),"progression":progression.snapshot(),"campaign":campaign,"escape":mission.snapshot(campaign.can_escape,run.elapsed_s),
		"fishing":fishing.snapshot(),"cargo":cargo.snapshot(),"lights":lights.snapshot(),"choice":choice.snapshot(),
		"abilities":abilities.snapshot(),"director":director.active,"notes":notes.duplicate(true),"poses":_poses(),
		"hunter":hunter_rules.state,"hunter_target":hunter_target,"hunter_goal":patrol.goal,"supplies":supplies.snapshot(),"rescue_progress":rescue_progress,"trip_result":trip_result.duplicate(true),"keeper_position":keeper_position,"lamp_enabled":lamp_enabled,"cosmetic_catches":cosmetic_catches.duplicate(true)}

func _publish() -> void:
	if active and session.is_host() and progression!=null: session.publish_snapshot(snapshot())

func _snapshot_received(data: Dictionary) -> void:
	snapshot_data=data
	if not session.is_host():
		active=true
		_sync_fish(data)
		_sync_supplies(data)
		_poses_received(data.get("poses",{}))
	_refresh_world(data)

func _sync_fish(data: Dictionary) -> void:
	var all: Dictionary=data.get("cargo",{})
	for id in all:
		var c: Dictionary=all[id]
		if c.state in ["whole_loose","whole_held","bank_pending"] and c.delivery_mode=="whole" and not fish_bodies.has(id):
			var b=FishBody.new()
			b.setup(id,c.catch_record.species_id,true,str(c.catch_record.get("trait_id","oversized")))
			get_parent().add_child(b)
			b.set_host_simulated(false)
			fish_bodies[id]=b
	for id in fish_bodies.keys():
		if not all.has(id) or all[id].state in ["packed","banked","lost"]:
			fish_bodies[id].queue_free()
			fish_bodies.erase(id)

func _poses_received(data: Dictionary) -> void:
	if session.is_host(): return
	if data.has("run_id") and data.run_id!=snapshot_data.get("run",{}).get("run_id",""): return
	var presentation_run: String=str(data.get("run_id",snapshot_data.get("run",{}).get("run_id","")))
	var reset: bool=presentation_run!=_presentation_run_id
	_presentation_run_id=presentation_run
	for p in data.get("players",{}):
		if avatars.has(p):
			var a: Angler=avatars[p]
			var pose: Dictionary=data.players[p]
			a.apply_network_pose(pose,p==session.local_profile_id,reset)
	for id in data.get("fish",{}):
		if fish_bodies.has(id): fish_bodies[id].apply_network_pose(data.fish[id])
	for id in data.get("supplies",{}):
		if supply_bodies.has(id): supply_bodies[id].apply_network_pose(data.supplies[id])
	if data.has("hunter"):
		if not is_instance_valid(hunter): _create_hunter()
		var shown: Transform3D=hunter_visual.global_transform
		var snap_hunter: bool=reset or not _hunter_presenting or hunter.global_position.distance_to(data.hunter.origin)>3.0
		var duplicate: bool=_hunter_presenting and _hunter_visual_to.is_equal_approx(data.hunter)
		hunter.global_transform=data.hunter
		hunter_visual.top_level=true
		_hunter_presenting=true
		_hunter_visual_to=hunter.global_transform
		if snap_hunter or not duplicate:
			_hunter_visual_from=hunter.global_transform if snap_hunter else shown
			_hunter_visual_elapsed=PlayerScene.NETWORK_TRANSITION if snap_hunter else 0.0
			hunter_visual.global_transform=_hunter_visual_from
		hunter.visible=snapshot_data.get("run",{}).get("elapsed_s",0)>=180

func _process(delta: float) -> void:
	if not _hunter_presenting or not is_instance_valid(hunter_visual): return
	_hunter_visual_elapsed=minf(PlayerScene.NETWORK_TRANSITION,_hunter_visual_elapsed+maxf(0.0,delta))
	hunter_visual.global_transform=_hunter_visual_from.interpolate_with(_hunter_visual_to,_hunter_visual_elapsed/PlayerScene.NETWORK_TRANSITION)

func _refresh_world(data: Dictionary) -> void:
	if data.is_empty(): return
	var saved: Dictionary=data.get("progression",{})
	if saved.is_empty(): return
	world.set_time(data.run.elapsed_s)
	world.set_repaired(saved.repairs.get("return_walkway",false))
	world.set_campaign(saved.repairs)
	world.set_fog(data.get("director","")=="fog")
	for s in ["jetty","reeds"]:
		world.set_station(s,data.run.elapsed_s<630 and (data.run.elapsed_s<240 or data.run.elapsed_s<float(data.lights.get("station_until",{}).get(s,240))))
	var cache_map: Dictionary=IslandContent.cache_markers()
	for id in cache_map: world.set_cache_opened(cache_map[id],id in saved.opened_caches)
	for p in avatars:
		if not saved.profiles.has(p): continue
		avatars[p].downed=data.run.players.get(p,{}).get("downed",false)
		avatars[p].fishing=data.fishing.has(p)
		avatars[p].carrying=false
		avatars[p].being_carried=data.run.players.get(p,{}).get("carried_by","")!=""
		avatars[p].carrying_teammate=false
		for entry in data.run.players.values():
			if entry.get("carried_by","")==p: avatars[p].carrying_teammate=true
		for entry in data.cargo.values():
			if entry.carrier_id==p: avatars[p].carrying=true
		for entry in data.get("supplies",{}).values():
			if entry.carrier_id==p: avatars[p].carrying=true
		avatars[p].set_loadout(saved.profiles[p],float(data.lights.batteries.get(p,90)),bool(data.get("lamp_enabled",{}).get(p,true)))

func _sync_supplies(data: Dictionary) -> void:
	var current_run: String=str(data.get("run",{}).get("run_id",""))
	if current_run!=supply_run_id:
		for body in supply_bodies.values(): body.queue_free()
		supply_bodies.clear()
		supply_run_id=current_run
	var all: Dictionary=data.get("supplies",{})
	for id in all:
		if all[id].state!="consumed" and not supply_bodies.has(id):
			var b=CellBody.new()
			b.setup_cell(id)
			get_parent().add_child(b)
			b.set_host_simulated(false)
			supply_bodies[id]=b
	for id in supply_bodies.keys():
		if not all.has(id) or all[id].state=="consumed":
			supply_bodies[id].queue_free()
			supply_bodies.erase(id)

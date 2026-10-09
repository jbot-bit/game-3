extends Node3D
const Effects=preload("res://game/world/gameplay_effects.gd")

var world: IslandWorld
var session: Session
var controller: RunController
var camera: CrewCamera
var hud: GameHUD
var sounds: SoundCues
var effects: Node3D
var cast_was_active: bool=false
var request_sequence: int=0
var last_note: int=0
var input_tick: float=0
var lamp_on: bool=true
var reel_toggle: bool=false
var toggle_mode: bool=false
var held_reel: bool=false
var game_port: int=24563
var save_path: String="user://household.json"
var player_name: String="Angler"
var configured_profile: String=""
var first_game_frame: bool=true
var panel_blocked: bool=false
var host_addresses: Array[String]=[]

func _ready() -> void:
	for address in IP.get_local_addresses():
		if address.count(".")==3 and not address.begins_with("127.") and not address.begins_with("169.254."): host_addresses.append(address)
	world=IslandWorld.new()
	add_child(world)
	session=Session.new()
	session.name="Session"
	add_child(session)
	controller=RunController.new()
	add_child(controller)
	controller.configure(session,world)
	effects=Effects.new()
	add_child(effects)
	camera=CrewCamera.new()
	camera.current=true
	camera.fov=65
	add_child(camera)
	camera.position=world.markers.spawn+Vector3(4,6,11)
	camera.look_at(world.markers.spawn+Vector3(0,1,0))
	hud=GameHUD.new()
	add_child(hud)
	hud.host_requested.connect(_host)
	hud.join_requested.connect(_join)
	hud.action_requested.connect(_send)
	hud.leave_requested.connect(_leave)
	sounds=SoundCues.new()
	add_child(sounds)
	session.status_changed.connect(_status)
	session.intent_rejected.connect(func(_id: String,code: String): hud.toast(code.replace("_"," ").capitalize()))
	hud.show_menu()
	_parse_launch_args()

func _parse_launch_args() -> void:
	var args: PackedStringArray=OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--port="): game_port=int(a.trim_prefix("--port="))
		if a.begins_with("--save=") and OS.is_debug_build(): save_path=a.trim_prefix("--save=")
		if a.begins_with("--name="): player_name=a.trim_prefix("--name=")
	if "--host" in args: _host(player_name)
	for a in args:
		if a.begins_with("--join="): _join(a.trim_prefix("--join="),-1,player_name)

func _host(display_name: String) -> void:
	player_name=display_name
	var result: Dictionary=controller.prepare_host(save_path)
	if not result.ok:
		hud.show_menu("Cannot load/save household: "+result.code+". Existing saves have been preserved.")
		return
	if session.host(game_port)!=OK: return
	controller.start_day()
	_enter_game()

func _join(address: String,slot: int,display_name: String) -> void:
	player_name=display_name
	session.preferred_slot=slot
	session.join(address,game_port)

func _status(status: String,message: String) -> void:
	if status=="connected": _enter_game()
	elif status in ["offline","rejected"]:
		hud.show_menu(message)
		controller.active=false
	else: hud.toast(message)

func _enter_game() -> void:
	hud.show_game()
	first_game_frame=true
	configured_profile=""
	cast_was_active=false
	panel_blocked=false
	held_reel=false
	reel_toggle=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func _send(action: String,payload: Dictionary) -> void:
	if action=="set_audio":
		AudioServer.set_bus_mute(0,bool(payload.get("muted",false)))
		return
	request_sequence+=1
	session.submit_intent(action,payload,str(Time.get_ticks_msec())+":"+str(request_sequence))

func _leave() -> void:
	session.close()
	get_tree().reload_current_scene()

func _process(delta: float) -> void:
	if not controller.active: return
	var p: String=session.local_profile_id
	if p=="" or not controller.avatars.has(p): return
	var data: Dictionary=controller.snapshot_data
	if data.is_empty(): return
	effects.update_view(data,controller.avatars,world,delta)
	camera.target=controller.avatars[p]
	var refuge: Node3D=effects.refuge_target()
	if refuge!=null: camera.target=refuge
	var casting: bool=data.get("fishing",{}).has(p)
	if casting and not cast_was_active:
		var toward: Vector3=effects.cast_focus(p)-controller.avatars[p].global_position
		camera.yaw=atan2(-toward.x,-toward.z)
	cast_was_active=casting
	if first_game_frame:
		camera.position=camera.target.global_position+Vector3(0,4,7)
		first_game_frame=false
	camera.follow(delta)
	data=data.duplicate(false)
	data.is_host=session.is_host()
	data.host_addresses=host_addresses
	data.audio_muted=AudioServer.is_bus_mute(0)
	hud.update_view(data,p,_context().get("text",""))
	if configured_profile!=p and not data.run.paused and not data.run.terminal:
		configured_profile=p
		if player_name.strip_edges() not in ["","Angler"]: _send("set_name",{"name":player_name.strip_edges()})
	for note in data.get("notes",[]):
		if note.id>last_note:
			last_note=note.id
			if note.profile=="" or note.profile==p:
				hud.toast(note.text)
				var cue: String="warn" if "footsteps" in note.text or "down!" in note.text or "bell" in note.text or "warning" in note.text else ("bank" if "coins" in note.text else ("catch" if " m" in note.text else "click"))
				sounds.play_cue(cue)
	if not session.is_host():
		for id in controller.avatars:
			var a: Angler=controller.avatars[id]
			if id!=p: a.animate(delta,Vector2(a.velocity.x,a.velocity.z).length()/5)

func _physics_process(delta: float) -> void:
	if not controller or not controller.active: return
	if hud.panel_open():
		if not panel_blocked:
			held_reel=false
			reel_toggle=false
			_send("move",{"direction":Vector2.ZERO,"yaw":camera.yaw})
			_send("reel",{"held":false,"pull":0.0})
			_send("receive_fish",{"held":false})
		panel_blocked=true
		return
	panel_blocked=false
	var p: String=session.local_profile_id
	if not controller.avatars.has(p): return
	var raw=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	var direction: Vector2=_movement_intent(raw)
	var data: Dictionary=controller.snapshot_data
	var frozen: bool=data.get("run",{}).get("paused",false) or data.get("run",{}).get("terminal",false) or data.get("run",{}).get("crossing_left",-1)>=0
	if not session.is_host() and not frozen:
		controller.avatars[p].advance(delta,direction,camera.yaw,true)
	input_tick+=delta
	if input_tick<0.05 or frozen: return
	input_tick=0
	_send("move",{"direction":direction,"yaw":camera.yaw})
	var cast: Dictionary=data.get("fishing",{}).get(p,{})
	if not cast.is_empty():
		var mouse_reel: bool=reel_toggle if toggle_mode else held_reel
		var target_pull: float=float(cast.get("pull",0))
		var counter: float=-raw.x*signf(target_pull)
		_send("reel",{"held":mouse_reel,"pull":counter})
	_send("receive_fish",{"held":Input.is_physical_key_pressed(KEY_E)})
	if Input.is_physical_key_pressed(KEY_E):
		var context: Dictionary=_context()
		if context.get("action","")=="revive": _send("revive",context.payload)
	if Input.is_physical_key_pressed(KEY_P):
		var id: String=_held_id()
		if id!="": _send("pack_fish",{"catch_id":id,"held_s":0.0})

func _unhandled_input(event: InputEvent) -> void:
	if not controller or not controller.active: return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not hud.panel_open():
		camera.orbit(event.relative)
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		held_reel=event.pressed
		if event.pressed and not hud.panel_open():
			if _held_id()!="": _send("toss_fish",{"direction":-controller.avatars[session.local_profile_id].global_basis.z})
			elif _is_fishing():
				if toggle_mode: reel_toggle=not reel_toggle
			else:
				reel_toggle=true
				_send("cast",{})
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_ESCAPE:
			hud.toggle_panel("pause")
		KEY_K: hud.toggle_panel("workshop")
		KEY_J: hud.toggle_panel("journal")
		KEY_F8:
			if session.is_host(): hud.toggle_panel("host")
		KEY_T:
			toggle_mode=not toggle_mode
			reel_toggle=false
			hud.toast("Reel mode: "+("toggle" if toggle_mode else "hold"))
	if hud.panel_open(): return
	match event.physical_keycode:
		KEY_E:
			var context: Dictionary=_context()
			if context.has("action"):
				_send(context.action,context.get("payload",{}))
				if context.action=="open_vote": hud.toggle_panel("vote")
		KEY_Q: _send("use_ability",{"target_id":_teammate_target()})
		KEY_R: _send("assist",{"target_id":_teammate_target()})
		KEY_F:
			lamp_on=not lamp_on
			_send("toggle_lamp",{"enabled":lamp_on})
		KEY_V:
			if not controller.snapshot_data.get("choice",{}).get("open",false): _send("open_vote",{})
			hud.toggle_panel("vote")
		KEY_B: _send("ready",{"ready":true})
		KEY_X: _send("cancel_cast",{})
		KEY_G: _send("ping",{})

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		held_reel=false

func _held_id() -> String:
	for id in controller.snapshot_data.get("cargo",{}):
		var entry: Dictionary=controller.snapshot_data.cargo[id]
		if entry.carrier_id==session.local_profile_id and entry.state=="whole_held": return id
	return ""

func _movement_intent(raw: Vector2) -> Vector2:
	if _is_fishing() and absf(raw.y)<0.1: return Vector2.ZERO
	return camera.movement(raw).limit_length(1)

func _is_fishing() -> bool: return controller.snapshot_data.get("fishing",{}).has(session.local_profile_id)

func _at(marker: String,radius: float) -> bool:
	var p: String=session.local_profile_id
	return controller.avatars.has(p) and controller.avatars[p].global_position.distance_to(world.markers[marker])<radius

func _teammate_target() -> String:
	var p: String=session.local_profile_id
	var best: String=""
	var range_m: float=6
	for id in controller.avatars:
		if id==p: continue
		if not controller.snapshot_data.get("run",{}).get("players",{}).get(id,{}).get("downed",false) and not controller.snapshot_data.get("fishing",{}).has(id): continue
		var d: float=controller.avatars[p].global_position.distance_to(controller.avatars[id].global_position)
		if d<range_m:
			range_m=d
			best=id
	return best

func _context() -> Dictionary:
	var p: String=session.local_profile_id
	if not controller.avatars.has(p): return {}
	var a: Angler=controller.avatars[p]
	var data: Dictionary=controller.snapshot_data
	if data.get("run",{}).get("players",{}).get(p,{}).get("downed",false): return {"text":"CALL FOR HELP · your crew can revive you"}
	var teammate: String=_teammate_target()
	if teammate!="" and data.get("run",{}).get("players",{}).get(teammate,{}).get("downed",false) and a.global_position.distance_to(controller.avatars[teammate].global_position)<2.5:
		return {"text":"HOLD E · revive crewmate (3 seconds)","action":"revive","payload":{"target_id":teammate}}
	if _held_id()!="":
		return {"text":"LMB toss · E drop · HOLD P pack for normal value","action":"drop_fish"}
	var nearest: String=""
	var distance: float=2.0
	for id in controller.fish_bodies:
		if data.get("cargo",{}).get(id,{}).get("state","")!="whole_loose": continue
		var d: float=(a.global_position+Vector3.UP).distance_to(controller.fish_bodies[id].global_position)
		if d<distance:
			nearest=id
			distance=d
	if nearest!="": return {"text":"E · grab whole fish — bring it aboard for the bonus","action":"grab_fish","payload":{"catch_id":nearest}}
	if _at("boat",3): return {"text":"E bank · K workshop · B ready for refuge","action":"bank"}
	var cache_map: Dictionary={"lens_cache":"lido_workshop_cache","rod_cache":"shore_rod_cache","repair_cache":"walkway_parts_cache"}
	for marker in cache_map:
		if _at(marker,3) and cache_map[marker] not in data.get("progression",{}).get("opened_caches",[]):
			return {"text":"E · open "+marker.replace("_"," "),"action":"open_cache","payload":{"cache_id":cache_map[marker]}}
	if _at("repair",3) and not data.get("progression",{}).get("repairs",{}).get("return_walkway",false):
		return {"text":"E · repair walkway (one brass fitting)","action":"repair","payload":{"repair_id":"return_walkway"}}
	if _at("vote",4): return {"text":"E / V · choose tonight's battery destination","action":"open_vote"}
	if _is_fishing(): return {"text":"LMB reel · release to ease tension · A/D oppose pull · X cancel"}
	if _at("reeds",8): return {"text":"Reeds shelter · move beyond the lights to cast (8–12 m from this post)"}
	if _at("jetty",12) or _at("reeds",12): return {"text":"LMB · cast a line     T · toggle/hold reel mode"}
	return {"text":"Follow the square lamps · fish at Jetty or Reeds · J catch journal"}

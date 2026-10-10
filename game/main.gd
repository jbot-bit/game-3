extends Node3D
const Effects=preload("res://game/world/gameplay_effects.gd")
const SettingsModel=preload("res://game/ui/settings_local.gd")
const Content=preload("res://game/world/island_content.gd")

var world: IslandWorld
var session: Session
var controller: RunController
var camera: CrewCamera
var hud: GameHUD
var sounds: SoundCues
var effects: Node3D
var cast_was_active: bool=false
var last_cast_id: String=""
var request_sequence: int=0
var last_note: int=0
var input_tick: float=0
var lamp_on: bool=true
var reel_toggle: bool=false
var toggle_mode: bool=false
var held_reel: bool=false
var throw_charge: float=0.0
var throw_id: String=""
var throw_kind: String=""
var game_port: int=24563
var save_path: String="user://household.json"
var player_name: String="Angler"
var configured_profile: String=""
var first_game_frame: bool=true
var panel_blocked: bool=false
var host_addresses: Array[String]=[]
var settings_path: String="user://settings.json"
var settings: RefCounted
var reduced_effects: bool=false
var _unmuted_volume: float=1.0
var _applied_window_mode: String=""
var _hud_elapsed: float=0.1
var _hud_snapshot: Dictionary={}
var _hud_panel: String=""
var _debug_elapsed: float=0.0

func _ready() -> void:
	settings=SettingsModel.new(settings_path)
	settings.load_settings()
	host_addresses=_lan_address_candidates(IP.get_local_interfaces())
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
	camera.position=world.markers.vote+Vector3(10,9,15)
	camera.look_at(world.markers.vote+Vector3(0,1,0))
	hud=GameHUD.new()
	hud.configure_settings(settings)
	add_child(hud)
	hud.host_requested.connect(_host)
	hud.join_requested.connect(_join)
	hud.action_requested.connect(_send)
	hud.leave_requested.connect(_leave)
	hud.new_island_requested.connect(_new_island)
	hud.settings_changed.connect(_apply_settings)
	sounds=SoundCues.new()
	add_child(sounds)
	_apply_settings(settings.snapshot())
	session.status_changed.connect(_status)
	session.intent_rejected.connect(func(_id: String,code: String): hud.toast(code.replace("_"," ").capitalize()))
	hud.show_menu(settings.load_error)
	_parse_launch_args()

func _lan_address_candidates(interfaces: Array[Dictionary]) -> Array[String]:
	# Adapter identity matters: Windows can enumerate WSL/Hyper-V before Wi-Fi.
	# These are labelled candidates, not a claim that another PC can reach them.
	var groups: Array[Array]=[[],[],[]]
	for adapter in interfaces:
		var label: String=str(adapter.get("friendly","")).strip_edges()
		if label.is_empty(): label=str(adapter.get("name","Network")).strip_edges()
		var identity: String=(label+" "+str(adapter.get("name",""))).to_lower()
		var priority: int=1
		for physical in ["wi-fi","wifi","wireless","ethernet","wlan","eth"]:
			if identity.contains(physical): priority=0
		for virtual in ["virtual","vethernet","hyper-v","vmware","vbox","docker","wsl","vpn","tailscale","zerotier","wireguard","tap","tun"]:
			if identity.contains(virtual): priority=2
		for value in adapter.get("addresses",[]):
			var address: String=str(value)
			if not address.is_valid_ip_address() or address.count(".")!=3 or address.contains(":"): continue
			var first: int=int(address.get_slice(".",0))
			if first==0 or first==127 or first>=224 or address.begins_with("169.254."): continue
			groups[priority].append({"address":address,"label":("virtual: " if priority==2 else "")+label})
	var result: Array[String]=[]
	var seen: Dictionary={}
	for group in groups:
		for candidate in group:
			if seen.has(candidate.address): continue
			seen[candidate.address]=true
			result.append("%s (%s)"%[candidate.address,candidate.label])
	return result

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

func _new_island(display_name: String) -> void:
	# Only the menu's explicit confirmation can reset an inactive local household.
	if controller.active or session.status not in ["offline","rejected"] or not hud._menu.visible: return
	var store := SaveStore.new(save_path)
	var result: Dictionary=store.archive_and_reset(Progression.blank_state())
	if not result.ok:
		hud.show_menu("New Island could not start: %s. Existing saves and any recovery archive have been preserved." % result.code)
		return
	_host(display_name)
	if session.is_host(): hud.toast("New island created. Prior saves archived on this PC.")

func _apply_settings(values: Dictionary) -> void:
	var volume: float=float(values.get("master_volume",1.0))
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(volume,0.0001)))
	AudioServer.set_bus_mute(0,volume<=0.0)
	if volume>0.0: _unmuted_volume=volume
	camera.apply_settings(values)
	sounds.apply_settings(values)
	reduced_effects=bool(values.get("reduced_effects",false))
	if effects.has_method("set_reduced_effects"): effects.set_reduced_effects(reduced_effects)
	world.set_reduced_effects(reduced_effects)
	world.set_shadows_enabled(bool(values.get("shadows",false)))
	var mode: String=str(values.get("window_mode","windowed"))
	if mode==_applied_window_mode or DisplayServer.get_name()=="headless": return
	_applied_window_mode=mode
	# Godot fullscreen keeps the monitor's desktop resolution (borderless).
	if mode=="fullscreen":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	elif mode=="borderless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

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
	last_cast_id=""
	panel_blocked=false
	held_reel=false
	reel_toggle=false
	_cancel_throw()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func _send(action: String,payload: Dictionary) -> void:
	if action=="set_audio":
		hud._set_local_setting("master_volume",0.0 if bool(payload.get("muted",false)) else _unmuted_volume)
		return
	request_sequence+=1
	session.submit_intent(action,payload,str(Time.get_ticks_msec())+":"+str(request_sequence))

func _leave() -> void:
	session.close()
	get_tree().reload_current_scene()

func _process(delta: float) -> void:
	_debug_elapsed+=delta
	if hud.debug_enabled and _debug_elapsed>=0.25:
		_debug_elapsed=0.0
		var fps: float=Engine.get_frames_per_second()
		hud.update_debug({"fps":fps,"frame_ms":1000.0/maxf(1.0,fps),
			"role":"host" if session.is_host() else ("client" if session.status=="connected" else "offline"),
			"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	if not controller.active:
		sounds.update_view({},"",delta)
		return
	var p: String=session.local_profile_id
	if p=="" or not controller.avatars.has(p): return
	var data: Dictionary=controller.snapshot_data
	if data.is_empty(): return
	# The local identity already appears in the crew HUD. Keep the view clear
	# when the camera moves close to a wall or a large catch.
	controller.avatars[p].name_tag.visible=false
	sounds.update_view({} if hud.panel_open() else data,p,delta)
	if throw_id!="":
		if data.run.paused or data.run.terminal or hud.panel_open(): _cancel_throw()
		else: throw_charge=minf(1.0,throw_charge+delta/0.8)
	effects.update_view(data,controller.avatars,world,delta)
	camera.target=controller.avatars[p]
	var refuge: Node3D=effects.refuge_target()
	if refuge!=null: camera.target=refuge
	var casting: bool=data.get("fishing",{}).has(p)
	var cast_id: String=str(data.get("fishing",{}).get(p,{}).get("catch_id",""))
	if casting and (not cast_was_active or cast_id!=last_cast_id) and not reduced_effects:
		var toward: Vector3=effects.cast_focus(p)-controller.avatars[p].global_position
		camera.yaw=atan2(-toward.x,-toward.z)
	cast_was_active=casting
	last_cast_id=cast_id
	if first_game_frame:
		camera.position=camera.target.global_position+Vector3(0,4,7)
		first_game_frame=false
	camera.follow(delta)
	_hud_elapsed+=delta
	if _hud_elapsed>=0.1 or not is_same(data,_hud_snapshot) or _hud_panel!=hud._panel_kind:
		_hud_elapsed=0.0
		_hud_snapshot=data
		_hud_panel=hud._panel_kind
		var view: Dictionary=data.duplicate(false)
		view.is_host=session.is_host()
		view.host_addresses=host_addresses
		view.audio_muted=AudioServer.is_bus_mute(0)
		view.throw_charge=throw_charge
		view.near_battery=_at("vote",4)
		view.reel_toggle_mode=toggle_mode
		view.reel_active=reel_toggle if toggle_mode else held_reel
		hud.update_view(view,p,_context().get("text",""))
	if configured_profile!=p and not data.run.paused and not data.run.terminal:
		configured_profile=p
		if player_name.strip_edges() not in ["","Angler"]: _send("set_name",{"name":player_name.strip_edges()})
	for note in data.get("notes",[]):
		if note.id>last_note:
			last_note=note.id
			if note.get("kind","")=="toss" and controller.avatars.has(note.profile):
				controller.avatars[note.profile].visual.play_action("throw")
			if note.profile=="" or note.profile==p:
				hud.toast(note.text)
				sounds.play_cue(str(note.get("kind","info")))
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
			_cancel_throw()
			_send("move",{"direction":Vector2.ZERO,"yaw":camera.yaw})
			_send("reel",{"held":false,"pull":0.0})
			_send("receive_fish",{"held":false})
		panel_blocked=true
		return
	panel_blocked=false
	var p: String=session.local_profile_id
	if not controller.avatars.has(p): return
	var raw: Vector2=_raw_movement()
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
	_send("receive_fish",{"held":settings.pressed("interact")})
	if settings.pressed("interact"):
		var context: Dictionary=_context()
		if context.get("action","")=="revive": _send("revive",context.payload)
	if settings.pressed("pack"):
		var id: String=_held_id()
		if id!="": _send("pack_fish",{"catch_id":id,"held_s":0.0})

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F3:
		hud.toggle_debug()
		return
	if not controller or not controller.active: return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not hud.panel_open():
		camera.orbit(event.relative)
	if event is InputEventMouseButton and event.pressed and not hud.panel_open():
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: camera.zoom(1.0)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN: camera.zoom(-1.0)
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		held_reel=event.pressed
		if event.pressed and not hud.panel_open():
			if _held_id()!="" or _held_cell()!="":
				throw_kind="toss_fish" if _held_id()!="" else "toss_cell"
				throw_id=_held_id() if _held_id()!="" else _held_cell()
				throw_charge=0.0
			elif _is_fishing():
				if toggle_mode: reel_toggle=not reel_toggle
			else:
				reel_toggle=true
				_send("cast",{})
	if not event is InputEventKey or not event.pressed or event.echo: return
	if settings.event_matches(event,"pause"): hud.toggle_panel("pause")
	elif settings.event_matches(event,"workshop"): hud.toggle_panel("workshop")
	elif settings.event_matches(event,"journal"): hud.toggle_panel("journal")
	elif settings.event_matches(event,"host_panel") and session.is_host(): hud.toggle_panel("host")
	elif settings.event_matches(event,"toggle_reel"):
		toggle_mode=not toggle_mode
		reel_toggle=false
		hud.toast("Reel mode: "+("toggle" if toggle_mode else "hold"))
	if hud.panel_open(): return
	if settings.event_matches(event,"interact"):
		var context: Dictionary=_context()
		if context.has("action"):
			_send(context.action,context.get("payload",{}))
			if context.action=="open_vote": hud.toggle_panel("vote")
	elif settings.event_matches(event,"ability"): _send("use_ability",{"target_id":_teammate_target()})
	elif settings.event_matches(event,"assist"):
		var target: String=_teammate_target()
		if _carried_teammate()!="": _send("drop_teammate",{})
		elif target!="" and controller.snapshot_data.get("run",{}).get("players",{}).get(target,{}).get("downed",false): _send("carry_teammate",{"target_id":target})
		else: _send("assist",{"target_id":target})
	elif settings.event_matches(event,"toggle_lamp"):
		lamp_on=not lamp_on
		_send("toggle_lamp",{"enabled":lamp_on})
	elif settings.event_matches(event,"vote"):
		if not controller.snapshot_data.get("choice",{}).get("open",false): _send("open_vote",{})
		hud.toggle_panel("vote")
	elif settings.event_matches(event,"ready"): _send("ready",{"ready":true})
	elif settings.event_matches(event,"cancel_cast"): _send("cancel_cast",{})
	elif settings.event_matches(event,"ping"): _send("ping",{})

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		held_reel=false
		if throw_id!="":
			var held: String=_held_id() if throw_kind=="toss_fish" else _held_cell()
			if held==throw_id and not hud.panel_open():
				_send("move",{"direction":_movement_intent(_raw_movement()),"yaw":camera.yaw})
				_send(throw_kind,{"strength":throw_charge})
			_cancel_throw()

func _cancel_throw() -> void:
	throw_id=""
	throw_kind=""
	throw_charge=0.0

func _held_cell() -> String:
	for id in controller.snapshot_data.get("supplies",{}):
		var entry: Dictionary=controller.snapshot_data.supplies[id]
		if entry.carrier_id==session.local_profile_id and entry.state=="held": return id
	return ""

func _carried_teammate() -> String:
	for id in controller.snapshot_data.get("run",{}).get("players",{}):
		if controller.snapshot_data.run.players[id].get("carried_by","")==session.local_profile_id: return id
	return ""

func _held_id() -> String:
	for id in controller.snapshot_data.get("cargo",{}):
		var entry: Dictionary=controller.snapshot_data.cargo[id]
		if entry.carrier_id==session.local_profile_id and entry.state=="whole_held": return id
	return ""

func _raw_movement() -> Vector2:
	return Vector2(float(settings.pressed("move_right"))-float(settings.pressed("move_left")),
		float(settings.pressed("move_back"))-float(settings.pressed("move_forward")))

func _movement_intent(raw: Vector2) -> Vector2:
	if _is_fishing() and absf(raw.y)<0.1: return Vector2.ZERO
	return camera.movement(raw).limit_length(1)

func _is_fishing() -> bool: return controller.snapshot_data.get("fishing",{}).has(session.local_profile_id)

func _at(marker: String,radius: float) -> bool:
	var p: String=session.local_profile_id
	return world.markers.has(marker) and controller.avatars.has(p) and controller.avatars[p].global_position.distance_to(world.markers[marker])<radius

func _teammate_target() -> String:
	var p: String=session.local_profile_id
	var best: String=""
	var range_m: float=6
	if not controller.avatars.has(p): return best
	var profile: Dictionary=controller.snapshot_data.get("progression",{}).get("profiles",{}).get(p,{})
	if profile.get("role_id","")=="rigger" and profile.get("tool_mode","")=="alternate": range_m=8.5
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
	var interact: String=settings.key_label("interact")
	if data.get("run",{}).get("players",{}).get(p,{}).get("downed",false): return {"text":"CALL FOR HELP · your crew can revive you"}
	if _carried_teammate()!="": return {"text":"%s · put crewmate down"%interact,"action":"drop_teammate"}
	var teammate: String=_teammate_target()
	if teammate!="" and data.get("run",{}).get("players",{}).get(teammate,{}).get("downed",false) and a.global_position.distance_to(controller.avatars[teammate].global_position)<2.5:
		return {"text":"Hold %s · revive crewmate" % interact,"action":"revive","payload":{"target_id":teammate}}
	if _held_id()!="":
		if _at("boat",3): return {"text":"%s · Bank fish"%interact,"action":"bank"}
		return {"text":"Hold LMB · Throw    %s · Drop"%interact,"action":"drop_fish"}
	if _held_cell()!="":
		for station in ["jetty","reeds"]:
			if _at(station,3): return {"text":"%s · Power light (+90s)"%interact,"action":"feed_station","payload":{"station_id":station}}
		return {"text":"LMB · Throw cell    %s · Drop"%interact,"action":"drop_cell"}
	for id in controller.supply_bodies:
		if data.get("supplies",{}).get(id,{}).get("state","")=="free" and (a.global_position+Vector3.UP).distance_to(controller.supply_bodies[id].global_position)<2:
			return {"text":"%s · Pick up power cell"%interact,"action":"grab_cell","payload":{"cell_id":id}}
	var nearest: String=""
	var distance: float=2.0
	for id in controller.fish_bodies:
		if data.get("cargo",{}).get(id,{}).get("state","")!="whole_loose": continue
		var d: float=(a.global_position+Vector3.UP).distance_to(controller.fish_bodies[id].global_position)
		if d<distance:
			nearest=id
			distance=d
	if nearest!="": return {"text":"%s · Pick up fish" % interact,"action":"grab_fish","payload":{"catch_id":nearest}}
	if data.get("escape",{}).get("can_signal",false) and _at("beacon_repair",3):
		return {"text":"%s · Signal the boat" % interact,"action":"signal_escape"}
	if _at("boat",3): return _boat_context(data,p,interact)
	var cache_map: Dictionary=Content.cache_markers()
	for id: String in cache_map:
		if _at(cache_map[id],3) and id not in data.get("progression",{}).get("opened_caches",[]):
			return {"text":"%s · open %s" % [interact,Content.cache(id).get("name",id.replace("_"," "))],"action":"open_cache","payload":{"cache_id":id}}
	for id: String in Content.repair_markers():
		if _at(Content.repair_markers()[id],3) and not data.get("progression",{}).get("repairs",{}).get(id,false):
			var repair: Dictionary=Content.repair(id)
			return {"text":"%s · %s (%s)" % [interact,repair.name,repair.requirements],"action":"repair","payload":{"repair_id":id}}
	if _at("vote",4): return {"text":"%s · Choose tonight's shelter" % interact,"action":"open_vote"}
	if _is_fishing(): return {"text":""}
	if _at("reeds",8): return {"text":"Cast beyond the shelter"}
	var habitat: String=world.fishing_habitat(a.global_position)
	if not habitat.is_empty(): return {"text":"LMB · Cast"}
	return {"text":""}

func _boat_context(data: Dictionary, profile: String, interact: String) -> Dictionary:
	for catch_entry: Dictionary in data.get("cargo",{}).values():
		if catch_entry.get("state","")=="packed" and catch_entry.get("pouch_profile_id","")==profile:
			return {"text":"%s · Bank catch"%interact,"action":"bank"}
	if bool(data.get("escape",{}).get("can_arm",false)):
		return {"text":"%s · Prepare night escape"%interact,"action":"arm_escape"}
	var saved: Dictionary=data.get("progression",{})
	if not bool(saved.get("repairs",{}).get("moth_engine",false)):
		if CampaignRules.requirements_met(saved,Content.repair("moth_engine")):
			return {"text":"%s · Fit engine (80 coins)"%interact,"action":"repair","payload":{"repair_id":"moth_engine"}}
		return {"text":"Find the engine part · %s journal / %s gear"%[settings.key_label("journal"),settings.key_label("workshop")]}
	if bool(data.get("escape",{}).get("can_signal",false)):
		return {"text":"Signal the beacon, then bring everyone aboard"}
	return {"text":"%s · Ready aboard    %s · Journal"%[settings.key_label("ready"),settings.key_label("journal")]}

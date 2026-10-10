extends SceneTree
## Rendered, real-time automated outing. Regular controller intents only;
## no clock jumps, teleports, forced catches or changes to household progress.
const Game = preload("res://game/main.gd")
var app: Node3D
var sequence: int = 0
var report: Dictionary = {"events":[], "casts":[], "phases":[], "automated":true, "time_scale":1.0}
var label: String = "before"
var started: int
var last_phase: String = ""
var last_telemetry: float = -30.0
var last_note: int = 0
var active: bool = false
var ending: bool = false

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--outing-label="): label = arg.trim_prefix("--outing-label=").validate_filename()
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	root.gui_disable_input = true
	Engine.max_fps = 60
	app = Game.new()
	app.game_port = 24883
	var fixture: String = "user://tests/outing-" + str(Time.get_ticks_usec())
	app.settings_path = fixture + "-settings.json"
	app.save_path = fixture + "-household.json"
	root.add_child(app)
	app.set_process_input(false)
	app.set_process_unhandled_input(false)
	app.set_physics_process(false)
	app.hud.set_process_input(false)
	app.hud.set_process_unhandled_input(false)
	AudioServer.set_bus_mute(0,true)
	app.hud.host_requested.emit("Harbour")
	app.controller.rng.seed = 1607
	started = Time.get_ticks_msec()
	active = true
	await create_timer(0.4).timeout
	await capture("start")
	await fish_at("jetty")
	await fish_at("jetty")
	await bank()
	await visit_cache("shore_rod_cache", "rod_cache")
	await capture("rod-discovered")
	await visit_cache("walkway_parts_cache", "repair_cache")
	await walk_to(app.world.markers.repair)
	action("repair", {"repair_id":"return_walkway"})
	await bank()
	action("equip_rod", {"rod_id":"soft_tip"})
	await visit_cache("lido_workshop_cache", "lens_cache")
	await fish_at("terraces")
	await visit_cache("tide_engine_cache", "engine_cache")
	await fish_at("tidepools")
	await visit_cache("beacon_parts_cache", "beacon_parts_cache")
	await bank()
	await walk_to(app.world.markers.workshop_repair)
	action("repair", {"repair_id":"workshop"})
	await walk_to(app.world.markers.vote)
	action("open_vote", {})
	action("vote", {"choice":"reeds"})
	await capture("prepared")
	while now() < 235.0 and not terminal():
		await fish_at("jetty")
		if now() > 210.0: break
	await bank()
	await walk_to(app.world.markers.reeds_cast)
	while now() < 560.0 and not terminal():
		for habitat: String in ["reeds", "beacon", "tidepools"]:
			if terminal() or now() >= 560.0: break
			await fish_at(habitat)
			if threatened():
				log_event("retreat_from_warning", {"hunter":app.controller.hunter_rules.state})
				await take_cover()
		if not terminal(): await bank()
	if not terminal():
		await bank()
		while now() < 595.0 and not terminal(): await create_timer(0.2).timeout
		action("ready", {"ready":true})
		await capture("return")
	while not terminal() and Time.get_ticks_msec()-started < 690000:
		await create_timer(0.2).timeout
	await create_timer(0.5).timeout
	await capture("outcome")
	report.final = app.controller.snapshot()
	report.wall_seconds = float(Time.get_ticks_msec()-started)/1000.0
	report.completed = terminal()
	active = false
	write_report()
	print("FULL_OUTING_DONE ",JSON.stringify({"completed":report.completed,"wall_seconds":report.wall_seconds,"phase":app.controller.run.phase,"result":app.controller.trip_result,"casts":report.casts.size()}))
	app.session.close()
	quit(0 if report.completed else 1)

func _process(_delta: float) -> bool:
	if not active or app == null or not app.controller.active: return false
	var phase: String = app.controller.run.phase
	if phase != last_phase:
		last_phase = phase
		report.phases.append({"phase":phase,"elapsed":now()})
		log_event("phase", {"phase":phase})
		capture.call_deferred(phase)
	for note: Dictionary in app.controller.snapshot_data.get("notes", []):
		if int(note.id) > last_note:
			last_note = int(note.id)
			log_event("notice", {"text":note.text,"kind":note.kind})
	if now()-last_telemetry >= 30.0:
		last_telemetry = now()
		var saved: Dictionary = app.controller.progression.snapshot()
		log_event("telemetry", {"position":app.controller.avatars.crew_1.global_position,"coins":saved.coins,"discoveries":saved.discoveries,"lamp":app.controller.lights.batteries.get("crew_1",0),"hunter":app.controller.hunter_rules.state,"context":app._context().get("text",""),"clock":app.hud._stats.text,"advice":app.hud._vote_notice.text if app.hud._vote_notice.visible else ""})
		write_report()
	return false

func now() -> float: return app.controller.run.elapsed_s
func terminal() -> bool: return app.controller.run.terminal
func threatened() -> bool: return app.controller.hunter_target == "crew_1" and app.controller.hunter_rules.state in ["warn","chase"]

func action(kind: String, payload: Dictionary) -> Dictionary:
	sequence += 1
	var result: Dictionary = app.controller.apply_intent(1,kind,payload,"outing-"+str(sequence))
	if kind not in ["move","reel","pack_fish"]: log_event(kind,result)
	return result

func walk_to(destination: Vector3, respond_to_warning: bool = true) -> bool:
	if terminal(): return false
	var actor: Node3D = app.controller.avatars.crew_1
	var deadline: int = Time.get_ticks_msec()+30000
	while actor.global_position.distance_to(destination)>1.0 and Time.get_ticks_msec()<deadline and not terminal():
		if respond_to_warning and threatened():
			var interrupted_at: int = Time.get_ticks_msec()
			await take_cover()
			deadline += Time.get_ticks_msec()-interrupted_at
			if terminal(): break
		var waypoint: Vector3 = app.world.route_step(actor.global_position,destination)
		var toward: Vector3 = waypoint-actor.global_position
		var direction := Vector2(toward.x,toward.z).normalized()
		action("move",{"direction":direction,"yaw":atan2(-direction.x,-direction.y)})
		await create_timer(0.05).timeout
	action("move",{"direction":Vector2.ZERO,"yaw":app.camera.view_yaw()})
	await create_timer(0.15).timeout
	var arrived: bool = actor.global_position.distance_to(destination)<1.5
	if not arrived: log_event("walk_failed",{"at":actor.global_position,"destination":destination,"terminal":terminal()})
	return arrived

func take_cover() -> void:
	# Follow the game's visible light/shelter advice instead of blindly running
	# the long route to Moth past the pursuer, as the first diagnostic run did.
	var actor: Node3D = app.controller.avatars.crew_1
	var destination: Vector3 = app.world.markers.boat
	var shelter: String = "Moth"
	for station: String in ["jetty","reeds"]:
		var candidate: Vector3 = app.world.markers[station]
		if app.controller.lights.station_powered(station,now()) and actor.global_position.distance_to(candidate)<actor.global_position.distance_to(destination):
			destination = candidate
			shelter = station
	action("cancel_cast",{})
	log_event("take_cover",{"shelter":shelter,"distance":actor.global_position.distance_to(destination)})
	await walk_to(destination,false)
	await capture("cover-"+str(report.casts.size()))
	while threatened() and not terminal(): await create_timer(0.1).timeout
	await create_timer(1.0).timeout

func fish_at(habitat: String) -> void:
	if terminal(): return
	var place: Vector3 = app.world.markers.reeds_cast if habitat=="reeds" else app.world.markers[habitat]
	if not await walk_to(place): return
	if threatened(): return
	var began: float = now()
	var saved_count: int = app.controller.progression.snapshot().landed_catch_ids.size()
	if not action("cast",{}).ok: return
	var reeling: bool = true
	var deadline: int = Time.get_ticks_msec()+65000
	while app.controller.fishing.casts.has("crew_1") and not terminal() and Time.get_ticks_msec()<deadline:
		if threatened():
			action("cancel_cast",{})
			break
		var state: Dictionary = app.controller.fishing.casts.crew_1
		reeling=float(state.fish_position)>float(state.bar_position)
		app.held_reel=reeling
		action("reel",{"held":reeling,"pull":0.0})
		await create_timer(0.05).timeout
	app.held_reel=false
	await create_timer(0.25).timeout
	var landed: bool = app.controller.progression.snapshot().landed_catch_ids.size()>saved_count
	var detail: Dictionary = {"habitat":habitat,"seconds":now()-began,"landed":landed,"phase":app.controller.run.phase}
	report.casts.append(detail)
	log_event("fishing_result",detail)
	await capture("catch-"+str(report.casts.size()))
	for id: String in app.controller.cargo.snapshot():
		var entry: Dictionary = app.controller.cargo.snapshot()[id]
		if entry.state=="whole_loose" and entry.catch_record.profile_id=="crew_1":
			if action("grab_fish",{"catch_id":id}).ok:
				for tick: int in range(14):
					action("pack_fish",{"catch_id":id})
					await create_timer(0.05).timeout

func bank() -> void:
	if await walk_to(app.world.markers.boat): action("bank",{})

func visit_cache(cache: String, marker: String) -> void:
	if await walk_to(app.world.markers[marker]): action("open_cache",{"cache_id":cache})

func capture(stage: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://logs/outing-"+label+"-"+stage.validate_filename()+".png")

func log_event(kind: String, details: Dictionary) -> void:
	var event: Dictionary = {"elapsed":snappedf(now(),0.1),"event":kind,"details":details}
	report.events.append(event)
	print("OUTING ",JSON.stringify(event))

func write_report() -> void:
	var file := FileAccess.open("res://logs/outing-"+label+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()

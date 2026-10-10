extends SceneTree
## Native rendered wall-clock frame samples, plus bounded CPU call timings.
## Three host-owned avatar fixtures are not three networked clients.
const Game=preload("res://game/main.gd")
var app: Node3D
var label: String="baseline"
var sample_seconds: float=15.0
var report: Dictionary={}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--perf-label="): label=arg.trim_prefix("--perf-label=").validate_filename()
		if arg.begins_with("--perf-seconds="): sample_seconds=clampf(float(arg.trim_prefix("--perf-seconds=")),3.0,20.0)
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("PERFORMANCE_PROBE_REQUIRES_NATIVE_RENDERER")
		quit(1)
		return
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(1280,720)
	root.gui_disable_input=true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	app=Game.new()
	app.settings_path="user://tests/performance-settings-"+str(Time.get_ticks_usec())+".json"
	app.save_path="user://tests/performance-save-"+str(Time.get_ticks_usec())+".json"
	app.game_port=24635
	root.add_child(app)
	app._host("Performance")
	# A native probe must not absorb typing/clicks from the user's desktop.
	app.set_process_input(false)
	app.set_process_unhandled_input(false)
	app.set_physics_process(false)
	app.hud.set_process_input(false)
	app.hud.set_process_unhandled_input(false)
	for peer in [2,3]: app.session.roster.assign(peer,peer-1,Session.BUILD_ID)
	app.controller._roster_changed(app.session.roster.snapshot())
	AudioServer.set_bus_mute(0,true)
	report={"label":label,"build_id":Session.BUILD_ID,"renderer":DisplayServer.get_name(),"gpu":RenderingServer.get_video_adapter_name(),"resolution":[1280,720],"vsync":false,"sample_seconds":sample_seconds,"avatars":3,"real_network_clients":0,"native_input_blocked":true,"cases":[],"cpu_calls":[]}
	await sample_case("day_fast",60.0,false)
	await sample_case("night_fast",300.0,false)
	await sample_case("day_shadows",60.0,true)
	await sample_case("night_shadows",300.0,true)
	app.set_process(false)
	app.set_physics_process(false)
	app.controller.set_physics_process(false)
	var c: Node=app.controller
	var snapshot: Dictionary=c.snapshot()
	measure("snapshot_three_avatars",func(): c.snapshot(),50)
	measure("refresh_world_unchanged",func(): c._refresh_world(snapshot),30)
	measure("route_beacon_to_terraces",func(): app.world.route_step(app.world.markers.beacon,app.world.markers.terraces),30)
	measure("route_short_direct",func(): app.world.route_step(app.world.markers.reeds,app.world.markers.reeds+Vector3(0,0,3)),30)
	measure("uncached_ground_and_collision_segment",func(): app.world._route_segment(app.world.markers.beacon,app.world.markers.terraces),30)
	c.hunter.global_position=app.world.markers.beacon
	c._hunter_route_to(app.world.markers.terraces,"patrol",0.25)
	c._hunter_route_left=1000.0
	measure("cached_waypoint_hot",func(): c._hunter_route_to(app.world.markers.terraces,"patrol",1.0/60.0),50)
	c._hunter_route_left=0.0
	measure("player_tick_three_avatars",func(): c._tick_players(1.0/60.0),30)
	c.run.elapsed_s=60.0
	measure("hunter_tick_day",func(): c._tick_hunter(1.0/60.0),120)
	c.run.elapsed_s=300.0
	measure("hunter_tick_night",func(): c._tick_hunter(1.0/60.0),120)
	var output: String="res://logs/performance-"+label+".json"
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("PERFORMANCE_PROBE_OK "+ProjectSettings.globalize_path(output))
	print(JSON.stringify(report))
	app.session.close()
	quit(0)

func sample_case(case_name: String, elapsed: float, shadows: bool) -> void:
	# Keep timing independent from screenshots. The separate native render
	# probes capture visuals; waiting on frame_post_draw can stall if hidden.
	await process_frame
	print("PERFORMANCE_STAGE "+case_name+" configuring")
	var settings: Dictionary=app.settings.snapshot()
	settings.shadows=shadows
	settings.reduced_effects=false
	app._apply_settings(settings)
	var c: Node=app.controller
	c.run.elapsed_s=elapsed
	c.run.phase="day" if elapsed<240 else "night"
	c.inputs.clear()
	c.choice=CrewChoice.new()
	c.vote_invited=true
	app.camera.yaw=0.0
	app.camera.pitch=-0.45
	c.hunter.global_position=app.world.markers.beacon
	c.hunter.velocity=Vector3.ZERO
	c.patrol=PatrolRules.new()
	c.hunter_rules=HunterRules.new()
	for id in c.avatars:
		c.avatars[id].global_position=app.world.markers.spawn+Vector3(c._slot(id)*2.5,0,0)
		c.avatars[id].last_dry=c.avatars[id].global_position
		c.avatars[id].velocity=Vector3.ZERO
		c.avatars[id].rotation.y=0.0
	c._publish()
	app.first_game_frame=true
	print("PERFORMANCE_STAGE "+case_name+" warming")
	var warm_until: int=Time.get_ticks_usec()+4000000
	var warm_samples: Array[float]=[]
	var warm_previous: int=Time.get_ticks_usec()
	while Time.get_ticks_usec()<warm_until:
		await process_frame
		var warm_now: int=Time.get_ticks_usec()
		warm_samples.append(float(warm_now-warm_previous)/1000.0)
		warm_previous=warm_now
	var samples: Array[float]=[]
	var process_samples: Array[float]=[]
	var physics_samples: Array[float]=[]
	var start: int=Time.get_ticks_usec()
	var previous: int=start
	print("PERFORMANCE_STAGE "+case_name+" sampling")
	while Time.get_ticks_usec()-start<int(sample_seconds*1000000.0):
		await process_frame
		var now: int=Time.get_ticks_usec()
		samples.append(float(now-previous)/1000.0)
		process_samples.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
		physics_samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
		previous=now
	var result: Dictionary={"name":case_name,"warmup_frame_ms":stats(warm_samples),"wall_frame_ms":stats(samples),"engine_process_ms":stats(process_samples),"engine_physics_ms":stats(physics_samples),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"static_memory_mb":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0,"video_memory_mb":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0,"avatar_position":str(c.avatars.crew_1.global_position),"camera_yaw":app.camera.yaw,"camera_pitch":app.camera.pitch}
	result.configuration={"shadows":shadows,"reduced_effects":false,"msaa":root.msaa_3d}
	report.cases.append(result)
	print("PERFORMANCE_CASE "+JSON.stringify(result))

func measure(name: String, work: Callable, count: int) -> void:
	var samples: Array[float]=[]
	for index in range(count):
		var start: int=Time.get_ticks_usec()
		work.call()
		samples.append(float(Time.get_ticks_usec()-start)/1000.0)
	report.cpu_calls.append({"name":name,"ms":stats(samples)})

func stats(samples: Array[float]) -> Dictionary:
	var ordered: Array[float]=samples.duplicate()
	ordered.sort()
	var total: float=0.0
	var over_budget: int=0
	for value in samples:
		total+=value
		if value>16.667: over_budget+=1
	return {"count":samples.size(),"mean":total/float(samples.size()),"p50":ordered[int(floor(float(ordered.size()-1)*0.50))],"p95":ordered[int(floor(float(ordered.size()-1)*0.95))],"p99":ordered[int(floor(float(ordered.size()-1)*0.99))],"max":ordered[-1],"over_16_7ms":over_budget}

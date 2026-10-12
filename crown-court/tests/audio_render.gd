extends SceneTree

var app
var checks: Array[Dictionary] = []
var output = "res://tests/audio-render"
var settings_existed = false
var settings_bytes = PackedByteArray()
var profile_path = ""
var pack_source = ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output = arg.trim_prefix("--evidence-dir=")
		if arg.begins_with("--pack-source="): pack_source = arg.trim_prefix("--pack-source=")
	run.call_deferred()

func expect(ok: bool, label: String, observed = null) -> void:
	checks.append({"check":label,"passed":ok,"observed":observed})
	print("PASS " if ok else "FAIL ",label," ",observed if observed != null else "")

func key(code: Key, pressed: bool) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func frames(count: int) -> void:
	for index in count: await physics_frame

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	settings_existed = FileAccess.file_exists("user://settings.cfg")
	if settings_existed: settings_bytes = FileAccess.get_file_as_bytes("user://settings.cfg")
	app = load("res://main.gd").new()
	app.manual_input_enabled = false
	profile_path = "user://audio_render_%d.json" % Time.get_ticks_usec()
	app.profile = load("res://profile.gd").new(profile_path)
	root.add_child(app)
	app.muted = false
	await frames(2)
	var bank = app.sounds
	expect(DisplayServer.get_name() != "headless" and bank.voices.size() == 10, "Rendered app allocates ten real playback voices")
	var started = 0
	for kind in ["grab","bounce","rim","land","tackle","dive","jump","double_jump"]:
		if bank.play_event(kind): started += 1
	expect(started == 8 and bank.voices.slice(0,8).all(func(voice):return voice.playing), "Eight collision voices are concurrently playing", started)
	expect(not bank.play_event("throw"), "Full collision pool drops excess sound rather than cutting a voice")
	expect(bank.play_event("throw", 1.0, true) and bank.voices.slice(0,8).filter(func(voice):return voice.playing).size() == 8, "Local action can replace one ambient voice without increasing the voice budget")
	expect(bank.play_event("score") and bank.voices[9].playing, "Score starts while all collision voices are occupied")
	var score_stream = bank.voices[9].stream
	var score_position = bank.voices[9].get_playback_position()
	expect(bank.play_event("countdown") and bank.voices[8].playing, "Countdown has an independent reserved voice")
	var before_count: int = bank.played_count
	for index in 30: bank.play_event("tackle")
	expect(bank.played_count == before_count, "Same-frame repeated tackles do not add more playback")
	await frames(2)
	expect(bank.voices[9].playing and bank.voices[9].stream == score_stream and bank.voices[9].get_playback_position() >= score_position, "Collision pressure does not restart or cut the score cue")
	await frames(40)
	app.practice_game("versus")
	app.manual_input_enabled = true
	await frames(195)
	var step_before: int = int(bank.variations.get("step",0))
	key(KEY_W,true)
	await frames(75)
	var forward: Vector3 = app.sim.players[1].vel
	key(KEY_W,false)
	key(KEY_S,true)
	await frames(1)
	var first_reverse: Vector3 = app.sim.players[1].vel
	await frames(30)
	var reversed: Vector3 = app.sim.players[1].vel
	key(KEY_S,false)
	await frames(20)
	expect(forward.z < -4 and first_reverse.z < 0 and reversed.z > 0, "Actual keyboard reversal keeps momentum then changes direction", [forward.z,first_reverse.z,reversed.z])
	expect(bank.last_played.has("skid"), "Actual movement reversal emits a skid sample through HUD integration")
	expect(int(bank.variations.get("step",0)) > step_before, "Actual running emits quiet step samples")
	key(KEY_SPACE,true)
	await frames(1)
	key(KEY_SPACE,false)
	await frames(16)
	key(KEY_SPACE,true)
	await frames(1)
	key(KEY_SPACE,false)
	await frames(90)
	app.set_process(false)
	app.set_physics_process(false)
	await frames(35)
	app.sim.reset_time = 0
	app.sim.celebration_time = 0
	app.sim.winner = -1
	for id in [1,2]:
		app.sim.players[id].stun = 0
		app.sim.players[id].dunk = 0
		app.sim.players[id].grounded = true
		app.sim.players[id].jump_count = 0
		app.sim.players[id].pos = Vector3((id-1)*3,0,0)
	app.sim.ball.owner = 1
	app.state = app.sim.snapshot()
	app.state.match_id = app.match_id
	app.update_hud(1.0/60)
	await frames(35)
	bank.last_played.erase("throw")
	bank.last_played.erase("jump")
	app.sim.action(1,"throw",.6)
	app.sim.action(2,"jump")
	app.state = app.sim.snapshot()
	app.state.match_id = app.match_id
	app.update_hud(1.0/60)
	expect(bank.last_played.has("throw") and bank.last_played.has("jump"), "Two accepted actions between updates both reach native playback")
	expect(bank.voices.slice(0,8).filter(func(voice):return voice.playing).size() >= 2, "Concurrent local throw and nearby jump have live audio voices")
	var delivered: int = bank.played_count
	app.update_hud(1.0/60)
	expect(bank.played_count == delivered, "Repeated HUD frames do not replay the delivered action sounds")
	await frames(30)
	var report = {"checks":checks,"passed":checks.all(func(item):return item.passed),"driver":"native InputEventKey reversal and jumps plus explicit audio-pool saturation fixture","display":DisplayServer.get_name(),"played_count":bank.played_count,"families":bank.variations,"source_hashes":{}}
	if pack_source.is_empty():
		for path in ["main.gd","audio.gd","sim.gd","world.gd"]: report.source_hashes[path] = FileAccess.get_sha256("res://"+path)
	else:
		report["pack_sha256"] = FileAccess.get_sha256(pack_source)
	var file = FileAccess.open(output.path_join("result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("AUDIO RENDER ",JSON.stringify({"passed":report.passed,"checks":checks.size(),"played_count":bank.played_count}))
	app.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(profile_path+suffix): DirAccess.remove_absolute(profile_path+suffix)
	if settings_existed:
		var settings_file = FileAccess.open("user://settings.cfg",FileAccess.WRITE)
		settings_file.store_buffer(settings_bytes)
	elif FileAccess.file_exists("user://settings.cfg"):
		DirAccess.remove_absolute("user://settings.cfg")
	quit(0 if report.passed else 1)

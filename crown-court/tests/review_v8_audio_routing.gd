extends SceneTree

class SoundSpy extends Node:
	var calls: Array = []
	func play_event(kind: String, strength: float = 1.0, local_priority: bool = false) -> bool:
		calls.append({"kind":kind,"strength":strength,"local_priority":local_priority})
		return true
	func update_motion(_player: Dictionary, _dt: float) -> void:
		pass

var checks: Array = []
var output := "C:/game-3/build/crown-court-evidence/v8-audio-routing-red"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output = arg.trim_prefix("--evidence-dir=")
	run.call_deferred()

func expect(ok: bool, label: String, observed: Variant = null) -> void:
	checks.append({"ok":ok,"label":label,"observed":observed})
	print("PASS " if ok else "FAIL ",label," ",observed if observed != null else "")

func run() -> void:
	var app = load("res://main.gd").new()
	var profile_path := "user://audio_routing_%d.json" % Time.get_ticks_usec()
	app.profile = load("res://profile.gd").new(profile_path)
	app.manual_input_enabled = false
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app.practice_game("coop")
	app.muted = false
	app.sim.reset_time = 0
	app.sim.celebration_time = 0
	app.sim.players[1].pos = Vector3.ZERO
	app.sim.players[4].pos = Vector3(4,0,0)
	app.sim.ball.owner = 1
	app.state = app.sim.snapshot()
	app.state.match_id = app.match_id
	app.sounds.queue_free()
	var spy := SoundSpy.new()
	app.add_child(spy)
	app.sounds = spy
	app.update_hud(1.0/60)
	spy.calls.clear()
	# These are accepted gameplay actions, between two ordinary presentation updates.
	app.sim.action(1,"throw",.6)
	var throw_id: int = app.sim.event_id
	app.sim.action(4,"jump")
	app.state = app.sim.snapshot()
	app.state.match_id = app.match_id
	app.update_hud(1.0/60)
	expect(app.sim.throws == 1 and app.sim.players[4].jump_count == 1,"Both throw and jump genuinely occurred in simulation")
	expect(spy.calls.any(func(c):return c.kind == "throw"),"Local throw sound survives a later remote action before HUD delivery",spy.calls.duplicate(true))
	expect(spy.calls.any(func(c):return c.kind == "jump"),"Nearby remote jump remains audible",spy.calls.duplicate(true))
	var delivered := spy.calls.size()
	app.update_hud(1.0/60)
	expect(spy.calls.size() == delivered,"Repeated rendering does not replay delivered sounds")
	spy.calls.clear()
	app.sim.emit("grab", "", app.sim.players[4].pos, 4)
	app.state = app.sim.snapshot()
	app.state.match_id = app.match_id
	app.update_hud(1.0/60)
	expect(spy.calls.size() == 1 and spy.calls[0].kind == "grab", "Nearby opponent catch produces one contact cue")
	spy.calls.clear()
	app.sim.emit("jump", "", Vector3(19,0,35), 4)
	app.state = app.sim.snapshot()
	app.state.match_id = app.match_id
	app.update_hud(1.0/60)
	expect(spy.calls.is_empty(), "Far court actions do not add minimum-volume noise")
	app.muted = true
	app.sim.emit("throw", "", Vector3.ZERO, 1)
	app.state = app.sim.snapshot()
	app.state.match_id = app.match_id
	app.update_hud(1.0/60)
	app.muted = false
	app.update_hud(1.0/60)
	expect(spy.calls.is_empty(), "Unmute does not replay events consumed while muted")
	app.paused = true
	app.sim.emit("tackle", "", Vector3.ZERO, 1)
	app.state = app.sim.snapshot()
	app.state.match_id = app.match_id
	app.update_hud(1.0/60)
	app.paused = false
	app.update_hud(1.0/60)
	expect(spy.calls.is_empty(), "Resume does not replay queued impact noise")
	app.sim.emit("jump", "", Vector3.ZERO, 1)
	app.state = app.sim.snapshot()
	app.state.match_id = "new-round"
	app.update_hud(1.0/60)
	expect(spy.calls.is_empty(), "New round seeds the sound cursor without historical replay")
	app.sim.emit("grab", "", Vector3.ZERO, 1)
	app.sim.ball.owner = 1
	app.state = app.sim.snapshot()
	app.state.match_id = "new-round"
	app.update_hud(1.0/60)
	expect(spy.calls.size() == 1 and spy.calls[0].kind == "grab", "History plus ownership transition never doubles a local catch")
	spy.calls.clear()
	app.sim.emit("throw", "", Vector3.ZERO, 1)
	app.state = app.sim.snapshot()
	app.state.match_id = "new-round"
	app.state.event_clock += 1.0
	app.update_hud(1.0/60)
	expect(spy.calls.is_empty(), "Expired history cannot create a late sound burst")
	app.sim.emit("jump", "", Vector3.ZERO, 4)
	app.sim.emit("throw", "", Vector3.ZERO, 1)
	app.state = app.sim.snapshot()
	app.state.match_id = "new-round"
	# Restore a valid monotonic receive clock after the explicit stale fixture.
	app._sound_event_clock = float(app.state.event_clock)
	app.update_hud(1.0/60)
	expect(spy.calls.size() == 2 and spy.calls[0].kind == "throw", "Local action gets a playback slot before concurrent remote effects")
	spy.calls.clear()
	app.sim.emit("throw", "", Vector3.ZERO, 1)
	app.state = app.sim.snapshot()
	app.state.match_id = "new-round"
	var valid: Array = app.state.recent_events[-1].duplicate()
	app.state.recent_events = [valid, valid.duplicate(), [int(app.state.event_id)+1,"jump",Vector3.ZERO,1,app.state.event_clock], [int(app.state.event_id),"jump","bad-position",1,app.state.event_clock], [int(app.state.event_id),"jump",Vector3.ZERO,1,NAN]]
	app.update_hud(1.0/60)
	app.update_hud(1.0/60)
	expect(spy.calls.size() == 1 and spy.calls[0].kind == "throw", "Duplicate, future-ID and malformed event records cannot repeat or break playback")
	DirAccess.make_dir_recursive_absolute(output)
	var report := {"checks":checks,"ok":checks.all(func(c):return c.ok),"throw_id":throw_id,"latest_event_id":app.sim.event_id,"latest_kind":app.sim.event_kind,"calls":spy.calls,"scope":"Headless actual Sim action -> production HUD routing with sound-call spy; not an audio audition"}
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	app.queue_free()
	await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(profile_path+suffix): DirAccess.remove_absolute(profile_path+suffix)
	quit(0 if report.ok else 1)

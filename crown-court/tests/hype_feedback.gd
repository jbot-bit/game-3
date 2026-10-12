extends SceneTree

class Probe extends "res://tests/controller_app.gd":
	func save_settings() -> void:
		pass # UI selection must never change the real player's settings.

var app
var results: Array = []
var evidence = ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="): evidence = argument.trim_prefix("--evidence-dir=")
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	results.append({"passed":ok,"check":label})
	print("PASS " if ok else "FAIL ",label)

func refresh() -> void:
	app.state = app.sim.snapshot()
	app.state["match_id"] = app.match_id
	app.update_hud(1.0/60)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless" or evidence.is_empty(): return
	DirAccess.make_dir_recursive_absolute(evidence)
	if app.phase == "match": app.world.present(app.state,1,1.0/60,0,.43)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence.path_join(label+".png"))

func press_hype(controller: bool) -> void:
	var event: InputEvent
	if controller:
		var button = InputEventJoypadButton.new()
		button.device = 7
		button.button_index = JOY_BUTTON_Y
		button.pressed = true
		event = button
	else:
		var key = InputEventKey.new()
		key.keycode = KEY_Q
		key.physical_keycode = KEY_Q
		key.pressed = true
		event = key
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	print("HYPE_INPUT ", JSON.stringify({"controller":controller,"pressed":Input.is_action_pressed("hype"),"just_pressed":Input.is_action_just_pressed("hype"),"armed":app.input_armed,"neutral":app.controller_neutral,"paused":app.paused}))
	app.read_controls(1.0/60)
	event = event.duplicate()
	if event is InputEventKey: event.pressed = false
	else: event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame

func run() -> void:
	app = Probe.new()
	app.profile = app.Profile.new("user://hype_feedback_unused_%d.json" % Time.get_ticks_usec())
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app.manual_input_enabled = false
	app.muted = true
	app.power_select.select(1)
	app.power_select.item_selected.emit(1)
	check(app.selected_power == "pad", "Power selection still selects the real ability")
	var description = app.get("power_description")
	check(is_instance_valid(description) and "launch" in str(description.text).to_lower(), "Selection explains the chosen power's effect")
	await capture("01-menu-power")
	app.practice_game("coop")
	app.sim.reset_time = 0
	app.sim.players[1].pos = Vector3.ZERO
	app.input_armed = true
	refresh()
	await process_frame
	check(app.hype_ring.power == "Jump pad", "HUD keeps the selected name while charging")
	check(str(app.hype_ring.get("status_text")) == "0%", "Empty Hype reports its charge")
	await press_hype(false)
	refresh()
	check(str(app.hype_ring.get("status_text")) == "Not ready", "Q below full charge gives feedback without activation")
	check(app.sim.players[1].hype == 0 and app.sim.power_pads.is_empty(), "Unavailable press cannot grant a power")
	app.ui_clock += 1.3
	app.sim.players[1].hype = 16
	refresh()
	check(str(app.hype_ring.get("status_text")) == "+16 Hype", "Authoritative earned charge is acknowledged once")
	app.ui_clock += 1.3
	refresh()
	check(str(app.hype_ring.get("status_text")) == "16%", "Earned notice expires without replay")
	app.sim.players[1].hype = 100
	refresh()
	check(str(app.hype_ring.get("status_text")) == "Ready", "Full Hype is explicitly ready")
	await capture("02-hype-ready")
	app.discovered_devices.assign([7])
	app.device_label = "DualSense Wireless Controller"
	app.configure_controller()
	await process_frame
	app.controller_neutral = true
	app.input_armed = true
	refresh()
	check(app.hype_ring.key == "△", "DualSense ready prompt uses Triangle")
	await press_hype(true)
	refresh()
	check(app.sim.power_pads.size() == 1 and app.sim.players[1].hype == 0, "Parsed top-button activates exactly one selected power")
	check(str(app.hype_ring.get("status_text")) == "Active 14s", "Placed power lifetime is authoritative and visible")
	await capture("03-hype-active")
	if not app.sim.power_pads.is_empty(): app.sim.power_pads[0].time = 2.1
	refresh()
	check(str(app.hype_ring.get("status_text")) == "Active 3s", "Active timer follows the received lifetime")
	app.sim.power_pads.clear()
	app.sim.players[1].power = "giant"
	app.sim.players[1].giant = 6.2
	refresh()
	check(str(app.hype_ring.get("status_text")) == "Active 7s", "Giant lifetime uses the player state")
	app.sim.players[1].giant = 0
	app.sim.players[1].power = "blast"
	app.sim.power_balls = [{"owner":1,"time":1.6}]
	refresh()
	check(str(app.hype_ring.get("status_text")) == "Active 2s", "Homing power lifetime uses the owned projectile")
	app.sim.power_balls.clear()
	app.sim.players[1].hype = 100
	refresh()
	app.sim.players[1].hype = 0
	refresh()
	check(str(app.hype_ring.get("status_text")) == "Activated", "A quick homing hit still acknowledges authoritative activation")
	app.ui_clock += 1.3
	refresh()
	check(str(app.hype_ring.get("status_text")) == "0%", "Expired activation cannot replay or look ready")
	app.sim.players[1].hype = 100
	app.device_label = "Nintendo Switch Pro Controller"
	refresh()
	check(app.hype_ring.key == "X", "Nintendo top button uses X without changing its action")
	app.device_label = "Generic gamepad"
	refresh()
	check(app.hype_ring.key == "Top", "Unknown controller uses an unambiguous positional label")
	app.sim.players[1].stun = .2
	refresh()
	check(str(app.hype_ring.get("status_text")) == "Recovering", "Full meter does not promise activation during stun")
	app.sim.players[1].stun = 0
	app.sim.reset_time = 2
	refresh()
	check(not app.hype_ring.visible, "Kickoff does not offer an unusable power")
	var passed = results.all(func(result): return result.passed)
	if not evidence.is_empty():
		DirAccess.make_dir_recursive_absolute(evidence)
		var file = FileAccess.open(evidence.path_join("result.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"passed":passed,"checks":results,"physical_controller_tested":false},"\t"))
	app.queue_free()
	await process_frame
	print("HYPE FEEDBACK: %d checks, %d failures" % [results.size(),results.filter(func(result): return not result.passed).size()])
	quit(0 if passed else 1)

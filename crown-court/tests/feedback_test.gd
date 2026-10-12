extends SceneTree

var failures = 0
var checks = 0

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func run() -> void:
	var app = load("res://tests/controller_app.gd").new()
	app.profile = load("res://profile.gd").new("user://feedback_probe_%d.json" % Time.get_ticks_usec())
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app.manual_input_enabled = false
	app.practice_game("coop")
	app.sim.reset_time = 0.0
	app.state = app.sim.snapshot()
	app.update_hud(1.0 / 60)
	expect(app.possession_label.visible, "Possession has a persistent readable cue")
	# Snapshot arrival can skip the score event when a subsequent action is newer.
	app.state.scores[0] = 1
	app.state.event_id += 3
	app.state.event_kind = "jump"
	app.update_hud(1.0 / 60)
	expect(app.event_label.text == "Your team +1\nTakes the lead!", "Score is announced even when its event was overwritten")
	app.state.event_id += 1
	app.state.event_kind = "bounce"
	app.update_hud(1.0 / 60)
	expect(app.event_label.text == "Your team +1\nTakes the lead!", "Unrelated ball bounce does not erase score feedback")
	app.build_hud()
	app.update_hud(1.0 / 60)
	expect(app.event_label.text.is_empty(), "New HUD baselines existing scores without phantom point")
	app.state.scores[1] = 1
	app.update_hud(.016)
	expect(app.event_label.text == "Bots +1\nAll tied!", "Equalizer credits the correct team with tie feedback")
	app.ui_clock += 2.0
	app.update_hud(.016)
	expect(app.event_label.text.is_empty(), "Repeated score snapshots cannot renew an expired celebration")
	app.state.time_left = 31.0
	app.update_hud(.016)
	app.state.time_left = 30.0
	app.update_hud(.016)
	expect(app.event_label.text == "30 seconds!", "Actual HUD announces the final thirty seconds once")
	expect(app.goal_flash.color.a == 0.0, "Clock announcement cannot trigger a goal flash")
	app.ui_clock += 3.0
	app.update_hud(.016)
	expect(app.event_label.text.is_empty(), "Repeated clock snapshot cannot renew a clock cue")
	app.state.time_left = 9.0
	app.update_hud(.016)
	expect(app.event_label.text == "10 seconds!", "Snapshot gap across final ten seconds preserves the milestone")
	app.ui_clock += 3.0
	app.state.time_left = 0.0
	app.update_hud(.016)
	expect(app.event_label.text == "Overtime!", "Live zero clock announces overtime")
	app.build_hud()
	app.update_hud(.016)
	expect(app.event_label.text.is_empty(), "New HUD baselines a late clock without phantom urgency")
	app.state.time_left = 60.0
	# Follow the authoritative hoop and terrain when arena dimensions change.
	var dunk_position: Vector3 = app.sim.hoop(1)
	dunk_position.z -= signf(dunk_position.z) * app.Sim.DUNK_RANGE * .5
	dunk_position.y = app.Sim.floor_height(dunk_position.x,dunk_position.z) + 2.0
	app.state.players[1].pos = dunk_position
	app.state.players[1].grounded = false
	app.state.players[1].jump_count = 1
	app.state.ball.owner = 1
	app.update_hud(1.0 / 60)
	expect(app.can_dunk() and app.prompt_label.text == "F  Dunk", "Keyboard dunk prompt uses only the active device")
	app.discovered_devices.assign([11])
	app.device_label = "DualSense Wireless Controller"
	app.controller_device = 11
	app.update_hud(1.0 / 60)
	expect(app.can_dunk() and app.prompt_label.text == "Circle  Dunk", "PlayStation dunk prompt names the physical button")
	app.state.reset_time = 2.0
	app.update_hud(1.0 / 60)
	expect(app.event_label.text == "2" and not app.prompt_label.visible, "Countdown suppresses live action prompt")
	app.state.reset_time = 0
	app.ui_clock = 50
	app.state.ball.owner = 0
	app.state.players[1].stun = 0
	app.update_hud(.016)
	app.state.event_id += 1
	app.state.event_kind = "tackle"
	app.state.players[1].stun = .5
	app.update_hud(.016)
	expect(app.event_label.text == "Tackled", "Empty-handed tackle does not claim a ball was lost")
	app.ui_clock += 1
	app.state.players[1].stun = 0
	app.state.ball.owner = 1
	app.update_hud(.016)
	app.state.ball.owner = 0
	app.state.players[1].stun = .5
	app.state.event_id += 1
	app.update_hud(.016)
	expect(app.event_label.text == "Ball lost", "Tackle of the carrier reports lost possession")
	print("FEEDBACK: %d checks, %d failures" % [checks, failures])
	app.queue_free()
	await process_frame
	quit(1 if failures else 0)

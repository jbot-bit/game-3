extends GutTest

const Network = preload("res://prototypes/physics_party/party_session.gd")

func controls() -> Dictionary:
	return {"move": Vector2(0, -1), "yaw": 0.0, "pitch": 0.0, "jump": false, "left": false, "right": false, "limp": false, "tick": 1}

func test_controls_reject_nonfinite_speed_and_unexpected_fields() -> void:
	assert_true(Network.valid_controls(controls()))
	var invalid = controls()
	invalid.move = Vector2(INF, 0)
	assert_false(Network.valid_controls(invalid))
	invalid.move = Vector2(2, 0)
	assert_false(Network.valid_controls(invalid))
	invalid = controls()
	invalid.yaw = NAN
	assert_false(Network.valid_controls(invalid))
	invalid = controls()
	invalid.teleport = Vector3(100, 0, 0)
	assert_false(Network.valid_controls(invalid))

func test_controls_require_boolean_buttons_and_sequence() -> void:
	var invalid = controls()
	invalid.jump = "yes"
	assert_false(Network.valid_controls(invalid))
	invalid = controls()
	invalid.erase("tick")
	assert_false(Network.valid_controls(invalid))

func test_grapple_controls_accept_both_modes_and_legacy_payloads() -> void:
	assert_true(Network.valid_controls(controls()), "Existing neutral probe schema remains accepted")
	for mode in ["pull", "swing"]:
		var data = controls()
		data.merge({"grapple": true, "grapple_mode": mode, "aim": Vector3(0, 2, -12)})
		assert_true(Network.valid_controls(data), "Extended input accepts " + mode)

func test_teamwork_controls_accept_only_a_held_boolean_button() -> void:
	var data = controls()
	data.merge({"grapple": false, "grapple_mode": "pull", "aim": Vector3.ZERO, "interact": true})
	assert_true(Network.valid_controls(data))
	data.interact = false
	assert_true(Network.valid_controls(data))
	data.interact = 1
	assert_false(Network.valid_controls(data))
	data.interact = true
	data.latch_stage = 3
	assert_false(Network.valid_controls(data), "Clients send a held button, never stage completion")

func test_match_controls_accept_buttons_but_never_client_hit_claims() -> void:
	var data: Dictionary = controls()
	data.merge({"grapple": false, "grapple_mode": "pull", "aim": Vector3.ZERO, "interact": false, "attack": true, "brace": true})
	assert_true(Network.valid_controls(data))
	data.attack = 1
	assert_false(Network.valid_controls(data))
	data.attack = true
	data.hit_player = "crew_2"
	assert_false(Network.valid_controls(data))

func test_grapple_controls_reject_partial_unknown_and_nonfinite_aim() -> void:
	var data = controls()
	data.grapple = true
	assert_false(Network.valid_controls(data))
	data.merge({"grapple_mode": "pull", "aim": Vector3.ZERO})
	for bad_aim in [Vector3(NAN, 0, 0), Vector3(INF, 0, 0), Vector3(513, 0, 0), "target"]:
		data.aim = bad_aim
		assert_false(Network.valid_controls(data), "Reject malformed or unbounded aim")
	data.aim = Vector3.ZERO
	data.grapple_mode = "teleport"
	assert_false(Network.valid_controls(data))
	data.grapple_mode = "swing"
	data.grapple = 1
	assert_false(Network.valid_controls(data))
	data.grapple = true
	data.erase("aim")
	data.anchor = Vector3.ZERO
	assert_false(Network.valid_controls(data), "Unknown replacement key rejected")

func test_names_cannot_inject_newlines_into_hud() -> void:
	assert_eq(Network.clean_name("\nDad\t\n"), "Dad")
	assert_eq(Network.clean_name(""), "Player")
	assert_eq(Network.clean_name("abcdefghijklmnopqrstuvwxyz").length(), 20)

func test_restart_is_host_only_and_unknown_actions_are_rejected() -> void:
	var network = Network.new()
	add_child_autofree(network)
	watch_signals(network)
	network._dispatch("crew_2", "restart", "")
	network._dispatch("crew_2", "next_course", "")
	network._dispatch("crew_2", "teleport", "")
	network._dispatch("", "power", "spring")
	assert_signal_not_emitted(network, "action_received")
	network._dispatch("crew_1", "restart", "")
	assert_signal_emitted_with_parameters(network, "action_received", ["crew_1", "restart", ""])
	network._dispatch("crew_1", "next_course", "")
	assert_signal_emitted_with_parameters(network, "action_received", ["crew_1", "next_course", ""])

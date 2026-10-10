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

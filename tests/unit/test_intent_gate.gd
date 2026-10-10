extends GutTest

const RosterModel = preload("res://game/session/roster.gd")
const GateModel = preload("res://game/session/intent_gate.gd")

func test_supply_rescue_and_charged_throw_are_valid_network_actions() -> void:
	var roster=RosterModel.new()
	roster.assign(2,1,Session.BUILD_ID)
	var gate=GateModel.new()
	for action in {"grab_cell":{"cell_id":"cell_1"},"toss_cell":{"strength":0.5},"drop_cell":{},"feed_station":{"station_id":"jetty"},"carry_teammate":{"target_id":"crew_3"},"drop_teammate":{},"toss_fish":{"strength":1.0}}:
		var payloads={"grab_cell":{"cell_id":"cell_1"},"toss_cell":{"strength":0.5},"drop_cell":{},"feed_station":{"station_id":"jetty"},"carry_teammate":{"target_id":"crew_3"},"drop_teammate":{},"toss_fish":{"strength":1.0}}
		assert_true(gate.authorize(2,action,payloads[action],roster).ok,action)
	assert_false(gate.authorize(2,"toss_cell",{"strength":NAN},roster).ok)
	assert_false(gate.authorize(2,"feed_station",{"station_id":"jetty","remaining":999},roster).ok)

func test_connection_determines_profile_and_payload_cannot_impersonate() -> void:
	var roster = RosterModel.new()
	roster.assign(2, 1, "0.4.0-tide")
	var gate = GateModel.new()
	assert_eq(gate.authorize(2, "cast", {}, roster).profile_id, "crew_2")
	assert_eq(gate.authorize(2, "cast", {"profile_id": "crew_1"}, roster).code, "invalid_payload")
	assert_eq(gate.authorize(2, "bank", {"coins": 999}, roster).code, "invalid_payload")

func test_stale_connection_and_unknown_action_are_rejected() -> void:
	var roster = RosterModel.new()
	roster.assign(2, 1, "0.4.0-tide")
	var gate = GateModel.new()
	assert_eq(gate.authorize(2, "grant_fish", {}, roster).code, "unknown_action")
	roster.disconnect_peer(2)
	assert_eq(gate.authorize(2, "move", {}, roster).code, "unknown_sender")

func test_host_controls_and_pause_are_enforced_in_handler_boundary() -> void:
	var roster = RosterModel.new()
	roster.assign(1, 0, "0.4.0-tide")
	roster.assign(2, 1, "0.4.0-tide")
	var gate = GateModel.new()
	assert_eq(gate.authorize(2, "host_event", {"event_id": "fog"}, roster).code, "not_host")
	gate.set_paused(true)
	assert_eq(gate.authorize(1, "cast", {}, roster).code, "paused")
	assert_true(gate.authorize(1, "pause", {"paused": false}, roster).ok)
	assert_true(gate.authorize(1, "host_event", {"event_id": "safe_return"}, roster).ok)
	assert_eq(gate.authorize(1, "host_event", {"event_id": "fog"}, roster).code, "paused")

func test_nonfinite_or_oversized_payload_cannot_enter_simulation() -> void:
	var roster = RosterModel.new()
	roster.assign(2, 1, "0.4.0-tide")
	var gate = GateModel.new()
	assert_eq(gate.authorize(2, "move", {"direction": Vector3(INF, 0, 0)}, roster).code, "invalid_payload")
	assert_eq(gate.authorize(2, "grab_fish", {"catch_id": "x".repeat(200)}, roster).code, "invalid_payload")

func test_listen_host_dispatches_once_and_rejects_replayed_request() -> void:
	var session_script: GDScript = load("res://game/session/session.gd")
	var session = add_child_autofree(session_script.new())
	assert_eq(session.host(24664), OK)
	assert_eq(session.local_profile_id, "crew_1")
	watch_signals(session)
	session.submit_intent("cast", {}, "host-request-1")
	session.submit_intent("cast", {}, "host-request-1")
	assert_signal_emit_count(session, "intent_received", 1)
	session.close()

func test_profile_lamp_and_vote_intents_allow_only_expected_types() -> void:
	var roster = RosterModel.new()
	roster.assign(2, 1, "0.4.0-tide")
	var gate = GateModel.new()
	assert_true(gate.authorize(2, "set_profile", {"name": "Crew", "role_id": "keeper"}, roster).ok)
	assert_true(gate.authorize(2, "toggle_lamp", {"enabled": true}, roster).ok)
	assert_true(gate.authorize(2, "open_vote", {}, roster).ok)
	assert_eq(gate.authorize(2, "move", {"direction": "invalid"}, roster).code, "invalid_payload")
	assert_eq(gate.authorize(2, "toggle_lamp", {"enabled": "yes"}, roster).code, "invalid_payload")

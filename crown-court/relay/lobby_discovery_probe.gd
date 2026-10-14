extends SceneTree
var app
var role = "host"
var elapsed = 0.0
var match_started = -1.0
var reported = false
var clicked = false
var joined = false
var endpoint = ""
var test_label = "DISCOVERY HOST"
func _initialize():
	boot.call_deferred()
func button(node: Node, label: String) -> Button:
	if node is Button and label in node.text: return node
	for child in node.get_children():
		var found = button(child, label)
		if found: return found
	return null
func boot():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("role="): role = arg.trim_prefix("role=")
		if arg.begins_with("url="): endpoint = arg.trim_prefix("url=")
		if arg.begins_with("label="): test_label = arg.trim_prefix("label=")
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	if endpoint.is_empty(): app.room_server_url = "ws://127.0.0.1:30220/rooms"
	elif app.room_server_url != endpoint:
		push_error("Published default server address does not match live service")
		quit(1)
		return
	app.muted = true
	app.nickname = test_label if role == "host" else role
	app.show_menu()
	var control = button(app, "Host online game" if role == "host" else "Find online game")
	if not control:
		push_error("Missing online menu control")
		quit(1)
		return
	control.pressed.emit()
func _process(dt):
	elapsed += dt
	if not is_instance_valid(app) or reported: return false
	if elapsed > 22:
		push_error("Click-to-join test timed out: " + role + " phase " + app.phase)
		quit(1)
		return false
	if role == "host" and app.phase == "lobby" and not clicked:
		clicked = true
		print("ROOM_TEST_CODE " + app.room_code)
	if role != "host" and not joined:
		var join_button = button(app, test_label)
		if join_button:
			joined = true
			join_button.pressed.emit()
	if role == "host" and app.phase == "lobby" and app.seats.size() == 3: app.start_match()
	if app.phase == "match":
		if match_started < 0: match_started = elapsed
		if elapsed - match_started > (8.0 if role == "host" else 5.0):
			if role != "host" and app.snapshot_count < 10:
				push_error("Joined but no live match snapshots")
				quit(1)
				return false
			reported = true
			print("ROOM_RPC_PASS ", role, ": menu host, automatic discovery, click Join, three players, live match")
			finish.call_deferred()
	return false
func finish():
	app.close_session("")
	await create_timer(.35).timeout
	quit(0)

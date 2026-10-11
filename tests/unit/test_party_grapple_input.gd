extends GutTest
const Game = preload("res://prototypes/physics_party/main.gd")

func test_neutral_controls_release_grapple_and_preserve_selected_mode() -> void:
	var app = Game.new()
	app.teamwork_enabled = false # Isolate the original course/input/save subsystem.
	add_child_autofree(app)
	var neutral: Dictionary = app._neutral()
	assert_eq(neutral.get("grapple"), false, "Menus, completion and stale input must detach")
	assert_eq(neutral.get("grapple_mode"), "pull")
	assert_eq(neutral.get("aim"), Vector3.ZERO)

func test_mode_key_only_changes_during_unblocked_gameplay() -> void:
	var app = Game.new()
	app.teamwork_enabled = false # Isolate the original course/input/save subsystem.
	add_child_autofree(app)
	app.set_physics_process(false)
	app.set_process(false)
	var event = InputEventKey.new()
	event.physical_keycode = KEY_G
	event.pressed = true
	app._unhandled_input(event)
	assert_eq(app.get("grapple_mode"), "pull", "Typing a name cannot switch the grapple")
	app.session.connected = true
	app.state = {"phase": "play"}
	app.hud.show_game()
	app._unhandled_input(event)
	assert_eq(app.get("grapple_mode"), "swing")
	event.echo = true
	app._unhandled_input(event)
	assert_eq(app.get("grapple_mode"), "swing", "Held key repeats cannot cycle modes")
	event.echo = false
	app._unhandled_input(event)
	assert_eq(app.get("grapple_mode"), "pull")
	app.session.connected = false

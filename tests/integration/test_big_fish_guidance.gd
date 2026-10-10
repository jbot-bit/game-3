extends GutTest
const Game = preload("res://game/main.gd")
var app: Node3D
var old_size: Vector2i
var old_scale: Vector2i
var catch_id: String = "guidance-catch"

func before_each() -> void:
	old_size = get_tree().root.size
	old_scale = get_tree().root.content_scale_size
	get_tree().root.size = Vector2i(960,540)
	get_tree().root.content_scale_size = Vector2i(960,540)
	app = Game.new()
	var stamp: String = str(Time.get_ticks_usec())
	app.save_path = "user://tests/big-fish-guidance-" + stamp + ".json"
	app.settings_path = "user://tests/big-fish-settings-" + stamp + ".json"
	app.game_port = 24942
	add_child_autofree(app)
	app._host("Angler")
	app.set_physics_process(false)
	app.set_process(false)
	app.controller.set_physics_process(false)
	var actor: Angler = app.controller.avatars.crew_1
	actor.global_position = app.world.markers.jetty
	actor.last_dry = actor.global_position
	var record: Dictionary = {"catch_id":catch_id,"run_id":app.controller.run.run_id,"profile_id":"crew_1","species_id":"penny_perch","trait_id":"oversized","size":2.27,"catch_value":12,"habitat_id":"jetty","rare_eligible":false}
	assert_true(app.controller.progression.record_specimen(record).ok)
	app.controller._add_landed(record)
	app.controller.fish_bodies[catch_id].freeze = true
	await wait_physics_frames(2)
	_refresh()

func after_each() -> void:
	_key(app.settings.action_key("pack"),false)
	_key(app.settings.action_key("interact"),false)
	app.session.close()
	get_tree().root.size = old_size
	get_tree().root.content_scale_size = old_scale

func _key(code: int, held: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = held
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _refresh() -> void:
	app.controller._publish()
	app._process(0.11)

func _pickup() -> void:
	assert_eq(app._context().get("action"),"grab_fish")
	_key(app.settings.action_key("interact"),true)
	_key(app.settings.action_key("interact"),false)
	_refresh()
	assert_eq(app.controller.cargo.held_by("crew_1"),catch_id)

func _visible_action() -> String:
	return (app.hud._action_key.text + " · " if app.hud._keycap.is_visible_in_tree() else "") + app.hud._context.text

func test_pickup_exposes_existing_pack_drop_and_throw_on_visible_card() -> void:
	_pickup()
	await wait_process_frames(2)
	assert_true(app.hud._action_card.is_visible_in_tree())
	var action: String = _visible_action()
	assert_string_contains(action,"Hold P")
	assert_string_contains(action,"Pack")
	assert_string_contains(action,"E")
	assert_string_contains(action,"Drop")
	assert_string_contains(action,"Hold LMB")
	assert_string_contains(action,"Throw")
	assert_eq(app._context().get("action"),"drop_fish","Interact keeps its existing action")
	assert_true(Rect2(Vector2.ZERO,Vector2(960,540)).encloses(app.hud._action_card.get_global_rect()))
	var font: Font = app.hud._context.get_theme_font("font")
	assert_lte(font.get_string_size(app.hud._context.text,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x,app.hud._context.size.x,"All three actions fit without ellipsis")

func test_remapped_visible_pack_input_frees_hands_and_restores_casting() -> void:
	app.settings.set_binding("pack",KEY_O)
	app.settings.set_binding("interact",KEY_I)
	_pickup()
	await wait_process_frames(2)
	assert_string_contains(_visible_action(),"Hold O")
	assert_string_contains(_visible_action(),"I")
	_key(KEY_O,true)
	for tick in range(16):
		app._physics_process(0.05)
		app.controller._physics_process(0.05)
	_key(KEY_O,false)
	_refresh()
	assert_eq(app.controller.cargo.snapshot()[catch_id].state,"packed")
	assert_eq(app.controller.cargo.held_by("crew_1"),"")
	assert_string_contains(_visible_action(),"LMB")
	assert_string_contains(_visible_action(),"Cast")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	app._unhandled_input(mouse)
	assert_true(app._is_fishing(),"The advertised cast action succeeds after packing")
	mouse.pressed = false
	app._unhandled_input(mouse)

func test_bank_keeps_priority_and_awards_whole_value() -> void:
	_pickup()
	app.controller.avatars.crew_1.global_position = app.world.markers.boat
	_refresh()
	assert_eq(app._context().get("action"),"bank")
	assert_string_contains(_visible_action(),"Bank")
	assert_false(_visible_action().contains("Pack"))
	_key(KEY_E,true)
	_key(KEY_E,false)
	_refresh()
	assert_eq(app.controller.cargo.snapshot()[catch_id].state,"banked")
	assert_eq(app.controller.progression.snapshot().coins,20,"Whole oversized Perch keeps the existing 20-coin payout")

func test_rescue_still_precedes_carried_fish_actions() -> void:
	_pickup()
	app.session.roster.assign(2,1,Session.BUILD_ID)
	app.controller._roster_changed(app.session.roster.snapshot())
	app.controller.avatars.crew_2.global_position = app.controller.avatars.crew_1.global_position + Vector3(1,0,0)
	app.controller.run.players.crew_2.protection = 0.0
	app.controller.run.down("crew_2")
	_refresh()
	assert_eq(app._context().get("action"),"revive")
	assert_string_contains(_visible_action(),"revive")
	assert_false(_visible_action().contains("Pack"))

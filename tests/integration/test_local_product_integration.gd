extends GutTest

const Game = preload("res://game/main.gd")
const Settings = preload("res://game/ui/settings_local.gd")
const Camera = preload("res://game/player/camera_rig.gd")
var app: Node
var fixture_path: String
var old_volume: float
var old_mute: bool

func before_each() -> void:
	old_volume = AudioServer.get_bus_volume_db(0)
	old_mute = AudioServer.is_bus_mute(0)
	fixture_path = "user://tests/local_product_" + str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture_path))
	app = Game.new()
	app.set("settings_path", fixture_path + "/settings.json")
	app.save_path = fixture_path + "/household.json"
	app.game_port = 24739
	add_child_autofree(app)
	app.set_process(false)
	app.set_physics_process(false)
	app.controller.set_physics_process(false)
	await get_tree().process_frame

func after_each() -> void:
	app.session.close()
	AudioServer.set_bus_volume_db(0, old_volume)
	AudioServer.set_bus_mute(0, old_mute)

func test_settings_changes_apply_to_camera_sound_and_local_file_only() -> void:
	var local_settings: RefCounted = app.get("settings")
	assert_not_null(local_settings, "Main must own the local settings instance")
	if local_settings == null: return
	app.hud._set_local_setting("master_volume", 0.35)
	app.hud._set_local_setting("threat_volume", 0.0)
	app.hud._set_local_setting("mouse_sensitivity", 2.0)
	app.hud._set_local_setting("invert_y", true)
	assert_almost_eq(db_to_linear(AudioServer.get_bus_volume_db(0)), 0.35, 0.001)
	assert_eq(app.camera.get("mouse_sensitivity"), 2.0)
	assert_eq(app.camera.get("invert_y"), true)
	app.sounds.play_cue("warn")
	assert_false(app.sounds.player.playing, "Threat slider silences warnings")
	app.sounds.play_cue("catch")
	assert_true(app.sounds.player.playing, "Threat slider must keep catch sounds")
	assert_eq(app.request_sequence, 0, "Local settings must not produce network intents")
	assert_true(FileAccess.file_exists(fixture_path + "/settings.json"))

func test_remapped_journal_key_opens_journal_and_context_uses_binding() -> void:
	var local_settings: RefCounted = app.get("settings")
	assert_not_null(local_settings)
	if local_settings == null: return
	app._host("Local test")
	local_settings.set_binding("journal", KEY_U)
	local_settings.set_binding("interact", KEY_H)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_U
	key.pressed = true
	app._unhandled_input(key)
	assert_eq(app.hud._panel_kind, "journal")
	app.controller.avatars.crew_1.global_position = app.world.markers.boat
	assert_string_contains(app._context().text, "U journal")
	app.controller.snapshot_data.cargo={"catch":{"state":"packed","carrier_id":"","pouch_profile_id":"crew_1"}}
	assert_string_contains(app._context().text, "H · Bank catch")

func test_camera_sensitivity_and_inversion_change_orbit_not_movement() -> void:
	var camera: Node = Camera.new()
	autofree(camera)
	assert_true(camera.has_method("apply_settings"))
	if not camera.has_method("apply_settings"): return
	camera.apply_settings({"mouse_sensitivity": 2.0, "invert_y": true})
	camera.orbit(Vector2(10, 10))
	assert_almost_eq(camera.yaw, -0.08, 0.0001)
	assert_almost_eq(camera.pitch, -0.39, 0.0001)
	assert_almost_eq(camera.movement(Vector2.UP).length(), 1.0, 0.0001)

func test_debug_toggle_is_local_and_works_before_hosting() -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=KEY_F3
	event.pressed=true
	app._unhandled_input(event)
	assert_true(app.hud.get("debug_enabled"), "F3 diagnostics are available on the menu")
	assert_eq(app.request_sequence,0,"Debug never sends a game intent")
	app._unhandled_input(event)
	assert_false(app.hud.get("debug_enabled"))

func test_unchanged_view_does_not_rebuild_hud_every_render_frame() -> void:
	app._host("Frame test")
	app.configured_profile="crew_1" # Exclude the legitimate first-frame name save.
	app._process(0.02)
	var first: Dictionary=app.hud._data
	for frame in range(3): app._process(0.01)
	assert_true(is_same(first,app.hud._data),"Camera animation must not reconstruct menus at render frequency")
	app._process(0.11)
	assert_false(is_same(first,app.hud._data),"Live countdown still refreshes at least ten times a second")

func test_carrying_a_whole_fish_home_offers_direct_bank_and_pays_once() -> void:
	app._host("Carrier")
	var c=app.controller
	var actor=c.avatars.crew_1
	actor.global_position=app.world.markers.jetty
	actor.last_dry=actor.global_position
	var record: Dictionary=CatchTable.roll("jetty","day",0,0.8,0.05,0.5)
	record.merge({"catch_id":"direct-bank-whole","run_id":c.run.run_id,"profile_id":"crew_1"})
	assert_eq(record.trait_id,"oversized")
	assert_true(c.progression.record_specimen(record).ok)
	c._add_landed(record)
	assert_true(c.apply_intent(1,"grab_fish",{"catch_id":record.catch_id},"grab-bank-test").ok)
	c._publish()
	assert_eq(app._context().action,"drop_fish","Away from home E still drops")
	actor.global_position=app.world.markers.boat
	app.settings.set_binding("interact",KEY_H)
	assert_eq(app._context().action,"bank","Carry-home reward must be explicit")
	assert_string_contains(app._context().text,"H")
	var key:=InputEventKey.new()
	key.physical_keycode=KEY_H
	key.pressed=true
	app._unhandled_input(key)
	assert_eq(c.cargo.snapshot()[record.catch_id].state,"banked")
	var payout: int=int(c.progression.snapshot().coins)
	assert_gt(payout,0)
	app._unhandled_input(key)
	assert_eq(int(c.progression.snapshot().coins),payout,"Repeated interaction cannot pay again")

func test_new_island_is_wired_and_archives_confirmed_current_save() -> void:
	assert_true(app.has_method("_new_island"))
	if not app.has_method("_new_island"): return
	var prior: Dictionary = Progression.blank_state()
	prior.coins = 37
	prior.lifetime_banked = 37
	var store := SaveStore.new(app.save_path)
	assert_eq(store.commit(prior), OK)
	var original_digest: String = FileAccess.get_sha256(app.save_path)
	app.hud.new_island_requested.emit("New crew")
	assert_true(app.session.is_host())
	assert_eq(app.controller.progression.snapshot().coins, 0)
	var archives: String = ProjectSettings.globalize_path(fixture_path + "/archives")
	var directories: PackedStringArray = DirAccess.get_directories_at(archives)
	assert_eq(directories.size(), 1)
	if directories.size() == 1:
		assert_eq(FileAccess.get_sha256(archives.path_join(directories[0]).path_join("household.json")), original_digest)

func test_host_does_not_reset_corrupt_save_without_new_island_confirmation() -> void:
	var file := FileAccess.open(app.save_path, FileAccess.WRITE)
	file.store_string("preserve corrupted household")
	file.close()
	app._host("Existing crew")
	assert_false(app.session.is_host())
	assert_eq(FileAccess.get_file_as_string(app.save_path), "preserve corrupted household")
	assert_string_contains(app.hud._menu_message.text, "preserved")

func test_confirmed_new_island_still_works_after_join_rejection() -> void:
	app.session._join_rejected("Moth is sailing. Join after the next dawn.")
	assert_eq(app.session.status,"rejected")
	test_new_island_is_wired_and_archives_confirmed_current_save()

func test_new_island_is_rejected_during_active_session() -> void:
	assert_true(app.has_method("_new_island"))
	if not app.has_method("_new_island"): return
	app._host("Existing crew")
	var identity: String = app.controller.progression.snapshot().household_id
	app._new_island("Unexpected reset")
	assert_eq(app.controller.progression.snapshot().household_id, identity)
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(fixture_path + "/archives")))

func test_context_discovers_all_cache_markers_and_prioritizes_final_beacon_signal() -> void:
	app._host("Explorer")
	var actor: Node3D = app.controller.avatars.crew_1
	for id: String in IslandContent.cache_markers():
		app.controller.snapshot_data.progression.opened_caches = IslandContent.cache_markers().keys()
		app.controller.snapshot_data.progression.opened_caches.erase(id)
		actor.global_position = app.world.markers[IslandContent.cache_markers()[id]]
		var context: Dictionary = app._context()
		assert_eq(context.get("action"), "open_cache", id)
		assert_eq(context.get("payload", {}).get("cache_id"), id)
	actor.global_position = app.world.markers.beacon_repair
	app.controller.snapshot_data.escape = {"can_signal": true}
	assert_eq(app._context().get("action"), "signal_escape")

func test_alternate_rigger_can_target_at_eight_metres_but_standard_cannot() -> void:
	app._host("Rigger")
	app.session.roster.assign(2, 1, Session.BUILD_ID)
	app.controller._roster_changed(app.session.roster.snapshot())
	app.controller.avatars.crew_2.global_position = app.controller.avatars.crew_1.global_position + Vector3(8, 0, 0)
	app.controller.snapshot_data.run.players.crew_2 = {"downed": true}
	app.controller.snapshot_data.progression.profiles.crew_1.role_id = "rigger"
	app.controller.snapshot_data.progression.profiles.crew_1.tool_mode = "standard"
	assert_eq(app._teammate_target(), "")
	app.controller.snapshot_data.progression.profiles.crew_1.tool_mode = "alternate"
	assert_eq(app._teammate_target(), "crew_2")

func test_new_catch_realigns_camera_without_an_empty_cast_snapshot() -> void:
	app._host("Fast recast")
	var actor: Node3D = app.controller.avatars.crew_1
	actor.global_position = app.world.markers.jetty
	assert_true(app.controller._cast("crew_1").ok)
	app.controller._publish()
	app._process(0.02)
	app.controller.fishing.cancel("crew_1")
	actor.global_position = app.world.markers.terraces
	assert_true(app.controller._cast("crew_1").ok)
	app.controller._publish()
	app._process(0.02)
	var toward: Vector3 = app.world.fishing_focus("terraces") - actor.global_position
	assert_almost_eq(app.camera.yaw, atan2(-toward.x, -toward.z), 0.0001)
	app.hud._set_local_setting("reduced_effects", true)
	app.camera.yaw = 0.4
	app.controller.fishing.cancel("crew_1")
	actor.global_position = app.world.markers.jetty
	assert_true(app.controller._cast("crew_1").ok)
	app.controller._publish()
	app._process(0.02)
	assert_eq(app.camera.yaw, 0.4, "Reduced camera motion keeps the user's view")

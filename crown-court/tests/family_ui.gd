extends SceneTree

const Profile = preload("res://profile.gd")
const DEVICE = 17
var app
var checks = 0
var failures = 0
var profile_path = ""
var capture_directory = ""

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func control(id: String) -> Control:
	for entry in app.focusable_controls(app.wardrobe_panel):
		if str(entry.get_meta("wardrobe_focus", "")) == id: return entry
	return null

func tap(index: int) -> void:
	for pressed in [true, false]:
		var event = InputEventJoypadButton.new()
		event.device = DEVICE
		event.button_index = index
		event.pressed = pressed
		Input.parse_input_event(event)
		await create_timer(0.06).timeout

func viewports(node: Node) -> int:
	var count = 1 if node is SubViewport else 0
	for child in node.get_children(): count += viewports(child)
	return count

func capture(label: String) -> void:
	if capture_directory.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_directory.path_join(label + ".png"))

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): capture_directory = argument.trim_prefix("--capture-dir=")
	if not capture_directory.is_empty(): DirAccess.make_dir_recursive_absolute(capture_directory)
	profile_path = "user://family_ui_%d.json" % Time.get_ticks_usec()
	app = load("res://tests/family_ui_app.gd").new()
	app.profile = Profile.new(profile_path)
	app.profile.data.inventory.append_array(["jersey", "cap"])
	app.profile.data.bags = 1
	app.profile.save_profile()
	root.add_child(app)
	app.muted = true
	app.nickname = "Independent nickname"
	app.discovered_devices.assign([DEVICE])
	Input.joy_connection_changed.emit(DEVICE, true)
	await process_frame
	app.show_wardrobe()
	await create_timer(0.15).timeout
	check(control("character") is OptionButton and root.gui_get_focus_owner() == control("character"), "Wardrobe opens focused on character selector")
	check(control("character").item_count == 4, "Four free character choices available")
	check(viewports(app.wardrobe_panel) == 1, "Wardrobe uses one real 3D preview")
	await capture("01-character-selector")
	var first_preview = weakref(app.wardrobe_panel)
	await tap(JOY_BUTTON_A)
	check(control("character").get_popup().visible, "Controller A opens native character selector")
	await tap(JOY_BUTTON_DPAD_DOWN)
	await tap(JOY_BUTTON_A)
	await process_frame
	check(app.profile.outfit().character == "evie", "Controller selects Evie")
	check(root.gui_get_focus_owner() == control("character"), "Character selection keeps controller focus after rebuild")
	check(first_preview.get_ref() == null and viewports(app.wardrobe_panel) == 1, "Rebuild frees previous preview tree")
	check(app.preview_equipment.character == "evie" and app.cosmetics[1].character == "evie", "Real preview and synchronization receive selected identity")
	check(app.nickname == "Independent nickname", "Character selection does not rename player")
	control("jersey").grab_focus()
	await tap(JOY_BUTTON_A)
	check(app.profile.outfit().outfit == "jersey" and app.profile.outfit().character == "evie", "Clothing selection preserves identity")
	check(root.gui_get_focus_owner() == control("jersey"), "Clothing selection preserves controller focus")
	check(app.preview_equipment == app.profile.outfit(), "Preview receives identity with equipped clothing")
	await capture("02-evie-jersey-focus")
	control("character").grab_focus()
	await tap(JOY_BUTTON_A)
	await tap(JOY_BUTTON_B)
	check(not control("character").get_popup().visible and is_instance_valid(app.wardrobe_panel), "Cancel closes character popup without leaving wardrobe")
	control("bag").grab_focus()
	await tap(JOY_BUTTON_A)
	check(is_instance_valid(app.reveal_panel) and app.preview_equipment.character == "evie", "Bag reveal retains selected identity")
	# A newly saved pending reward can refresh the wardrobe below an open reveal.
	app.show_wardrobe()
	await create_timer(0.1).timeout
	check(app.reveal_panel.is_ancestor_of(root.gui_get_focus_owner()), "Background wardrobe refresh does not steal reveal focus")
	app.close_reveal()
	await create_timer(0.1).timeout
	check(root.gui_get_focus_owner() == control("character"), "Last bag consumption restores focus to enabled selector")
	check(app.profile.outfit().character == "evie" and app.profile.data.inventory.size() == 5, "Bag reward changes collection only")
	await tap(JOY_BUTTON_B)
	check(not is_instance_valid(app.wardrobe_panel), "Controller cancel closes wardrobe")
	app.show_wardrobe()
	await create_timer(0.1).timeout
	check(control("character").selected == 1 and root.gui_get_focus_owner() == control("character"), "Reopened wardrobe retains identity and usable focus")
	var reloaded = Profile.new(profile_path)
	check(reloaded.outfit() == app.profile.outfit(), "UI selections persisted in isolated profile")
	app.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(profile_path + suffix): DirAccess.remove_absolute(profile_path + suffix)
	print("FAMILY_UI_RESULT %d checks; %d failures; display=%s" % [checks, failures, DisplayServer.get_name()])
	quit(1 if failures else 0)

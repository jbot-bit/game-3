class_name GameHUD
extends CanvasLayer

signal host_requested(name: String)
signal join_requested(address: String, slot: int, name: String)
signal action_requested(action: String, payload: Dictionary)
signal leave_requested
signal new_island_requested(name: String)
signal settings_changed(settings: Dictionary)

const INK: Color = Color("112b46")
const TEAL: Color = Color("227b93")
const CREAM: Color = Color("f4fbff")
const AMBER: Color = Color("ffd15c")
const CORAL: Color = Color("ff795d")
const MUTED: Color = Color("acccdd")
const MINT: Color = Color("68e1c2")
const ROLE_IDS: Array[String] = ["scout", "keeper", "rigger"]
const SpeciesModel = preload("res://game/fishing/species.gd")
const CatchModel = preload("res://game/fishing/catch_table.gd")
const GearModel = preload("res://game/progression/equipment.gd")
const CraftModel = preload("res://game/progression/crafting.gd")
const SettingsModel = preload("res://game/ui/settings_local.gd")
const PullRail = preload("res://game/ui/fishing_pull_rail.gd")
const CatchPortrait = preload("res://game/ui/catch_portrait.gd")
const HABITATS: Array[String] = ["jetty", "reeds", "terraces", "tidepools", "beacon"]
const TIME_BANDS: Array[String] = ["day", "dusk", "night", "storm"]

var _root: Control
var _menu: Control
var _game: Control
var _overlay: Control
var _menu_message: Label
var _menu_name: LineEdit
var _address: LineEdit
var _slot: OptionButton
var _stats: Label
var _top_strip: MarginContainer
var _host_address: Label
var _host_tools: Button
var _vote_notice: Label
var _crew_labels: Array[Label] = []
var _context: Label
var _equipment: Label
var _controls: Label
var _fish_box: VBoxContainer
var _fish_card: PanelContainer
var _progress: ProgressBar
var _fish_hint: Label
var _fish_state: Label
var _fish_instruction: Label
var _fish_pull: Control
var _fish_counter: Label
var _progress_label: Label
var _fish_mode: Label
var _catch_reveal: PanelContainer
var _catch_name: Label
var _catch_details: Label
var _catch_badges: Label
var _catch_destination: Label
var _catch_portrait: SubViewportContainer
var _catch_until: float = 0.0
var _revealed_catch_id: String = ""
var _catch_scope: String = ""
var _catch_seen: Dictionary = {}
var _discoveries_seen: Dictionary = {}
var _next_step_card: PanelContainer
var _next_step_title: Label
var _next_step_detail: Label
var _toast_label: Label
var _toast_card: PanelContainer
var _toast_until: float = 0.0
var _panel_kind: String = ""
var _panel_title: Label
var _panels: Dictionary = {}
var _data: Dictionary = {}
var _profile_id: String = ""
var _workshop_status: Label
var _craft_button: Button
var _gear_buttons: Dictionary = {}
var _outfit_buttons: Dictionary = {}
var _outfit_grid: GridContainer
var _profile_name: LineEdit
var _role: OptionButton
var _journal: Label
var _vote_status: Label
var _jetty: Button
var _reeds: Button
var _open_vote: Button
var _pause_status: Label
var _resume: Button
var _mute: CheckButton
var _objective: Label
var _campaign_details: Label
var _escape_status: Label
var _arm_escape: Button
var _signal_escape: Button
var _continue_island: Button
var _return_to_ending: Button
var _repair_buttons: Dictionary = {}
var _repairs_box: VBoxContainer
var _campaign_page: VBoxContainer
var _catches_page: VBoxContainer
var _ending_summary: Label
var _ending_seen: bool = false
var _recipe_buttons: Dictionary = {}
var _tool_status: Label
var _standard_tool: Button
var _alternate_tool: Button
var _journal_habitat: OptionButton
var _journal_time: OptionButton
var _new_island_confirmation: ConfirmationDialog
var _settings: RefCounted
var _setting_widgets: Dictionary = {}
var _binding_buttons: Dictionary = {}
var _capture_action: String = ""
var _settings_status: Label
var _menu_controls: Label
var _help_text: Label
var _panel_scroll: ScrollContainer
var _paused_by_menu: bool = false
var debug_enabled: bool = false
var _debug_card: PanelContainer
var _debug_text: Label
var _menu_views: Dictionary = {}
var _menu_screen: String = "home"
var _join_name: LineEdit
var _action_card: PanelContainer
var _action_key: Label
var _keycap: PanelContainer
var _lamp_status: Label
var _pouch_status: Label
var _ability_status: Label
var _field_status: Label
var _status_strip: HBoxContainer
var _recap_card: PanelContainer
var _recap_text: Label
var _catalog_cache: Dictionary = {}
var _workshop_pages: Dictionary = {}
var _journal_species: OptionButton
var _journal_pool: Label
var _outfit_hint: Label
static var _icons: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _settings == null: _settings = SettingsModel.new()
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _make_theme()
	add_child(_root)
	_build_menu()
	_build_game()
	_build_panels()
	_build_debug()
	_sync_settings_widgets()
	show_menu()

func _build_debug() -> void:
	_debug_card = _card(_root)
	_debug_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_debug_card.offset_left = -244
	_debug_card.offset_right = -22
	_debug_card.offset_top = 100
	_debug_card.offset_bottom = 185
	_debug_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_text = _add_label(_debug_card, "", 13, CREAM)
	_debug_card.hide()

func set_debug_enabled(enabled: bool) -> void:
	debug_enabled = enabled
	if _debug_card != null: _debug_card.visible = enabled

func toggle_debug() -> void:
	set_debug_enabled(not debug_enabled)

func update_debug(metrics: Dictionary) -> void:
	if _debug_text == null or not debug_enabled: return
	var lines: PackedStringArray = []
	if metrics.has("fps") and metrics.has("frame_ms"):
		lines.append("%.0f FPS · %.1f ms" % [float(metrics.fps), float(metrics.frame_ms)])
	var connection: String = str(metrics.get("role", "offline")).capitalize()
	if metrics.has("rtt_ms") and float(metrics.rtt_ms) >= 0:
		connection += " · %.1f ms RTT" % float(metrics.rtt_ms)
	lines.append(connection)
	if metrics.has("draw_calls") and metrics.has("objects"):
		lines.append("%d draws · %d objects" % [int(metrics.draw_calls), int(metrics.objects)])
	if metrics.has("primitives"): lines.append("%d primitives" % int(metrics.primitives))
	_debug_text.text = "\n".join(lines)

func configure_settings(model: RefCounted) -> void:
	_settings = model
	if _root != null: _sync_settings_widgets()

func request_new_island() -> void:
	if not _menu.visible: return
	_new_island_confirmation.popup_centered(Vector2i(540, 220))

func show_menu(message: String = "") -> void:
	if _root == null:
		return
	_panel_kind = ""
	_overlay.hide()
	_game.hide()
	_menu.show()
	_menu_message.text = message
	_catch_scope = ""
	_catch_until = 0.0
	if _catch_reveal != null: _catch_reveal.hide()
	show_menu_flow(_menu_screen)

func show_game() -> void:
	if _root == null:
		return
	_menu.hide()
	_game.show()
	_overlay.hide()
	_panel_kind = ""

func panel_open() -> bool:
	return not _panel_kind.is_empty() or (_menu != null and _menu.visible)

func toggle_panel(kind: String) -> void:
	if _overlay == null or (_menu.visible and kind not in ["settings", "help"]):
		return
	if kind == "host" and not bool(_data.get("is_host", false)):
		toast("Lake Office is available on the host PC.")
		return
	if kind == _panel_kind:
		_close_panel()
		return
	if not _panels.has(kind):
		return
	_close_panel(false)
	_panel_kind = kind
	for key: String in _panels:
		_panels[key].visible = key == kind
	_panel_title.text = {"workshop": "BOAT WORKSHOP", "journal": "FIELD JOURNAL", "vote": "ONE BATTERY. TWO ROUTES.", "host": "LAKE OFFICE", "pause": "MENU", "settings": "SETTINGS", "help": "HOW TO PLAY", "ending": "HOME AT LAST"}.get(kind, kind.to_upper())
	_return_to_ending.visible = bool(_data.get("escape", {}).get("completed", false)) and kind != "ending"
	_panel_scroll.scroll_vertical = 0
	if kind == "workshop":
		var profiles: Dictionary = _data.get("progression", {}).get("profiles", {})
		var profile: Dictionary = profiles.get(_profile_id, {})
		_profile_name.text = str(profile.get("name", "Angler"))
		_role.select(maxi(0, ROLE_IDS.find(str(profile.get("role_id", "scout")))))
	if kind == "pause" and bool(_data.get("is_host", false)) and not _paused_by_menu:
		_paused_by_menu = true
		action_requested.emit("pause", {"paused": true})
	if kind == "settings": _sync_settings_widgets()
	_refresh_catalogs(kind)
	_overlay.show()

func toast(text: String) -> void:
	if _toast_label == null:
		return
	_toast_label.text = text
	_toast_label.show()
	_toast_card.show()
	_toast_until = float(Time.get_ticks_msec()) / 1000.0 + 4.5

func update_view(data: Dictionary, profile_id: String, context: String) -> void:
	_data = data
	_profile_id = profile_id
	if _root == null:
		return
	var run: Dictionary = data.get("run", {})
	var progression: Dictionary = data.get("progression", {})
	var profiles: Dictionary = progression.get("profiles", {})
	var players: Dictionary = run.get("players", {})
	var elapsed: float = float(run.get("elapsed_s", 0.0))
	var phase: String = str(run.get("phase", "day")).to_upper()
	var terminal: bool = bool(run.get("terminal", false))
	var departing: bool = terminal or phase == "REFUGE" or float(run.get("crossing_left", -1.0)) >= 0.0
	var before_night: bool = elapsed < 240.0 and not departing
	var remaining: int = maxi(0, ceili((240.0 if before_night else 630.0) - elapsed))
	var clock_label: String = "Night in " if before_night else "Return in " if not departing else ""
	if bool(run.get("paused", false)):
		phase = "PAUSED"
	var phase_label: String = "" if phase == "DAY" else " · " + phase.capitalize()
	_stats.text = "Day %d%s · %s%d:%02d\n%d crew coins" % [int(progression.get("day_index", 0)) + 1, phase_label, clock_label, int(floor(remaining / 60.0)), remaining % 60, int(progression.get("coins", 0))]
	_host_address.visible = bool(data.get("is_host", false))
	_host_tools.visible = _host_address.visible
	var addresses: PackedStringArray = PackedStringArray(data.get("host_addresses", []))
	_host_address.text = ("Addresses to try: " + " · ".join(addresses) if not addresses.is_empty() else "LAN address unavailable")
	for i: int in range(3):
		var id: String = "crew_%d" % (i + 1)
		var profile: Dictionary = profiles.get(id, {})
		var player: Dictionary = players.get(id, {})
		var status: String = str(profile.get("role_id", "scout")).capitalize()
		if not players.has(id):
			status = "Open crew slot"
		elif bool(player.get("downed", false)):
			status = "HELP · %ds" % ceili(float(player.get("down_left", 25.0)))
			var poses: Dictionary = data.get("poses", {}).get("players", {})
			if id != profile_id and poses.get(id, {}).get("position") is Vector3 and poses.get(profile_id, {}).get("position") is Vector3:
				status += " · %dm" % ceili((poses[id].position as Vector3).distance_to(poses[profile_id].position))
			if not str(player.get("carried_by", "")).is_empty(): status = "Being carried · %ds" % ceili(float(player.get("down_left", 25.0)))
		elif bool(player.get("ready", false)):
			status += " · Ready"
		var name_text: String = str(profile.get("name", "Angler %d" % (i + 1)))
		_crew_labels[i].text = name_text + (" · you" if id == profile_id else "")
		if bool(player.get("downed", false)) or bool(player.get("ready", false)):
			_crew_labels[i].text += "\n" + (status if bool(player.get("downed", false)) else "Ready")
		_crew_labels[i].get_parent().visible = players.has(id)
		_crew_labels[i].add_theme_color_override("font_color", CORAL if bool(player.get("downed", false)) else CREAM)
	_context.text = context
	_context.add_theme_color_override("font_color", AMBER)
	_controls.text = "%s interact · %s journal · %s menu" % [_key("interact"), _key("journal"), _key("pause")]
	if departing:
		_controls.text = "%s journal · %s menu" % [_key("journal"), _key("pause")]
		if terminal:
			var saved: bool = str(run.get("run_id", "")) in progression.get("settled_run_ids", [])
			_context.text = "Trip saved. Dawn is on its way." if saved else "Departure save pending · " + ((_key("pause") + " → Resume to retry") if bool(data.get("is_host", false)) else "waiting for the host")
			if bool(data.get("escape", {}).get("completed", false)):
				_context.text = "Island saved · %s journal → ending → Continue Island" % _key("journal")
		else:
			_context.text = ("Crossing the outer channel · %ds" if bool(data.get("escape", {}).get("departing", false)) or phase == "ESCAPE" else "Heading for refuge · %ds to the mooring") % maxi(0, ceili(float(run.get("crossing_left", 0.0))))
	var current_profile: Dictionary = profiles.get(profile_id, {})
	var lamp: String = str(current_profile.get("lamp_id", "flood"))
	var remaining_light: float = float(data.get("lights", {}).get("batteries", {}).get(profile_id, 45.0 if lamp == "surveyor" else 90.0))
	var lamp_drain: float = float(GearModel.outfit(str(current_profile.get("outfit_id", "harbour"))).get("lamp_drain_multiplier", 1.0))
	remaining_light /= maxf(0.001, lamp_drain)
	var ready_at: float = float(data.get("abilities", {}).get("ready_at", {}).get(profile_id, 0.0))
	var lamp_on: bool = bool(data.get("lamp_enabled", {}).get(profile_id, true))
	var tool_text: String = "Tool ready" if ready_at <= elapsed else "Tool %ds" % ceili(ready_at - elapsed)
	var cargo: Dictionary = data.get("cargo", {})
	var pouch: int = 0
	var held: bool = false
	for entry: Dictionary in cargo.values():
		if entry.get("state", "") == "packed" and entry.get("pouch_profile_id", "") == profile_id:
			pouch += int(entry.get("catch_record", {}).get("catch_value", 0))
		if entry.get("state", "") == "whole_held" and entry.get("carrier_id", "") == profile_id:
			held = true
	var light_text: String = "%s %ds" % [lamp.capitalize(), ceili(remaining_light)] if lamp_on else "%s off · %ds" % [lamp.capitalize(), ceili(remaining_light)]
	if remaining_light <= 0: light_text = "LANTERN EMPTY · recharge at Moth"
	elif lamp_on and remaining_light <= 15: light_text = "LOW LIGHT · %ds" % ceili(remaining_light)
	_equipment.text = "%s · %s · Pouch %d" % [light_text, tool_text, pouch]
	var has_cell: bool = false
	for supply: Dictionary in data.get("supplies", {}).values():
		if supply.get("state", "") == "held" and supply.get("carrier_id", "") == profile_id: has_cell = true
	if has_cell: _equipment.text = "POWER CELL · carry to a shelter for +90s of light"
	elif held: _equipment.text += " · WHOLE FISH · hold %s to pack" % _key("pack")
	var stations: Dictionary = data.get("lights", {}).get("station_until", {})
	if not stations.is_empty():
		_equipment.text += "   |   " + _field_power(stations, elapsed)
	if not departing:
		var carried_by: String = str(players.get(profile_id, {}).get("carried_by", ""))
		var rescue: Dictionary = data.get("rescue_progress", {}).get(profile_id, {})
		if not carried_by.is_empty():
			_context.text = "%s is carrying you to safety" % str(profiles.get(carried_by, {}).get("name", carried_by))
		elif not rescue.is_empty():
			_context.text = "Hold %s · revive %s · %d%%" % [_key("interact"), str(profiles.get(str(rescue.get("target", "")), {}).get("name", "crewmate")), clampi(roundi(float(rescue.get("held_s", 0.0)) / 3.0 * 100.0), 0, 100)]
		elif float(data.get("throw_charge", 0.0)) > 0.0:
			_context.text = "Release LMB · throw %d%%" % clampi(roundi(float(data.throw_charge) * 100.0), 0, 100)
		elif data.get("hunter", "") in ["warn", "chase"] and str(data.get("hunter_target", "")) == profile_id:
			_context.text = "LIFEGUARD NEAR · run to a lit shelter"
			_context.add_theme_color_override("font_color", CORAL)
		else: _context.add_theme_color_override("font_color", AMBER)
	if departing:
		_equipment.text = ("The crew is leaving Last Light together." if phase=="ESCAPE" else "The crew is returning to the mooring.") if not terminal else ("Your collection and island improvements are saved." if bool(data.get("escape",{}).get("completed",false)) else "The island clock is stopped while this trip finishes.")
	var fishing: Dictionary = data.get("fishing", {}).get(profile_id, {})
	_fish_card.visible = not fishing.is_empty() and not departing
	if not fishing.is_empty():
		_update_fishing(fishing, data)
	_update_catch_reveal(data, profile_id, departing, not fishing.is_empty())
	var next_step: Dictionary = data.get("next_step", {})
	_next_step_title.text = str(next_step.get("title", ""))
	_next_step_detail.text = str(next_step.get("detail", ""))
	var urgent: bool = bool(players.get(profile_id, {}).get("downed", false)) or not data.get("rescue_progress", {}).get(profile_id, {}).is_empty() or (data.get("hunter", "") in ["warn", "chase"] and str(data.get("hunter_target", "")) == profile_id)
	_next_step_card.visible = not next_step.is_empty() and not _next_step_title.text.is_empty() and fishing.is_empty() and not departing and not urgent and not panel_open() and not _catch_reveal.visible
	_refresh_catalogs()
	_update_vote(data.get("choice", {}), elapsed)
	_update_night_advice(remaining_light, departing, urgent)
	if _vote_notice.visible: _next_step_card.hide()
	if terminal and str(run.get("run_id", "")) in progression.get("settled_run_ids", []) and not data.get("trip_result", {}).is_empty():
		var recap: Dictionary = data.trip_result
		var outcome: String = str(recap.get("outcome", "refuge"))
		_context.text = {"escaped":"Open sea · island saved · journal → Continue Island", "refuge":"Refuge reached · trip saved · dawn shortly", "retreat":"Retreat · banked progress saved · dawn shortly"}.get(outcome, "Trip saved · dawn shortly")
		_equipment.text = "%d coins banked · %d new species · %d records · %d lost catches" % [int(recap.get("banked", 0)), int(recap.get("new_species", 0)), int(recap.get("records", 0)), int(recap.get("lost_count", 0))]
		_objective.text = str(recap.get("next_goal", ""))
	if departing:
		_vote_notice.hide()
	_pause_status.text = "The island is paused for everyone." if bool(run.get("paused", false)) else "The island keeps moving. Only the host can pause it."
	_resume.text = "Resume" if bool(data.get("is_host", false)) else "Back to game"
	_update_compact_status(remaining_light, lamp_on, ready_at <= elapsed, maxi(0, ceili(ready_at-elapsed)), pouch, has_cell, held, stations, elapsed, departing)
	_recap_card.visible = terminal and str(run.get("run_id", "")) in progression.get("settled_run_ids", []) and not data.get("trip_result", {}).is_empty()
	if _recap_card.visible: _recap_text.text = _equipment.text + "\n" + str(data.trip_result.get("next_goal", ""))
	_format_action()
	if data.has("audio_muted"):
		_mute.set_pressed_no_signal(bool(data.audio_muted))

func _process(_delta: float) -> void:
	if _fish_card != null and _fish_card.visible:
		var half_width: float = minf(270.0, maxf(150.0, _root.size.x * 0.5 - 24.0))
		_fish_card.offset_left = -half_width
		_fish_card.offset_right = half_width
	if _vote_notice != null and _vote_notice.visible:
		_vote_notice.position.y = _top_strip.get_global_rect().end.y + 12.0
	if _next_step_card != null and _next_step_card.visible:
		_next_step_card.offset_top = _top_strip.get_global_rect().end.y + 12.0
	if _toast_card != null and _toast_card.visible and _top_strip != null:
		var notice_end: float = maxf(_top_strip.get_global_rect().end.y, _vote_notice.get_global_rect().end.y if _vote_notice.visible else 0.0)
		if _next_step_card.visible: notice_end = maxf(notice_end, _next_step_card.get_global_rect().end.y)
		_toast_card.offset_top = notice_end + 12.0
		_toast_card.offset_bottom = _toast_card.offset_top + 56.0
		if _catch_reveal.visible and _toast_card.get_global_rect().intersects(_catch_reveal.get_global_rect()):
			_toast_card.offset_top = _catch_reveal.get_global_rect().end.y + 12.0
			_toast_card.offset_bottom = _toast_card.offset_top + 56.0
	if _toast_label != null and _toast_label.visible and float(Time.get_ticks_msec()) / 1000.0 >= _toast_until:
		_toast_label.hide()
		_toast_card.hide()
	if _catch_reveal != null and _catch_reveal.visible and float(Time.get_ticks_msec()) / 1000.0 >= _catch_until:
		_catch_reveal.hide()

func _update_fishing(fishing: Dictionary, data: Dictionary) -> void:
	_progress.value = clampf(float(fishing.get("progress", 0.0)), 0.0, 1.0)
	var waiting: bool = float(fishing.get("elapsed", 2.0)) < 0.8
	var tracking: bool = bool(fishing.get("tracking", false))
	var active: bool = bool(data.get("reel_active", false))
	var toggled: bool = bool(data.get("reel_toggle_mode", false))
	_fish_state.text = "BITE!" if waiting else "ON TARGET" if tracking else "FOLLOW THE FISH"
	_fish_state.add_theme_color_override("font_color", MINT if tracking and not waiting else AMBER)
	_fish_counter.text = "Get ready" if waiting else "Progress rising ↑" if tracking else "Progress falling ↓"
	_fish_counter.add_theme_color_override("font_color", MINT if tracking and not waiting else AMBER)
	_fish_instruction.text = "Click LMB to switch direction" if toggled else "Hold LMB →    Release ←"
	_fish_hint.text = ("Moving right →" if active else "← Moving left") if toggled else "Keep the blue fish line inside your bar."
	_progress_label.text = "CATCH  %d%%" % roundi(_progress.value * 100.0)
	_fish_pull.set_tracking(float(fishing.get("bar_position", 0.5)), float(fishing.get("bar_width", 0.34)), float(fishing.get("fish_position", 0.5)), tracking)
	_fish_pull.set_input_direction(active)
	_fish_pull.tooltip_text = "Keep the blue fish line inside your bar to catch it."
	_fish_mode.text = "%s · %s mode    %s · cancel" % [_key("toggle_reel"), "hold" if toggled else "click", _key("cancel_cast")]

func _update_catch_reveal(data: Dictionary, profile_id: String, departing: bool, fishing: bool) -> void:
	var saved: Dictionary = data.get("progression", {})
	var run: Dictionary = data.get("run", {})
	var scope: String = str(saved.get("household_id", "")) + ":" + str(run.get("run_id", "")) + ":" + profile_id
	var baseline: bool = scope != _catch_scope
	if baseline:
		_catch_scope = scope
		_catch_seen.clear()
		_discoveries_seen.clear()
		_catch_reveal.hide()
	var local_player: Dictionary = run.get("players", {}).get(profile_id, {})
	var interrupted: bool = departing or fishing or bool(local_player.get("downed", false)) or not str(local_player.get("carried_by", "")).is_empty() or not data.get("rescue_progress", {}).get(profile_id, {}).is_empty() or (data.get("hunter", "") in ["warn", "chase"] and str(data.get("hunter_target", "")) == profile_id)
	var revealed: Dictionary = {}
	var badges: PackedStringArray = []
	for raw_id: Variant in saved.get("landed_catch_ids", []):
		var id: String = str(raw_id)
		if _catch_seen.has(id): continue
		_catch_seen[id] = true
		if baseline or interrupted: continue
		var record: Dictionary = data.get("cargo", {}).get(id, {}).get("catch_record", {})
		if str(record.get("profile_id", "")) != profile_id: continue
		var species_id: String = str(record.get("species_id", ""))
		if not SpeciesModel.catalog().has(species_id): continue
		revealed = record
		badges.clear()
		if species_id in saved.get("discoveries", []) and not _discoveries_seen.has(species_id):
			badges.append("NEW SPECIES")
		if str(saved.get("specimen_records", {}).get(species_id, {}).get("largest_catch_id", "")) == id:
			badges.append("NEW CREW RECORD")
	for species_id: Variant in saved.get("discoveries", []):
		_discoveries_seen[str(species_id)] = true
	if interrupted:
		_catch_reveal.hide()
		_catch_until = 0.0
	elif not revealed.is_empty():
		_show_catch(revealed, badges)
	if _catch_reveal.visible:
		_update_catch_destination(data.get("cargo", {}).get(_revealed_catch_id, {}), profile_id)

func _show_catch(record: Dictionary, badges: PackedStringArray) -> void:
	_revealed_catch_id = str(record.catch_id)
	var fish: Dictionary = SpeciesModel.catalog()[str(record.species_id)]
	var trait_id: String = str(record.get("trait_id", "none"))
	_catch_name.text = str(fish.name)
	var details: PackedStringArray = [str(fish.rarity).capitalize()]
	if trait_id not in ["", "none"]: details.append(trait_id.replace("_", " ").capitalize())
	_catch_details.text = " · ".join(details)
	if record.has("size"): _catch_details.text += "\n%.2f m" % float(record.size)
	if record.has("catch_value"): _catch_details.text += "  ·  %d coins" % int(record.catch_value)
	_catch_badges.text = "  ·  ".join(badges) if not badges.is_empty() else "ADDED TO YOUR COLLECTION"
	_catch_portrait.show_species(str(record.species_id), trait_id)
	_catch_until = float(Time.get_ticks_msec()) / 1000.0 + 5.5
	_catch_reveal.show()

func _update_catch_destination(entry: Dictionary, profile_id: String) -> void:
	var state: String = str(entry.get("state", ""))
	var profiles: Dictionary = _data.get("progression", {}).get("profiles", {})
	if state == "packed":
		var custodian: String = str(entry.get("pouch_profile_id", ""))
		var whose: String = "your" if custodian == profile_id else str(profiles.get(custodian, {}).get("name", "Crewmate")) + "'s"
		_catch_destination.text = "In %s pouch · unbanked\nBring it to Moth to keep the coins" % whose
	elif state == "whole_loose":
		_catch_destination.text = "Whole fish · packed value shown · unbanked\n%s pick up · bring it to Moth for more" % _key("interact")
	elif state == "whole_held":
		var carrier: String = str(entry.get("carrier_id", ""))
		var custody: String = "In your hands" if carrier == profile_id else "Carried by " + str(profiles.get(carrier, {}).get("name", "a crewmate"))
		_catch_destination.text = custody + " · unbanked\nPacked value shown · whole fish earn more at Moth"
	else:
		# Banking reservations, completed deliveries, losses and missing cargo retire the prompt.
		_catch_reveal.hide()
		_catch_until = 0.0

func _close_panel(release_pause: bool = true) -> void:
	_capture_action = ""
	if release_pause and _paused_by_menu and bool(_data.get("is_host", false)):
		_paused_by_menu = false
		action_requested.emit("pause", {"paused": false})
	_panel_kind = ""
	_overlay.hide()
	_sync_binding_buttons()

func _build_menu() -> void:
	_menu = _full_control(_root)
	var backdrop := TextureRect.new()
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.42, 0.82, 1.0])
	gradient.colors = PackedColorArray([Color(INK,0.97),Color(INK,0.88),Color(INK,0.12),Color(INK,0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2(1,0)
	backdrop.texture = texture
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	margin.offset_left = 56
	margin.offset_right = 476
	margin.offset_top = -244
	margin.offset_bottom = 244
	_menu.add_child(margin)
	var box: VBoxContainer = _column(margin, 10)
	_add_label(box, "LAST LIGHT ISLAND", 14, MINT)
	var game_title: Label = _add_label(box, "ONE MORE\nCAST", 64, CREAM)
	var title_font := SystemFont.new()
	title_font.font_names = PackedStringArray(["Arial", "Segoe UI"])
	title_font.font_weight = 900
	game_title.add_theme_font_override("font", title_font)
	game_title.add_theme_constant_override("line_spacing", -12)
	game_title.add_theme_color_override("font_shadow_color", Color(INK,0.55))
	game_title.add_theme_constant_override("shadow_offset_y", 4)
	_add_label(box, "One island. Strange fish. Home before dark.", 16, MUTED, true)
	_menu_message = _add_label(box, "", 14, CORAL, true)
	for id: String in ["home", "host", "join"]:
		_menu_views[id] = _column(box, 10)
	var home: VBoxContainer = _menu_views.home
	_primary_button(home, "Host a game", func() -> void: show_menu_flow("host"))
	_button(home, "Join a game", func() -> void: show_menu_flow("join")).custom_minimum_size.y = 48
	var secondary := HBoxContainer.new()
	secondary.add_theme_constant_override("separation", 12)
	home.add_child(secondary)
	_quiet_button(secondary, "Settings", func() -> void: toggle_panel("settings"))
	_quiet_button(secondary, "Help", func() -> void: toggle_panel("help"))
	_add_label(home, "Up to 3 players · same home network", 13, MUTED)
	var host: VBoxContainer = _menu_views.host
	_add_label(host, "HOST A GAME", 14, MUTED)
	_menu_name = _line_edit(host, "Your name", "Angler")
	_menu_name.max_length = 32
	_primary_button(host, "Start island", func() -> void: host_requested.emit(_menu_name.text.strip_edges()))
	_add_label(host, "Your island saves on this PC.", 13, MUTED)
	var host_links := HBoxContainer.new()
	host_links.add_theme_constant_override("separation", 16)
	host.add_child(host_links)
	_quiet_button(host_links, "← Back", func() -> void: show_menu_flow("home"))
	_quiet_button(host_links, "New island…", request_new_island)
	var join: VBoxContainer = _menu_views.join
	_add_label(join, "JOIN A GAME", 14, MUTED)
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 8)
	join.add_child(identity)
	_join_name = _line_edit(identity, "Your name", "Angler")
	_join_name.max_length = 32
	_join_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot = OptionButton.new()
	for title: String in ["Any crew slot", "Crew slot 2", "Crew slot 3"]: _slot.add_item(title)
	identity.add_child(_slot)
	_address = _line_edit(join, "Host address · e.g. 192.168.1.20", "")
	_primary_button(join, "Join crew", func() -> void: join_requested.emit(_address.text.strip_edges(), -1 if _slot.selected == 0 else _slot.selected, _join_name.text.strip_edges()))
	_quiet_button(join, "← Back", func() -> void: show_menu_flow("home"))
	_new_island_confirmation = ConfirmationDialog.new()
	_new_island_confirmation.title = "Start a new island?"
	_new_island_confirmation.dialog_text = "Start fresh on this host PC?\nYour current island will be kept in an archive."
	_new_island_confirmation.ok_button_text = "Create New Island"
	_new_island_confirmation.confirmed.connect(func() -> void:
		if _menu.visible: new_island_requested.emit(_menu_name.text.strip_edges()))
	add_child(_new_island_confirmation)
	_menu_controls = _add_label(box, "", 13, MUTED)
	_menu_controls.hide()
	show_menu_flow("home")

func show_menu_flow(kind: String) -> void:
	if not _menu_views.has(kind): return
	_menu_screen = kind
	for id: String in _menu_views: _menu_views[id].visible = id == kind

func _primary_button(parent: Node, text: String, callback: Callable) -> Button:
	var button: Button = _button(parent, text, callback)
	button.custom_minimum_size.y = 48
	button.add_theme_stylebox_override("normal", _style(AMBER, AMBER, 12))
	button.add_theme_stylebox_override("hover", _style(CREAM, CREAM, 12))
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	return button

func _quiet_button(parent: Node, text: String, callback: Callable) -> Button:
	var button: Button = _button(parent, text, callback)
	button.add_theme_stylebox_override("normal", _style(Color.TRANSPARENT, Color.TRANSPARENT, 4))
	button.add_theme_stylebox_override("hover", _style(Color(TEAL, 0.3), Color.TRANSPARENT, 4))
	button.custom_minimum_size.y = 32
	button.clip_text = false
	button.add_theme_font_size_override("font_size", 15)
	return button

func _build_game() -> void:
	_game = _full_control(_root)
	_game.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_strip = MarginContainer.new()
	_top_strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top_strip.offset_left = 24
	_top_strip.offset_right = -24
	_top_strip.offset_top = 20
	_game.add_child(_top_strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_top_strip.add_child(row)
	for i: int in range(3):
		var pill: PanelContainer = _card(row)
		pill.custom_minimum_size.x = 126
		pill.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var crew_style: StyleBoxFlat = _style(Color(INK,0.88),Color(TEAL,0.35),8)
		crew_style.border_color = [Color("50c8f3"),CORAL,Color("b598ff")][i]
		crew_style.border_width_left = 4
		crew_style.border_width_top = 0
		crew_style.border_width_bottom = 0
		crew_style.border_width_right = 0
		pill.add_theme_stylebox_override("panel", crew_style)
		var name_label: Label = _add_label(pill, "", 14, CREAM)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.max_lines_visible = 2
		_crew_labels.append(name_label)
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(space)
	_stats = _add_label(row, "", 17, CREAM)
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_outline(_stats)
	_objective = _add_label(_game, "", 14, CREAM)
	_objective.hide()
	_vote_notice = _add_label(_game, "", 14, CREAM, true)
	_vote_notice.position = Vector2(24, 74)
	_vote_notice.size.x = 334
	_vote_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline(_vote_notice)
	_vote_notice.hide()
	_action_card = _card(_game)
	_action_card.add_theme_stylebox_override("panel", _style(Color(INK, 0.86), Color.TRANSPARENT, 8))
	_action_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_action_card.offset_top = -100
	_action_card.offset_bottom = -54
	var action := HBoxContainer.new()
	action.add_theme_constant_override("separation", 10)
	_action_card.add_child(action)
	_keycap = _card(action)
	_keycap.add_theme_stylebox_override("panel", _style(CREAM, CREAM, 5))
	_action_key = _add_label(_keycap, "", 14, INK)
	_context = _add_label(action, "", 17, CREAM)
	_context.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_context.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_context.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_card.hide()
	_status_strip = HBoxContainer.new()
	_status_strip.add_theme_constant_override("separation", 8)
	_status_strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_status_strip.offset_left = 24
	_status_strip.offset_top = -54
	_status_strip.offset_bottom = -18
	_game.add_child(_status_strip)
	_lamp_status = _status_chip(_status_strip, "lamp", "Lantern time remaining")
	_pouch_status = _status_chip(_status_strip, "pouch", "Unbanked coins in your pouch")
	_ability_status = _status_chip(_status_strip, "tool", "Role tool cooldown")
	_field_status = _add_label(_status_strip, "", 13, MUTED)
	_field_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_equipment = _add_label(_game, "", 13, CREAM)
	_equipment.hide()
	_controls = _add_label(_game, "", 13, MUTED)
	_controls.hide()
	_recap_card = _card(_game)
	_recap_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_recap_card.offset_left = -320
	_recap_card.offset_right = 320
	_recap_card.offset_top = -192
	_recap_card.offset_bottom = -112
	_recap_text = _add_label(_recap_card, "", 15, CREAM, true)
	_recap_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_recap_card.hide()
	_fish_card = _card(_game)
	_fish_card.add_theme_stylebox_override("panel", _style(Color(INK, 0.96), Color(MINT, 0.55), 16))
	_fish_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_fish_card.offset_left = -270
	_fish_card.offset_right = 270
	_fish_card.offset_top = -350
	_fish_card.offset_bottom = -112
	_fish_box = _column(_fish_card, 7)
	var fishing_heading := HBoxContainer.new()
	_fish_box.add_child(fishing_heading)
	_fish_state = _add_label(fishing_heading, "BITE!", 16, AMBER)
	_fish_state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fish_counter = _add_label(fishing_heading, "", 12, MINT)
	_fish_instruction = _add_label(_fish_box, "", 24, CREAM)
	_fish_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fish_hint = _add_label(_fish_box, "", 13, MUTED, true)
	_fish_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fish_pull = PullRail.new()
	_fish_box.add_child(_fish_pull)
	_progress = _bar(_fish_box, MINT)
	_progress.custom_minimum_size.y = 10
	var fishing_footer := HBoxContainer.new()
	_fish_box.add_child(fishing_footer)
	_progress_label = _add_label(fishing_footer, "CATCH", 12, MINT)
	_progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fish_mode = _add_label(fishing_footer, "", 11, MUTED)
	_ignore_feedback_input(_fish_card)
	_fish_card.hide()
	_build_catch_reveal()
	_next_step_card = _card(_game)
	_next_step_card.add_theme_stylebox_override("panel", _style(Color(INK, 0.84), Color(TEAL, 0.4), 12))
	_next_step_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_next_step_card.offset_left = 24
	_next_step_card.offset_right = 320
	_next_step_card.offset_top = 86
	var next_step_column: VBoxContainer = _column(_next_step_card, 4)
	_next_step_title = _add_label(next_step_column, "", 15, MINT, true)
	_next_step_detail = _add_label(next_step_column, "", 13, CREAM, true)
	_ignore_feedback_input(_next_step_card)
	_next_step_card.hide()
	_toast_card = _card(_game)
	_toast_card.add_theme_stylebox_override("panel", _style(Color(INK, 0.78), Color.TRANSPARENT, 10))
	_toast_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_toast_card.offset_left = 24
	_toast_card.offset_right = 358
	_toast_label = _add_label(_toast_card, "", 14, CREAM, true)
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.hide()
	_toast_card.hide()
	_ignore_feedback_input(_toast_card)

func _build_catch_reveal() -> void:
	_catch_reveal = _card(_game)
	_catch_reveal.add_theme_stylebox_override("panel", _style(Color(INK, 0.97), AMBER, 14))
	_catch_reveal.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_catch_reveal.offset_left = -226
	_catch_reveal.offset_right = 226
	_catch_reveal.offset_top = 104
	var column: VBoxContainer = _column(_catch_reveal, 8)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var landed: Label = _add_label(heading, "LANDED!", 17, AMBER)
	landed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_catch_badges = _add_label(heading, "", 11, MINT)
	_catch_badges.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	_catch_portrait = CatchPortrait.new()
	row.add_child(_catch_portrait)
	var information: VBoxContainer = _column(row, 8)
	information.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	information.alignment = BoxContainer.ALIGNMENT_CENTER
	_catch_name = _add_label(information, "", 23, CREAM)
	_catch_details = _add_label(information, "", 15, MINT)
	_catch_destination = _add_label(column, "", 13, MUTED, true)
	_catch_destination.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ignore_feedback_input(_catch_reveal)
	_catch_reveal.hide()

func _ignore_feedback_input(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in control.find_children("*", "Control", true, false):
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _status_chip(parent: Node, kind: String, hint: String) -> Label:
	var chip: PanelContainer = _card(parent)
	chip.add_theme_stylebox_override("panel",_style(Color(INK,0.88),Color(TEAL,0.4),6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.tooltip_text = hint
	chip.add_child(row)
	if not _icons.has(kind):
		var paths: Dictionary = {"lamp":"M8 5V3h8v2M7 7h10l2 14H5L7 7zM9 9v9M15 9v9", "pouch":"M6 7l2-4h8l2 4-2 3 4 9-3 2H7l-3-2 4-9-2-3zM7 7h10", "tool":"M14 3l-3 4 2 4 4 1 4-3-1 6-5 2-3-1-7 7-3-3 7-7-1-3 2-5 4-2z"}
		var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path d="%s" fill="none" stroke="#f3eee2" stroke-width="1.6" stroke-linejoin="round"/></svg>' % paths[kind]
		var icon := Image.new()
		icon.load_svg_from_string(svg)
		_icons[kind] = ImageTexture.create_from_image(icon)
	var picture := TextureRect.new()
	picture.texture = _icons[kind]
	picture.custom_minimum_size = Vector2(22,22)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	row.add_child(picture)
	var label: Label = _add_label(row, "", 14, CREAM)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outline(label)
	return label

func _update_compact_status(light: float, enabled: bool, tool_ready: bool, cooldown: int, pouch: int, cell: bool, fish: bool, stations: Dictionary, elapsed: float, departing: bool) -> void:
	_status_strip.visible = not departing
	_lamp_status.text = "%ds" % ceili(light) if enabled else "off · %ds" % ceili(light)
	_lamp_status.add_theme_color_override("font_color", CORAL if enabled and light <= 15 else CREAM)
	_pouch_status.text = "Cell" if cell else "Whole fish" if fish else str(pouch)
	_ability_status.text = "Ready" if tool_ready else "%ds" % cooldown
	_field_status.text = _field_power(stations, elapsed)
	_field_status.visible = not stations.is_empty() and (elapsed >= 180 or not str(_data.get("choice", {}).get("committed", "")).is_empty())

func _format_action() -> void:
	var full: String = _context.text.strip_edges()
	_action_card.visible = not full.is_empty()
	_keycap.hide()
	if full.is_empty(): return
	var split: int = full.find(" · ")
	if split > 0:
		var prefix: String = full.substr(0, split)
		var key_part: String = prefix.trim_prefix("Hold ").trim_prefix("HOLD ").trim_prefix("Release ")
		var allowed: Array = ["LMB", _key("interact"), _key("assist"), _key("ability"), _key("workshop"), _key("journal"), _key("vote"), _key("ready")]
		if key_part in allowed:
			_action_key.text = prefix
			_context.text = full.substr(split + 3)
			_keycap.show()
	var font: Font = _context.get_theme_font("font")
	var width: float = font.get_string_size(_context.text,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x + 26.0
	if _keycap.visible: width += font.get_string_size(_action_key.text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x + 24.0
	width = clampf(width, 120.0, minf(620.0, _root.size.x - 48.0))
	_action_card.offset_left = -width * 0.5
	_action_card.offset_right = width * 0.5

func _refresh_catalogs(force_kind: String = "") -> void:
	var saved: Dictionary = _data.get("progression", {})
	var progress_key: String = str(saved.get("household_id", "")) + ":" + str(saved.revision) if saved.has("revision") else str(saved.hash())
	var workshop_key: String = progress_key + ":" + _profile_id + ":" + str(_data.get("campaign", {}).get("tools", {}).hash())
	if force_kind == "workshop" or _catalog_cache.get("workshop", "") != workshop_key:
		_catalog_cache.workshop = workshop_key
		_update_workshop(saved, saved.get("profiles", {}).get(_profile_id, {}))
	var journal_key: String = progress_key + ":%d:%d" % [_journal_habitat.selected, _journal_time.selected]
	if force_kind == "journal" or _catalog_cache.get("journal", "") != journal_key:
		_catalog_cache.journal = journal_key
		_update_journal(saved)
	var campaign_key: int = hash([progress_key, _data.get("campaign", {}), _data.get("escape", {}), _data.get("is_host", false)])
	if _catalog_cache.get("campaign", -1) != campaign_key:
		_catalog_cache.campaign = campaign_key
		_update_campaign(_data)

func _build_panels() -> void:
	_overlay = _full_control(_root)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(INK, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var card: PanelContainer = _card(center)
	card.custom_minimum_size = Vector2(740, 0)
	var box: VBoxContainer = _column(card, 12)
	var header: HBoxContainer = HBoxContainer.new()
	box.add_child(header)
	_panel_title = _add_label(header, "", 26, CREAM)
	_panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(header, "Close", _close_panel).custom_minimum_size.x = 92
	var scroll: ScrollContainer = ScrollContainer.new()
	_panel_scroll = scroll
	scroll.custom_minimum_size = Vector2(700, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var body: VBoxContainer = _column(scroll, 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_return_to_ending = _button(body, "Return to the ending · Continue Island", func() -> void: toggle_panel("ending"))
	_return_to_ending.hide()
	for kind: String in ["workshop", "journal", "vote", "host", "pause", "settings", "help", "ending"]:
		var section: VBoxContainer = _column(body, 12)
		section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		section.hide()
		_panels[kind] = section
	_build_workshop(_panels.workshop)
	var journal_tabs := HBoxContainer.new()
	_panels.journal.add_child(journal_tabs)
	_button(journal_tabs, "Island progress", func() -> void: _journal_page(false)).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(journal_tabs, "Fish collection", func() -> void: _journal_page(true)).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_campaign_page = _column(_panels.journal, 12)
	_catches_page = _column(_panels.journal, 12)
	_catches_page.hide()
	_campaign_details = _add_label(_campaign_page, "", 17, CREAM, true)
	_repairs_box = _column(_campaign_page, 8)
	_escape_status = _add_label(_campaign_page, "", 17, AMBER, true)
	_arm_escape = _button(_campaign_page, "Arm Moth for the final night crossing", func() -> void: action_requested.emit("arm_escape", {}))
	_signal_escape = _button(_campaign_page, "Send the beacon signal", func() -> void: action_requested.emit("signal_escape", {}))
	_journal_species = OptionButton.new()
	for id: String in SpeciesModel.catalog():
		_journal_species.add_item(str(SpeciesModel.catalog()[id].name))
		_journal_species.set_item_metadata(_journal_species.item_count - 1, id)
	_journal_species.item_selected.connect(func(_index: int) -> void: _update_journal(_data.get("progression", {})))
	_catches_page.add_child(_journal_species)
	_journal = _add_label(_catches_page, "", 17, CREAM, true)
	_add_label(_catches_page, "Where to fish", 14, MUTED)
	var pool_options: HBoxContainer = HBoxContainer.new()
	_catches_page.add_child(pool_options)
	_journal_habitat = OptionButton.new()
	_journal_time = OptionButton.new()
	for habitat: String in HABITATS: _journal_habitat.add_item(habitat.capitalize())
	for band: String in TIME_BANDS: _journal_time.add_item(band.capitalize())
	pool_options.add_child(_journal_habitat)
	pool_options.add_child(_journal_time)
	_journal_habitat.item_selected.connect(func(_index: int) -> void: _update_journal(_data.get("progression", {})))
	_journal_time.item_selected.connect(func(_index: int) -> void: _update_journal(_data.get("progression", {})))
	_journal_pool = _add_label(_catches_page, "", 15, MUTED, true)
	_build_vote(_panels.vote)
	_build_host(_panels.host)
	_pause_status = _add_label(_panels.pause, "", 19, CREAM, true)
	_host_address = _add_label(_panels.pause, "", 15, MUTED, true)
	_host_address.hide()
	_resume = _button(_panels.pause, "Resume expedition", _close_panel)
	_mute = CheckButton.new()
	_mute.text = "Mute sound on this PC"
	_mute.custom_minimum_size.y = 42
	_mute.add_theme_color_override("font_color", CREAM)
	_mute.toggled.connect(func(muted: bool) -> void: action_requested.emit("set_audio", {"muted": muted}))
	_panels.pause.add_child(_mute)
	var pause_options := HBoxContainer.new()
	pause_options.add_theme_constant_override("separation", 8)
	_panels.pause.add_child(pause_options)
	_button(pause_options, "Settings", func() -> void: toggle_panel("settings")).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(pause_options, "Help", func() -> void: toggle_panel("help")).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_host_tools = _button(pause_options, "Lake Office", func() -> void: toggle_panel("host"))
	_host_tools.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_host_tools.hide()
	_add_label(_panels.pause, "Bank your catch before leaving.", 17, MUTED, true)
	_button(_panels.pause, "Leave island", func() -> void: leave_requested.emit())
	_build_settings(_panels.settings)
	_help_text = _add_label(_panels.help, _control_text(), 17, CREAM, true)
	_ending_summary = _add_label(_panels.ending, "", 21, CREAM, true)
	_continue_island = _button(_panels.ending, "Continue Island", func() -> void:
		if bool(_data.get("is_host", false)):
			action_requested.emit("continue_island", {})
			_close_panel())
	_button(_panels.ending, "Browse the field journal", func() -> void: toggle_panel("journal"))
	_button(_panels.ending, "Leave island", func() -> void: leave_requested.emit())
	_overlay.hide()

func _build_workshop(parent: VBoxContainer) -> void:
	_workshop_status = _add_label(parent, "", 15, MUTED, true)
	var tabs := HBoxContainer.new()
	parent.add_child(tabs)
	for section: String in ["gear", "make", "crew"]:
		_button(tabs, section.capitalize(), func() -> void: _workshop_page(section)).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_workshop_pages[section] = _column(parent, 6)
	var gear: VBoxContainer = _workshop_pages.gear
	for kind: String in ["rod", "lamp"]:
		_add_label(gear, "Rod" if kind == "rod" else "Lantern", 14, MUTED)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 6)
		gear.add_child(grid)
		for id: String in _gear(kind):
			var metadata: Dictionary = _gear(kind)[id]
			var button: Button = _button(grid, str(metadata.name), func() -> void: action_requested.emit("equip_" + kind, {kind + "_id": id}))
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.custom_minimum_size.y = 34
			button.add_theme_font_size_override("font_size", 15)
			button.tooltip_text = str(metadata.description) + "\n" + str(metadata.acquisition)
			button.set_meta("base_text", button.text)
			button.set_meta("gear_kind", kind)
			_gear_buttons[id] = button
	_add_label(gear, "Outfit", 14, MUTED)
	_outfit_grid = GridContainer.new()
	_outfit_grid.columns = 4
	_outfit_grid.add_theme_constant_override("h_separation", 6)
	gear.add_child(_outfit_grid)
	for id: String in GearModel.outfits_all():
		var metadata: Dictionary = GearModel.outfit(id)
		var button: Button = _button(_outfit_grid, str(metadata.name), func() -> void: action_requested.emit("equip_outfit", {"outfit_id": id}))
		button.custom_minimum_size.y = 34
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
		button.tooltip_text = str(metadata.description) + "\n" + str(metadata.acquisition)
		_outfit_buttons[id] = button
	_outfit_hint = _add_label(gear, "", 14, MUTED, true)
	var make: VBoxContainer = _workshop_pages.make
	for id: String in _recipes():
		var recipe: Dictionary = _recipes()[id]
		_recipe_buttons[id] = _button(make, str(recipe.name), func() -> void: action_requested.emit("craft", {"recipe_id": id}))
		_add_label(make, _recipe_cost(recipe) + "\n" + str(recipe.get("hint", "")), 15, MUTED, true)
	_button(make, "Island repairs", func() -> void:
		_journal_page(false)
		toggle_panel("journal"))
	var crew: VBoxContainer = _workshop_pages.crew
	_profile_name = _line_edit(crew, "Your name", "Angler")
	_profile_name.max_length = 32
	_role = OptionButton.new()
	_role.add_item("Scout · find fish")
	_role.add_item("Keeper · protect the crew")
	_role.add_item("Rigger · pull fish and crewmates")
	_role.custom_minimum_size.y = 40
	crew.add_child(_role)
	_button(crew, "Save name & role", func() -> void: action_requested.emit("set_profile", {"name": _profile_name.text.strip_edges(), "role_id": ROLE_IDS[_role.selected]}))
	_tool_status = _add_label(crew, "", 16, CREAM, true)
	_standard_tool = _button(crew, "Standard tool", func() -> void: action_requested.emit("set_tool", {"mode": "standard"}))
	_alternate_tool = _button(crew, "Alternate tool", func() -> void: action_requested.emit("set_tool", {"mode": "alternate"}))
	_workshop_page("gear")

func _workshop_page(kind: String) -> void:
	for id: String in _workshop_pages: _workshop_pages[id].visible = id == kind
	_panel_scroll.scroll_vertical = 0
func _build_vote(parent: VBoxContainer) -> void:
	_vote_status = _add_label(parent, "", 18, CREAM, true)
	_add_label(parent, "One pull decides for everyone. Chosen shelter: 150s of night light.\nJetty protects the way home. Reeds shelters night fishing.", 18, MUTED, true)
	_open_vote = _button(parent, "Use dock battery", func() -> void: action_requested.emit("open_vote", {}))
	_jetty = _button(parent, "Power Jetty · Reeds goes dark", func() -> void: action_requested.emit("vote", {"choice": "jetty"}))
	_reeds = _button(parent, "Power Reeds · Jetty goes dark", func() -> void: action_requested.emit("vote", {"choice": "reeds"}))
	_add_label(parent, "Locked until dawn. Spare cells add 90s to either shelter.\nMoth stays safe. No choice by dusk powers Jetty.", 16, MUTED, true)

func _build_host(parent: VBoxContainer) -> void:
	_add_label(parent, "A little trouble. Always recoverable.\nOne event at a time; ordinary rewards stay intact.", 18, CREAM, true)
	for pair: Array in [["odd_catch", "Odd Catch · next fish looks ridiculous"], ["fog", "Fog · a brief 15-second bank"], ["sighting", "Suspicious Splash · a distant sighting"], ["clear_event", "Clear current event"], ["safe_return", "Return crew safely · end current risk"]]:
		var event_id: String = pair[0]
		_button(parent, pair[1], func() -> void: action_requested.emit("host_event", {"event_id": event_id}))

func _update_workshop(progression: Dictionary, profile: Dictionary) -> void:
	var owned_lamps: Array = progression.get("owned_lamps", [])
	var owned_rods: Array = progression.get("owned_rods", [])
	var coins: int = int(progression.get("coins", 0))
	var salvage: Dictionary = progression.get("salvage", {})
	var supply_text: PackedStringArray = []
	for supply: String in salvage: supply_text.append("%d %s" % [int(salvage[supply]), supply.replace("_", " ")])
	_workshop_status.text = "%d shared coins · %s" % [coins, " · ".join(supply_text) if not supply_text.is_empty() else "Find supplies in caches"]
	for id: String in _recipe_buttons:
		var recipe: Dictionary = _recipes()[id]
		var owned: bool = str(recipe.output_id) in (owned_rods if recipe.output_kind == "rod" else owned_lamps)
		var known: bool = id in progression.get("known_recipes", [])
		var affordable: bool = coins >= int(recipe.coins)
		for supply: String in recipe.salvage:
			affordable = affordable and int(salvage.get(supply, 0)) >= int(recipe.salvage[supply])
		var button: Button = _recipe_buttons[id]
		button.disabled = owned or not known or not affordable
		button.text = str(recipe.name) + ("  [crafted for crew]" if owned else "  [find recipe]" if not known else "  [need supplies]" if not affordable else "  · Craft")
	for id: String in _outfit_buttons:
		var selected: bool = str(profile.get("outfit_id", "harbour")) == id
		var unlocked: bool = GearModel.outfit_unlocked(progression, id)
		_outfit_buttons[id].disabled = selected or not unlocked
		_outfit_buttons[id].text = str(GearModel.outfit(id).name) + (" ✓" if selected else "")
	_outfit_hint.text = str(GearModel.outfit(str(profile.get("outfit_id", "harbour"))).description)
	for id: String in _gear_buttons:
		var button: Button = _gear_buttons[id]
		var is_rod: bool = button.get_meta("gear_kind") == "rod"
		var has_item: bool = id in (owned_rods if is_rod else owned_lamps)
		var selected: bool = profile.get("rod_id" if is_rod else "lamp_id", "") == id
		button.disabled = not has_item or selected
		button.text = str(button.get_meta("base_text")) + (" ✓" if selected else " · locked" if not has_item else "")
	var tool: Dictionary = _data.get("campaign", {}).get("tools", {}).get(str(profile.get("role_id", "scout")), {})
	var alternate: bool = profile.get("tool_mode", "standard") == "alternate"
	_tool_status.text = str(tool.get("name", "Alternate tool")) + " · " + str(tool.get("hint", "Explore and restore the island to unlock a second tool."))
	if not str(tool.get("description", "")).is_empty(): _tool_status.text += "\n" + str(tool.description)
	_standard_tool.disabled = not alternate
	_alternate_tool.disabled = alternate or not bool(tool.get("unlocked", false))
	_alternate_tool.text = "Use " + str(tool.get("name", "alternate tool")) + ("  [equipped]" if alternate else "  [locked]" if not bool(tool.get("unlocked", false)) else "")

func _update_journal(progression: Dictionary) -> void:
	var catalog: Dictionary = SpeciesModel.catalog()
	var id: String = str(_journal_species.get_item_metadata(_journal_species.selected))
	var fish: Dictionary = catalog[id]
	var record: Dictionary = progression.get("specimen_records", {}).get(id, {})
	var detail: String = "%s · %d / %d discovered\n\n%s\n%s · %d coins base\n%s" % [fish.name, progression.get("discoveries", []).size(), catalog.size(), "Not caught yet" if record.is_empty() else "%d caught · best %.2f m" % [int(record.get("count", 0)), float(record.get("largest_size", 0.0))], str(fish.rarity).capitalize(), int(fish.value), fish.habitat_hint]
	if not record.get("traits", []).is_empty(): detail += "\nTraits: " + ", ".join(PackedStringArray(record.traits))
	_journal.text = detail
	var habitat: String = HABITATS[_journal_habitat.selected]
	var band: String = TIME_BANDS[_journal_time.selected]
	var chances: PackedStringArray = []
	var rare_pool: bool = false
	for entry: Dictionary in CatchModel.pool(habitat, band):
		chances.append("%s %.0f%%" % [catalog[entry.species_id].name, float(entry.chance) * 100.0])
		rare_pool = rare_pool or SpeciesModel.is_rare(entry.species_id)
	_journal_pool.text = "Base chances: " + " · ".join(chances)
	if rare_pool: _journal_pool.text += "\nRare catch streak: %d / 11" % mini(int(progression.get("dry_streaks", {}).get(habitat, 0)), 11)
	_journal_pool.tooltip_text = "After 11 eligible ordinary landings in this habitat, the next eligible cast offers its rare fish. Failed casts keep the streak. Fish are recorded on landing; bank them at Moth to keep their coins."
func _journal_page(catches: bool) -> void:
	_campaign_page.visible = not catches
	_catches_page.visible = catches
	_panel_scroll.scroll_vertical = 0

func _recipes() -> Dictionary:
	return CraftModel.recipes_all()

func _gear(kind: String) -> Dictionary:
	return GearModel.rods_all() if kind == "rod" else GearModel.lamps_all()

func _recipe_cost(recipe: Dictionary) -> String:
	var parts: PackedStringArray = ["%d coins" % int(recipe.get("coins", 0))]
	for id: String in recipe.get("salvage", {}): parts.append("%d %s" % [int(recipe.salvage[id]), id.replace("_", " ")])
	return " + ".join(parts)

func _update_campaign(data: Dictionary) -> void:
	var campaign: Dictionary = data.get("campaign", {})
	var escape: Dictionary = data.get("escape", {})
	_objective.text = str(campaign.get("objective", "Explore the island, land a catch, and return it to Moth.")) + "  · %s journal" % _key("journal")
	var details: String = str(campaign.get("title", "GET THE CREW HOME")).to_upper() + "\n" + str(campaign.get("objective", "Find the engine part and beacon coil. Bank fish to fund repairs."))
	var repairs: Array = campaign.get("repairs", []).duplicate()
	repairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("optional",false)) < int(b.get("optional",false)))
	for repair: Dictionary in repairs:
		if not bool(repair.get("optional", false)):
			details += "\n\n%s %s · %s" % ["✓" if bool(repair.get("complete", false)) else "○", repair.get("name", repair.get("id", "Repair")), repair.get("location", "")]
			if not bool(repair.get("complete", false)): details += "\n" + str(repair.get("requirements", "Explore the nearby caches."))
		var id: String = str(repair.get("id", ""))
		if not id.is_empty():
			if not _repair_buttons.has(id):
				_repair_buttons[id] = _button(_repairs_box, "", func() -> void: action_requested.emit("repair", {"repair_id": id}))
			_repair_buttons[id].text = "%s%s" % [repair.get("name", id), " · optional" if bool(repair.get("optional", false)) else ""]
			_repair_buttons[id].tooltip_text = "%s · %s" % [repair.get("location", ""), repair.get("requirements", "")]
			_repair_buttons[id].visible = not bool(repair.get("complete", false))
			_repair_buttons[id].disabled = bool(repair.get("complete", false)) or not bool(repair.get("available", false))
	_campaign_details.text = details
	_return_to_ending.visible = bool(escape.get("completed", false)) and _panel_kind != "ending"
	_escape_status.text = str(escape.get("description", "Restore the island before attempting the final night crossing."))
	_arm_escape.disabled = not bool(escape.get("can_arm", false))
	_signal_escape.disabled = not bool(escape.get("can_signal", false))
	_continue_island.disabled = not bool(data.get("is_host", false))
	var saved: Dictionary = data.get("progression", {})
	_ending_summary.text = "You brought the crew home.\n\n%d species discovered · %d coins banked.\n\nContinue for new catches or another night escape. Your gear and repairs stay." % [saved.get("discoveries", []).size(), int(saved.get("lifetime_banked", 0))]
	if not bool(data.get("is_host", false)): _ending_summary.text += "\nThe host chooses when to continue."
	if bool(escape.get("completed", false)) and not _ending_seen:
		_ending_seen = true
		toggle_panel("ending")
	elif not bool(escape.get("completed", false)):
		_ending_seen = false
		if _panel_kind == "ending": _close_panel()

func _field_power(stations: Dictionary, elapsed: float) -> String:
	var parts: PackedStringArray = []
	for id: String in ["jetty", "reeds"]:
		var remaining: int = ceili(maxf(0.0, minf(630.0, float(stations.get(id, 240.0))) - maxf(240.0, elapsed)))
		parts.append("%s %ds" % [id.capitalize(), remaining] if remaining > 0 else "%s %s" % [id.capitalize(), "daylight" if elapsed < 240.0 else "dark"])
	return " · ".join(parts)

func _key(action: String) -> String:
	return _settings.key_label(action) if _settings != null else "?"

func _control_text() -> String:
	return "EXPLORE\n%s / %s / %s / %s move · Right mouse drag to look\n%s interact · %s lantern · %s role tool\n\nFISH\nLMB casts. Hold LMB to move your bar right; release to move left.\nKeep the blue fish line inside your bar to fill catch progress.\n%s switch hold/click mode · %s cancel\n\nCARRY & RESCUE\n%s pick up / put down · Hold LMB, release to throw\nHold %s to pack a fish. Whole fish earn more at the boat.\nHold %s to revive a crewmate · %s carry / put down\n\nRETURN\n%s bank at the boat · %s ready to leave\n%s workshop · %s dock battery · %s journal · %s menu" % [_key("move_forward"), _key("move_left"), _key("move_back"), _key("move_right"), _key("interact"), _key("toggle_lamp"), _key("ability"), _key("toggle_reel"), _key("cancel_cast"), _key("interact"), _key("pack"), _key("interact"), _key("assist"), _key("interact"), _key("ready"), _key("workshop"), _key("vote"), _key("journal"), _key("pause")]

func _build_settings(parent: VBoxContainer) -> void:
	_add_label(parent, "Saved on this PC.", 16, MUTED, true)
	_settings_status = _add_label(parent, "", 16, AMBER, true)
	for key: String in ["master_volume", "threat_volume", "mouse_sensitivity"]:
		var label: Label = _add_label(parent, "", 17, CREAM)
		var slider := HSlider.new()
		slider.min_value = 0.2 if key == "mouse_sensitivity" else 0.0
		slider.max_value = 3.0 if key == "mouse_sensitivity" else 1.0
		slider.step = 0.05
		slider.custom_minimum_size.y = 32
		slider.value_changed.connect(func(value: float) -> void: _set_local_setting(key, value))
		parent.add_child(slider)
		_setting_widgets[key] = {"control": slider, "label": label}
	for key: String in ["invert_y", "reduced_effects", "shadows", "smooth_edges"]:
		var check := CheckButton.new()
		check.text = {"invert_y":"Invert mouse look", "reduced_effects":"Reduce effects", "shadows":"Shadows", "smooth_edges":"Smooth edges"}[key]
		check.custom_minimum_size.y = 42
		check.toggled.connect(func(enabled: bool) -> void: _set_local_setting(key, enabled))
		parent.add_child(check)
		_setting_widgets[key] = {"control": check}
	_add_label(parent, "Window mode", 17, CREAM)
	var modes := OptionButton.new()
	for mode: String in ["Windowed", "Borderless", "Fullscreen"]: modes.add_item(mode)
	modes.item_selected.connect(func(index: int) -> void: _set_local_setting("window_mode", ["windowed", "borderless", "fullscreen"][index]))
	parent.add_child(modes)
	_setting_widgets.window_mode = {"control": modes}
	_add_label(parent, "KEYBOARD · click an action, then press a key\nEscape cancels. Conflicting keys swap.", 16, AMBER, true)
	for action: String in SettingsModel.DEFAULT_BINDINGS:
		var button: Button = _button(parent, "", func() -> void:
			_capture_action = action
			_sync_binding_buttons())
		_binding_buttons[action] = button
	_button(parent, "Reset keyboard bindings", func() -> void:
		for action: String in SettingsModel.DEFAULT_BINDINGS: _settings.set_binding(action, SettingsModel.DEFAULT_BINDINGS[action])
		_commit_settings())

func _set_local_setting(key: String, value: Variant) -> void:
	if _settings.set_value(key, value): _commit_settings()

func _commit_settings() -> void:
	var error: Error = _settings.save_settings()
	_settings_status.text = "Saved on this PC." if error == OK else "Active for this session; settings could not be saved (error %d)." % error
	_sync_settings_widgets()
	settings_changed.emit(_settings.snapshot())

func _sync_settings_widgets() -> void:
	if _settings == null: return
	var values: Dictionary = _settings.snapshot()
	for key: String in _setting_widgets:
		var widget: Control = _setting_widgets[key].control
		if widget is HSlider:
			widget.set_value_no_signal(float(values[key]))
			_setting_widgets[key].label.text = "%s · %.2f%s" % [key.replace("_", " ").capitalize(), float(values[key]) if key == "mouse_sensitivity" else float(values[key]) * 100.0, "×" if key == "mouse_sensitivity" else "%"]
		elif widget is CheckButton: widget.set_pressed_no_signal(bool(values[key]))
		elif widget is OptionButton: widget.select(["windowed", "borderless", "fullscreen"].find(values[key]))
	_sync_binding_buttons()
	if _help_text != null: _help_text.text = _control_text()

func _sync_binding_buttons() -> void:
	for action: String in _binding_buttons:
		_binding_buttons[action].text = str(SettingsModel.ACTION_NAMES[action]) + "  ·  " + ("Press a key…" if _capture_action == action else _key(action))

func _input(event: InputEvent) -> void:
	if _capture_action.is_empty() or not event is InputEventKey or not event.pressed or event.echo: return
	get_viewport().set_input_as_handled()
	if event.physical_keycode == KEY_ESCAPE:
		_capture_action = ""
		_sync_binding_buttons()
	elif _settings.set_binding(_capture_action, int(event.physical_keycode)):
		_capture_action = ""
		_commit_settings()

func _update_vote(choice: Dictionary, elapsed: float) -> void:
	var committed: String = str(choice.get("committed", ""))
	var opened: bool = bool(choice.get("open", false))
	var nearby: bool = bool(_data.get("near_battery", false))
	_vote_notice.hide()
	_vote_status.text = "Pull once before dusk. Your choice affects the whole crew." if nearby else "Return to the dock battery to choose."
	if not committed.is_empty():
		var until: float = float(_data.get("lights", {}).get("station_until", {}).get(committed, 390.0))
		var seconds: int = ceili(maxf(0.0, minf(630.0, until) - maxf(240.0, elapsed)))
		var who: String = str(_data.get("progression", {}).get("profiles", {}).get(str(choice.get("decided_by", "")), {}).get("name", "Default switch"))
		_vote_status.text = "%s powered %s · %ds %s.\nA spare cell can light either shelter." % [who, committed.capitalize(), seconds, "after sunset" if elapsed < 240.0 else "remaining"]
	_open_vote.visible = not opened and committed.is_empty()
	_open_vote.disabled = not nearby or elapsed >= 180.0
	_jetty.disabled = not nearby or not opened or not committed.is_empty() or elapsed >= 180.0
	_reeds.disabled = _jetty.disabled

func _update_night_advice(light: float, departing: bool, urgent: bool) -> void:
	_vote_notice.hide()
	if departing or urgent or panel_open() or _catch_reveal.visible: return
	for player: Dictionary in _data.get("run", {}).get("players", {}).values():
		if bool(player.get("downed", false)) or not str(player.get("carried_by", "")).is_empty(): return
	if not _data.get("rescue_progress", {}).is_empty(): return
	var elapsed: float = float(_data.get("run", {}).get("elapsed_s", 0.0))
	var stations: Dictionary = _data.get("lights", {}).get("station_until", {})
	var advice: String = ""
	if light <= 0.0:
		var destinations: PackedStringArray = ["Moth"]
		for station: String in ["jetty", "reeds"]:
			if elapsed < 630.0 and elapsed < float(stations.get(station, 240.0)):
				destinations.append(station.capitalize())
		advice = "Lantern empty · return to recharge\nWalk into the light at " + " or ".join(destinations) + "."
	elif elapsed >= 150.0 and elapsed < 180.0 and str(_data.get("choice", {}).get("committed", "")).is_empty():
		advice = "Choose a night shelter · %ds left\nAt the dock battery: %s · Jetty or Reeds" % [ceili(180.0-elapsed), _key("vote")]
	elif elapsed >= 180.0 and elapsed < 240.0:
		var station: String = str(_data.get("choice", {}).get("committed", ""))
		var seconds: int = ceili(maxf(0.0, minf(630.0, float(stations.get(station, 240.0))) - 240.0))
		advice = ("%s · %ds of night shelter\n" % [station.capitalize(), seconds] if seconds > 0 else "Spare cells can light Jetty or Reeds.\n") + "Moth stays safe through the night."
	if advice.is_empty(): return
	_vote_notice.text = advice
	_vote_notice.add_theme_color_override("font_color", CORAL if light <= 0.0 else CREAM)
	_vote_notice.show()

func _full_control(parent: Node) -> Control:
	var control: Control = Control.new()
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(control)
	return control

func _card(parent: Node) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _style(Color(INK, 0.96), TEAL.lightened(0.2), 16))
	parent.add_child(card)
	return card

func _column(parent: Node, gap: int) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", gap)
	parent.add_child(column)
	return column

func _add_label(parent: Node, text: String, size: int, color: Color, wrap: bool = false) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.clip_text = true
	button.custom_minimum_size.y = 40
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _outline(label: Label) -> void:
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", 4)

func _line_edit(parent: Node, placeholder: String, text: String) -> LineEdit:
	var field: LineEdit = LineEdit.new()
	field.placeholder_text = placeholder
	field.text = text
	field.custom_minimum_size.y = 42
	parent.add_child(field)
	return field

func _bar(parent: Node, color: Color) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.max_value = 1.0
	bar.step = 0.001
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.add_theme_stylebox_override("background", _style(INK.lightened(0.12), INK, 0))
	bar.add_theme_stylebox_override("fill", _style(color, color, 0))
	parent.add_child(bar)
	return bar

func _style(background: Color, border: Color, padding: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

func _make_theme() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", CREAM)
	for type: String in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, _style(Color(INK,0.3), Color(CREAM,0.3), 10))
		theme.set_stylebox("hover", type, _style(TEAL.lightened(0.12), AMBER, 10))
		theme.set_stylebox("pressed", type, _style(INK, AMBER, 10))
		theme.set_stylebox("disabled", type, _style(INK.lightened(0.05), TEAL, 10))
		theme.set_stylebox("focus", type, _style(Color(0, 0, 0, 0), AMBER, 0))
		theme.set_color("font_color", type, CREAM)
		theme.set_color("font_hover_color", type, CREAM)
		theme.set_color("font_disabled_color", type, MUTED.darkened(0.2))
	theme.set_stylebox("normal", "LineEdit", _style(INK.lightened(0.06), TEAL.lightened(0.2), 10))
	theme.set_stylebox("focus", "LineEdit", _style(Color(0, 0, 0, 0), AMBER, 0))
	theme.set_color("font_color", "LineEdit", CREAM)
	theme.set_color("caret_color", "LineEdit", AMBER)
	return theme

class_name SettingsLocal
extends RefCounted

var path: String
var load_error: String = ""
const DEFAULT_BINDINGS: Dictionary = {
	"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
	"interact": KEY_E, "ability": KEY_Q, "toggle_lamp": KEY_F, "assist": KEY_R,
	"vote": KEY_V, "ready": KEY_B, "workshop": KEY_K, "journal": KEY_J,
	"pause": KEY_ESCAPE, "toggle_reel": KEY_T, "pack": KEY_P,
	"cancel_cast": KEY_X, "ping": KEY_G, "host_panel": KEY_F8}
const ACTION_NAMES: Dictionary = {
	"move_forward": "Move forward", "move_back": "Move back", "move_left": "Move left", "move_right": "Move right",
	"interact": "Interact / receive / revive", "ability": "Role tool", "toggle_lamp": "Lantern", "assist": "Assist fishing",
	"vote": "Dock battery", "ready": "Ready aboard", "workshop": "Workshop", "journal": "Journal / objectives",
	"pause": "Menu", "toggle_reel": "Toggle reel mode", "pack": "Hold to pack fish",
	"cancel_cast": "Cancel cast", "ping": "Ping", "host_panel": "Host Lake Office"}
var _values: Dictionary

func _init(settings_path: String = "user://settings.json") -> void:
	path = settings_path
	_values = _defaults()

static func _defaults() -> Dictionary:
	return {"master_volume": 1.0, "threat_volume": 1.0, "mouse_sensitivity": 1.0,
		"invert_y": false, "window_mode": "windowed", "reduced_effects": false, "shadows": false,
		"bindings": DEFAULT_BINDINGS.duplicate(true)}

func load_settings() -> Dictionary:
	_values = _defaults()
	load_error = ""
	if not FileAccess.file_exists(path): return snapshot()
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		load_error = "Unreadable settings; defaults are active. Existing file was preserved."
		return snapshot()
	var loaded: Dictionary = parser.data
	for key: String in loaded:
		if key == "bindings": continue
		set_value(key, loaded[key])
	if loaded.get("bindings") is Dictionary:
		for action: String in loaded.bindings:
			var code: Variant = loaded.bindings[action]
			if (code is int or code is float) and is_finite(float(code)) and float(code) == floorf(float(code)):
				set_binding(action, int(code))
	return snapshot()

func snapshot() -> Dictionary:
	return _values.duplicate(true)

func set_value(key: String, value: Variant) -> bool:
	if key in ["master_volume", "threat_volume", "mouse_sensitivity"]:
		if not (value is float or value is int) or not is_finite(float(value)): return false
		_values[key] = clampf(float(value), 0.2, 3.0) if key == "mouse_sensitivity" else clampf(float(value), 0.0, 1.0)
	elif key in ["invert_y", "reduced_effects", "shadows"]:
		if not value is bool: return false
		_values[key] = value
	elif key == "window_mode":
		if value not in ["windowed", "borderless", "fullscreen"]: return false
		_values[key] = value
	else: return false
	return true

func set_binding(action: String, physical_keycode: int) -> bool:
	if not DEFAULT_BINDINGS.has(action) or physical_keycode <= 0 or physical_keycode > KEY_SPECIAL + 65535: return false
	if physical_keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK, KEY_NUMLOCK, KEY_SCROLLLOCK]: return false
	if OS.get_keycode_string(physical_keycode).is_empty(): return false
	var old_key: int = action_key(action)
	for other: String in _values.bindings:
		if other != action and int(_values.bindings[other]) == physical_keycode:
			_values.bindings[other] = old_key
	_values.bindings[action] = physical_keycode
	return true

func save_settings() -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(_values, "\t"))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	return error

func action_key(action: String) -> int:
	return int(_values.bindings.get(action, 0))

func key_label(action: String) -> String:
	return OS.get_keycode_string(action_key(action))

func pressed(action: String) -> bool:
	return action_key(action) != 0 and Input.is_physical_key_pressed(action_key(action))

func event_matches(event: InputEventKey, action: String) -> bool:
	return event.pressed and not event.echo and action_key(action) != 0 and event.physical_keycode == action_key(action)

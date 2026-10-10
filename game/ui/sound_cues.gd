class_name SoundCues
extends Node
## Local presentation only: cached procedural PCM, driven by confirmed state/events.
const RATE: int = 22050
const THREAT_KINDS: Array[String] = ["warn", "down", "storm", "bell"]
const PHYSICAL_KINDS: Array[String] = ["cast", "toss", "cell", "splash", "cargo"]
static var _clips: Dictionary = {}
var player: AudioStreamPlayer
var threat_volume: float = 1.0
var _channels: Dictionary = {}
var _clock: float = 0.0
var _step_at: float = 0.0
var _hunter_at: float = 0.0
var _reel_until: float = 0.0
var _cast_id: String = ""
var _cast_progress: float = 0.0
var _variation: int = 0

func _ready() -> void:
	if _clips.is_empty():
		for kind: String in ["water", "wind", "rain", "reel", "woodstep", "wetstep", "cast", "catch", "bank", "warn", "down", "rescue", "toss", "cell", "storm", "escape", "click", "bell", "cargo", "splash"]:
			_clips[kind] = _make_clip(kind)
	for id: String in ["water", "wind", "rain", "reel", "steps", "hunter", "threat", "physical", "reward"]:
		var channel := AudioStreamPlayer.new()
		channel.name = id.capitalize() + "Audio"
		channel.bus = "Master"
		add_child(channel)
		_channels[id] = channel
	player = _channels.reward

func apply_settings(values: Dictionary) -> void:
	threat_volume = clampf(float(values.get("threat_volume", 1.0)), 0.0, 1.0)
	for id: String in ["threat", "hunter"]:
		if not _channels.has(id): continue
		if threat_volume <= 0.0: _channels[id].stop()
		else: _channels[id].volume_db = (-14.0 if id == "threat" else -22.0) + linear_to_db(threat_volume)

func play_cue(kind: String) -> void:
	if _channels.is_empty(): return
	if not _clips.has(kind): kind = "click"
	var target: String = "threat" if kind in THREAT_KINDS else "physical" if kind in PHYSICAL_KINDS else "reward"
	if target == "threat" and threat_volume <= 0.0: return
	var channel: AudioStreamPlayer = _channels[target]
	channel.stream = _clips[kind]
	channel.volume_db = (-14.0 + linear_to_db(threat_volume)) if target == "threat" else -17.0
	channel.pitch_scale = 1.0
	channel.play()

func update_view(snapshot: Dictionary, local_profile: String, delta: float) -> void:
	if _channels.is_empty(): return
	var run: Dictionary = snapshot.get("run", {})
	if run.is_empty() or bool(run.get("paused", false)):
		for channel: AudioStreamPlayer in _channels.values(): channel.stop()
		_cast_id = ""
		_cast_progress = 0.0
		_reel_until = 0.0
		_step_at = _clock
		_hunter_at = _clock
		return
	_clock += clampf(delta, 0.0, 0.5)
	var phase: String = str(run.get("phase", "day"))
	_loop("water", true, -28.0)
	_loop("wind", true, -29.0 if phase in ["night", "storm"] else -34.0)
	_loop("rain", phase == "storm", -29.0)
	var frozen: bool = bool(run.get("terminal", false)) or float(run.get("crossing_left", -1.0)) >= 0.0
	var local_player: Dictionary = run.get("players", {}).get(local_profile, {})
	var pose: Dictionary = snapshot.get("poses", {}).get("players", {}).get(local_profile, {})
	var velocity: Vector3 = pose.get("velocity", Vector3.ZERO) as Vector3
	var moving: bool = not frozen and not bool(local_player.get("downed", false)) and Vector2(velocity.x, velocity.z).length() > 0.8
	if moving and _clock >= _step_at:
		_step_at = _clock + 0.38
		_step("steps", "woodstep", -25.0)
	elif not moving: _channels.steps.stop()
	var fishing: Dictionary = snapshot.get("fishing", {}).get(local_profile, {})
	var cast: String = str(fishing.get("catch_id", ""))
	var progress: float = float(fishing.get("progress", 0.0))
	if cast != _cast_id:
		_cast_id = cast
		_reel_until = 0.0
	elif progress > _cast_progress + 0.0001:
		_reel_until = _clock + 0.3
	_cast_progress = progress
	_loop("reel", not frozen and not cast.is_empty() and _clock < _reel_until, -27.0)
	var hunter_pose: Variant = snapshot.get("poses", {}).get("hunter")
	var near_hunter: bool = false
	var distance: float = 100.0
	if hunter_pose is Transform3D and pose.get("position") is Vector3:
		distance = (hunter_pose as Transform3D).origin.distance_to(pose.position)
		near_hunter = distance < 30.0 and phase in ["night", "storm"] and snapshot.get("hunter", "") in ["patrol", "investigate", "chase"]
	if near_hunter and not frozen and threat_volume > 0.0 and _clock >= _hunter_at:
		_hunter_at = _clock + (0.44 if snapshot.get("hunter", "") == "chase" else 0.78)
		_step("hunter", "wetstep", -16.0 - distance * 0.45 + linear_to_db(threat_volume))
	elif not near_hunter or frozen or threat_volume <= 0.0: _channels.hunter.stop()

func _loop(id: String, enabled: bool, volume: float) -> void:
	var channel: AudioStreamPlayer = _channels[id]
	if not enabled:
		channel.stop()
		return
	channel.volume_db = volume
	if not channel.playing:
		channel.stream = _clips[id]
		channel.play()

func _step(channel_id: String, kind: String, volume: float) -> void:
	var channel: AudioStreamPlayer = _channels[channel_id]
	_variation += 1
	channel.stream = _clips[kind]
	channel.volume_db = volume
	channel.pitch_scale = 0.96 if _variation % 2 == 0 else 1.04
	channel.play()

static func _make_clip(kind: String) -> AudioStreamWAV:
	var looped: bool = kind in ["water", "wind", "rain", "reel"]
	var duration: float = {"water":3.0, "wind":3.0, "rain":3.0, "reel":0.4, "woodstep":0.18, "wetstep":0.26, "cast":0.45, "catch":0.65, "bank":0.65, "warn":1.1, "down":0.8, "rescue":0.65, "toss":0.25, "cell":0.55, "storm":1.8, "escape":1.6, "click":0.08, "bell":1.3, "cargo":0.32, "splash":0.5}.get(kind, 0.2)
	var count: int = int(RATE * duration)
	var values := PackedFloat32Array()
	values.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var low: float = 0.0
	var slower: float = 0.0
	for index: int in range(count):
		var t: float = float(index) / RATE
		var u: float = float(index) / count
		var noise: float = rng.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.075)
		slower = lerpf(slower, noise, 0.008)
		var value: float = 0.0
		match kind:
			"water": value = (low * 2.1 + slower * 2.0) * (0.45 + 0.25 * sin(TAU * t / duration))
			"wind": value = slower * 3.5 * (0.65 + 0.2 * sin(TAU * t / duration))
			"rain": value = noise * 0.18 + low * 0.65
			"reel":
				var click: float = fposmod(t, 0.05)
				value = (sin(TAU * 1450.0 * click) * 0.3 + noise * 0.25) * exp(-click * 180.0)
			"woodstep": value = (sin(TAU * 125.0 * t) * 0.6 + low * 0.8) * exp(-t * 25.0)
			"wetstep": value = (sin(TAU * 82.0 * t) * 0.55 + low * 1.2 + noise * 0.08) * exp(-t * 15.0)
			"cast", "splash": value = (low * 2.0 + noise * 0.12 + sin(TAU * (620.0 - t * 700.0) * t) * 0.2) * sin(PI * u) * exp(-t * (4.0 if kind == "cast" else 2.0))
			"toss": value = low * 2.8 * sin(PI * u)
			"cell", "cargo": value = (sin(TAU * (190.0 if kind == "cell" else 95.0) * t) * 0.45 + sin(TAU * 370.0 * t) * 0.15 + low * 0.9) * exp(-t * 12.0)
			"warn": value = (sin(TAU * 122.0 * t) * 0.33 + sin(TAU * 183.0 * t) * 0.22 + slower * 1.2) * sin(PI * u) * (0.55 + 0.45 * sin(TAU * 4.0 * t))
			"down": value = (sin(TAU * (180.0 - t * 90.0) * t) * 0.45 + low * 0.75) * exp(-t * 4.0)
			"storm": value = (slower * 5.0 + sin(TAU * 43.0 * t) * 0.16) * sin(PI * u)
			"bell": value = (sin(TAU * 440.0 * t) * 0.32 + sin(TAU * 1174.0 * t) * 0.14 + sin(TAU * 1980.0 * t) * 0.08) * exp(-t * 3.0)
			_:
				var notes: Array = {"catch":[523.25,659.25], "bank":[659.25,880.0], "rescue":[440.0,587.33], "escape":[392.0,493.88,587.33,783.99], "click":[740.0]}.get(kind,[420.0])
				var segment: float = duration / notes.size()
				var note: int = mini(notes.size() - 1, int(t / segment))
				var local_t: float = fposmod(t, segment)
				value = (sin(TAU * float(notes[note]) * local_t) * 0.45 + sin(TAU * float(notes[note]) * 2.0 * local_t) * 0.1) * sin(PI * local_t / segment) * exp(-local_t * 4.0)
		if not looped: value *= minf(1.0, t / 0.004) * minf(1.0, (duration - t) / 0.02)
		values[index] = clampf(value, -0.9, 0.9)
	if looped:
		# Join noise loops gently; no pop where the cached recording wraps.
		var overlap: int = mini(2205, count / 4)
		for index: int in range(overlap):
			values[count - overlap + index] = lerpf(values[count - overlap + index], values[index], float(index) / overlap)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for index: int in range(count): bytes.encode_s16(index * 2, roundi(values[index] * 28000.0))
	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = RATE
	clip.data = bytes
	if looped:
		clip.loop_mode = AudioStreamWAV.LOOP_FORWARD
		clip.loop_begin = mini(2205, count / 4)
		clip.loop_end = count
	return clip

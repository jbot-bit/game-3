extends Node
## Original short toy tones, generated once. Replicated state owns every cue.
signal cue_played(cue: String)

const SAMPLE_RATE := 22050
var muted: bool = false:
	set(value):
		muted = value
		if muted:
			for player: AudioStreamPlayer in _players.values(): player.stop()
var _players: Dictionary = {}
var _previous: Dictionary = {}

func _ready() -> void:
	_add("power", [Vector4(0.0, 660.0, 0.18, 0.34), Vector4(0.09, 990.0, 0.24, 0.29)])
	_add("checkpoint", [Vector4(0.0, 392.0, 0.18, 0.25), Vector4(0.07, 523.25, 0.22, 0.25), Vector4(0.14, 659.25, 0.28, 0.25)])
	_add("fan", [Vector4(0.0, 280.0, 0.22, 0.34)], 200.0)
	_add("finish", [Vector4(0.0, 523.25, 0.24, 0.25), Vector4(0.09, 659.25, 0.24, 0.25), Vector4(0.18, 784.0, 0.24, 0.25), Vector4(0.27, 1046.5, 0.38, 0.28)])
	# Short original warning beats leave the players' voices audible; the rising
	# two-tone announcement distinguishes an actual speed change from its lead-in.
	_add("knockout_warning", [Vector4(0.0, 440.0, 0.14, 0.34)])
	_add("knockout_stage", [Vector4(0.0, 440.0, 0.17, 0.30), Vector4(0.10, 880.0, 0.24, 0.28)], 100.0)

func update_state(data: Dictionary, local_id: String) -> void:
	var run: String = str(data.get("run_id", ""))
	var crew: Dictionary = data.get("players", {})
	if run.is_empty() or local_id.is_empty() or not crew.has(local_id): return
	var match_state: Dictionary = data.get("match", {})
	var timer: float = float(match_state.get("timer", 90.0))
	if not is_finite(timer): timer = 90.0
	var next: Dictionary = {"run": run, "local_id": local_id, "power": str(crew[local_id].get("power", "")),
		"checkpoint": int(data.get("checkpoint", 0)), "wind": int(data.get("wind", 1)),
		"complete": data.get("phase", "play") == "complete", "mode": str(data.get("mode_id", "coop")),
		"match_phase": str(match_state.get("phase", "")), "round": int(match_state.get("round", 0)),
		"fight_second": clampi(floori(90.0 - timer + 0.0001), 0, 90)}
	var previous: Dictionary = _previous
	_previous = next
	# Joining or restarting establishes a baseline; it does not replay history.
	if previous.is_empty() or previous.run != run or previous.local_id != local_id: return
	if next.complete and not previous.complete:
		_play("finish")
		return
	if not next.power.is_empty() and next.power != previous.power: _play("power")
	if next.checkpoint > previous.checkpoint: _play("checkpoint")
	if next.wind != previous.wind: _play("fan")
	var knockout_cue: String = _knockout_cue(previous, next)
	if not knockout_cue.is_empty(): _play(knockout_cue)

func _knockout_cue(previous: Dictionary, next: Dictionary) -> String:
	if next.mode != "knockout" or previous.mode != "knockout" or next.complete: return ""
	if next.match_phase != "fight" or previous.match_phase != "fight" or next.round != previous.round: return ""
	var elapsed: int = int(next.fight_second)
	var before: int = int(previous.fight_second)
	if elapsed <= before: return ""
	var stage: int = mini(4, floori(float(elapsed) / 15.0))
	var previous_stage: int = mini(4, floori(float(before) / 15.0))
	# A delayed snapshot plays at most one current cue, never a backlog of beats.
	if stage > previous_stage: return "knockout_stage"
	if elapsed < 60 and elapsed % 15 in [12, 13, 14]: return "knockout_warning"
	return ""

func reset() -> void:
	_previous.clear()
	for player: AudioStreamPlayer in _players.values(): player.stop()

func _exit_tree() -> void:
	reset()
	# Release the generated resources as well as stopping the mixer voices.
	# Otherwise an active playback can retain its WAV through final teardown.
	for player: AudioStreamPlayer in _players.values(): player.stream=null
	_players.clear()

func toggle_mute() -> bool:
	muted = not muted
	return muted

func _play(cue: String) -> void:
	if muted or not _players.has(cue): return
	_players[cue].play()
	cue_played.emit(cue)

func _add(cue: String, notes: Array[Vector4], glide: float = 0.0) -> void:
	var player := AudioStreamPlayer.new()
	player.name = cue.capitalize()
	player.volume_db = -10.0
	player.stream = _clip(notes, glide)
	add_child(player)
	_players[cue] = player

func _clip(notes: Array[Vector4], glide: float) -> AudioStreamWAV:
	var duration := 0.0
	for note: Vector4 in notes: duration = maxf(duration, note.x + note.z)
	var samples: int = ceili(duration * SAMPLE_RATE)
	var pcm := PackedByteArray()
	pcm.resize(samples * 2)
	for index: int in samples:
		var time: float = float(index) / SAMPLE_RATE
		var sample := 0.0
		for note: Vector4 in notes:
			var age: float = time - note.x
			if age < 0.0 or age >= note.z: continue
			var envelope: float = minf(age / 0.008, 1.0) * minf((note.z - age) / 0.02, 1.0) * exp(-6.0 * age / note.z)
			var phase: float = TAU * (note.y * age + 0.5 * glide * age * age / note.z)
			sample += note.w * envelope * (sin(phase) + 0.16 * sin(phase * 2.0))
		pcm.encode_s16(index * 2, roundi(clampf(sample, -0.6, 0.6) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = pcm
	return stream

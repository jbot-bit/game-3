extends Node

# Short licensed transients. No oscillator beeps or rising tone on every jump.
const BANK_PATH = "res://assets/audio/"
const ALIASES = {"basket": "score", "steal": "grab", "block": "tackle", "bump": "tackle", "hazard": "tackle", "wall": "bounce", "backboard": "bounce", "shot": "throw", "launch": "double_jump", "boost": "pass", "power": "double_jump", "pass_request": "request"}
const EVENTS = {
	"grab": {"sample": "catch", "gain": -17.0, "gap": .10},
	"bounce": {"sample": "ball", "gain": -17.0, "gap": .085},
	"rim": {"sample": "rim", "gain": -19.0, "gap": .12},
	"land": {"sample": "body", "gain": -19.0, "gap": .14},
	"tackle": {"sample": "body", "gain": -17.0, "gap": .12},
	"dive": {"sample": "air", "gain": -21.0, "gap": .16},
	"jump": {"sample": "air", "gain": -24.0, "gap": .16},
	"double_jump": {"sample": "air", "gain": -20.0, "gap": .18},
	"pass": {"sample": "air", "gain": -19.0, "gap": .12},
	"throw": {"sample": "air", "gain": -17.0, "gap": .12},
	"dunk": {"sample": "air", "gain": -17.0, "gap": .25},
	"step": {"sample": "step", "gain": -27.0, "gap": .16},
	"skid": {"sample": "step", "gain": -20.0, "gap": .24},
	"request": {"sample": "tick", "gain": -22.0, "gap": .7},
	"countdown": {"sample": "tick", "gain": -17.0, "gap": .6},
	"go": {"sample": "go", "gain": -19.0, "gap": .6},
	"score": {"sample": "score", "gain": -17.0, "gap": .6},
	"win": {"sample": "score", "gain": -15.0, "gap": .8, "pitch": .82},
	"score_lead": {"sample": "score", "gain": -17.0, "gap": .6, "pitch": 1.12},
	"score_tie": {"sample": "score", "gain": -17.0, "gap": .6, "pitch": .94},
	"late_clock": {"sample": "tick", "gain": -21.0, "gap": 2.0, "pitch": .8},
	"overtime": {"sample": "go", "gain": -19.0, "gap": 2.0, "pitch": .84},
	"power_ready": {"sample": "go", "gain": -22.0, "gap": 1.0, "pitch": 1.2},
}
var voices: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var last_played: Dictionary = {}
var last_local_played: Dictionary = {}
var variations: Dictionary = {}
var next_voice = 0
var clock = 0.0
var step_phase = 0.0
var played_count = 0

func _ready() -> void:
	if DisplayServer.get_name() != "headless": initialize_bank()

func _process(dt: float) -> void:
	clock += dt

func initialize_bank() -> void:
	if not voices.is_empty(): return
	for family in ["ball", "catch", "body", "step", "rim", "air"]:
		var variants: Array[AudioStream] = []
		for index in range(3):
			variants.append(load(BANK_PATH + "%s_%d.wav" % [family, index]) as AudioStream)
		streams[family] = variants
	for family in ["score", "tick", "go"]:
		streams[family] = [load(BANK_PATH + family + ".wav") as AudioStream]
	for index in range(10):
		var voice = AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)

func play_event(kind: String, strength: float = 1.0, local_priority: bool = false) -> bool:
	kind = str(ALIASES.get(kind, kind))
	if not EVENTS.has(kind) or voices.is_empty() or strength < .045: return false
	var event: Dictionary = EVENTS[kind]
	if clock - float(last_played.get(kind, -1000.0)) < float(event.gap):
		# A distant action must not suppress the player's next contact/action.
		# Repeating local cues still obey the same cooldown.
		if not local_priority or clock - float(last_local_played.get(kind, -1000.0)) < float(event.gap): return false
	var family: String = event.sample
	var choices: Array = streams.get(family, [])
	if choices.is_empty(): return false
	# Important cues have reserved voices; collisions cannot cut a score.
	var index = 9 if kind in ["score", "score_lead", "score_tie", "win"] else (8 if kind in ["countdown", "go", "request", "late_clock", "overtime", "power_ready"] else -1)
	# A request/ready cue must never truncate kickoff or a clock milestone.
	if index == 8 and voices[8].playing and kind in ["request", "power_ready"]: return false
	if index < 0:
		for offset in range(8):
			var candidate = (next_voice + offset) % 8
			if not voices[candidate].playing:
				index = candidate
				break
		if index < 0 and local_priority:
			for candidate in range(8):
				if bool(voices[candidate].get_meta("local_priority", false)): continue
				if index < 0 or voices[candidate].volume_db < voices[index].volume_db: index = candidate
		if index < 0: return false
		next_voice = (index + 1) % 8
	var variant = int(variations.get(family, 0)) % choices.size()
	variations[family] = variant + 1
	var voice = voices[index]
	voice.set_meta("local_priority", local_priority)
	voice.stream = choices[variant]
	voice.volume_db = float(event.gain) + linear_to_db(clampf(strength, .045, 1.0))
	var base_pitch = float(event.get("pitch", {"skid":.84, "jump":1.08, "double_jump":1.2, "pass":1.12, "throw":.94, "dunk":.8}.get(kind, 1.0)))
	voice.pitch_scale = base_pitch + (float(variant) - 1.0) * .025 if choices.size() > 1 else base_pitch
	if DisplayServer.get_name() != "headless": voice.play()
	last_played[kind] = clock
	if local_priority: last_local_played[kind] = clock
	played_count += 1
	return true

func update_motion(player: Dictionary, dt: float) -> void:
	if voices.is_empty() or not bool(player.get("grounded", false)) or float(player.get("stun", 0)) > 0 or float(player.get("dunk", 0)) > 0 or float(player.get("dive", 0)) > 0:
		step_phase = 0.0
		return
	var velocity: Vector3 = player.get("vel", Vector3.ZERO)
	var move: Vector3 = player.get("move", Vector3.ZERO)
	var horizontal = Vector3(velocity.x, 0, velocity.z)
	var speed = horizontal.length()
	if move.length() < .1 or speed < .6:
		step_phase = 0.0
		return
	if speed > 1.5 and horizontal.normalized().dot(move.normalized()) < -.15 and float(player.get("boost_time", 0)) <= 0:
		play_event("skid", .8)
	step_phase += dt * clampf(speed * .35, 1.8, 4.5)
	if step_phase >= 1:
		step_phase = fmod(step_phase, 1.0)
		play_event("step", clampf(speed / 10.0, .3, .85))

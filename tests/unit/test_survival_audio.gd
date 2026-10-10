extends GutTest

const Audio = preload("res://game/ui/sound_cues.gd")
var sound: Node

func before_each() -> void:
	sound = Audio.new()
	add_child_autofree(sound)

func _view(data: Dictionary) -> bool:
	assert_true(sound.has_method("update_view"),"Audio follows the actual expedition snapshot")
	if not sound.has_method("update_view"): return false
	sound.update_view(data,"crew_1",0.5)
	return true

func test_ambient_channels_stop_on_pause_and_menu() -> void:
	if not _view({"run":{"phase":"storm","elapsed_s":580}}): return
	var channels: Dictionary = sound.get("_channels")
	assert_true(channels.water.playing)
	assert_true(channels.wind.playing)
	assert_true(channels.rain.playing)
	_view({"run":{"phase":"storm","paused":true}})
	assert_false(channels.water.playing)
	assert_false(channels.wind.playing)
	assert_false(channels.rain.playing)
	_view({"run":{"phase":"night"}})
	assert_true(channels.water.playing)
	assert_false(channels.rain.playing)
	_view({})
	assert_false(channels.water.playing)
	assert_false(channels.wind.playing)

func test_reward_cue_cannot_interrupt_threat_warning() -> void:
	sound.play_cue("warn")
	var channels: Variant = sound.get("_channels")
	assert_not_null(channels,"Threat must have its own playback channel")
	if channels == null: return
	var warning: AudioStream = channels.threat.stream
	sound.play_cue("catch")
	assert_true(channels.threat.playing)
	assert_eq(channels.threat.stream,warning)
	assert_true(sound.player.playing)
	assert_ne(sound.player,channels.threat)

func test_threat_volume_mutes_only_threat_and_cached_cues_are_reused() -> void:
	sound.apply_settings({"threat_volume":0.0})
	sound.play_cue("warn")
	var channels: Variant = sound.get("_channels")
	assert_not_null(channels)
	if channels == null: return
	assert_false(channels.threat.playing)
	sound.play_cue("catch")
	assert_true(sound.player.playing)
	var first: AudioStream = sound.player.stream
	sound.play_cue("catch")
	assert_eq(sound.player.stream,first,"Repeated cues reuse cached PCM")
	sound.apply_settings({"threat_volume":0.5})
	sound.play_cue("down")
	assert_true(channels.threat.playing)
	sound.apply_settings({"threat_volume":0.0})
	assert_false(channels.threat.playing)

func test_motion_and_reeling_audio_follow_actual_activity() -> void:
	var data: Dictionary = {"run":{"phase":"night","players":{"crew_1":{}}},"poses":{"players":{"crew_1":{"position":Vector3.ZERO,"velocity":Vector3(3,0,0)}}},"fishing":{"crew_1":{"catch_id":"a","progress":0.2,"elapsed":2.0}}}
	if not _view(data): return
	var channels: Dictionary = sound.get("_channels")
	assert_true(channels.steps.playing)
	data.poses.players.crew_1.velocity = Vector3.ZERO
	data.fishing.crew_1.progress = 0.25
	_view(data)
	assert_true(channels.reel.playing)
	data.fishing.clear()
	_view(data)
	assert_false(channels.reel.playing)

func test_typed_cues_generate_distinct_non_silent_bounded_pcm() -> void:
	var channels: Variant = sound.get("_channels")
	assert_not_null(channels)
	if channels == null: return
	var digests: Dictionary = {}
	for kind: String in ["cast","catch","bank","warn","down","rescue","toss","cell","storm","escape"]:
		sound.play_cue(kind)
		var channel: AudioStreamPlayer = channels.threat if kind in ["warn","down","storm"] else channels.physical if kind in ["cast","toss","cell"] else sound.player
		var clip: AudioStreamWAV = channel.stream
		assert_not_null(clip,kind)
		if clip == null: continue
		var peak: int = 0
		for at: int in range(0,clip.data.size(),202): peak = maxi(peak,absi(clip.data.decode_s16(at)))
		assert_gt(peak,200,kind+" must not be silent")
		assert_lt(peak,32760,kind+" must not clip")
		var digest: int = hash(clip.data)
		assert_false(digests.has(digest),kind+" must be recognizable")
		digests[digest] = true

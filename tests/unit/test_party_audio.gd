extends "res://addons/gut/test.gd"

const AUDIO_PATH := "res://prototypes/physics_party/party_audio.gd"
var events: Array[String] = []

func before_each() -> void:
	events.clear()

func _audio() -> Node:
	assert_true(FileAccess.file_exists(AUDIO_PATH), "State audio implementation exists")
	if not FileAccess.file_exists(AUDIO_PATH): return null
	var audio: Node = add_child_autofree(load(AUDIO_PATH).new())
	audio.cue_played.connect(func(cue: String): events.append(cue))
	return audio

func _state(run_id: String = "run-a") -> Dictionary:
	return {"run_id": run_id, "players": {"crew_1": {"power": ""}, "crew_2": {"power": ""}}, "checkpoint": 0, "wind": 1, "phase": "play"}

func test_initial_and_duplicate_snapshots_are_silent() -> void:
	var audio := _audio()
	if audio == null: return
	var state := _state()
	state.players.crew_1.power = "spring"
	state.checkpoint = 1
	state.phase = "complete"
	audio.update_state(state, "crew_1")
	audio.update_state(state.duplicate(true), "crew_1")
	assert_eq(events, [])

func test_only_local_power_selection_plays_once() -> void:
	var audio := _audio()
	if audio == null: return
	var state := _state()
	audio.update_state(state, "crew_1")
	state.players.crew_2.power = "heavy"
	audio.update_state(state, "crew_1")
	assert_eq(events, [])
	state.players.crew_1.power = "spring"
	audio.update_state(state, "crew_1")
	audio.update_state(state, "crew_1")
	assert_eq(events, ["power"])

func test_actual_checkpoint_fan_and_finish_transitions() -> void:
	var audio := _audio()
	if audio == null: return
	var state := _state()
	audio.update_state(state, "crew_1")
	state.checkpoint = 1
	audio.update_state(state, "crew_1")
	state.wind = -1
	audio.update_state(state, "crew_1")
	state.phase = "complete"
	audio.update_state(state, "crew_1")
	audio.update_state(state, "crew_1")
	assert_eq(events, ["checkpoint", "fan", "finish"])

func test_muting_tracks_state_without_replaying_later() -> void:
	var audio := _audio()
	if audio == null: return
	var state := _state()
	audio.update_state(state, "crew_1")
	assert_true(audio.toggle_mute())
	state.wind = -1
	audio.update_state(state, "crew_1")
	assert_eq(events, [])
	assert_false(audio.toggle_mute())
	audio.update_state(state, "crew_1")
	assert_eq(events, [])
	state.wind = 1
	audio.update_state(state, "crew_1")
	assert_eq(events, ["fan"])

func test_reset_and_new_run_establish_silent_baselines() -> void:
	var audio := _audio()
	if audio == null: return
	var state := _state()
	audio.update_state(state, "crew_1")
	state = _state("run-b")
	state.players.crew_1.power = "grip"
	state.wind = -1
	audio.update_state(state, "crew_1")
	assert_eq(events, [])
	audio.reset()
	state.phase = "complete"
	audio.update_state(state, "crew_1")
	assert_eq(events, [])

func test_clips_are_short_nonempty_original_pcm_without_loops_or_clipping() -> void:
	var audio := _audio()
	if audio == null: return
	assert_eq(audio.get_child_count(), 4)
	for player: AudioStreamPlayer in audio.get_children():
		var clip: AudioStreamWAV = player.stream
		assert_eq(clip.format, AudioStreamWAV.FORMAT_16_BITS)
		assert_eq(clip.loop_mode, AudioStreamWAV.LOOP_DISABLED)
		assert_true(clip.get_length() > 0.1 and clip.get_length() < 1.0)
		var peak: int = 0
		for index: int in range(0, clip.data.size(), 2):
			peak = maxi(peak, absi(clip.data.decode_s16(index)))
		assert_true(peak > 100 and peak < 24000, "Clip is audible data with headroom")

func test_exit_stops_active_cues_and_detaches_generated_streams() -> void:
	var audio := _audio()
	if audio == null: return
	var state := _state()
	audio.update_state(state, "crew_1")
	state.players.crew_1.power = "spring"
	state.wind = -1
	audio.update_state(state, "crew_1")
	assert_eq(events, ["power", "fan"], "Exercise actual playback before shutdown")
	var references: Array[WeakRef] = []
	for player: AudioStreamPlayer in audio.get_children(): references.append(weakref(player.stream))
	audio.get_parent().remove_child(audio)
	for player: AudioStreamPlayer in audio.get_children():
		assert_false(player.playing, "Exiting audio stops playback")
		assert_null(player.stream, "Exiting audio releases its generated stream")
	audio.free()
	# Audio mixes on its own clock. Poll the actual release with a deadline;
	# a fixed 150 ms wait can finish before the dummy mixer's next cleanup.
	var deadline: int = Time.get_ticks_msec() + 1000
	var retained: bool = true
	while retained and Time.get_ticks_msec() < deadline:
		await wait_seconds(0.02)
		retained = false
		for reference: WeakRef in references:
			retained = retained or reference.get_ref() != null
	for reference: WeakRef in references:
		assert_null(reference.get_ref(), "Mixer releases each original stream after shutdown")

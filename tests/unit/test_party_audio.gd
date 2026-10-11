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
	assert_eq(audio.get_child_count(), 6)
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

func _knockout_state(elapsed: float = 0.0, run_id: String = "knockout-a") -> Dictionary:
	var state := _state(run_id)
	state.mode_id = "knockout"
	state.match = {"phase": "fight", "round": 1, "timer": 90.0 - elapsed}
	return state

func test_knockout_warning_beats_and_stage_cues_play_once_at_each_boundary() -> void:
	var audio := _audio()
	var state := _knockout_state()
	audio.update_state(state, "crew_1")
	var expected: Array[String] = []
	for stage in 4:
		state.match.timer = 90.0 - (stage * 15.0 + 11.9)
		audio.update_state(state, "crew_1")
		assert_eq(events, expected, "No early warning before the three-beat countdown")
		for second in [12, 13, 14]:
			state.match.timer = 90.0 - (stage * 15.0 + second)
			audio.update_state(state, "crew_1")
			state.match.timer -= 0.4
			audio.update_state(state, "crew_1")
			audio.update_state(state.duplicate(true), "crew_1")
			expected.append("knockout_warning")
			assert_eq(events, expected, "One warning per elapsed second despite repeated snapshots")
		state.match.timer = 90.0 - (stage + 1) * 15.0
		audio.update_state(state, "crew_1")
		audio.update_state(state, "crew_1")
		expected.append("knockout_stage")
		assert_eq(events, expected, "Each new speed stage gets one distinct announcement")
	state.match.timer = 15.0
	audio.update_state(state, "crew_1")
	assert_eq(events, expected, "No nonexistent fifth stage after the 60-second finale")

func test_knockout_join_restart_round_change_and_pause_do_not_replay_history() -> void:
	var audio := _audio()
	var state := _knockout_state(28.0)
	audio.update_state(state, "crew_1")
	audio.update_state(state, "crew_1")
	state = _knockout_state(45.0, "knockout-b")
	audio.update_state(state, "crew_1")
	audio.reset()
	state.match.timer = 31.0
	audio.update_state(state, "crew_1")
	state.match.round = 2
	state.match.timer = 75.0
	audio.update_state(state, "crew_1")
	for match_phase in ["intermission", "practice", "countdown", "complete"]:
		state.match.phase = match_phase
		state.match.timer = 78.0
		audio.update_state(state, "crew_1")
		state.match.timer = 75.0
		audio.update_state(state, "crew_1")
	state.match.phase = "fight"
	state.match.timer = 60.0
	audio.update_state(state, "crew_1")
	assert_eq(events, [], "Only continuing live fights emit escalation cues")
	state.match.timer = 48.0
	audio.update_state(state, "crew_1")
	assert_eq(events, ["knockout_warning"], "A later live warning still works after silent baselines")

func test_knockout_cues_are_mode_specific_and_finish_takes_priority() -> void:
	var audio := _audio()
	for mode_id in ["coop", "gladiator", "wipeout"]:
		var state := _knockout_state(11.0, mode_id)
		state.mode_id = mode_id
		audio.update_state(state, "crew_1")
		state.match.timer = 78.0
		audio.update_state(state, "crew_1")
		state.match.timer = 75.0
		audio.update_state(state, "crew_1")
	assert_eq(events, [], "Other game modes never emit Knockout warnings")
	var final_state := _knockout_state(14.0)
	audio.update_state(final_state, "crew_1")
	final_state.match.timer = 75.0
	final_state.phase = "complete"
	audio.update_state(final_state, "crew_1")
	assert_eq(events, ["finish"], "Finished match plays only its completion cue")

func test_knockout_muting_and_skipped_snapshots_do_not_queue_old_beats() -> void:
	var audio := _audio()
	var state := _knockout_state(11.0)
	audio.update_state(state, "crew_1")
	audio.muted = true
	state.match.timer = 78.0
	audio.update_state(state, "crew_1")
	state.match.timer = 75.0
	audio.update_state(state, "crew_1")
	audio.muted = false
	audio.update_state(state, "crew_1")
	assert_eq(events, [], "Unmuting never replays a muted beat or stage")
	state.match.timer = 44.0
	audio.update_state(state, "crew_1")
	assert_eq(events, ["knockout_stage"], "A skipped snapshot announces only the current stage, not missed beats")
	state.match.timer = 33.0
	audio.update_state(state, "crew_1")
	assert_eq(events, ["knockout_stage", "knockout_warning"], "Live warning beats continue after packet delay")

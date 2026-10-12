extends SceneTree

var failures = 0
var checks = 0

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func run() -> void:
	var bank = load("res://audio.gd").new()
	root.add_child(bank)
	bank.set_process(false)
	expect(bank.voices.is_empty(), "Normal headless peers do not allocate audio voices")
	bank.initialize_bank()
	var files = 0
	var highest_peak = 0.0
	for family in bank.streams:
		for stream in bank.streams[family]:
			files += 1
			var wav = stream as AudioStreamWAV
			expect(wav != null and wav.format == AudioStreamWAV.FORMAT_16_BITS and wav.get_length() > .02 and wav.get_length() <= .5 and wav.mix_rate == 44100, "Valid bounded PCM sample " + family)
			if wav and wav.format == AudioStreamWAV.FORMAT_16_BITS:
				var peak = 0.0
				for i in range(0, wav.data.size(), 2): peak = maxf(peak, absf(wav.data.decode_s16(i)) / 32768.0)
				highest_peak = maxf(highest_peak, peak)
	expect(files == 21 and highest_peak <= .631, "All 21 samples load with measured peak headroom")
	expect(bank.play_event("bounce"), "First collision starts a voice")
	var first_stream = bank.voices[0].stream
	expect(not bank.play_event("bounce"), "Repeated same-frame collision is suppressed")
	expect(not bank.play_event("wall"), "Aliases share collision cooldown")
	bank.clock += .10
	expect(bank.play_event("bounce") and bank.voices[1].stream != first_stream, "Next collision uses a different sample")
	expect(bank.play_event("score") and bank.voices[9].stream == bank.streams.score[0], "Score routes to its reserved voice")
	var count = bank.played_count
	for i in range(30): bank.play_event("tackle")
	expect(bank.played_count == count + 1 and bank.voices[9].stream == bank.streams.score[0], "Collision burst cannot spam voices or replace the score stream")
	expect(not bank.play_event("throw", .01), "Inaudible distant events do not allocate voices")
	# Sum of all 10 worst-case peaks, even with perfect phase alignment.
	var maximum_mix = highest_peak * (8 * db_to_linear(-17.0) + db_to_linear(-17.0) + db_to_linear(-15.0))
	expect(maximum_mix < .95, "Worst-case simultaneous mix retains digital headroom")
	for voice in bank.voices: voice.stop()
	bank.last_played.clear()
	bank.update_motion({"grounded":true,"move":Vector3.BACK,"vel":Vector3.FORWARD*8}, .01)
	expect(bank.last_played.has("skid"), "Reversal produces a short traction sound")
	bank.last_played.clear()
	bank.update_motion({"grounded":false,"move":Vector3.BACK,"vel":Vector3.FORWARD*8}, .4)
	expect(bank.last_played.is_empty(), "Airborne movement has no foot or skid noise")
	for voice in bank.voices:
		voice.stop()
		voice.stream = null
	bank.streams.clear()
	bank.voices.clear()
	bank.queue_free()
	await process_frame
	print("AUDIO_BANK: %d checks, %d failures" % [checks, failures])
	finish.call_deferred()

func finish() -> void:
	quit(1 if failures else 0)

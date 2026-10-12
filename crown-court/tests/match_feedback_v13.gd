extends SceneTree

const HUD = preload("res://hud.gd")
var failures = 0
var checks = 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func run() -> void:
	check(HUD.score_feedback({}, {0:3,1:2}, "teams", {}).is_empty(), "Joining a match does not replay a basket")
	check(HUD.score_feedback({0:3,1:2}, {0:3,1:2}, "teams", {}).is_empty(), "Repeated snapshot does not replay a basket")
	var lead = HUD.score_feedback({0:2,1:2}, {0:3,1:2}, "teams", {})
	check(lead.text == "Blue +1\nTakes the lead!" and lead.cue == "score_lead", "Lead change credits the authoritative scoring team")
	var tie = HUD.score_feedback({0:2,1:3}, {0:3,1:3}, "coop", {})
	check(tie.text == "Your team +1\nAll tied!" and tie.cue == "score_tie", "Equalizer has distinct readable feedback")
	var trailing = HUD.score_feedback({1:1,2:5,3:2}, {1:2,2:5,3:2}, "versus", {1:"Evie"})
	check(trailing.text == "Evie +1\nBasket!" and trailing.cue == "score", "Versus does not claim a lead or tie against a lower scoring rival")
	var aggregate = HUD.score_feedback({0:0,1:0}, {0:2,1:0}, "teams", {})
	check(aggregate.delta == 2 and "+2" in aggregate.text, "Snapshot gap reports actual score gain")
	check(HUD.score_feedback({0:1,1:1}, {0:2,1:2}, "teams", {}).text == "Score updated", "Multiple changed teams do not fabricate one scoring play")
	check(HUD.score_feedback({0:1,1:1}, {0:5,1:1}, "teams", {}, 0).text.ends_with("Winning basket!"), "Winning score is distinguished without inventing a reward")
	check(HUD.clock_feedback(-1,9).is_empty(), "Joining late does not replay clock cue")
	check(HUD.clock_feedback(31,30).text == "30 seconds!", "Thirty-second milestone is readable")
	check(HUD.clock_feedback(12,9).text == "10 seconds!", "Snapshot crossing still catches final ten seconds")
	check(HUD.clock_feedback(9,8).is_empty(), "Final clock does not beep every second")
	check(HUD.clock_feedback(1,0).cue == "overtime", "Live overtime transition is distinct")
	check(HUD.clock_feedback(1,0,0).is_empty(), "Finished match cannot announce overtime")
	var ring = HUD.new()
	root.add_child(ring)
	ring.set_process(false)
	ring.set_status(1.0,"giant",false)
	check(ring.ready_reveal == 0.0, "Joining with full Hype does not invent earned animation")
	ring.set_status(.8,"giant",false)
	ring.set_status(1.0,"giant",false)
	check(ring.ready_reveal > 0.0, "Earning full Hype gets one restrained ring reveal")
	ring._process(.8)
	ring.set_status(1.0,"giant",false)
	check(ring.ready_reveal == 0.0, "Ready reveal expires and does not loop")
	var bank = load("res://audio.gd").new()
	root.add_child(bank)
	bank.initialize_bank()
	for kind in ["score_lead", "score_tie", "win"]:
		check(bank.play_event(kind) and bank.voices[9].stream == bank.streams.score[0], kind + " protects its celebration voice")
		check(bank.voices[9].pitch_scale != 1.0, kind + " has a distinct licensed-sample voicing")
	for kind in ["late_clock", "overtime", "power_ready"]:
		check(bank.play_event(kind) and not bank.play_event(kind), kind + " routes once and is cooldown protected")
	for voice in bank.voices:
		voice.stop()
		voice.stream = null
	bank.streams.clear()
	bank.voices.clear()
	bank.queue_free()
	ring.queue_free()
	await process_frame
	print("MATCH_FEEDBACK: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

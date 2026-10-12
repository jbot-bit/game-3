extends SceneTree

var checks = 0
var failures = 0

func check(ok: bool, label: String, detail = null) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",label," ",detail if detail != null else "")

func _initialize() -> void:
	var app = load("res://main.gd").new()
	app.phase = "match"
	app.match_id = "hazard-prediction"
	app.manual_input_enabled = false
	var g = app.Sim.new()
	g.reset("coop")
	g.reset_time = 0
	g.players = {2:g.players[2]}
	var p: Dictionary = g.players[2]
	p.pos = app.Sim.HAZARDS[0]+Vector3(2,.15,1.3)
	p.vel = Vector3(0,0,-8)
	p.grounded = false
	p.jump_count = 1
	p.stun = .5
	p.boost_time = 0
	p.hazard_cooldown = 0
	g.ball.pos = Vector3(0,10,0)
	g.ball.vel = Vector3.ZERO
	var snapshot = g.snapshot()
	snapshot.match_id = app.match_id
	snapshot._snapshot_seq = 1
	app.receive_state(var_to_bytes(snapshot).compress(FileAccess.COMPRESSION_DEFLATE))
	app.predict_render_state(0)
	app.ui_clock = .08
	app.predict_render_state(.08)
	for index in 3: g.step(1.0/60)
	check(g.players[2].hazard_cooldown>0,"Real simulation sweeper hits an already-stunned airborne player")
	snapshot = g.snapshot()
	snapshot.match_id = app.match_id
	snapshot._snapshot_seq = 2
	app.receive_state(var_to_bytes(snapshot).compress(FileAccess.COMPRESSION_DEFLATE))
	var authority = var_to_bytes(app.state)
	var shown = app.predict_render_state(0)
	check(app.snapshot_count==2,"Hazard transition arrives through compressed snapshot receiver")
	check(shown.players[2].pos.distance_to(app.state.players[2].pos)<.001,"Fresh hazard impulse cannot inherit stale pre-contact correction",shown.players[2].pos.distance_to(app.state.players[2].pos))
	check(shown.players[2].vel==app.state.players[2].vel and var_to_bytes(app.state)==authority,"Hazard presentation preserves authoritative impulse and state bytes")
	var moving = app.predict_render_state(.025)
	check(is_equal_approx(moving.clock,app.state.clock+.025),"Moving sweepers share bounded presentation time between snapshots")
	var capped = app.predict_render_state(.5)
	check(is_equal_approx(capped.clock,app.state.clock+.08) and var_to_bytes(app.state)==authority,"Rotor phase freezes with the80ms prediction cap without changing authority")
	app.state.celebration_time = .5
	app.state.reset_time = 2.9
	var frozen = app.predict_render_state(.05)
	check(frozen.clock==app.state.clock,"Score celebration preserves the authoritative frozen obstacle phase")
	app.free()
	print("HAZARD PREDICTION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

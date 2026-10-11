extends SceneTree
## Actual Jolt puppet fixtures: initial placement, then ordinary jump input only.
## No forces, velocities, falls, contact callbacks or artificial pushes are injected.
const World = preload("res://prototypes/physics_party/party_knockout_world.gd")
const Puppet = preload("res://prototypes/physics_party/puppet.tscn")
var world: Node3D
var actor: Node3D
var failures: Array[String] = []
var checks: int = 0
var evidence: Dictionary = {}
var elapsed: float = 0.0
var controls: Dictionary = {}

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok: failures.append(detail)
	print("PASS " if ok else "FAIL ", detail)

func _step() -> void:
	actor.set_controls(controls)
	await physics_frame
	elapsed += 1.0 / 60.0

func _hazard_contacts() -> int:
	var contacts: int = 0
	for bone: PhysicalBone3D in actor.physics_bones:
		var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(bone.get_rid())
		if state == null: continue
		for index in state.get_contact_count():
			var collider: Object = state.get_contact_collider_object(index)
			if collider in world.movers.values(): contacts += 1
	return contacts

func _near_low_bar() -> bool:
	var low: AnimatableBody3D = world.movers.SweepLow
	var predicted := Basis(Vector3.UP, low.rotation.y + float(world.mover_specs.SweepLow.speed) * world.hazard_speed_scale() * 0.25)
	var local: Vector3 = predicted.inverse() * (actor.body_position() - low.global_position)
	return absf(local.z) < 1.35 and absf(local.x) < 9.2

func _trial(jump: bool, round_index: int, initial_point: Vector3 = Vector3(7.3, 7, -2.2)) -> Dictionary:
	world.set_round_phase("countdown", round_index)
	controls = {}
	actor.reset_at(initial_point)
	for tick in 120: await _step()
	var before: Vector3 = actor.body_position()
	_check(actor.is_on_floor, "Fixture settles on the real circular pad before " + ("jump" if jump else "idle") + " trial")
	var still_pose: Dictionary = world.capture_movers()
	for tick in 60: await _step()
	_check(world.capture_movers() == still_pose, "Countdown holds both real collision sweepers still")
	var start_time: float = elapsed
	var contact_count: int = 0
	var first_contact: float = -1.0
	var peak_speed: float = 0.0
	var displacement: float = 0.0
	var peak_height: float = before.y
	var airborne_ticks: int = 0
	var jumps: int = 0
	var last_jump: float = -10.0
	var ringout_time: float = -1.0
	world.set_round_phase("fight", round_index)
	for tick in 900:
		var jump_now: bool = jump and actor.is_on_floor and elapsed - last_jump > 0.9 and _near_low_bar()
		controls = {"jump": jump_now}
		if jump_now:
			jumps += 1
			last_jump = elapsed
		await _step()
		var contacts: int = _hazard_contacts()
		contact_count += contacts
		if contacts > 0 and first_contact < 0.0: first_contact = elapsed - start_time
		var speed: Vector3 = actor.physical_bone_body.linear_velocity
		peak_speed = maxf(peak_speed, Vector2(speed.x, speed.z).length())
		displacement = maxf(displacement, Vector2(actor.body_position().x - before.x, actor.body_position().z - before.z).length())
		peak_height = maxf(peak_height, actor.body_position().y)
		if not actor.is_on_floor: airborne_ticks += 1
		if actor.body_position().y < world.elimination_y:
			ringout_time = elapsed - start_time
			break
	return {"initial": str(before), "final": str(actor.body_position()), "elapsed_s": elapsed - start_time,
		"hazard_contacts": contact_count, "first_contact_s": first_contact, "ringout_s": ringout_time,
		"peak_horizontal_speed": peak_speed, "max_horizontal_displacement": displacement,
		"height_gain": peak_height - before.y, "airborne_ticks": airborne_ticks, "ordinary_jumps": jumps,
		"standing_at_end": actor.is_on_floor, "finite": actor.body_position().is_finite()}

func _run() -> void:
	world = World.new()
	root.add_child(world)
	actor = Puppet.instantiate()
	root.add_child(actor)
	actor.set_combat_visual(true)
	world.track_puppets([actor])
	# Read real contact records without changing any puppet dynamics.
	for bone: PhysicalBone3D in actor.physics_bones:
		PhysicsServer3D.body_set_max_contacts_reported(bone.get_rid(), 8)
	if not OS.get_cmdline_user_args().has("--late-only"):
		evidence.idle = await _trial(false, 1)
		_check(evidence.idle.hazard_contacts > 0, "Moving AnimatableBody makes recorded physical contact with an idle puppet")
		_check(evidence.idle.max_horizontal_displacement > 1.0 and evidence.idle.peak_horizontal_speed > 1.2, "Physical sweeper collision overcomes ordinary puppet braking")
		evidence.jumping = await _trial(true, 2)
		_check(evidence.jumping.ordinary_jumps >= 2 and evidence.jumping.height_gain > 0.8, "Ordinary timed jump input clears multiple low-bar passes")
		_check(evidence.jumping.ringout_s < 0.0 and evidence.jumping.finite, "The same edge fixture survives fifteen seconds by timing normal jumps")
		_check(evidence.jumping.hazard_contacts < evidence.idle.hazard_contacts, "Timed jumping reduces actual hazard contacts against the idle control")
		evidence.edge = await _trial(false, 3, Vector3(7.8, 7, -2.2))
		_check(evidence.edge.ringout_s > 0.0 and evidence.edge.hazard_contacts > 0, "A real sweeper hit can knock an idle competitive puppet off from the outer lane")
		evidence.shrinking = await _shrink_trial()
		_check(evidence.shrinking.started_supported, "Outer-lane shrink fixture begins on real floor support")
		_check(evidence.shrinking.ringout_s > 30.0 and evidence.shrinking.ringout_s < 55.0, "Retracting actual floor makes an idle outer-lane puppet fall under gravity")
		_check(evidence.shrinking.hazard_contacts == 0 and evidence.shrinking.final_radius < 8.0, "Isolated floor loss requires no sweeper contact or artificial push")
	evidence.late = await _late_trial()
	_check(evidence.late.started_supported, "Late-round fixture starts on the actual six-metre arena")
	_check(evidence.late.ordinary_jumps >= 3 and evidence.late.height_gain > 0.8, "Normal jumps remain effective against final-speed sweepers")
	_check(evidence.late.ringout_s < 0.0 and evidence.late.elapsed_s >= 9.99, "Timed normal input can survive ten seconds at final speed and arena size")
	var report := {"checks": checks, "passed": checks - failures.size(), "failures": failures, "evidence": evidence,
		"limits": "Explicit initial placement at the outer lane on the actual arena. Jolt contacts and normal puppet jump motor at 60Hz; The floor-loss fixture disables only sweeper collision to isolate natural gravity as real support retracts. Automated timing proves physical feasibility, not human difficulty or three-PC play."}
	var file := FileAccess.open("res://logs/knockout-late-physics-probe.json" if OS.get_cmdline_user_args().has("--late-only") else "res://logs/knockout-physics-probe.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("KNOCKOUT_PHYSICS ", JSON.stringify(report))
	actor.release_all()
	actor.queue_free()
	world.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _shrink_trial() -> Dictionary:
	world.set_round_phase("countdown", 4)
	controls = {}
	# Isolate floor loss from the independently proven sweeper collision.
	for body: AnimatableBody3D in world.movers.values():
		body.collision_layer = 0
		body.collision_mask = 0
	actor.reset_at(Vector3(0, 7, 8.0))
	for tick in 120: await _step()
	var initial: Vector3 = actor.body_position()
	var started_supported: bool = actor.is_on_floor
	var start_time: float = elapsed
	var contact_count: int = 0
	var ringout_time: float = -1.0
	world.set_round_phase("fight", 4)
	for tick in 3300:
		await _step()
		contact_count += _hazard_contacts()
		if actor.body_position().y < world.elimination_y:
			ringout_time = elapsed - start_time
			break
	var result := {"started_supported": started_supported, "initial": str(initial), "final": str(actor.body_position()),
		"ringout_s": ringout_time, "final_radius": world.arena_radius(), "hazard_contacts": contact_count,
		"fixture": "Explicit initial outer-lane placement; only sweeper collision disabled; ordinary idle controls and gravity while actual floor retracts at 0.1 m/s after 30 s."}
	for body: AnimatableBody3D in world.movers.values():
		body.collision_layer = 1
		body.collision_mask = 1
	return result

func _late_trial() -> Dictionary:
	world.set_round_phase("countdown", 5)
	world._set_pad_radius(6.0)
	controls = {}
	var target := Vector2(0, 5.30)
	actor.reset_at(Vector3(0, 7, 3.5))
	# Settle the real competitive arm stance safely, then approach the outer
	# lane using normal movement; a mid-air edge teleport is not a late round.
	for tick in 180:
		var at: Vector3 = actor.body_position()
		var velocity: Vector3 = actor.physical_bone_body.linear_velocity
		var settle_target := Vector2(0, 3.5) if tick < 90 else target
		controls = {"move": ((settle_target - Vector2(at.x, at.z)) * 0.85 - Vector2(velocity.x, velocity.z) * 0.16).limit_length(1.0)}
		await _step()
	var initial: Vector3 = actor.body_position()
	var started_supported: bool = actor.is_on_floor
	var start_time: float = elapsed
	var jumps: int = 0
	var last_jump: float = -10.0
	var ringout_time: float = -1.0
	var peak_height: float = initial.y
	var contact_count: int = 0
	world.set_round_phase("fight", 5)
	world._round_elapsed = 62.0
	for tick in 600:
		var low: AnimatableBody3D = world.movers.SweepLow
		var predicted := Basis(Vector3.UP, low.rotation.y + float(world.mover_specs.SweepLow.speed) * world.hazard_speed_scale() * 0.18)
		var local: Vector3 = predicted.inverse() * (actor.body_position() - low.global_position)
		var jump_now: bool = actor.is_on_floor and elapsed - last_jump > 0.9 and absf(local.z) < 0.75
		var at: Vector3 = actor.body_position()
		var velocity: Vector3 = actor.physical_bone_body.linear_velocity
		var move: Vector2 = ((target - Vector2(at.x, at.z)) * 0.85 - Vector2(velocity.x, velocity.z) * 0.16).limit_length(1.0)
		controls = {"jump": jump_now, "move": move}
		if jump_now:
			jumps += 1
			last_jump = elapsed
		await _step()
		contact_count += _hazard_contacts()
		peak_height = maxf(peak_height, actor.body_position().y)
		if actor.body_position().y < world.elimination_y:
			ringout_time = elapsed - start_time
			break
	return {"started_supported": started_supported, "initial": str(initial), "final": str(actor.body_position()),
		"elapsed_s": elapsed - start_time, "ringout_s": ringout_time, "ordinary_jumps": jumps,
		"height_gain": peak_height - initial.y, "hazard_contacts": contact_count,
		"final_radius": world.arena_radius(), "speed_scale": world.hazard_speed_scale(),
		"fixture": "Explicit late-phase initial fixture at radius 5.3 m, floor 6 m and elapsed 62 s; competitive arm stance and normal jump/movement input only after placement. No extra jump strength or collision disabling."}

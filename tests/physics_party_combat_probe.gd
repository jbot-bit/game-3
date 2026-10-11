extends SceneTree
## Actual two-puppet Jolt contact fixture; no injected target velocities or falls.
const Puppet = preload("res://prototypes/physics_party/puppet.tscn")
const Pugil = preload("res://prototypes/physics_party/party_pugil.gd")
const Match = preload("res://prototypes/physics_party/party_match.gd")
class Arena extends Node3D:
	var elimination_y: float = -2.0
var actors: Dictionary = {}
var failures: Array[String] = []
var checks: int = 0
var evidence: Dictionary = {}
var arena: Node3D
var combat = Pugil.new()

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok: failures.append(detail)
	print("PASS " if ok else "FAIL ", detail)

func _input(yaw: float, attack: bool = false, brace: bool = false) -> Dictionary:
	return {"move": Vector2.ZERO, "yaw": yaw, "pitch": 0.0, "jump": false, "left": false, "right": false,
		"limp": false, "grapple": false, "attack": attack, "brace": brace}

func _step(data: Dictionary, match_rules: RefCounted = null) -> Dictionary:
	for id: String in actors: actors[id].set_controls(data.get(id, _input(0)))
	var event: Dictionary = {}
	if match_rules == null: combat.tick(actors, data, ["crew_1", "crew_2"], 1.0 / 60.0)
	else: event = match_rules.tick(actors, data, 1.0 / 60.0)
	await physics_frame
	return event

func _place(a: Vector3, b: Vector3) -> void:
	actors.crew_1.reset_at(a)
	actors.crew_2.reset_at(b)
	combat.reset()
	for tick in 120: await _step({"crew_1": _input(0), "crew_2": _input(PI)})
	_check(actors.crew_1.is_on_floor and actors.crew_2.is_on_floor, "Both fixtures settle on actual platform contact")

func _trial(braced: bool) -> Dictionary:
	await _place(Vector3(0, 3, 3), Vector3(0, 3, 0.5))
	var start: Vector3 = actors.crew_2.body_position()
	var hits: int = 0
	for tick in 30:
		await _step({"crew_1": _input(0, tick < 24), "crew_2": _input(PI, false, braced)})
		hits = maxi(hits, combat.fighters.crew_1.hit.size())
	var travel: float = start.z - actors.crew_2.body_position().z
	return {"travel": travel, "hits": hits, "cooldown": combat.fighters.crew_1.cooldown}

func _run() -> void:
	arena = Arena.new()
	root.add_child(arena)
	var floor_body := StaticBody3D.new()
	floor_body.name = "ContactPlatform"
	var shape := BoxShape3D.new()
	shape.size = Vector3(18, 1, 18)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	floor_body.add_child(collision)
	arena.add_child(floor_body)
	floor_body.position.y = -0.5
	for index in 2:
		var actor: Node3D = Puppet.instantiate()
		actor.name = "Fighter" + str(index)
		root.add_child(actor)
		actors["crew_" + str(index + 1)] = actor
	evidence.unbraced = await _trial(false)
	_check(evidence.unbraced.hits == 1, "One target contact is recorded once during a swing")
	_check(evidence.unbraced.travel > 1.3, "Ordinary grounded braking does not erase padded-stick push")
	_check(evidence.unbraced.cooldown > 0.1, "Holding attack cannot bypass the 0.65 second cooldown")
	evidence.braced = await _trial(true)
	_check(evidence.braced.hits == 1, "Braced defender still receives real contact")
	_check(evidence.braced.travel < evidence.unbraced.travel * 0.6, "Facing brace meaningfully reduces displacement")
	await _place(Vector3(0, 3, 3), Vector3(0, 3, 0.5))
	for tick in 25: await _step({"crew_1": _input(PI, true), "crew_2": _input(PI)})
	_check(combat.fighters.crew_1.hit.is_empty(), "Swing away from an opponent does not hit behind the attacker")
	await _place(Vector3(0, 3, 4), Vector3(0, 3, -1))
	for tick in 25: await _step({"crew_1": _input(0, true), "crew_2": _input(PI)})
	_check(combat.fighters.crew_1.hit.is_empty(), "Out-of-range swing misses")
	await _place(Vector3(0, 3, 3), Vector3(0, 3, 0.5))
	var wall := StaticBody3D.new()
	var wall_collision := CollisionShape3D.new()
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(5, 5, 0.2)
	wall_collision.shape = wall_shape
	wall.add_child(wall_collision)
	arena.add_child(wall)
	wall.position = Vector3(0, 2, 1.7)
	for tick in 25: await _step({"crew_1": _input(0, true), "crew_2": _input(PI)})
	_check(combat.fighters.crew_1.hit.is_empty(), "Physical wall blocks stick contact")
	wall.queue_free()
	await physics_frame
	await _place(Vector3(0, 3, -4.8), Vector3(0, 3, -7.3))
	var match_rules = Match.new()
	match_rules.configure(arena)
	for tick in 190: await _step({"crew_1": _input(0), "crew_2": _input(PI)}, match_rules)
	_check(match_rules.phase == "fight", "Real actor match reaches fight after countdown")
	var knockout_ticks: int = -1
	for tick in 240:
		await _step({"crew_1": _input(0, tick < 30), "crew_2": _input(PI)}, match_rules)
		if match_rules.phase == "intermission":
			knockout_ticks = tick
			break
	evidence.knockoff = {"ticks": knockout_ticks, "target_position": actors.crew_2.body_position(), "scores": match_rules.scores.duplicate()}
	_check(knockout_ticks > 0 and actors.crew_2.body_position().y < -2.0, "Actual padded-stick hit pushes a standing puppet off the edge")
	_check(match_rules.scores.get("crew_1") == 1, "Natural physics ring-out awards one round win")
	var host_staff: Node3D = actors.crew_1.get_node_or_null("PaddedStick")
	_check(host_staff != null and host_staff.find_children("*", "MeshInstance3D", true, false).size() == 5, "Padded staff has shaft, two grips and two foam ends")
	var remote: Node3D = Puppet.instantiate()
	remote.authoritative = false
	root.add_child(remote)
	remote.present_pose(actors.crew_1.capture_pose())
	match_rules.present(match_rules.capture(), {"crew_1": remote})
	_check(remote.has_node("PaddedStick") and remote.get_node("PaddedStick").visible, "Remote actor receives the same visible staff state")
	_check(remote.get_node("PaddedStick").find_children("*", "CollisionObject3D", true, false).is_empty(), "Remote weapon display creates no competing physics authority")
	actors.crew_1.set_combat_visual(false)
	_check(not host_staff.visible, "Leaving combat hides staff for existing co-op modes")
	var report := {"checks": checks, "passed": checks - failures.size(), "failures": failures, "evidence": evidence,
		"limits": "Two actual Jolt puppets on a bounded flat platform. Explicit initial positions for each contact fixture. Native visual feel, human timing and LAN latency are separate checks."}
	var file := FileAccess.open("res://logs/gladiator-combat-probe.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("GLADIATOR_COMBAT ", JSON.stringify(report))
	remote.queue_free()
	for actor: Node3D in actors.values(): actor.queue_free()
	arena.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)

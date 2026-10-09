extends SceneTree
var _failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		_failed = true

func _run() -> void:
	if not ResourceLoader.exists("res://game/world/island.gd"):
		push_error("Island implementation is missing")
		quit(1)
		return
	var world_script: Script = load("res://game/world/island.gd") as Script
	if world_script == null or not world_script.can_instantiate():
		push_error("Island script does not compile")
		quit(1)
		return
	var world: Node3D = world_script.new() as Node3D
	root.add_child(world)
	await physics_frame
	await physics_frame
	var markers: Dictionary = world.get("markers")
	for key: String in ["spawn", "boat", "jetty", "reeds", "lens_cache", "rod_cache", "repair_cache", "repair", "vote"]:
		_check(markers.has(key), "Missing interaction marker: " + key)
		var at: Vector3 = markers.get(key, Vector3.ZERO)
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at + Vector3.UP * 5.0, at - Vector3.UP * 3.0)
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
		_check(not hit.is_empty(), "Interaction marker has no supporting collision: " + key)
	_check((markers["boat"] as Vector3).distance_to(markers["jetty"] as Vector3) > 25.0, "Boat and jetty shelter must occupy separate areas")
	world.call("set_station", "jetty", false)
	_check(not (world.get_node("Station_jetty/Light") as OmniLight3D).visible, "Station must visibly lose power")
	world.call("set_station", "jetty", true)
	_check((world.get_node("Station_jetty/Light") as OmniLight3D).visible, "Station must visibly gain power")
	world.call("set_repaired", false)
	await physics_frame
	await physics_frame
	var crossing: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(0.0, 7.0, 10.0), Vector3(0.0, -1.0, 10.0))
	_check(world.get_world_3d().direct_space_state.intersect_ray(crossing).is_empty(), "Broken crossing must not provide invisible collision")
	world.call("set_repaired", true)
	await physics_frame
	await physics_frame
	_check(not world.get_world_3d().direct_space_state.intersect_ray(crossing).is_empty(), "Repaired crossing must support players")
	if not world.has_method("route_step"):
		push_error("Hunter needs a ground-only route_step helper")
		quit(1)
		return
	world.call("set_repaired", false)
	await physics_frame
	await physics_frame
	var next_broken: Vector3 = world.call("route_step", Vector3(-66, 2.05, 10), Vector3(66, 2.05, 10)) as Vector3
	_check(absf(next_broken.x) > 55.0 and absf(next_broken.z - 10.0) > 5.0, "Broken crossing must route around a shore")
	_probe_route(world, Vector3(-66, 2.05, 30), Vector3(66, 2.05, -30))
	_probe_route(world, Vector3(66, 2.05, -30), Vector3(-66, 2.05, 30))
	_probe_route(world, Vector3(-66, 2.05, 30), Vector3(-45, 2.05, -42))
	var same_bank: Vector3 = world.call("route_step", Vector3(-66, 2.05, 40), Vector3(-66, 2.05, -32)) as Vector3
	_check(same_bank.distance_to(Vector3(-66, 2.05, -32)) < 0.1, "Same-bank pursuit should stay direct")
	world.call("set_repaired", true)
	await physics_frame
	await physics_frame
	var next_repaired: Vector3 = world.call("route_step", Vector3(-66, 2.05, 10), Vector3(66, 2.05, 10)) as Vector3
	_check(next_repaired.distance_to(Vector3(66, 2.05, 10)) < 0.1, "Repaired crossing should provide the direct route")
	_probe_route(world, Vector3(-66, 2.05, 30), Vector3(66, 2.05, -30))
	world.call("set_time", 300.0)
	world.call("set_fog", true)
	await process_frame
	if _failed:
		quit(1)
	else:
		print("ART_WORLD_PROBE_OK")
		quit(0)

func _probe_route(world: Node3D, start: Vector3, destination: Vector3) -> void:
	var at: Vector3 = start
	for step: int in range(700):
		if at.distance_to(destination) < 0.8:
			return
		var next: Vector3 = world.call("route_step", at, destination) as Vector3
		if at.distance_to(next) < 0.01:
			_check(false, "Hunter route stalled at " + str(at))
			return
		at = at.move_toward(next, 0.75)
		var ground: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at - Vector3.UP * 0.3)
		if world.get_world_3d().direct_space_state.intersect_ray(ground).is_empty():
			_check(false, "Hunter route crossed unsupported water at " + str(at))
			return
	_check(false, "Hunter route did not reach its target in a bounded walk")

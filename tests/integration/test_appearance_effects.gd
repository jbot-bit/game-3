extends GutTest
const Art=preload("res://game/world/block_art.gd")
const PlayerBody=preload("res://game/player/player.gd")
const Effects=preload("res://game/world/gameplay_effects.gd")

class FishingWater extends Node3D:
	var markers: Dictionary={"jetty":Vector3.ZERO}
	func fishing_habitat(_position: Vector3) -> String: return "jetty"
	func fishing_focus(_habitat: String) -> Vector3: return Vector3(0,0.35,-10)

class DepartureWater extends Node3D:
	var markers: Dictionary={"refuge_mooring": Vector3(-4.2,1,8.4), "escape_channel": Vector3(0,1,16.8), "escape_destination": Vector3(0,1,47.04)}

func test_cast_animation_changes_transforms_without_rebuilding_line_geometry() -> void:
	var scene: Node3D=Node3D.new()
	add_child_autofree(scene)
	var world: Node3D=FishingWater.new()
	scene.add_child(world)
	var effects: Node3D=Effects.new()
	scene.add_child(effects)
	var actor: CharacterBody3D=PlayerBody.new()
	actor.setup("crew_1",Color("62b9db"))
	scene.add_child(actor)
	actor.position=Vector3(0,2,0)
	var avatars: Dictionary={"crew_1":actor}
	var snapshot: Dictionary={"fishing":{"crew_1":{"catch_id":"line:1","habitat_id":"jetty","elapsed":2.0,"pull":0.0,"tension":0.2}}}
	effects._update_casts(snapshot,avatars,world)
	var cast: Node3D=effects._casts.crew_1
	var meshes: Array[Mesh]=[]
	for index: int in range(6): meshes.append(cast.get_node("Line%s"%index).mesh)
	actor.position=Vector3(2,2,0)
	actor.rotation.y=0.3
	effects._clock=2.0
	snapshot.fishing.crew_1.pull=0.8
	snapshot.fishing.crew_1.tension=0.9
	effects._update_casts(snapshot,avatars,world)
	var tip: Node3D=actor.visual.get_node("RightArm/HeldTool/RodTip")
	var endpoint: Vector3=cast.get_node("Bobber").global_position
	for index: int in range(6):
		var line: MeshInstance3D=cast.get_node("Line%s"%index)
		assert_same(line.mesh,meshes[index])
		assert_eq((line.mesh as BoxMesh).size,Vector3(0.025,1,0.025),"Line animation must leave mesh geometry unchanged")
		var a: Vector3=effects._line_point(tip.global_position,endpoint,float(index)/6.0)
		var b: Vector3=effects._line_point(tip.global_position,endpoint,float(index+1)/6.0)
		assert_lt((line.global_transform*Vector3(0,-0.5,0)).distance_to(a),0.00001)
		assert_lt((line.global_transform*Vector3(0,0.5,0)).distance_to(b),0.00001)
		assert_eq(line.material_override.albedo_color,Color("f48777"))

func test_departure_clones_keep_saved_outfits_and_original_crew_colours() -> void:
	var scene: Node3D=Node3D.new()
	add_child_autofree(scene)
	var world: Node3D=DepartureWater.new()
	scene.add_child(world)
	var boat: Node3D=Node3D.new()
	boat.name="MothSkiff"
	boat.position=Vector3(-47.4,1,43.8)
	world.add_child(boat)
	var effects: Node3D=Effects.new()
	scene.add_child(effects)
	var avatars: Dictionary={}
	var colours: Array[Color]=[Color("62b9db"),Color("e67c61"),Color("a28ad6")]
	var outfits: Array[String]=["angler","deckhand","stormwatch"]
	var players: Dictionary={}
	for index: int in range(3):
		var id: String="crew_%s"%(index+1)
		var actor: CharacterBody3D=PlayerBody.new()
		actor.setup(id,colours[index])
		scene.add_child(actor)
		actor.set_loadout({"outfit_id":outfits[index]},90,false)
		avatars[id]=actor
		players[id]={"aboard":true}
	var snapshot: Dictionary={"run":{"phase":"escape","players":players,"crossing_left":20.0}}
	effects._update_refuge(snapshot,avatars,world)
	var passengers: Node3D=boat.get_node("RefugeCrew")
	for index: int in range(3):
		var id: String="crew_%s"%(index+1)
		var clone: Node3D=passengers.get_node(id)
		assert_eq(clone.get_meta("outfit_id"),outfits[index],"Departure must retain the earned outfit")
		assert_eq(clone.get_meta("crew_color"),colours[index],"Coat material is not the player's identity colour")
		assert_false(avatars[id].visual.visible)
		assert_not_null(clone.get_node_or_null("RiggedModel/Rig/Skeleton3D"),"Departure must use the same rigged crew as the island")
		assert_true(clone.has_method("set_seated"),"Boat pose uses the authored seated clip")
		if clone.has_method("set_seated"): assert_eq(clone.animation_state,"Seated")
		assert_false(clone.get_node("RightArm/HeldTool").visible)
	snapshot.run.phase="day"
	effects._update_refuge(snapshot,avatars,world)
	for actor: Node3D in avatars.values(): assert_true(actor.visual.visible)
	assert_eq(boat.position,Vector3(-47.4,1,43.8))


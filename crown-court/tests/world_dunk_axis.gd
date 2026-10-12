extends SceneTree
## Presentation fixture: turn input must not move an active dunk's rim-contact axis.
const World = preload("res://world.gd")
const Sim = preload("res://sim.gd")
var evidence := "C:/game-3/build/crown-court-evidence/v10-world-dunk-axis"
var pack_source := ""
var checks: Array = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence = arg.trim_prefix("--evidence-dir=")
		if arg.begins_with("--pack-source="): pack_source = arg.trim_prefix("--pack-source=")
	run.call_deferred()

func check(ok: bool, label: String, detail: Dictionary = {}) -> void:
	checks.append({"passed":ok,"check":label,"details":detail})
	print("PASS " if ok else "FAIL ",label," ",detail)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(evidence)
	var world = World.new()
	root.add_child(world)
	world.actor_root = Node3D.new()
	world.add_child(world.actor_root)
	world.effect_root = Node3D.new()
	world.add_child(world.effect_root)
	var immutable := true
	for side in [-1,1]:
		for giant in [false,true]:
			var axis := Vector3(0,0,side)
			var hoop: Vector3 = Sim.NORTH if side<0 else Sim.SOUTH
			var size := 1.8 if giant else 1.0
			var actor: Dictionary = world._make_actor(1)
			actor.team = 0 if side<0 else 1
			var data := {"pos":hoop-axis*(Sim.RIM_RADIUS+Sim.RIM_TUBE+.58*size)-Vector3.UP*1.8,"vel":Vector3.ZERO,"move":Vector3.ZERO,"aim":-axis,"facing":-axis,"dunk_direction":axis,"dunk":.18,"dunk_duration":1.5,"grounded":false,"giant":4.0 if giant else 0.0}
			var before := var_to_bytes(data)
			world._present_actor(actor,1,data,true,false,hoop,"Probe",.5)
			immutable = immutable and before==var_to_bytes(data)
			var error := 0.0
			for hand_side in [-1.0,1.0]:
				var hand: Node3D = actor.left_hand if hand_side<0 else actor.right_hand
				var across := Vector3(-axis.z,0,axis.x)
				var expected: Vector3 = hoop-axis*Sim.RIM_RADIUS+across*hand_side*.32+Vector3.UP*.06
				error = maxf(error,hand.global_position.distance_to(expected))
			var heading_dot: float = (-actor.root.global_basis.z).dot(axis)
			check(heading_dot>.999 and error<.001,"Frozen dunk axis controls body and released rim hands",{"side":side,"giant":giant,"heading_dot":heading_dot,"max_hand_error_m":error})
			# The held pose remains attached to the supplied ball, independently of
			# the input aim. Snapshot ownership/position are never changed here.
			data.dunk = .5
			var ball := hoop-axis*.4+Vector3.UP*.65
			world._present_actor(actor,1,data,true,true,ball,"Probe",.5)
			var rendered_ball: Vector3 = ball+actor.carry_offset
			var max_gap := maxf(actor.left_hand.global_position.distance_to(rendered_ball),actor.right_hand.global_position.distance_to(rendered_ball))
			check(max_gap<.33*size,"Held dunk hands stay attached while input faces away",{"side":side,"giant":giant,"max_hand_center_gap_m":max_gap})
	check(immutable,"Presentation leaves input dictionaries unchanged")
	var failures := checks.filter(func(item):return not item.passed).size()
	var report := {"fixture":true,"passed":failures==0,"checks":checks,"world_sha256":FileAccess.get_sha256("res://world.gd"),"pack_sha256":FileAccess.get_sha256(pack_source) if not pack_source.is_empty() else "","limit":"Headless transform fixture; not native pixel or whole-match proof. Sim dunk_aim separately tests actual input, motion and scoring."}
	var file := FileAccess.open(evidence.path_join("result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	world.free()
	quit(0 if failures==0 else 1)

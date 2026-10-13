extends SceneTree
const Sim = preload("res://sim.gd")
const World = preload("res://world.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures += 1
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	# Measured family GLB bounds, excluding raised hands/accessories.
	for height in [2.163983,2.157110,2.155772]:
		check(Sim.HOOP_Y/height >= 2.65 and Sim.HOOP_Y/height <= 2.75,"Standing family rim ratio restored to approximately 2.7")
	var world = World.new()
	root.add_child(world)
	world.build("coop")
	for name in ["NorthHoop","SouthHoop"]:
		var support = world.arena.get_node(name+"/PaddedBackboard").get_child(0)
		var bounds: AABB = support.mesh.get_aabb()
		var bottom: float = support.position.y+bounds.position.y
		var top: float = bottom+bounds.size.y
		check(bottom <= .05 and top >= Sim.HOOP_Y+.7,"Support connects court to raised backboard "+name)
	check(is_equal_approx(Sim.RIM_RADIUS,1.65) and is_equal_approx(Sim.BALL_RADIUS,.52),"Scoring opening and ball size preserved")
	print("HOOP_PROPORTIONS_RESULT failures=",failures)
	quit(0 if failures == 0 else 1)

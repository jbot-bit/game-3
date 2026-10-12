extends SceneTree
const World = preload("res://world.gd")
const Sim = preload("res://sim.gd")
var world
var sim
var label: Label
var frame := 0
var samples: Array = []
var evidence := "C:/game-3/build/crown-court-evidence/v7-world-reversal"
var phase := "candidate"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence = arg.trim_prefix("--evidence-dir=")
		if arg.begins_with("--phase="): phase = arg.trim_prefix("--phase=")
	prepare.call_deferred()

func prepare() -> void:
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(1280,800)
	world = World.new()
	root.add_child(world)
	world.build("coop")
	sim = Sim.new()
	sim.reset("coop")
	sim.players = {1:sim.players[1]}
	sim.players[1].pos = Vector3(0,0,6)
	sim.reset_time = 0
	sim.ball.lock = 0
	sim.ball.pos = Vector3(7,.65,6)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	label = Label.new()
	label.position = Vector2(28,690)
	label.add_theme_font_size_override("font_size",22)
	label.add_theme_color_override("font_color",Color.WHITE)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",2)
	layer.add_child(label)

func _process(_dt: float) -> bool:
	if sim == null: return false
	var direction := Vector3.ZERO
	var action := "RELEASE INPUT"
	if frame >= 60 and frame < 132:
		direction = Vector3.FORWARD
		action = "FORWARD"
	elif frame >= 132 and frame < 228:
		direction = Vector3.BACK
		action = "REVERSE 180 DEGREES"
	elif frame >= 258 and frame < 330:
		direction = Vector3.FORWARD
		action = "START FORWARD"
	elif frame >= 330 and frame < 402:
		direction = Vector3.RIGHT
		action = "TURN RIGHT"
	elif frame >= 402 and frame < 480:
		direction = Vector3.LEFT
		action = "REVERSE LEFT"
	sim.move_input(1,direction,direction if direction.length_squared() > 0 else sim.players[1].aim)
	sim.step(1.0/60)
	var state: Dictionary = sim.snapshot()
	world.present(state,1,1.0/60,.85,.43)
	var p: Dictionary = sim.players[1]
	label.text = "%s | %s\nInput speed %.2f  |  Actual speed %.2f m/s\nAuthored diagnostic commands through Sim.move_input; no position animation." % [phase.to_upper(),action,direction.length(),Vector2(p.vel.x,p.vel.z).length()]
	samples.append({"frame":frame,"time":frame/60.0,"input":direction,"position":p.pos,"velocity":p.vel,"facing":p.facing,"left_foot":world.actors[1].left_foot.position,"rig_rotation":world.actors[1].rig.rotation})
	frame += 1
	if frame >= 600:
		FileAccess.open(evidence.path_join("reversal.json"),FileAccess.WRITE).store_string(JSON.stringify({"fixture":true,"real_simulation":true,"phase":phase,"samples":samples,"world_sha256":FileAccess.get_sha256("res://world.gd"),"sim_sha256":FileAccess.get_sha256("res://sim.gd")},"  "))
		quit()
	return false

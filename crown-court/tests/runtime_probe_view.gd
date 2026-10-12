extends "res://tests/active_play.gd"

var probe = preload("runtime_probe_log.gd").new()
var frame_delta = 0.0

func _initialize() -> void:
	RenderingServer.frame_post_draw.connect(sample_presented)
	super._initialize()

func _process(dt: float) -> bool:
	frame_delta = dt
	return false

func sample_presented() -> void:
	probe.sample(app,frame_delta)

func finish(completed: bool) -> void:
	RenderingServer.frame_post_draw.disconnect(sample_presented)
	probe.save(output_dir.path_join("runtime-view.json"),"view")
	super.finish(completed)

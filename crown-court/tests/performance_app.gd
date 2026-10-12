extends "res://main.gd"

var measurements: Dictionary = {}
var process_rows: Array[Dictionary] = []
var previous_process_at = -1
var initialization_ms = 0.0

func record_metric(metric: String, started: int) -> void:
	if not measurements.has(metric): measurements[metric] = []
	measurements[metric].append(float(Time.get_ticks_usec()-started)/1000.0)

func _ready() -> void:
	var started = Time.get_ticks_usec()
	super._ready()
	initialization_ms = float(Time.get_ticks_usec()-started)/1000.0

func _process(dt: float) -> void:
	var started = Time.get_ticks_usec()
	super._process(dt)
	var work = float(Time.get_ticks_usec()-started)/1000.0
	if phase == "match":
		if not measurements.has("app.process_work_ms"): measurements["app.process_work_ms"] = []
		measurements["app.process_work_ms"].append(work)
		process_rows.append({"wall_usec":started,"wall_gap_ms":float(started-previous_process_at)/1000.0 if previous_process_at >= 0 else 0.0,"work_ms":work,"engine_dt_ms":dt*1000,"clock":state.get("clock",0),"reset":state.get("reset_time",0),"celebration":state.get("celebration_time",0)})
	previous_process_at = started

func _physics_process(dt: float) -> void:
	var started = Time.get_ticks_usec()
	super._physics_process(dt)
	if phase == "match": record_metric("app.physics_work_ms",started)

func update_hud(dt: float) -> void:
	var started = Time.get_ticks_usec()
	super.update_hud(dt)
	record_metric("app.hud_work_ms",started)

func trajectory_preview() -> PackedVector3Array:
	var started = Time.get_ticks_usec()
	var value = super.trajectory_preview()
	record_metric("app.trajectory_work_ms",started)
	return value

func presentation_state() -> Dictionary:
	var started = Time.get_ticks_usec()
	var value = super.presentation_state()
	record_metric("app.prediction_work_ms",started)
	return value

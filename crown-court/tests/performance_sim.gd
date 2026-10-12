extends "res://sim.gd"

var measurements: Dictionary = {}

func record_metric(metric: String, started: int) -> void:
	if not measurements.has(metric): measurements[metric] = []
	measurements[metric].append(float(Time.get_ticks_usec()-started)/1000.0)

func step(dt: float) -> void:
	var started = Time.get_ticks_usec()
	super.step(dt)
	record_metric("sim.step_work_ms",started)

func bot_command(id: int) -> Dictionary:
	var started = Time.get_ticks_usec()
	var value = super.bot_command(id)
	record_metric("sim.bot_work_ms",started)
	return value

func snapshot() -> Dictionary:
	var started = Time.get_ticks_usec()
	var value = super.snapshot()
	record_metric("sim.snapshot_work_ms",started)
	return value

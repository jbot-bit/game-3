extends "res://main.gd"

# Godot exposes no script API to register a virtual physical joypad. Only the
# discovery list is injected; all controls below use real parsed InputEvents.
var discovered_devices: Array[int] = []
var commands: Array[String] = []
var device_label = ""
var isolate_pointer_motion = false
var pointer_events: Array[Dictionary] = []

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var before_yaw: float = yaw
		var before_ball_camera: bool = ball_camera
		if isolate_pointer_motion: get_viewport().set_input_as_handled()
		else: super._input(event)
		if phase == "match" and not paused and pointer_events.size() < 1000:
			pointer_events.append({"time":Time.get_ticks_msec(),"relative":[event.relative.x,event.relative.y],"screen_relative":[event.screen_relative.x,event.screen_relative.y],"probe":bool(event.get_meta("controller_probe",false)),"isolated":isolate_pointer_motion,"yaw_delta":yaw-before_yaw,"ball_camera_before":before_ball_camera,"ball_camera_after":ball_camera})
		return
	super._input(event)

func controller_devices() -> Array[int]:
	return discovered_devices

func controller_name() -> String:
	return device_label

func submit_action(command: String, charge: float = 0.5) -> void:
	commands.append(command)
	super.submit_action(command, charge)

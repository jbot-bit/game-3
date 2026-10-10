class_name PatrolRules
extends RefCounted
## Chooses destinations only. The host moves along the island's valid routes.
var mode: String="patrol"
var goal: Vector3=Vector3.ZERO
var noise_until: float=-1.0
var _noise_position: Vector3=Vector3.ZERO
var _noise_time: float=-1.0
var _pending_noises: Array[Dictionary]=[]
var _heard_noise: bool=false
var _waypoint: int=-1

func record_noise(position: Vector3, now_s: float) -> bool:
	if not position.is_finite() or not is_finite(now_s) or now_s<0.0 or now_s<_noise_time: return false
	_noise_time=now_s
	_pending_noises.append({"position":position,"until":now_s+12.0})
	if _pending_noises.size()>8: _pending_noises.pop_front()
	return true

func next_goal(now_s: float, position: Vector3, waypoints: Array) -> Vector3:
	if not position.is_finite(): return Vector3.ZERO
	if not is_finite(now_s) or now_s<0.0: return position
	var route: Array[Vector3]=[]
	for point in waypoints:
		if point is Vector3 and point.is_finite(): route.append(point)
	if route.is_empty():
		mode="patrol"
		goal=position
		return goal
	if _waypoint<0 or _waypoint>=route.size():
		_waypoint=0
		for index in range(1,route.size()):
			if position.distance_squared_to(route[index])<position.distance_squared_to(route[_waypoint]): _waypoint=index
	# Process a bounded set of cues together. An inaudible teammate's cast must
	# not erase the nearby cue being investigated or one received in this frame.
	for noise: Dictionary in _pending_noises:
		if now_s<float(noise.until) and position.distance_to(noise.position)<=55.0:
			_noise_position=noise.position
			noise_until=noise.until
			_heard_noise=true
	_pending_noises.clear()
	if _heard_noise and now_s<noise_until and position.distance_to(_noise_position)>3.0:
		mode="investigate"
		goal=_noise_position
		return goal
	_heard_noise=false
	mode="patrol"
	if position.distance_to(route[_waypoint])<=3.0: _waypoint=(_waypoint+1)%route.size()
	goal=route[_waypoint]
	return goal

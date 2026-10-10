extends RefCounted
## Render-only timeline. The host's bodies remain the gameplay authority.

const BUFFER_MSEC: float = 67.0
const MAX_SNAPSHOTS: int = 12
const PUPPET_TELEPORT_METERS: float = 8.0
const PROP_TELEPORT_METERS: float = 12.0

var _snapshots: Array[Dictionary] = []
var _run_id: String = ""
var _clock_offset: float = INF
var _last_source_time: float = -INF

func reset() -> void:
	_snapshots.clear()
	_run_id = ""
	_clock_offset = INF
	_last_source_time = -INF

func push(data: Dictionary, received_msec: float) -> void:
	if not is_finite(received_msec) or not _valid_snapshot(data):
		return
	var stamp: float = float(data.pose_msec)
	if str(data.run_id) != _run_id:
		reset()
		_run_id = str(data.run_id)
	if not _snapshots.is_empty() and stamp <= float(_snapshots.back().pose_msec):
		return
	# Arrival delays must not continually move the presentation clock backwards.
	_clock_offset = minf(_clock_offset, received_msec - stamp)
	_snapshots.append(data.duplicate(true))
	while _snapshots.size() > MAX_SNAPSHOTS:
		_snapshots.pop_front()

func sample(now_msec: float) -> Dictionary:
	if _snapshots.is_empty() or not is_finite(now_msec):
		return {}
	var source_time: float = maxf(_last_source_time, now_msec - _clock_offset - BUFFER_MSEC)
	_last_source_time = source_time
	# Keep the two snapshots around the render time, rather than restarting a
	# tween on every arrival. Bones and props use this exact same pair and alpha.
	while _snapshots.size() > 2 and float(_snapshots[1].pose_msec) <= source_time:
		_snapshots.pop_front()
	var first: Dictionary = _snapshots.front()
	if source_time <= float(first.pose_msec):
		return first.duplicate(true)
	var latest: Dictionary = _snapshots.back()
	if _snapshots.size() == 1 or source_time >= float(latest.pose_msec):
		return latest.duplicate(true)
	var second: Dictionary = _snapshots[1]
	var blend: float = clampf((source_time - float(first.pose_msec)) / (float(second.pose_msec) - float(first.pose_msec)), 0.0, 1.0)
	var shown: Dictionary = {"run_id": _run_id, "pose_msec": source_time, "puppets": {}, "props": {}}
	for id: Variant in first.puppets:
		var before: Array = first.puppets[id]
		if not second.puppets.has(id) or before[0].origin.distance_to(second.puppets[id][0].origin) > PUPPET_TELEPORT_METERS:
			shown.puppets[id] = before.duplicate()
			continue
		var bones: Array = []
		for index: int in range(10):
			bones.append(before[index].interpolate_with(second.puppets[id][index], blend))
		shown.puppets[id] = bones
	for id: Variant in first.props:
		var before: Transform3D = first.props[id]
		if not second.props.has(id) or before.origin.distance_to(second.props[id].origin) > PROP_TELEPORT_METERS:
			shown.props[id] = before
		else:
			shown.props[id] = before.interpolate_with(second.props[id], blend)
	return shown

func _valid_snapshot(data: Dictionary) -> bool:
	if not data.get("run_id") is String or str(data.run_id).is_empty():
		return false
	var stamp: Variant = data.get("pose_msec")
	if (not stamp is float and not stamp is int) or not is_finite(float(stamp)) or float(stamp) < 0.0:
		return false
	if not data.get("puppets") is Dictionary or not data.get("props") is Dictionary:
		return false
	for pose: Variant in data.puppets.values():
		if not pose is Array or pose.size() != 10:
			return false
		for bone: Variant in pose:
			if not _valid_transform(bone):
				return false
	for prop: Variant in data.props.values():
		if not _valid_transform(prop):
			return false
	return true

func _valid_transform(value: Variant) -> bool:
	return value is Transform3D and value.origin.is_finite() and value.basis.is_finite()

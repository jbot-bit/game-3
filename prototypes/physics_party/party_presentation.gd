extends RefCounted
## Render-only timeline. The host's bodies remain the gameplay authority.
const Teamwork = preload("res://prototypes/physics_party/party_teamwork.gd")
const Match = preload("res://prototypes/physics_party/party_match.gd")

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
	var shown: Dictionary = {"run_id": _run_id, "pose_msec": source_time, "puppets": {}, "props": {}, "grapples": {}}
	if first.has("teamwork") and second.has("teamwork"):
		shown.teamwork = Teamwork.interpolate(first.teamwork, second.teamwork, blend)
	if first.has("match") and second.has("match"):
		shown.match = Match.interpolate(first.match, second.match, blend)
	shown.movers = {}
	for id in first.get("movers", {}):
		var before: Transform3D = first.movers[id]
		var after: Transform3D = second.get("movers", {}).get(id, before)
		shown.movers[id] = before.interpolate_with(after, blend)
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
	for id: Variant in first.get("grapples", {}):
		var before: Dictionary = first.grapples[id]
		var after: Dictionary = second.get("grapples", {}).get(id, {})
		var rope: Dictionary = before.duplicate()
		# Attach/release/mode transitions happen with their matching body snapshot.
		# Only compatible continuous values share the body's interpolation fraction.
		if before.active and after.get("active", false) and before.mode == after.get("mode") and before.anchor.distance_to(after.anchor) < 4.0:
			if second.puppets.has(id) and first.puppets[id][0].origin.distance_to(second.puppets[id][0].origin) <= PUPPET_TELEPORT_METERS:
				rope.anchor = before.anchor.lerp(after.anchor, blend)
				rope.length = lerpf(float(before.length), float(after.length), blend)
		shown.grapples[id] = rope
	return shown

func _valid_snapshot(data: Dictionary) -> bool:
	if not data.get("run_id") is String or str(data.run_id).is_empty():
		return false
	var stamp: Variant = data.get("pose_msec")
	if (not stamp is float and not stamp is int) or not is_finite(float(stamp)) or float(stamp) < 0.0:
		return false
	if not data.get("puppets") is Dictionary or not data.get("props") is Dictionary:
		return false
	if data.has("teamwork"):
		if not data.teamwork is Dictionary: return false
		if not data.teamwork.is_empty() and not Teamwork.valid_snapshot(data.teamwork): return false
	if data.has("match"):
		if not data.match is Dictionary: return false
		if not data.match.is_empty() and not Match.valid_snapshot(data.match): return false
	if not data.get("movers", {}) is Dictionary or data.get("movers", {}).size() > 16: return false
	for mover in data.get("movers", {}).values():
		if not _valid_transform(mover) or mover.origin.length() > 600.0: return false
	for pose: Variant in data.puppets.values():
		if not pose is Array or pose.size() != 10:
			return false
		for bone: Variant in pose:
			if not _valid_transform(bone):
				return false
	for prop: Variant in data.props.values():
		if not _valid_transform(prop):
			return false
	if not data.get("grapples", {}) is Dictionary: return false
	var grapples: Dictionary = data.get("grapples", {})
	if grapples.size() > 3: return false
	for id: Variant in grapples:
		if not data.puppets.has(id) or not grapples[id] is Dictionary: return false
		var rope: Dictionary = grapples[id]
		if rope.size() != 4 or not rope.get("active") is bool or rope.get("mode") not in ["pull", "swing"]: return false
		if not rope.get("anchor") is Vector3 or not rope.anchor.is_finite() or rope.anchor.length() > 512.0: return false
		var length: Variant = rope.get("length")
		if (not length is float and not length is int) or not is_finite(float(length)) or float(length) < 0.0 or float(length) > 33.0: return false
	return true

func _valid_transform(value: Variant) -> bool:
	return value is Transform3D and value.origin.is_finite() and value.basis.is_finite()

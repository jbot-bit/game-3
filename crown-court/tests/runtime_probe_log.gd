extends RefCounted

var rows: Array[Dictionary] = []
var started = Time.get_ticks_usec()

func sample(app, process_delta: float) -> void:
	if not is_instance_valid(app) or app.phase != "match" or app.state.is_empty() or not app.state.players.has(app.local_seat): return
	var player: Dictionary = app.state.players[app.local_seat]
	var now = Time.get_ticks_usec()
	var shown: Vector3 = app.world.actors[app.local_seat].root.position if app.world.actors.has(app.local_seat) else player.pos
	rows.append({"wall_seconds":float(now-started)/1000000.0,"unix_seconds":Time.get_unix_time_from_system(),"process_dt":process_delta,"physics_frame":Engine.get_physics_frames(),"snapshot_count":app.snapshot_count,"snapshot_seq":app.snapshot_received_sequence,"snapshot_age_app_seconds":maxf(0,app.ui_clock-app.snapshot_received_at),"clock":app.state.clock,"reset":app.state.reset_time,"celebration":app.state.celebration_time,"pos":vec(player.pos),"vel":vec(player.vel),"shown_pos":vec(shown),"camera":vec(app.world.camera.position),"yaw":app.yaw,"dunk":player.dunk,"boost":player.get("boost_time",0),"owner":app.state.ball.owner,"humans":app.seats.size(),"scores":app.state.scores.duplicate(),"event":app.state.event_kind})

func vec(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

func distance(a: Array,b: Array) -> float:
	return Vector3(a[0],a[1],a[2]).distance_to(Vector3(b[0],b[1],b[2]))

func save(path: String, role: String) -> Dictionary:
	var gaps: Array[Dictionary] = []
	var max_wall = 0.0
	var max_snapshot_wall = 0.0
	var max_snapshot_clock = 0.0
	var max_position = 0.0
	var max_shown = 0.0
	var max_camera = 0.0
	var previous_snapshot_wall = 0.0
	for index in range(1,rows.size()):
		var row = rows[index]
		var before = rows[index-1]
		var gap = float(row.wall_seconds)-float(before.wall_seconds)
		var snapshot_gap = 0.0
		if int(row.snapshot_seq) != int(before.snapshot_seq):
			if previous_snapshot_wall > 0: snapshot_gap = row.wall_seconds-previous_snapshot_wall
			previous_snapshot_wall = row.wall_seconds
			max_snapshot_wall = maxf(max_snapshot_wall,snapshot_gap)
			max_snapshot_clock = maxf(max_snapshot_clock,absf(float(row.clock)-float(before.clock)))
		var reset = float(before.celebration) > 0 and float(row.celebration) <= 0 and float(row.reset) > 0
		var position_step = distance(row.pos,before.pos)
		var shown_step = distance(row.shown_pos,before.shown_pos)
		var camera_step = distance(row.camera,before.camera)
		max_wall = maxf(max_wall,gap)
		if not reset:
			max_position = maxf(max_position,position_step)
			max_shown = maxf(max_shown,shown_step)
			max_camera = maxf(max_camera,camera_step)
		if gap > .045 or snapshot_gap > .09 or position_step > 1 or camera_step > 1:
			gaps.append({"row":index,"wall_seconds":row.wall_seconds,"wall_gap":gap,"snapshot_observation_gap":snapshot_gap,"snapshot_seq_advance":int(row.snapshot_seq)-int(before.snapshot_seq),"clock_advance":float(before.clock)-float(row.clock),"position_step":position_step,"shown_step":shown_step,"camera_step":camera_step,"kickoff_reset":reset,"yaw_step":angle_difference(before.yaw,row.yaw),"dunk":row.dunk,"velocity":row.vel,"position":row.pos})
	var summary = {"role":role,"frames":rows.size(),"wall_span":rows[-1].wall_seconds-rows[0].wall_seconds if rows.size()>1 else 0,"max_frame_wall_gap_s":max_wall,"max_snapshot_observation_gap_s":max_snapshot_wall,"max_snapshot_clock_advance_s":max_snapshot_clock,"max_state_step_excluding_kickoff_m":max_position,"max_presented_step_excluding_kickoff_m":max_shown,"max_camera_step_excluding_kickoff_m":max_camera,"capture":false,"fixture_mutations":false,"application_version":ProjectSettings.get_setting("application/config/version","unknown"),"limitation":"Snapshot arrival observed once per process/render frame, not packet timestamps; local loopback, no capture/readback; bounded natural play, not a full-match result."}
	var file = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"summary":summary,"gaps":gaps,"frames":rows},"\t"))
	print("RUNTIME_PROBE ",JSON.stringify(summary))
	return summary

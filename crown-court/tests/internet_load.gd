extends "res://tests/internet_actions.gd"

var played=0.0
var command_age=0.0
var load_mind=preload("res://sim.gd").new()
var saturated=false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg=="--saturated":saturated=true
	super._initialize()

func boot() -> void:
	super.boot()
	app.test_saturated=saturated

func _process(dt: float) -> bool:
	if not is_instance_valid(app) or reported:return false
	observe_network(dt)
	elapsed+=dt
	peak_roster=maxi(peak_roster,app.seats.size())
	if role=="host" and app.phase=="lobby" and app.seats.size()==3:
		app.selected_mode="coop"
		app.start_match()
	if app.phase=="match" and not app.state.is_empty():
		played+=dt
		command_age+=dt
		if command_age>=.04 and app.state.players.has(app.local_seat):
			command_age=0
			load_mind.players=app.state.players.duplicate(true)
			load_mind.ball=app.state.ball.duplicate(true)
			load_mind.mode=app.state.mode
			load_mind.clock=app.state.clock
			var command=load_mind.bot_command(app.local_seat)
			app.submit_move(command.move,command.aim)
			if command.action!="":app.submit_action(command.action,command.charge)
		if role=="host" and played>24:
			var report={"ok":maximum_reliable>1200 and int(snapshot_transport.get("reliable",0))>20,"scenario":"load","played":played,"counters":counts(app.state),"host_scores":app.state.scores.duplicate(),"fixture_mutations":saturated,"transport_fixture":"384 deterministic incompressible bytes in test-only snapshot field" if saturated else "none"}
			if saturated:report.ok=report.ok and stats(app.test_encoded_sizes).min>1200
			for peer in app.connected_peers():coordinator.complete.rpc_id(peer,report)
			complete(report)
	if elapsed>45 and not reported:complete({"ok":false,"failure":"load session timeout"})
	return false

func complete(report: Dictionary) -> void:
	if reported:return
	reported=true
	var output=report.duplicate(true)
	output.merge(metrics())
	output["observed_scores"]=app.state.get("scores",{})
	output["ok"]=bool(report.get("ok",false)) and peak_roster==3
	if role!="host":output.ok=output.ok and large_packets.size()>5
	if role=="host":await create_timer(2.5).timeout
	else:await create_timer(.5).timeout
	write_report(role,output)
	print("INTERNET_LOAD_RESULT "+JSON.stringify(output))
	app.close_session("")
	await create_timer(.4).timeout
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(profile_path+suffix):DirAccess.remove_absolute(profile_path+suffix)
	quit(0 if output.ok else 1)

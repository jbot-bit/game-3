extends "res://tests/internet_actions.gd"

var saw_connecting=false

func _process(dt: float) -> bool:
	if not is_instance_valid(app) or reported:return false
	elapsed+=dt
	if app.phase=="connecting":saw_connecting=true
	if role!="host" and saw_connecting and app.phase=="menu":
		complete({"ok":elapsed>=5 and elapsed<18 and not app.status_message.is_empty(),"scenario":"unreachable_timeout","saw_connecting":saw_connecting,"returned_to_menu":true,"elapsed":elapsed,"message":app.status_message})
	elif role=="host" and elapsed>16:
		complete({"ok":app.phase=="lobby" and app.seats.size()==1,"scenario":"unreachable_timeout","elapsed":elapsed,"remaining_seats":app.seats.size()})
	if elapsed>20 and not reported:complete({"ok":false,"failure":"Production connect timeout did not return to menu"})
	return false

func complete(report: Dictionary) -> void:
	if reported:return
	reported=true
	report["role"]=role
	report["fixture_mutations"]=false
	report["label"]="SIMULATED_INTERNET_100_PERCENT_BLACKHOLE"
	write_report(role,report)
	print("INTERNET_TIMEOUT_RESULT "+JSON.stringify(report))
	app.close_session("")
	await create_timer(.4).timeout
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(profile_path+suffix):DirAccess.remove_absolute(profile_path+suffix)
	quit(0 if report.ok else 1)

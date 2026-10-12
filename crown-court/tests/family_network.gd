extends SceneTree

# Real application RPCs over an isolated local relay. Match state is never
# fabricated; start_match is used to test round transitions, not natural wins.
const Profile = preload("res://profile.gd")
var apps: Array = []
var profile_paths: Array[String] = []
var checks: Array[Dictionary] = []
var url = "ws://127.0.0.1:30262/rooms"
var evidence = "res://tests"
var host
var tyler
var dad

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--room-url="): url = arg.trim_prefix("--room-url=")
		if arg.begins_with("--evidence-dir="): evidence = arg.trim_prefix("--evidence-dir=")
	run.call_deferred()

func check(ok: bool, label: String, details: Dictionary = {}) -> bool:
	checks.append({"check":label,"passed":ok,"details":details})
	print("PASS " if ok else "FAIL ",label," ",details)
	return ok

func until(condition: Callable, seconds: float = 6.0) -> bool:
	var started = Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec()-started < seconds*1000:
		await process_frame
	return condition.call()

func make_app(label: String, identity: String):
	var branch = Node.new()
	branch.name = label
	root.add_child(branch)
	var api = SceneMultiplayer.new()
	api.root_path = branch.get_path()
	set_multiplayer(api,branch.get_path())
	var app = load("res://main.gd").new()
	app.name = "App"
	app.manual_input_enabled = false
	var path = "user://family_network_%s_%d.json" % [label,Time.get_ticks_usec()]
	profile_paths.append(path)
	app.profile = Profile.new(path)
	check(app.profile.select_character(identity),label+" selected character through profile API")
	branch.add_child(app)
	app.room_server_url = url
	app.nickname = label
	app.muted = true
	apps.append(app)
	return app

func profile_progress(app) -> Dictionary:
	return {"inventory":app.profile.data.inventory.duplicate(),"bags":app.profile.data.bags,"redeemed":app.profile.data.redeemed.duplicate(),"outfit":app.profile.outfit().outfit,"accessory":app.profile.outfit().accessory}

func cosmetics_agree(expected: Dictionary, snapshots: bool = false) -> bool:
	for app in apps:
		if app.phase not in ["lobby","match"]: return false
		if app.cosmetics != expected: return false
		if snapshots and app.state.get("cosmetics",{}) != expected: return false
	return true

func expected_cosmetics() -> Dictionary:
	var result = {}
	for app in apps: result[app.local_seat] = app.profile.outfit()
	return result

func run() -> void:
	host = make_app("Evie","evie")
	host.host_room("teams")
	if not check(await until(func(): return host.phase == "lobby" and not host.room_code.is_empty()),"host receives registered room identity",{"error":host.status_message}):
		await finish()
		return
	tyler = make_app("Tyler","tyler")
	tyler.join_room(host.room_code)
	if not check(await until(func(): return host.seats.size() == 2 and tyler.local_seat > 0 and cosmetics_agree(expected_cosmetics())),"Evie and Tyler register equipment through roster RPC"):
		await finish()
		return
	# Exercise the real host team-selector callback, not a simulation assignment.
	var option: OptionButton = host.team_rows.get_child(1).get_child(1)
	var old_side = option.selected
	option.select(1-old_side)
	option.item_selected.emit(1-old_side)
	check(await until(func(): return int(tyler.lobby_setup.get("teams",{}).get(tyler.local_seat,-1)) == 1-old_side),"host team switch reaches client lobby setup")
	var switched_side = 1-old_side
	host.start_match()
	if not check(await until(func(): return tyler.phase == "match" and tyler.snapshot_count > 3 and cosmetics_agree(expected_cosmetics(),true)),"family IDs survive authoritative compressed snapshots"):
		await finish()
		return
	check(int(tyler.state.players[tyler.local_seat].team) == switched_side,"team switch reaches match without changing Tyler identity")
	var first_round: String = host.match_id
	dad = make_app("Dad","dad")
	dad.join_room(host.room_code)
	if not check(await until(func(): return host.seats.size() == 3 and tyler.seats.size() == 3 and dad.seats.size() == 3 and dad.snapshot_count > 3 and cosmetics_agree(expected_cosmetics(),true)),"Dad late joins actual match with full family roster"):
		await finish()
		return
	check(dad.match_id == first_round and tyler.match_id == first_round,"late join preserves current match identity")
	check(host.local_seat != tyler.local_seat and host.local_seat != dad.local_seat and tyler.local_seat != dad.local_seat,"family IDs do not alias peer seats")
	var original_progress = profile_progress(dad)
	check(dad.profile.select_character("tyler"),"second peer may select Tyler")
	dad.sync_equipment()
	check(await until(func(): return cosmetics_agree(expected_cosmetics(),true)),"duplicate Tyler identity propagates independently on two seats")
	check(host.cosmetics[tyler.local_seat].character == "tyler" and host.cosmetics[dad.local_seat].character == "tyler" and host.seats.size() == 3,"duplicate selection retains both peers")
	check(dad.profile.select_character("dad"),"Dad can restore identity")
	dad.sync_equipment()
	check(profile_progress(dad) == original_progress,"identity selection preserves bags inventory redeemed IDs and clothing")
	check(await until(func(): return cosmetics_agree(expected_cosmetics(),true)),"restored Dad identity reaches all snapshots")
	# Earn disposable-profile cosmetics through public progression methods.
	var earned: Dictionary = {}
	var accessory: Dictionary = {}
	for index in range(11):
		check(tyler.profile.award_win("family-network-setup-%d" % index),"disposable progression setup %d" % index)
		var item: Dictionary = tyler.profile.open_bag()
		if item.get("slot","") == "outfit":
			earned = item
		elif item.get("slot","") == "accessory": accessory = item
		if not earned.is_empty() and not accessory.is_empty():
			break
	if check(not earned.is_empty(),"an outfit earned through bag API"):
		check(tyler.profile.equip(str(earned.id)),"earned outfit equipped through profile API")
		tyler.sync_equipment()
		check(await until(func(): return cosmetics_agree(expected_cosmetics(),true)),"outfit changes replicate while family identity remains Tyler",{"outfit":earned.id})
		check(tyler.profile.outfit().character == "tyler","bag opening and outfit change retain selected identity")
	if check(not accessory.is_empty(),"an accessory earned through bag API"):
		check(tyler.profile.equip(str(accessory.id)),"earned accessory equipped through profile API")
		tyler.sync_equipment()
		check(await until(func(): return cosmetics_agree(expected_cosmetics(),true)),"accessory and outfit replicate together with family identity",{"accessory":accessory.id})
	var populated_progress = profile_progress(tyler)
	check(tyler.profile.select_character("evie") and tyler.profile.select_character("tyler"),"populated profile can change and restore family identity")
	check(profile_progress(tyler) == populated_progress,"family selection preserves earned outfit accessory inventory bags and redeemed IDs")
	var reloaded = Profile.new(tyler.profile.path)
	# Loading normalizes inventory into catalog order; ownership is set-valued.
	var loaded_inventory: Array = reloaded.data.inventory.duplicate()
	var earned_inventory: Array = tyler.profile.data.inventory.duplicate()
	loaded_inventory.sort()
	earned_inventory.sort()
	check(reloaded.outfit() == tyler.profile.outfit() and loaded_inventory == earned_inventory and reloaded.data.bags == tyler.profile.data.bags and reloaded.data.redeemed == tyler.profile.data.redeemed,"family selection and earned equipment survive profile reload")
	var expected = expected_cosmetics()
	var saved_profile = dad.profile.data.duplicate(true)
	for invalid in ["intruder",42,["dad"]]:
		var malformed: Dictionary = dad.profile.outfit()
		malformed.character = invalid
		dad.register_equipment.rpc_id(1,malformed)
		expected[dad.local_seat] = {"character":"blank","outfit":malformed.outfit,"accessory":malformed.accessory}
		check(await until(func(): return cosmetics_agree(expected,true)),"invalid wire character falls back to blank",{"invalid":invalid})
	check(dad.profile.data == saved_profile,"malformed remote appearance does not modify sender profile")
	dad.register_equipment.rpc_id(1,{"outfit":"blank","accessory":"none"})
	check(await until(func(): return cosmetics_agree(expected,true)),"legacy wire equipment without character falls back to blank")
	dad.sync_equipment()
	check(await until(func(): return cosmetics_agree(expected_cosmetics(),true)),"valid appearance recovers after invalid wire payload")
	var before_rematch = {}
	for app in apps: before_rematch[app.nickname] = profile_progress(app)
	host.start_match()
	check(await until(func(): return host.match_id != first_round and tyler.match_id == host.match_id and dad.match_id == host.match_id and tyler.snapshot_count > 3 and dad.snapshot_count > 3 and cosmetics_agree(expected_cosmetics(),true)),"rematch creates shared new round and preserves all family equipment")
	for app in apps:
		check(profile_progress(app) == before_rematch[app.nickname],app.nickname+" progression unchanged by round restart")
	var former_seat: int = dad.local_seat
	await dad.close_session()
	check(await until(func(): return host.seats.size() == 2 and tyler.seats.size() == 2),"disconnect removes only Dad peer")
	dad.join_room(host.room_code)
	check(await until(func(): return host.seats.size() == 3 and dad.snapshot_count > 3 and cosmetics_agree(expected_cosmetics(),true)),"Dad rejoins and registers family equipment again")
	check(dad.local_seat == former_seat,"freed peer seat is reusable independently of family identity")
	await finish()

func finish() -> void:
	var snapshots = {}
	for app in apps:
		snapshots[app.nickname] = {"seat":app.local_seat,"count":app.snapshot_count,"character":app.profile.outfit().character,"cosmetics":app.state.get("cosmetics",{}).duplicate(true)}
		await app.close_session()
	await create_timer(.2).timeout
	for app in apps: app.get_parent().queue_free()
	await process_frame
	for path in profile_paths:
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	var report = {"passed":checks.all(func(row): return row.passed),"checks":checks,"peers":snapshots,"transport":"real local WebSocket room relay","match_state_fixture_mutations":false,"profile_setup":"disposable profiles; public selection, award and bag methods","scope":"registration, roster, snapshot, team, appearance and round transition; not natural match completion, physical three-PC or WAN evidence"}
	DirAccess.make_dir_recursive_absolute(evidence)
	var file = FileAccess.open(evidence.path_join("family-network-result.json"),FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report,"  "))
	print("FAMILY_NETWORK_RESULT ",JSON.stringify(report))
	quit(0 if report.passed else 1)

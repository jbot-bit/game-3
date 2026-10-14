extends SceneTree
# Actual two-peer ENet/RPC integration with explicitly controlled outcomes.
class Probe extends "res://main.gd":
	var saved_powers: Array[String] = []
	func save_settings() -> void: saved_powers.append(selected_power)

var checks = []
var apps = []
var host
var client
var port = 28996

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--port="): port = int(argument.trim_prefix("--port="))
	run.call_deferred()

func check(ok: bool, label: String, detail = {}) -> bool:
	checks.append({"passed":ok,"check":label,"detail":detail.duplicate(true)})
	if not ok: printerr("FAIL ",label," ",detail)
	return ok

func until(condition: Callable, seconds: float = 5.0) -> bool:
	var started = Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec()-started < seconds*1000: await process_frame
	return condition.call()

func make_app(label: String):
	var branch = Node.new()
	branch.name = label
	root.add_child(branch)
	var api = SceneMultiplayer.new()
	api.root_path = branch.get_path()
	set_multiplayer(api,branch.get_path())
	var app = Probe.new()
	app.name = "App"
	app.manual_input_enabled = false
	app.profile = app.Profile.new("user://series_network_%s_%d.json" % [label,Time.get_ticks_usec()])
	branch.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app.nickname = label
	app.muted = true
	apps.append(app)
	return app

func publish() -> bool:
	host._physics_process(.05)
	var sequence: int = host.snapshot_serial
	var began = Time.get_ticks_msec()
	var next_sample = began + 50
	# Production snapshots can use unreliable transport. Keep sampling at its
	# normal 20Hz rate instead of mistaking one dropped datagram for a failure.
	while Time.get_ticks_msec()-began < 5000:
		if not client.state.is_empty() and client.match_id == host.match_id and client.snapshot_received_sequence >= sequence: return true
		if Time.get_ticks_msec() >= next_sample:
			host._physics_process(.05)
			next_sample = Time.get_ticks_msec()+50
		await process_frame
	return false

func choose_client_power(value: String) -> void:
	var option = client.result_panel.find_child("NextPower",true,false) as OptionButton
	option.select(client.POWER_IDS.find(value))
	option.item_selected.emit(option.selected)

func client_power_status() -> String:
	var status = client.result_panel.find_child("NextPowerStatus",true,false) as Label
	return status.text if is_instance_valid(status) else ""

func client_dropdown_power() -> String:
	var option = client.result_panel.find_child("NextPower",true,false) as OptionButton
	return client.POWER_IDS[option.selected]

func finish() -> void:
	if is_instance_valid(host): await host.close_session()
	for app in apps: app.queue_free()
	await process_frame
	var failed = checks.filter(func(row): return not row.passed).size()
	print("SERIES_NETWORK_RESULT ",JSON.stringify({"checks":checks,"failures":failed}))
	quit(0 if failed == 0 else 1)

func run() -> void:
	host = make_app("SeriesHost")
	var server = ENetMultiplayerPeer.new()
	if not check(server.create_server(port,2,host.NETWORK_CHANNELS) == OK,"Isolated ENet server binds"):
		await finish()
		return
	host.multiplayer.multiplayer_peer = server
	host.selected_mode = "coop"
	host.show_lobby()
	client = make_app("SeriesClient")
	client.selected_power = "pad"
	client.join_game("127.0.0.1:%d" % port)
	var joined = await until(func(): return host.seats.size() == 2 and client.local_seat > 0 and client.seats.size() == 2 and host.powers.get(client.local_seat,"") == "pad")
	if not check(joined,"Two peers complete real application handshake",{"host_seats":host.seats,"client_seats":client.seats,"client_slot":client.local_seat,"host_powers":host.powers,"phase":client.phase,"status":client.status_message}):
		await finish()
		return
	host.start_match()
	if not check(await until(func(): return client.phase == "match" and client.match_id == host.match_id),"Initial match identity reaches client"):
		await finish()
		return
	host.sim.winner = 0
	host.sim.celebration_time = 0
	check(await publish(),"Finished match snapshot reaches client")
	for app in apps: app.update_hud(0)
	var first_id: String = host.match_id
	var slot: int = client.local_seat
	check(host.profile.data.bags == 1 and client.profile.data.bags == 1,"Both eligible peers receive first-match reward exactly once")
	var saved_before: int = client.saved_powers.size()
	choose_client_power("blast")
	check(client.saved_powers.size() == saved_before and "Sending" in client_power_status(),"Remote selection waits for host acknowledgement before saving")
	check(await until(func(): return host.powers.get(slot,"") == "blast"),"Client result choice reaches host through register_next_power RPC")
	check(await until(func(): return client.saved_powers.size() == saved_before+1 and "confirmed" in client_power_status()),"Accepted choice acknowledgement reaches client and saves once")
	check(client.selected_power == "blast" and client_dropdown_power() == "blast" and client.saved_powers.back() == "blast","Accepted choice agrees across client selection dropdown and saved setting")
	check(host.sim.players[slot].power == "pad","Result choice does not rewrite the completed round")
	host.runback_series()
	check(await until(func(): return client.match_id == host.match_id and client.match_id != first_id),"Runback broadcasts a unique round identity")
	check(await publish(),"Round-two series snapshot reaches client")
	check(client.state.get("series",{}).get("wins",{}) == {0:1,1:0} and client.state.series.active,"Client receives the opted-in first win")
	check(host.sim.players[slot].power == "blast" and client.state.players[slot].power == "blast","Next-round power agrees on both peers")
	host.sim.winner = 0
	host.sim.celebration_time = 0
	check(await publish(),"Second outcome reaches client")
	for app in apps: app.update_hud(0)
	var second_id: String = host.match_id
	client.register_next_power.rpc_id(1,"giant",first_id)
	# Reliable marker on the same channel proves the stale choice was processed.
	client.register_name.rpc_id(1,"StaleReceived")
	check(await until(func(): return host.names.get(slot,"") == "StaleReceived"),"Stale RPC delivery is confirmed by following reliable message")
	check(host.powers[slot] == "blast","Previous-round power choice is rejected even while current result is open")
	check(client.state.series.finished and client.state.series.wins == {0:2,1:0},"Client receives completed 2-0 series")
	check(await publish(),"Repeated outcome snapshot is delivered")
	for app in apps: app.update_hud(0)
	check(host.rivalry.recorded.size() == 2 and host.profile.data.bags == 2 and client.profile.data.bags == 2,"Repeated outcome snapshots cannot duplicate wins or rewards")
	check(first_id in client.profile.data.redeemed and second_id in client.profile.data.redeemed,"Client reward identities match both actual rounds")
	# Both requests travel over the real reliable channel without yielding. The
	# first acknowledgement arrives after the second choice is already selected.
	saved_before = client.saved_powers.size()
	choose_client_power("giant")
	choose_client_power("blast")
	check(await until(func(): return client.saved_powers.size() > saved_before and "confirmed" in client_power_status()),"Acknowledgements arrive after two rapid result choices")
	check(client.saved_powers.slice(saved_before) == ["blast"] and client.selected_power == "blast" and client_dropdown_power() == "blast" and host.powers[slot] == "blast","Older accepted acknowledgement cannot overwrite or persist over the newer selection",{"saved":client.saved_powers.slice(saved_before),"selected":client.selected_power})
	# Reproduce the real boundary race: queue the choice and start immediately,
	# before the host has polled that inbound RPC. The host must reject it and
	# the client must reconcile its dropdown and persisted choice to authority.
	saved_before = client.saved_powers.size()
	choose_client_power("giant")
	check(client.selected_power == "giant" and client.saved_powers.size() == saved_before,"Racing choice remains pending before host starts")
	host.runback_series()
	check(await until(func(): return client.match_id == host.match_id and client.match_id != second_id),"New series broadcasts another unique match identity")
	check(await until(func(): return client.saved_powers.size() == saved_before+1 and "Host already started" in client_power_status()),"Rejected racing choice receives an authoritative acknowledgement")
	check(host.powers[slot] == "blast" and host.sim.players[slot].power == "blast","Host retains the original power when the request arrives after round start")
	check(client.selected_power == "blast" and client_dropdown_power() == "blast" and client.saved_powers.back() == "blast","Rejected choice rolls back client selection dropdown and saved setting")
	check(await publish(),"New-series snapshot reaches client")
	check(client.state.series.active and client.state.series.wins == {0:0,1:0},"New series is zeroed on client")
	host.single_rematch()
	check(await until(func(): return client.match_id == host.match_id),"Single rematch reaches client")
	check(await publish(),"Single-rematch snapshot reaches client")
	check(not client.state.series.active and client.state.series.wins == {0:0,1:0},"Single rematch clears client-visible series")
	await host.close_session()
	check(await until(func(): return client.phase == "menu"),"Closing host session returns client to menu")
	check(not host.rivalry.active and not client.rivalry.active,"Both peers clear session series state")
	await finish()

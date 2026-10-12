extends SceneTree

const PORT = 28993
const Sim = preload("res://sim.gd")
var apps = []
var branches = []
var apis = []
var results = []
var profile_paths = []

func _initialize() -> void:
	run.call_deferred()

func wait_until(condition: Callable, seconds=4.0) -> bool:
	var start=Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec()-start<seconds*1000:
		await process_frame
	return condition.call()

func make_app(label: String, script: String):
	var branch=Node.new()
	branch.name=label
	root.add_child(branch)
	var api=SceneMultiplayer.new()
	api.root_path=branch.get_path()
	set_multiplayer(api,branch.get_path())
	var app=load(script).new()
	app.name="App"
	app.manual_input_enabled=false
	branch.add_child(app)
	app.muted=true
	app.nickname=label
	app.balance_teams=false
	var path="user://review_v3_%s_%d.json" % [label,Time.get_ticks_usec()]
	profile_paths.append(path)
	app.profile=load("res://profile.gd").new(path)
	apps.append(app)
	branches.append(branch)
	apis.append(api)
	return app

func place(sim, seat: int, at: Vector3, aim: Vector3) -> void:
	var p: Dictionary=sim.players[seat]
	at.y=Sim.floor_height(at.x,at.z)
	p.pos=at
	p.vel=Vector3.ZERO
	p.move=Vector3.ZERO
	p.aim=aim
	p.facing=aim
	p.grounded=true
	p.guard=0
	p.stun=0
	p.dive=0
	p.dunk=0
	p.cooldown=0
	p.jump_count=0
	sim.reset_movement_state(p)

func run() -> void:
	var host=make_app("ReviewHost","res://tests/review_v3_host.gd")
	var server_peer=ENetMultiplayerPeer.new()
	if server_peer.create_server(PORT,2,host.NETWORK_CHANNELS)!=OK:
		print("REVIEW_V3_NETWORK_SETUP_FAILED port")
		quit(2)
		return
	host.multiplayer.multiplayer_peer=server_peer
	host.selected_mode="teams"
	host.seats={1:1}
	host.show_lobby()
	for index in 2:
		var client=make_app("ReviewClient%d"%index,"res://tests/review_v3_client.gd")
		var peer=ENetMultiplayerPeer.new()
		peer.create_client("127.0.0.1",PORT,client.NETWORK_CHANNELS)
		client.multiplayer.multiplayer_peer=peer
		client.local_seat=0
		client.seats.clear()
		client.names.clear()
		client.phase="connecting"
		client.connect_time=client.ui_clock
	if not await wait_until(func(): return host.seats.size()==3 and apps[1].local_seat>0 and apps[2].local_seat>0):
		print("REVIEW_V3_NETWORK_SETUP_FAILED handshake")
		await finish(2)
		return
	host.team_choices={1:0,2:0,3:1}
	host.start_match()
	if not await wait_until(func(): return host.sim.reset_time<=0 and apps[1].phase=="match" and not apps[1].state.is_empty(),6):
		print("REVIEW_V3_NETWORK_SETUP_FAILED match")
		await finish(2)
		return
	var client=apps[1] if apps[1].local_seat==2 else apps[2]
	var sim=host.sim
	place(sim,1,Vector3(-12,0,12),Vector3.FORWARD)
	place(sim,2,Vector3.ZERO,Vector3.FORWARD)
	place(sim,3,Vector3(12,0,12),Vector3.FORWARD)
	client.submit_move(Vector3.FORWARD,Vector3.FORWARD)
	await wait_until(func(): return sim.players[2].move.z<-.9)
	# Drop the new movement packet while the reliable action arrives normally.
	host.drop_moves=true
	client.submit_move(Vector3.RIGHT,Vector3.RIGHT)
	client.submit_action("tackle")
	await wait_until(func(): return sim.players[2].dive>0)
	var velocity: Vector3=sim.players[2].vel
	await create_timer(.1).timeout
	results.append({"case":"tackle_before_delayed_turn_packet","pass":velocity.x>10 and absf(velocity.z)<3,"velocity":velocity,"requested_direction":client.local_direction,"dropped_moves":host.dropped_moves})
	host.drop_moves=false
	client.submit_move(Vector3.ZERO,Vector3.BACK)
	await create_timer(.6).timeout
	# Acquire and pass through actual actions and ball flight; suppress only the
	# receiver's snapshots during arrival to reproduce a stale Catch prompt.
	place(sim,1,Vector3.ZERO,Vector3.FORWARD)
	place(sim,2,Vector3(0,0,-7),Vector3.BACK)
	place(sim,3,Vector3(12,0,12),Vector3.FORWARD)
	sim.ball.owner=0
	sim.ball.pos=Vector3(0,1.2,-.5)
	sim.ball.vel=Vector3.ZERO
	sim.ball.lock=0
	host.submit_move(Vector3.ZERO,Vector3.FORWARD)
	host.submit_action("catch")
	await wait_until(func(): return sim.ball.owner==1 and not client.state.is_empty() and client.state.ball.owner==1)
	host.submit_action("pass")
	if not await wait_until(func(): return client.state.ball.owner==0):
		results.append({"case":"catch_pass_setup","pass":false,"reason":"no loose-ball snapshot"})
	else:
		client.drop_snapshots=true
		if not await wait_until(func(): return sim.ball.owner==2):
			results.append({"case":"catch_pass_setup","pass":false,"reason":"receiver did not catch actual pass"})
		else:
			var throws_before=sim.throws
			var stale_owner=client.state.ball.owner
			client.submit_action("catch_pass")
			await create_timer(.10).timeout
			results.append({"case":"stale_catch_intent_after_auto_pass_receive","pass":sim.throws==throws_before and sim.ball.owner==2,"client_owner_at_press":stale_owner,"throws_before":throws_before,"throws_after":sim.throws,"owner_after":sim.ball.owner,"dropped_snapshots":client.dropped_snapshots})
	client.drop_snapshots=false
	await create_timer(.1).timeout
	# Delay the reliable new-round notification past kickoff. The old client must
	# not be able to apply an old-round input to the fresh server simulation.
	var old_round=client.match_id
	client.drop_round_starts=true
	host.start_match()
	if not await wait_until(func(): return host.sim.reset_time<=0,5):
		results.append({"case":"old_round_input_setup","pass":false})
	else:
		var before_jumps=host.sim.players[2].jump_count
		client.submit_action("jump")
		await create_timer(.10).timeout
		results.append({"case":"old_round_action_after_delayed_begin","pass":host.sim.players[2].jump_count==before_jumps,"client_old_round":client.match_id==old_round,"server_new_round":host.match_id!=old_round,"dropped_round_starts":client.dropped_round_starts,"jumps_before":before_jumps,"jumps_after":host.sim.players[2].jump_count})
	print("REVIEW_V3_NETWORK "+JSON.stringify(results))
	var passed=true
	for item in results: passed=passed and bool(item.pass)
	await finish(0 if passed else 1)

func finish(code: int) -> void:
	for app in apps:
		app._closing=true
		app.set_process(false)
		app.set_physics_process(false)
	for api in apis:
		if api.multiplayer_peer: api.multiplayer_peer.close()
	for branch in branches: branch.queue_free()
	await process_frame
	for path in profile_paths:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	quit(code)

extends SceneTree
const Sim = preload("res://sim.gd")
var checks = 0
var failures = 0
func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+label)
func fresh():
	var s = Sim.new()
	s.reset("coop")
	s.reset_time = 0
	for id in s.players:
		s.players[id].pos = Vector3(25,0,30+id*2)
		s.players[id].vel = Vector3.ZERO
		s.players[id].guard = 0
	return s
func _initialize():
	# Launch a held ball from the exact carry pose, not a new torso origin.
	var s = fresh()
	s.players[1].pos = Vector3.ZERO
	s.players[4].pos = Vector3(0,0,-1.1)
	s.players[1].facing = Vector3.FORWARD
	s.secure_ball(4)
	var release: Vector3 = s.hand_position(4)
	s.hit(1,4)
	check(s.ball.owner==0 and s.ball.pos.distance_to(release)<.001,"Tackle releases from the actual hands")
	check(s.players[4].stun>0 and s.players[4].guard>s.players[4].stun,"Recovery remains protected")
	check(s.ball.lock>0 and s.ball.pass_target==0,"Dropped ball remains contested rather than auto-awarded")
	# A symmetric head-on dive must not select its winner from player IDs.
	for reverse in [false,true]:
		s = fresh()
		var a = 4 if reverse else 1
		var b = 1 if reverse else 4
		s.players[a].pos = Vector3(0,0,.55)
		s.players[b].pos = Vector3(0,0,-.55)
		s.players[a].move = Vector3.FORWARD
		s.players[b].move = Vector3.BACK
		s.action(a,"tackle")
		s.action(b,"tackle")
		s.resolve_players()
		check(s.players[a].stun>0 and s.players[b].stun>0,"Mutual contest is symmetric "+str(reverse))
		check(s.players[a].vel.z>0 and s.players[b].vel.z<0,"Clash separates both bodies "+str(reverse))
	# A dive past a player must not hit backwards with an invisible rear radius.
	s = fresh()
	s.players[1].pos = Vector3.ZERO
	s.players[4].pos = Vector3(0,0,1.1)
	s.players[1].move = Vector3.FORWARD
	s.action(1,"tackle")
	s.resolve_players()
	check(s.players[4].stun==0,"Facing away does not produce a rear tackle")
	# Ordinary contact exchanges momentum without stealing the ball.
	s = fresh()
	s.players[1].pos = Vector3.ZERO
	s.players[4].pos = Vector3(0,0,-.9)
	s.players[1].vel = Vector3(0,0,-9)
	s.secure_ball(4)
	s.resolve_players()
	check(s.players[4].vel.z<-.1 and s.players[1].vel.z> -9,"Body contact transfers momentum")
	check(s.ball.owner==4 and s.players[4].stun==0,"Bumping alone does not force a turnover")
	check(is_equal_approx(s.players[1].vel.z+s.players[4].vel.z,-9),"Equal-mass body contact conserves horizontal momentum")
	# Team contact cannot stun or strip possession.
	s = fresh()
	s.players[1].pos = Vector3.ZERO
	s.players[2].pos = Vector3(0,0,-1.1)
	s.secure_ball(2)
	s.players[1].move = Vector3.FORWARD
	s.action(1,"tackle")
	s.resolve_players()
	check(s.ball.owner==2 and s.players[2].stun==0,"Friendly tackles do not strip teammates")
	print("TACKLE_CONTACTS_RESULT ",checks," checks; ",failures," failures")
	quit(0 if failures==0 else 1)

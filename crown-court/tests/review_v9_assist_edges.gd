extends SceneTree
const Sim=preload("res://sim.gd")
var failures:=0
var checks:=0

func check(ok: bool,label: String,detail: Variant=null) -> void:
	checks+=1
	if not ok: failures+=1
	print("PASS " if ok else "FAIL ",label," ",detail if detail!=null else "")

func complete_pass():
	var g=Sim.new()
	g.reset("coop")
	g.reset_time=0
	g.ball.lock=0
	for id in g.players.keys():
		if id not in [1,2,4]:g.players.erase(id)
	for id in [1,2]:
		g.players[id].pos=Sim.NORTH+Vector3(0,-Sim.HOOP_Y,18 if id==1 else 9)
		g.players[id].pos.y=Sim.floor_height(g.players[id].pos.x,g.players[id].pos.z)
		g.players[id].aim=Vector3.FORWARD
		g.players[id].guard=0
	g.players[4].pos=Vector3(25,0,0)
	g.ball.owner=1
	g.action(1,"pass")
	for frame in 120:
		g.step(1.0/60)
		if g.ball.owner==2:break
	return g

func _initialize() -> void:
	var g=complete_pass()
	check(g.ball.owner==2 and g.assist_player==1,"Actual pass establishes assist candidate")
	for frame in 481:g.step(1.0/60)
	g.action(2,"throw",preload("res://tests/shot_fixture.gd").aimed_charge(g,2))
	for frame in 240:
		g.step(1.0/60)
		if g.baskets>0:break
	check(g.baskets==1 and g.players[1].hype==10,"Expired assist cannot award stale credit after a physical score",[g.baskets,g.players[1].hype])
	g=complete_pass()
	g.players[4].pos=g.players[2].pos+Vector3.BACK
	g.players[4].facing=Vector3.FORWARD
	g.hit(4,2)
	check(g.ball.owner==0 and g.assist_player==0,"Carrier tackle clears pending assist before loose-ball recovery")
	g=Sim.new()
	g.reset("coop")
	g.reset_time=0
	g.ball.lock=0
	g.players={4:g.players[4],5:g.players[5],6:g.players[6]}
	g.players[5].pos=Vector3(25,0,0)
	for id in [4,6]:
		g.players[id].pos=Sim.SOUTH+Vector3(0,-Sim.HOOP_Y,-9 if id==4 else -18)
		g.players[id].pos.y=Sim.floor_height(g.players[id].pos.x,g.players[id].pos.z)
		g.players[id].aim=Vector3.BACK
	g.ball.owner=6
	g.action(6,"pass")
	for frame in 120:
		g.step(1.0/60)
		if g.ball.owner==4:break
	var joined: bool=g.add_human(3,1)
	check(joined and g.ball.owner==4 and g.assist_player==3 and not g.players.has(6),"Replacing the actual passer bot remaps the pending assist identity")
	g.action(4,"throw",preload("res://tests/shot_fixture.gd").aimed_charge(g,4))
	for frame in 240:
		g.step(1.0/60)
		if g.baskets>0:break
	check(g.scores[1]==1 and g.players[3].hype==30,"Remapped assist rewards the same-side replacement once after physical score",[g.scores,g.players[3].hype])
	g.reset("coop")
	check(g.assist_player==0 and g.assist_receiver==0 and g.assist_until==0,"New round clears all assist identity and expiry state")
	# A deliberate free lob into the shooter's own basket remains an opponent
	# point. It must not reward the shooter as if they scored for their team.
	g=Sim.new()
	g.reset("coop")
	g.reset_time=0
	g.ball.lock=0
	g.players={1:g.players[1]}
	g.players[1].pos=Sim.SOUTH+Vector3(0,-Sim.HOOP_Y,-9)
	g.players[1].pos.y=Sim.floor_height(g.players[1].pos.x,g.players[1].pos.z)
	g.players[1].aim=Vector3.BACK
	g.ball.owner=1
	var distance: float=Sim.SOUTH.z-g.hand_position(1).z
	var charge: float=preload("res://tests/shot_fixture.gd").aimed_charge(g,1,0,Sim.SOUTH)
	g.action(1,"throw",charge)
	for frame in 300:
		g.step(1.0/60)
		if g.baskets>0:break
	check(g.scores[1]==1 and g.scores[0]==0,"Physical own basket credits the opponent",g.scores)
	check(g.players[1].hype==0,"Own basket cannot generate scorer Hype",g.players[1].hype)
	print("ASSIST_EDGES_RESULT checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)

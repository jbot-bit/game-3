extends RefCounted
## Original block fishermen: big heads, bold jackets, readable faces and silhouettes.
const Art=preload("res://game/world/block_art.gd")
const SKIN: Color=Color("ffc59b")
const INK: Color=Color("182d48")
const WHITE: Color=Color("f7fcff")
const PIVOTS: Dictionary={"Torso":Vector3(0,1.015,0),"Head":Vector3(0,1.70,0),"LeftArm":Vector3(-0.60,1.34,0),"RightArm":Vector3(0.60,1.34,0),"LeftLeg":Vector3(-0.23,0.64,0),"RightLeg":Vector3(0.23,0.64,0)}

static func build(root: Node3D) -> void:
	for key: String in PIVOTS:
		var part: Node3D=Node3D.new()
		part.name=key
		part.position=PIVOTS[key]
		root.add_child(part)
	var tool: Node3D=Node3D.new()
	tool.name="HeldTool"
	tool.position=Vector3(0,-0.53,-0.035)
	root.get_node("RightArm").add_child(tool)

static func dress(root: Node3D, outfit: String, identity: Color) -> void:
	# The jacket carries player identity across every outfit and viewing angle.
	var coat: Color=Color.from_hsv(identity.h,maxf(identity.s,0.72),0.94)
	var trim: Color=WHITE
	if outfit=="stormwatch": trim=Color("ffe46a")
	for key: String in PIVOTS:
		var part: Node3D=root.get_node(key)
		for child: Node in part.get_children():
			if child.name!="HeldTool": child.free()
	var torso: Node3D=root.get_node("Torso")
	piece(torso,"Coat",Vector3.ZERO,Vector3(0.89,0.68,0.51),coat)
	piece(torso,"Hem",Vector3(0,-0.305,0),Vector3(0.90,0.075,0.525),INK)
	piece(torso,"CrewScarf",Vector3(0,0.30,0),Vector3(0.57,0.13,0.54),identity)
	piece(torso,"CollarLeft",Vector3(-0.19,0.285,-0.26),Vector3(0.22,0.14,0.075),trim)
	piece(torso,"CollarRight",Vector3(0.19,0.285,-0.26),Vector3(0.22,0.14,0.075),trim)
	piece(torso,"Shirt",Vector3(0,0.15,-0.267),Vector3(0.17,0.30,0.025),INK)
	piece(torso,"Zip",Vector3(0,-0.14,-0.27),Vector3(0.035,0.26,0.035),WHITE)
	piece(torso,"ChestBand",Vector3(0,0.05,-0.266),Vector3(0.88,0.09,0.035),trim)
	piece(torso,"BackBand",Vector3(0,0.18,0.267),Vector3(0.88,0.10,0.035),trim)
	# A large fish emblem reads from the game's normal rear camera.
	piece(torso,"CrewEmblem",Vector3(-0.04,-0.055,0.272),Vector3(0.27,0.13,0.035),WHITE)
	var tail: MeshInstance3D=piece(torso,"EmblemTail",Vector3(0.145,-0.055,0.275),Vector3(0.12,0.12,0.035),WHITE)
	tail.rotation.z=PI*0.25
	piece(torso,"EmblemEye",Vector3(-0.115,-0.04,0.294),Vector3(0.035,0.035,0.012),INK)
	# A small side bag leaves the coloured jacket back unobstructed.
	piece(torso,"SlingPack",Vector3(0.38,-0.12,0.32),Vector3(0.25,0.32,0.23),INK)
	piece(torso,"SlingFlap",Vector3(0.38,0.005,0.34),Vector3(0.27,0.08,0.24),coat.darkened(0.22))
	piece(torso,"SlingClasp",Vector3(0.38,-0.055,0.455),Vector3(0.08,0.09,0.025),trim)
	if outfit=="angler":
		piece(torso,"VestLeft",Vector3(-0.29,-0.125,-0.30),Vector3(0.23,0.20,0.085),WHITE)
		piece(torso,"VestRight",Vector3(0.29,-0.125,-0.30),Vector3(0.23,0.20,0.085),WHITE)
	var head: Node3D=root.get_node("Head")
	piece(head,"Face",Vector3.ZERO,Vector3(0.83,0.72,0.71),SKIN)
	piece(head,"HairBack",Vector3(0,0.07,0.355),Vector3(0.845,0.50,0.06),INK)
	for side: int in [-1,1]:
		piece(head,"Eye%s"%side,Vector3(side*0.175,0.015,-0.366),Vector3(0.075,0.105,0.025),INK)
		piece(head,"Brow%s"%side,Vector3(side*0.175,0.13,-0.368),Vector3(0.14,0.036,0.022),INK)
		piece(head,"Ear%s"%side,Vector3(side*0.432,-0.02,0.015),Vector3(0.075,0.17,0.20),SKIN)
		piece(head,"SideHair%s"%side,Vector3(side*0.421,0.12,0.16),Vector3(0.035,0.30,0.32),INK)
	piece(head,"Smile",Vector3(0,-0.145,-0.372),Vector3(0.15,0.045,0.025),INK)
	piece(head,"SmileLeft",Vector3(-0.09,-0.12,-0.372),Vector3(0.035,0.045,0.025),INK)
	piece(head,"SmileRight",Vector3(0.09,-0.12,-0.372),Vector3(0.035,0.045,0.025),INK)
	match outfit:
		"angler":
			piece(head,"HatBrim",Vector3(0,0.305,-0.02),Vector3(1.03,0.09,0.93),WHITE)
			piece(head,"HatCrown",Vector3(0,0.43,0.01),Vector3(0.75,0.22,0.68),coat)
			piece(head,"HatBand",Vector3(0,0.35,0.01),Vector3(0.77,0.075,0.70),INK)
		"deckhand":
			piece(head,"Beanie",Vector3(0,0.325,0.02),Vector3(0.87,0.24,0.76),coat)
			piece(head,"BeanieBand",Vector3(0,0.24,0),Vector3(0.90,0.105,0.79),WHITE)
			piece(head,"BeaniePatch",Vector3(0,0.27,-0.407),Vector3(0.18,0.14,0.035),INK)
		"stormwatch":
			piece(head,"Hood",Vector3(0,0.305,0.04),Vector3(0.89,0.29,0.81),coat)
			piece(head,"HatBrim",Vector3(0,0.235,-0.27),Vector3(0.94,0.065,0.58),trim)
			piece(head,"HatBadge",Vector3(0,0.34,-0.38),Vector3(0.17,0.14,0.04),WHITE)
		_:
			piece(head,"Cap",Vector3(0,0.33,0.04),Vector3(0.88,0.26,0.77),coat)
			piece(head,"CapBand",Vector3(0,0.24,0.015),Vector3(0.90,0.07,0.79),INK)
			piece(head,"CapBrim",Vector3(0,0.225,-0.33),Vector3(0.91,0.065,0.42),WHITE)
			piece(head,"CapBadge",Vector3(0,0.34,-0.36),Vector3(0.18,0.14,0.035),WHITE)
	for key: String in ["LeftArm","RightArm"]:
		var arm: Node3D=root.get_node(key)
		piece(arm,"Sleeve",Vector3(0,-0.18,0),Vector3(0.36,0.48,0.43),coat)
		piece(arm,"Cuff",Vector3(0,-0.39,0),Vector3(0.37,0.09,0.44),trim)
		piece(arm,"Hand",Vector3(0,-0.525,0),Vector3(0.33,0.21,0.38),INK)
	for key: String in ["LeftLeg","RightLeg"]:
		var leg: Node3D=root.get_node(key)
		piece(leg,"Trouser",Vector3(0,-0.23,0),Vector3(0.36,0.47,0.38),Color("304a6d"))
		piece(leg,"Boot",Vector3(0,-0.505,-0.055),Vector3(0.40,0.24,0.48),INK)
		piece(leg,"Sole",Vector3(0,-0.62,-0.055),Vector3(0.42,0.05,0.50),Color("203854"))

static func piece(parent: Node3D, part_name: String, offset: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh: MeshInstance3D=Art.box(parent,offset,size,color)
	mesh.name=part_name
	return mesh

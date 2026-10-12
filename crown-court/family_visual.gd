extends RefCounted
## Identity is a cosmetic child of the existing rig; no simulation parameters.
const IDS := ["evie", "tyler", "dad"]
const SKIN := {"evie": Color("f2be9f"), "tyler": Color("f2be9f"), "dad": Color("f2be9f")}
const SHIRT := {"evie": Color("303443"), "tyler": Color("eee9dc"), "dad": Color("263341")}

static func apply(actor: Dictionary, character: String, outfit: String, accessory: String, headgear: Node3D) -> void:
	if not IDS.has(character): character = "blank"
	var family := character != "blank"
	actor["face"].visible = not family
	actor["body"].visible = not family
	setup_limbs(actor, family, character)
	if str(actor.get("character", "")) != character:
		if is_instance_valid(actor.get("identity")):
			actor["identity"].get_parent().remove_child(actor["identity"])
			actor["identity"].queue_free()
		actor["identity"] = null
		actor["character"] = character
		if family:
			var scene := load("res://assets/characters/%s.glb" % character) as PackedScene
			var identity := scene.instantiate() as Node3D
			identity.name = "FamilyIdentity"
			identity.position.z = 0.0
			actor["rig"].add_child(identity)
			actor["identity"] = identity
	actor["label"].position.y = 2.65 if family else 2.15
	if not family: return
	var skin := StandardMaterial3D.new()
	skin.albedo_color = SKIN[character]
	skin.roughness = .55
	for key in ["left_hand", "right_hand", "left_arm", "right_arm"]:
		actor[key].material_override = skin
	if outfit == "blank":
		var shirt := StandardMaterial3D.new()
		shirt.albedo_color = SHIRT[character]
		shirt.roughness = .75
		actor["body"].material_override = shirt
	for node in actor["identity"].find_children("Torso*", "MeshInstance3D", true, false):
		node.material_override = null if outfit == "blank" else actor["body"].material_override
	for node in actor["identity"].find_children("ShirtTrim*", "MeshInstance3D", true, false):
		node.material_override = null if outfit == "blank" else actor["body"].material_override
	for key in ["left_arm", "right_arm"]:
		var sleeve = actor[key].get_node_or_null("FamilySleeve")
		if sleeve:
			sleeve.visible = character != "dad" or outfit != "blank"
			sleeve.material_override = actor["body"].material_override
	for node in actor["identity"].find_children("HairTop*", "MeshInstance3D", true, false):
		node.visible = accessory != "cap"
	for node in actor["identity"].find_children("HairFront*", "MeshInstance3D", true, false):
		node.scale.y = .70 if accessory == "cap" else 1.0
		node.position.y = .51 if accessory == "cap" else 0.0
	match accessory:
		"cap":
			headgear.scale = Vector3.ONE
			headgear.position = Vector3.ZERO
		"sweatband":
			headgear.scale.x = 1.09
			headgear.position.y = .37
			headgear.position.z = 0.0
		"shades":
			headgear.position = Vector3(0,.46,.13)
		"headphones":
			headgear.scale = Vector3(1.12,1.1,1.08)
			headgear.position.y = .22
		"horns": headgear.position.y = .35
		"crown": headgear.position.y = .41

static func part(parent: Node3D, name: String, position: Vector3, size: Vector3, color: Color, box: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	if box:
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		node.mesh = mesh
	else:
		var mesh := SphereMesh.new()
		mesh.radius = .5
		mesh.height = 1.0
		node.mesh = mesh
	node.position = position
	node.scale = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .78
	node.material_override = material
	parent.add_child(node)
	return node

static func setup_limbs(actor: Dictionary, family: bool, character: String) -> void:
	for side in [-1,1]:
		var hand: MeshInstance3D = actor["left_hand" if side < 0 else "right_hand"]
		var arm: MeshInstance3D = actor["left_arm" if side < 0 else "right_arm"]
		var foot: MeshInstance3D = actor["left_foot" if side < 0 else "right_foot"]
		if not hand.has_meta("bean_mesh"):
			hand.set_meta("bean_mesh", hand.mesh)
			foot.set_meta("bean_mesh", foot.mesh)
		if not family:
			hand.mesh = hand.get_meta("bean_mesh")
			foot.mesh = foot.get_meta("bean_mesh")
			for parent in [hand,arm,foot]:
				for node in parent.get_children():
					if str(node.name).begins_with("Family"): node.hide()
					else: node.show()
			continue
		var mitten := CapsuleMesh.new()
		mitten.radius = .55
		mitten.height = 1.40
		hand.mesh = mitten
		foot.mesh = null
		for node in foot.get_children(): node.hide()
		for parent in [hand,arm,foot]:
			for node in parent.get_children():
				if str(node.name).begins_with("Family"):
					parent.remove_child(node)
					node.queue_free()
		part(hand,"FamilyThumb",Vector3(-side*.43,-.11,-.45),Vector3(.48,.57,.50),SKIN[character])
		var sleeve := part(arm,"FamilySleeve",Vector3(0,.12,0),Vector3.ONE,SHIRT[character])
		var sleeve_mesh := CapsuleMesh.new()
		sleeve_mesh.radius = .17
		sleeve_mesh.height = .35
		sleeve.mesh = sleeve_mesh
		var shoe_color: Color = Color("e7e3dc") if character == "tyler" else Color("272e3a")
		part(foot,"FamilySole",Vector3(0,-.29,-.08),Vector3(1.08,.29,1.22),Color("e8e2d8"))
		part(foot,"FamilyShoe",Vector3(0,.03,-.08),Vector3(1.02,.85,1.19),shoe_color)
		part(foot,"FamilyToe",Vector3(0,-.04,-.37),Vector3(.96,.57,.65),shoe_color.lightened(.1))
		for n in 3:
			part(foot,"FamilyLace%d" % n,Vector3(0,.48,-.33+n*.17),Vector3(.60,.075,.07),Color("eee9e0"),true)

extends RefCounted
## Soft decorative pieces, attached only to the displayed head skeleton.
const IDS: Array[String] = ["none", "cap", "beanie", "sprout", "headphones", "crown", "halo"]

static func valid_id(value: Variant) -> String:
	return value if value is String and value in IDS else "none"

static func build(skeleton: Skeleton3D, id: String) -> BoneAttachment3D:
	if valid_id(id) == "none" or skeleton.find_bone("Head") < 0: return null
	var attachment := BoneAttachment3D.new()
	attachment.name = "PartyAccessory"
	attachment.bone_name = "Head"
	skeleton.add_child(attachment)
	# The imported Head origin is at the neck, 1.13 m below its skin's top.
	match id:
		"cap":
			_ball(attachment, "SoftCap", Vector3(0, 1.03, 0), Vector3(0.52, 0.32, 0.52), Color("b8c9ee"))
			_ball(attachment, "RoundedBrim", Vector3(0, 0.9, 0.43), Vector3(0.48, 0.055, 0.32), Color("9faedd"))
			_ball(attachment, "TopButton", Vector3(0, 1.34, 0), Vector3.ONE * 0.065, Color("e4dbf5"))
		"beanie":
			_ball(attachment, "KnitDome", Vector3(0, 1.07, 0), Vector3(0.51, 0.32, 0.51), Color("f2b6cd"))
			_ring(attachment, "FoldedCuff", Vector3(0, 0.89, 0), 0.46, 0.07, Color("d993b2"))
			_ball(attachment, "PomPom", Vector3(0, 1.45, 0), Vector3.ONE * 0.13, Color("f9d4df"))
		"sprout":
			_segment(attachment, "Stem", Vector3(0, 1.09, 0), Vector3(0, 1.4, 0), 0.05, Color("80c795"))
			var left := _ball(attachment, "LeafLeft", Vector3(-0.18, 1.4, 0), Vector3(0.25, 0.075, 0.14), Color("a9dfa3"))
			left.rotation.z = -0.3
			var right := _ball(attachment, "LeafRight", Vector3(0.18, 1.45, 0), Vector3(0.25, 0.075, 0.14), Color("8bcdab"))
			right.rotation.z = 0.3
		"headphones":
			for index in 12:
				var a: float = -PI / 2.0 + PI * float(index) / 12.0
				var b: float = -PI / 2.0 + PI * float(index + 1) / 12.0
				_segment(attachment, "PaddedBand" + str(index), Vector3(sin(a) * 0.55, 0.58 + cos(a) * 0.64, 0), Vector3(sin(b) * 0.55, 0.58 + cos(b) * 0.64, 0), 0.065, Color("c5bee8"))
			for side in [-1, 1]:
				_ball(attachment, "EarCushion" + str(side), Vector3(side * 0.55, 0.59, 0), Vector3(0.115, 0.23, 0.23), Color("9f95cb"))
				_ball(attachment, "EarPad" + str(side), Vector3(side * 0.63, 0.59, 0), Vector3(0.07, 0.17, 0.17), Color("e3dbf5"))
		"crown":
			_ring(attachment, "SoftGoldBand", Vector3(0, 1.02, 0), 0.45, 0.065, Color("e6c36f"))
			for index in 5:
				var angle: float = TAU * float(index) / 5.0
				var base := Vector3(sin(angle) * 0.45, 1.03, cos(angle) * 0.45)
				var tip: Vector3 = base + Vector3(0, 0.27, 0)
				_segment(attachment, "RoundedPoint" + str(index), base, tip, 0.075, Color("f2d891"))
				_ball(attachment, "CrownTip" + str(index), tip, Vector3.ONE * 0.085, Color("fae5a5"))
		"halo":
			_ring(attachment, "FloatingHalo", Vector3(0, 1.47, 0), 0.53, 0.055, Color("f6dfa3"))
	return attachment

static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	return material

static func _ball(parent: Node3D, label: String, center: Vector3, radii: Vector3, color: Color) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = 1.0
	shape.height = 2.0
	shape.radial_segments = 16
	shape.rings = 8
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = shape
	mesh.material_override = _material(color)
	mesh.position = center
	mesh.scale = radii
	parent.add_child(mesh)
	return mesh

static func _segment(parent: Node3D, label: String, start: Vector3, end: Vector3, radius: float, color: Color) -> void:
	var shape := CapsuleMesh.new()
	shape.radius = radius
	shape.height = start.distance_to(end) + radius * 2.0
	shape.radial_segments = 12
	shape.rings = 4
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = shape
	mesh.material_override = _material(color)
	mesh.position = (start + end) * 0.5
	mesh.basis = Basis(Quaternion(Vector3.UP, (end - start).normalized()))
	parent.add_child(mesh)

static func _ring(parent: Node3D, label: String, center: Vector3, radius: float, thickness: float, color: Color) -> void:
	for index in 16:
		var a: float = TAU * float(index) / 16.0
		var b: float = TAU * float(index + 1) / 16.0
		_segment(parent, label + str(index), center + Vector3(sin(a), 0, cos(a)) * radius, center + Vector3(sin(b), 0, cos(b)) * radius, thickness, color)

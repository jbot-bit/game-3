extends SceneTree
## Real host/remote puppets; headless checks do not claim rendered visual approval.
const PuppetScene = preload("res://prototypes/physics_party/puppet.tscn")
var checks: int = 0
var failures: Array[String] = []
var host: Node3D
var remote: Node3D

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok: failures.append(detail)

func _attachments(actor: Node3D) -> Array[Node]:
	return actor._render_skel.find_children("PartyAccessory", "BoneAttachment3D", false, false)

func _skin(actor: Node3D) -> MeshInstance3D:
	return actor._render_skel.get_node("Character")

func _signature(attachment: Node) -> String:
	var parts: Array = []
	for mesh: MeshInstance3D in attachment.find_children("*", "MeshInstance3D", true, false):
		parts.append([mesh.name, mesh.transform, mesh.mesh.get_class(), mesh.mesh.get_aabb(), mesh.material_override.albedo_color])
	return str(parts)

func _run() -> void:
	host = PuppetScene.instantiate()
	remote = PuppetScene.instantiate()
	remote.authoritative = false
	root.add_child(host)
	root.add_child(remote)
	_check(host.has_method("set_appearance"), "Puppet exposes set_appearance(style)")
	if not host.has_method("set_appearance"):
		await _finish()
		return
	var base_mesh: Mesh = _skin(host).mesh
	var base_skin: Skin = _skin(host).skin
	var body_ids: Array = []
	var masses: Array = []
	for bone: PhysicalBone3D in host.physics_bones:
		body_ids.append(bone.get_instance_id())
		masses.append(bone.mass)
	_check(_attachments(host).is_empty() and _attachments(remote).is_empty(), "Bare none is the default on host and remote")
	_check(_skin(host).visible and base_skin != null and base_mesh.get_surface_count() == 1, "Continuous skinned base remains visible")
	var signatures: Array[String] = []
	# Eight look changes include removing and re-equipping an accessory.
	for id: String in ["cap", "beanie", "sprout", "headphones", "crown", "halo", "none", "cap"]:
		host.set_appearance({"color": "mint", "accessory": id})
		remote.set_appearance({"color": "mint", "accessory": id})
		await process_frame
		_check(_skin(host).material_override.albedo_color.is_equal_approx(Color("43d6cf")), id + ": catalog tint applied")
		_check(_skin(host).mesh == base_mesh and _skin(host).skin == base_skin, id + ": original skin and mesh retained")
		var a := _attachments(host)
		var b := _attachments(remote)
		_check(a.size() == (0 if id == "none" else 1) and b.size() == a.size(), id + ": exactly the selected attachment")
		if id == "none" or a.is_empty() or b.is_empty(): continue
		_check(a[0].bone_name == "Head" and not a[0].override_pose, id + ": follows rendered head without overriding bones")
		var signature := _signature(a[0])
		_check(not signature.is_empty() and signature == _signature(b[0]), id + ": host and remote have identical geometry and colors")
		if signatures.size() < 6:
			_check(not signature in signatures, id + ": visibly distinct geometry")
			signatures.append(signature)
		_check(a[0].find_children("*", "CollisionObject3D", true, false).is_empty(), id + ": purely decorative")
		for part: MeshInstance3D in a[0].find_children("*", "MeshInstance3D", true, false):
			_check(part.material_override.roughness >= 0.65 and part.global_transform.is_finite(), id + ": matte finite mesh")
	var retained: Node = _attachments(host)[0]
	var material: Material = _skin(host).material_override
	for index in 20: host.set_appearance({"color": "mint", "accessory": "cap"})
	_check(_attachments(host)[0] == retained and _skin(host).material_override == material, "Repeated snapshots reuse attachment and tint material")
	host.set_appearance({"color": "rose", "accessory": "cap"})
	_check(_attachments(host)[0] == retained and _skin(host).material_override.albedo_color.is_equal_approx(Color("ee85a2")), "Color-only change retains accessory")
	var old: WeakRef = weakref(retained)
	host.set_appearance({"color": "blue", "accessory": "halo"})
	await process_frame
	_check(old.get_ref() == null and _attachments(host).size() == 1, "Replacing accessories frees the old attachment")
	host.setup_color(Color("ffaa55"))
	_check(_skin(host).material_override.albedo_color.is_equal_approx(Color("ffaa55")), "Legacy setup_color still recolors body")
	host.set_appearance({"color": "blue", "accessory": "halo"})
	_check(_skin(host).material_override.albedo_color.is_equal_approx(Color("4dabf7")), "Appearance restores tint after legacy recoloring")
	for invalid: Variant in ["not-a-hat", ["cap"], 7, null]:
		host.set_appearance({"color": "bogus", "accessory": invalid})
		_check(_attachments(host).is_empty() and _skin(host).material_override.albedo_color.is_equal_approx(Color("ff9c44")), "Malformed style falls back safely")
	host.set_appearance({"color": "lilac", "accessory": "sprout"})
	host.reset_at(Vector3(4, 8, 2))
	var pose: Array = host.capture_pose()
	remote.set_appearance({"color": "lilac", "accessory": "sprout"})
	remote.present_pose(pose)
	await process_frame
	_check(pose.size() == 10 and host.physics_bones.size() == 10 and remote.physics_bones.size() == 10, "Appearance retains ten-body pose protocol")
	for index in 10:
		_check(host.physics_bones[index].get_instance_id() == body_ids[index] and host.physics_bones[index].mass == masses[index], "Appearance preserves physical bone " + str(index))
	for actor: Node3D in [host, remote]:
		var attachment: BoneAttachment3D = _attachments(actor)[0]
		var head: int = actor._render_skel.find_bone("Head")
		var target: Transform3D = actor._render_skel.global_transform * actor._render_skel.get_bone_global_pose(head)
		_check(attachment.global_transform.is_finite() and attachment.global_transform.origin.distance_to(target.origin) < 0.001, "Accessory follows displayed head after reset/remote pose")
		_check(actor.find_children("*Eye*", "", true, false).is_empty() and actor.find_children("*Face*", "", true, false).is_empty(), "Base remains faceless")
	var early: Node3D = PuppetScene.instantiate()
	early.authoritative = false
	early.set_appearance({"color": "cream", "accessory": "beanie"})
	root.add_child(early)
	_check(_attachments(early).size() == 1 and _skin(early).material_override.albedo_color.is_equal_approx(Color("eee8dc")), "Appearance set before ready is retained")
	early.queue_free()
	await _finish()

func _finish() -> void:
	var report := {"checks": checks, "passed": checks - failures.size(), "failures": failures, "renderer": DisplayServer.get_name(), "limits": "Real host and remote puppet scene; headless structural/physics checks, not a visual approval or multiplayer transport test."}
	var file := FileAccess.open("res://logs/cosmetic-probe.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("COSMETIC_PROBE " + JSON.stringify(report))
	host.queue_free()
	remote.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

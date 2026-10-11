extends RefCounted
## Merge decorative siblings once at construction, never across moving parents.
## Physics bodies, labels and independently animated nodes keep their identity.
static func merge_children(parent: Node3D) -> void:
	var groups: Dictionary = {}
	for child: Node in parent.get_children():
		if not child is MeshInstance3D or child.mesh == null or child.material_override == null: continue
		if child.mesh.get_surface_count() != 1 or not child.visible: continue
		var key: String = str(child.material_override.get_instance_id()) + ":" + str(child.cast_shadow)
		if not groups.has(key): groups[key] = []
		groups[key].append(child)
	for members: Array in groups.values():
		if members.size() < 2: continue
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: MeshInstance3D in members:
			builder.append_from(part.mesh, 0, part.transform)
		var merged := MeshInstance3D.new()
		merged.name = "BatchedDetail"
		merged.mesh = builder.commit()
		merged.material_override = members[0].material_override
		merged.cast_shadow = members[0].cast_shadow
		parent.add_child(merged)
		for part: MeshInstance3D in members:
			parent.remove_child(part)
			part.free()

static func merge_tree(parent: Node3D) -> void:
	for child: Node in parent.get_children():
		if child is Node3D and not child is MeshInstance3D: merge_tree(child)
	merge_children(parent)

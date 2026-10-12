extends Node3D
## Original procedural arena presentation. All collision and scoring live in sim.gd.

const SKY := Color("9bdceb")
const NAVY := Color("162f50")
const TEAL := Color("27becb")
const GOLD := Color("ffd35d")
const CORAL := Color("ff725c")
const CREAM := Color("fff4d4")
const PALETTE := [Color("3dd5db"), Color("a68bff"), Color("ffd35d"), Color("ff7960"), Color("f894bc"), Color("f09f4d")]
const Simulation = preload("res://sim.gd")
const ArenaLayout = preload("res://arena_layout.gd")
const FamilyVisual = preload("res://family_visual.gd")
const BLUE := Color("20a9df")
const ORANGE := Color("f79b35")
const TURF := Color("229e56")

var camera: Camera3D
var arena: Node3D
var actor_root: Node3D
var effect_root: Node3D
var actors: Dictionary = {}
var ball_root: Node3D
var ball_shadow: MeshInstance3D
var hoop_lights: Array[MeshInstance3D] = []
var mode := "coop"
var clock_time := 0.0
var last_event := -1
var camera_target := Vector3.ZERO
var camera_ready := false
var camera_seat := -1
var effects: Array[Dictionary] = []
var score_flash := 0.0
var built := false
var material_cache: Dictionary = {}
var preview_dots: Array[MeshInstance3D] = []
var occluders: Array[Dictionary] = []
var floor_marks: Dictionary = {}
var shared_sphere: SphereMesh
var floor_model = Simulation.new()
var sim_constants: Dictionary = (load("res://sim.gd") as GDScript).get_script_constant_map()
var impact_shake := 0.0
var local_player_id := 0
var temporary_pads: Dictionary = {}
var power_orbs: Dictionary = {}
var aim_good_material: StandardMaterial3D
var aim_bad_material: StandardMaterial3D
var booster_visuals: Array[Dictionary] = []
var goal_beacons: Array[Dictionary] = []
var camera_distance := 7.8
var booster_team := -999
var previous_ball_owner := 0
var carry_ball_offset := Vector3.ZERO
var release_ball_offset := Vector3.ZERO
var previous_ball_input := Vector3.ZERO
var release_input_time := 0.0
var ball_presented := false
var catch_context_valid := false
var pass_trail: MeshInstance3D
var pass_trail_mesh: ImmediateMesh
var pass_history: Array[Vector3] = []
var pass_sample_clock := 0.0
var court_texture: ImageTexture
var hazard_visuals: Array[Dictionary] = []

func _dimension(key: String, fallback: float) -> float:
	return float(sim_constants.get(key, fallback))

func _floor_height(x: float, z: float) -> float:
	return ArenaLayout.floor_height(x,z)

func _ground(at: Vector3, lift: float = 0.0) -> Vector3:
	return Vector3(at.x, Simulation.surface_height(at,at.y) + lift, at.z)

func _floor_normal(x: float, z: float) -> Vector3:
	return ArenaLayout.floor_normal(x,z)

func build(new_mode: String) -> void:
	mode = new_mode
	if built:
		for id in actors:
			var actor: Dictionary = actors[id]
			_update_team_material(actor, int(id))
		return
	built = true
	arena = Node3D.new()
	arena.name = "FestivalArena"
	add_child(arena)
	actor_root = Node3D.new()
	actor_root.name = "Players"
	add_child(actor_root)
	effect_root = Node3D.new()
	effect_root.name = "CourtEffects"
	add_child(effect_root)
	_build_lighting()
	_build_court()
	_build_hazards()
	_finish_floor_marks()
	_build_hoop(-1)
	_build_hoop(1)
	_build_kickoff_deck(-1)
	_build_kickoff_deck(1)
	_build_stands()
	_build_ball()
	pass_trail_mesh = ImmediateMesh.new()
	var trail_material := StandardMaterial3D.new()
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.vertex_color_use_as_albedo = true
	trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	pass_trail = _mesh(effect_root,pass_trail_mesh,Vector3.ZERO,trail_material)
	pass_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aim_good_material = _mat(Color("6df069")).duplicate() as StandardMaterial3D
	aim_good_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aim_bad_material = _mat(Color("ff5268")).duplicate() as StandardMaterial3D
	aim_bad_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 36:
		var dot := _sphere(self, Vector3.ZERO, Vector3.ONE * .15, CREAM)
		dot.material_override = aim_good_material
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dot.visible = false
		preview_dots.append(dot)
	camera = Camera3D.new()
	camera.name = "FollowCamera"
	camera.fov = 72.0
	camera.near = 0.12
	camera.far = 260.0
	camera.current = true
	add_child(camera)
	camera.position = _overview_position()
	camera.look_at(Vector3(0, 0.8, 0))

func _mat(color: Color, roughness: float = 0.65, metallic: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var key := "%s_%s_%s_%s" % [color.to_html(), roughness, metallic, glow]
	if material_cache.has(key):
		return material_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_cache[key] = material
	return material

func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance

func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color, roughness: float = 0.65) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return _mesh(parent, shape, at, _mat(color, roughness))

func _sphere(parent: Node3D, at: Vector3, size: Vector3, color: Color, roughness: float = 0.55) -> MeshInstance3D:
	if shared_sphere == null:
		shared_sphere = SphereMesh.new()
		shared_sphere.radius = 0.5
		shared_sphere.height = 1.0
		shared_sphere.radial_segments = 24
		shared_sphere.rings = 12
	var instance := _mesh(parent, shared_sphere, at, _mat(color, roughness))
	instance.scale = size
	return instance

func _capsule(parent: Node3D, at: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var shape := CapsuleMesh.new()
	shape.radius = radius
	shape.height = height
	shape.radial_segments = 24
	shape.rings = 8
	return _mesh(parent, shape, at, _mat(color, 0.38))

func _rod(parent: Node3D, start: Vector3, end: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = start.distance_to(end)
	shape.radial_segments = 8
	var instance := _mesh(parent, shape, (start + end) * 0.5, _mat(color))
	var direction := (end - start).normalized()
	var perpendicular := Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > 0.98 else Vector3.UP
	var side := perpendicular.cross(direction).normalized()
	instance.basis = Basis(side, direction, side.cross(direction).normalized())
	return instance

func _ring(parent: Node3D, at: Vector3, radius: float, width: float, color: Color) -> MeshInstance3D:
	var shape := TorusMesh.new()
	shape.inner_radius = radius - width
	shape.outer_radius = radius + width
	shape.rings = 48
	shape.ring_segments = 8
	return _mesh(parent, shape, at, _mat(color, 0.5))

func _text(parent: Node3D, words: String, at: Vector3, font_size: int, pixel_size: float, color: Color, billboard: bool = false) -> Label3D:
	var label := Label3D.new()
	label.text = words
	label.position = at
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_modulate = NAVY
	label.outline_size = 8 if billboard else 0
	label.no_depth_test = billboard
	label.shaded = false
	if billboard:
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	return label

func _floor_line(a: Vector3, b: Vector3, width: float, color: Color = CREAM) -> void:
	var key := color.to_html()
	if not floor_marks.has(key):
		floor_marks[key] = {"color": color, "vertices": PackedVector3Array()}
	var flat_a := Vector3(a.x, 0, a.z)
	var flat_b := Vector3(b.x, 0, b.z)
	var offset := (flat_b - flat_a).normalized().cross(Vector3.UP) * width * .5
	var vertices: PackedVector3Array = floor_marks[key]["vertices"]
	var segments := maxi(1, int(ceilf(a.distance_to(b) / .3)))
	for i in segments:
		var start := a.lerp(b, float(i) / segments)
		var end := a.lerp(b, float(i + 1) / segments)
		vertices.append_array(PackedVector3Array([_ground(start + offset, .045 + a.y), _ground(end - offset, .045 + a.y), _ground(end + offset, .045 + a.y), _ground(start + offset, .045 + a.y), _ground(start - offset, .045 + a.y), _ground(end - offset, .045 + a.y)]))
	floor_marks[key]["vertices"] = vertices

func _finish_floor_marks() -> void:
	for key in floor_marks:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for vertex in floor_marks[key]["vertices"]:
			surface.set_normal(_floor_normal(vertex.x, vertex.z))
			surface.add_vertex(vertex)
		var material := _mat(floor_marks[key]["color"]).duplicate() as StandardMaterial3D
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		var marks := _mesh(arena, surface.commit(), Vector3.ZERO, material)
		marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	floor_marks.clear()

func _floor_arc(center: Vector3, radius: float, from_angle: float, to_angle: float, width: float, color: Color) -> void:
	var count := maxi(12, int(absf(to_angle - from_angle) * radius * 5))
	for i in count:
		var a := lerpf(from_angle, to_angle, float(i) / count)
		var b := lerpf(from_angle, to_angle, float(i + 1) / count)
		_floor_line(center + Vector3(cos(a), 0, sin(a)) * radius, center + Vector3(cos(b), 0, sin(b)) * radius, width, color)

func _build_lighting() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("58b7e0")
	sky_material.sky_horizon_color = Color("c5edf1")
	sky_material.ground_bottom_color = Color("67959c")
	sky_material.ground_horizon_color = Color("c5edf1")
	sky_material.sky_curve = 0.18
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d5e6ef")
	environment.ambient_light_energy = 0.36
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment_node.environment = environment
	add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("fff4dc")
	sun.light_energy = 0.56
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 110.0
	sun.shadow_bias = 0.05
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-28, 145, 0)
	fill.light_color = Color("a8e9ff")
	fill.light_energy = 0.16
	add_child(fill)

func _court_grain() -> ImageTexture:
	if court_texture != null: return court_texture
	# Original fine rubber/turf grain. One small mipmapped texture is shared by
	# the whole arena; it introduces no extra draw calls or procedural GPU cost.
	var raster := Image.create(128,128,false,Image.FORMAT_RGB8)
	var noise := RandomNumberGenerator.new()
	noise.seed = 60317
	for y in 128:
		for x in 128:
			var grain := noise.randf_range(.87,1.0)
			if y % 4 == 0: grain *= .98
			raster.set_pixel(x,y,Color(grain,grain,grain))
	raster.generate_mipmaps()
	court_texture = ImageTexture.create_from_image(raster)
	return court_texture

func _court_color(x: float, z: float) -> Color:
	var team_color := BLUE if z > 0 else ORANGE
	var road := ArenaLayout.road_weight(x,z)
	var bank := ArenaLayout.bank_height(x,z)
	var turf := Color("238c47").lightened(.035 if int(floor((z+56)/5.6))%2==0 else 0)
	var base := turf.lerp(team_color.darkened(.18),smoothstep(.06,.30,bank))
	# Continuous color ramps avoid sawtooth bands caused by assigning a whole
	# adaptive triangle a different crown/shoulder class at a hard threshold.
	var crown := Color("6f989a") if z>0 else Color("b0956d")
	var shoulder := Color("69a2b0") if z>0 else Color("a8885e")
	var pavement := shoulder.lerp(crown,smoothstep(.77,.99,road))
	var bevel := smoothstep(.84,.95,road)*(1.0-smoothstep(.95,1.0,road))
	pavement = pavement.lerp(team_color.darkened(.12),bevel*.65)
	var coverage := smoothstep(.015,.16,road)*smoothstep(-.04,.08,road*ArenaLayout.ROAD_HEIGHT-bank)
	return base.lerp(pavement,coverage)

func _terrain_point(cache: Dictionary, key: Vector2i) -> Vector3:
	if cache.has(key): return cache[key]
	var x := -float(Simulation.HALF_WIDTH)+key.x/32.0
	var z := -float(Simulation.HALF_LENGTH)+key.y/32.0
	var point := Vector3(x,_floor_height(x,z),z)
	cache[key] = point
	return point

func _terrain_triangle_error(a: Vector3, b: Vector3, c: Vector3) -> float:
	var at := (a+b+c)/3
	return absf(at.y-_floor_height(at.x,at.z))

func _terrain_cell(cache: Dictionary, leaves: Array[Vector4i], corners: Dictionary, x: int, z: int, size: int) -> void:
	var a := _terrain_point(cache,Vector2i(x,z))
	var b := _terrain_point(cache,Vector2i(x+size,z))
	var c := _terrain_point(cache,Vector2i(x,z+size))
	var d := _terrain_point(cache,Vector2i(x+size,z+size))
	var middle := _terrain_point(cache,Vector2i(x+size/2,z+size/2))
	var error_bc := maxf(maxf(_terrain_triangle_error(a,b,c),_terrain_triangle_error(b,d,c)),absf((b.y+c.y)*.5-middle.y))
	var error_ad := maxf(maxf(_terrain_triangle_error(a,b,d),_terrain_triangle_error(a,d,c)),absf((a.y+d.y)*.5-middle.y))
	var error := minf(error_bc,error_ad)
	for edge in [[a,b],[b,d],[d,c],[c,a]]:
		var mid: Vector3 = (Vector3(edge[0])+Vector3(edge[1]))*.5
		error = maxf(error,absf(mid.y-_floor_height(mid.x,mid.z)))
	if error>.045 and size>2:
		var half := size/2
		for dz in [0,half]:
			for dx in [0,half]: _terrain_cell(cache,leaves,corners,x+dx,z+dz,half)
		return
	leaves.append(Vector4i(x,z,size,0 if error_bc<=error_ad else 1))
	for key in [Vector2i(x,z),Vector2i(x+size,z),Vector2i(x,z+size),Vector2i(x+size,z+size)]: corners[key]=true

func _terrain_vertex(builder: Dictionary, cache: Dictionary, key: Vector2i) -> int:
	if builder.lookup.has(key): return builder.lookup[key]
	var at := _terrain_point(cache,key)
	var index: int = builder.points.size()
	builder.points.append(at)
	builder.normals.append(_floor_normal(at.x,at.z))
	builder.colors.append(_court_color(at.x,at.z))
	builder.uv.append(Vector2(at.x,at.z)*.72)
	builder.lookup[key] = index
	return index

func _adaptive_terrain(nx: int, nz: int) -> ArrayMesh:
	var cache := {}
	var corners := {}
	var leaves: Array[Vector4i] = []
	for zi in nz:
		for xi in nx: _terrain_cell(cache,leaves,corners,xi*16,zi*16,16)
	var builder := {"points":[],"normals":[],"colors":[],"uv":[],"indices":[],"lookup":{}}
	for leaf in leaves:
		var x := leaf.x
		var z := leaf.y
		var size := leaf.z
		var boundary: Array[Vector2i] = []
		# Every adjacent leaf uses the same corner set. Coarse cells include fine
		# neighbor vertices rather than leaving hanging edges or height cracks.
		for i in range(0,size,2):
			var key := Vector2i(x+i,z)
			if corners.has(key): boundary.append(key)
		for i in range(0,size,2):
			var key := Vector2i(x+size,z+i)
			if corners.has(key): boundary.append(key)
		for i in range(0,size,2):
			var key := Vector2i(x+size-i,z+size)
			if corners.has(key): boundary.append(key)
		for i in range(0,size,2):
			var key := Vector2i(x,z+size-i)
			if corners.has(key): boundary.append(key)
		var ids: Array[int] = []
		for key in boundary: ids.append(_terrain_vertex(builder,cache,key))
		if ids.size()==4:
			# Clockwise as viewed from above: Godot's front-face convention.
			if leaf.w==0: builder.indices.append_array([ids[0],ids[1],ids[3],ids[1],ids[2],ids[3]])
			else: builder.indices.append_array([ids[0],ids[1],ids[2],ids[0],ids[2],ids[3]])
		else:
			var center := _terrain_vertex(builder,cache,Vector2i(x+size/2,z+size/2))
			for i in ids.size(): builder.indices.append_array([center,ids[i],ids[(i+1)%ids.size()]])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(builder.points)
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(builder.normals)
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray(builder.colors)
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(builder.uv)
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(builder.indices)
	var terrain := ArrayMesh.new()
	terrain.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return terrain

func _build_court() -> void:
	var half_width := _dimension("HALF_WIDTH",32)
	var half_length := _dimension("HALF_LENGTH",56)
	_box(arena,Vector3(0,-1.05,0),Vector3(300,1,300),Color("668d96"))
	_box(arena,Vector3(0,-.36,0),Vector3(half_width*2+2,.65,half_length*2+2),NAVY)
	# One indexed terrain grid: query shared physics once per vertex, then reuse
	# the heights for its normals and route contours. No separate visual height.
	var nx := int(half_width*4)
	var nz := int(half_length*4)
	var stride := nx+1
	var points := PackedVector3Array()
	var weights := PackedFloat32Array()
	for zi in nz+1:
		for xi in nx+1:
			var x := -half_width+xi*.5
			var z := -half_length+zi*.5
			points.append(Vector3(x,_floor_height(x,z),z))
			weights.append(ArenaLayout.road_weight(x,z) if ArenaLayout.bank_height(x,z)<ArenaLayout.ROAD_HEIGHT+.02 else 0)
	var terrain := _adaptive_terrain(nx,nz)
	var material := _mat(Color.WHITE,.86).duplicate() as StandardMaterial3D
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _court_grain()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var floor_mesh := _mesh(arena,terrain,Vector3.ZERO,material)
	floor_mesh.name = "PlayableTerrain"
	# A shared-weight contour traces the curved crowns through every junction;
	# the old straight rectangle markings would contradict the new collision.
	for zi in nz:
		for xi in nx:
			var a := zi*stride+xi
			var corners := [a,a+1,a+stride+1,a+stride]
			var intersections: Array[Vector3] = []
			for edge in 4:
				var first: int = corners[edge]
				var last: int = corners[(edge+1)%4]
				if (weights[first]>.985)==(weights[last]>.985): continue
				var point := points[first].lerp(points[last],(.985-weights[first])/(weights[last]-weights[first]))
				point.y = 0
				intersections.append(point)
			if intersections.size()==2: _floor_line(intersections[0],intersections[1],.105,CREAM.darkened(.19))
	for side in [-1,1]:
		_floor_line(Vector3(side*(half_width-.35),0,-half_length+.35),Vector3(side*(half_width-.35),0,half_length-.35),.23)
		_floor_line(Vector3(-half_width+.35,0,side*(half_length-.35)),Vector3(half_width-.35,0,side*(half_length-.35)),.23)
		for z in [-34.0,-13.0,13.0,34.0]:
			var center := Vector3(side*ArenaLayout.road_center_x(absf(z)),0,z)
			var next := Vector3(side*ArenaLayout.road_center_x(absf(z+.5)),0,z+.5)
			_road_chevron(center,(next-center).normalized()*signf(z),1.05)
		for x in [-8.0,8.0]:
			_road_chevron(Vector3(x,0,side*ArenaLayout.road_cross_z(absf(x))),Vector3(signf(x),0,0),.95)
		var goal: Vector3 = Simulation.NORTH if side<0 else Simulation.SOUTH
		_terrain_disc(arena,goal*Vector3(1,0,1),0,4.75,Color("147642"),.026)
		_floor_arc(goal*Vector3(1,0,1),5.05,0,TAU,.23,CREAM)
		_floor_arc(goal*Vector3(1,0,1),4.65,0,TAU,.10,BLUE if side>0 else ORANGE)
		_build_team_emblem(Vector3(0,0,side*9),BLUE if side>0 else ORANGE)
		for i in int(ceilf(half_length)):
			var z := -half_length+1+i*2
			var pad := _capsule(arena,Vector3(side*(half_width+.2),_floor_height(half_width,z)+.43,z),.36,1.96,BLUE if z>0 else ORANGE)
			pad.rotation.x = PI/2
		for i in int(ceilf(half_width)):
			var x := -half_width+1+i*2
			var pad := _capsule(arena,Vector3(x,_floor_height(x,half_length)+.4,side*(half_length+.2)),.36,1.96,BLUE if side>0 else ORANGE)
			pad.rotation.z = PI/2
	_floor_line(Vector3(-half_width+.4,0,0),Vector3(half_width-.4,0,0),.13)
	_floor_arc(Vector3.ZERO,3.5,0,TAU,.19,CREAM)
	_build_center_emblem()
	for at in Simulation.PADS:
		_build_booster(at,true)
		_floor_arc(at,2.25,0,TAU,.14,NAVY)
		for angle in [0.0,PI/2,PI,PI*1.5]:
			var direction := Vector3(cos(angle),0,sin(angle))
			_floor_line(at+direction*2.48,at+direction*2.86,.36,CREAM)
	for at in Simulation.SPEED_PADS: _build_booster(at,false)

func _road_chevron(at: Vector3, direction: Vector3, width: float) -> void:
	var across := direction.cross(Vector3.UP).normalized()*width
	for row in 2:
		var center := at+direction*row*.85
		_floor_line(center-across-direction*.60,center,.23,CREAM)
		_floor_line(center,center+across-direction*.60,.23,CREAM)

func _build_team_emblem(at: Vector3, color: Color) -> void:
	# Original split comet-and-ball paint, distinct from the center logo.
	_terrain_disc(arena,at,0,3.25,color.darkened(.05),.03)
	_floor_arc(at,3.55,-.8,1.9,.17,CREAM)
	_floor_arc(at,1.15,0,TAU,.19,CREAM)
	_floor_line(at+Vector3(-1.1,0,0),at+Vector3(1.1,0,0),.12,CREAM)
	for offset in [-.7,0.0,.7]:
		_floor_line(at+Vector3(-2.3,0,offset),at+Vector3(-1.4,0,offset+.3),.20,CREAM)

func _build_center_emblem() -> void:
	# A ball crossing two sweeping arcs: authored court identity without a logo
	# from the reference game or another block of arena copy.
	_terrain_disc(arena,Vector3.ZERO,0,2.65,NAVY,.028)
	_floor_arc(Vector3.ZERO,2.35,-.25,PI-.25,.20,BLUE.lightened(.25))
	_floor_arc(Vector3.ZERO,2.35,PI-.25,TAU-.25,.20,ORANGE.lightened(.12))
	_floor_arc(Vector3.ZERO,.84,0,TAU,.14,CREAM)
	_floor_line(Vector3(-.84,0,0),Vector3(.84,0,0),.09,CREAM)
	_floor_line(Vector3(0,0,-.84),Vector3(0,0,.84),.09,CREAM)
	for side in [-1,1]:
		_floor_line(Vector3(-1.9*side,0,-.55),Vector3(-1.2*side,0,-1.0),.18,CREAM)
		_floor_line(Vector3(1.2*side,0,1.0),Vector3(1.9*side,0,.55),.18,CREAM)

func _build_hazards() -> void:
	# Mesh endpoints, thickness and rotation follow the authority's shared
	# segment helper. The swept-circle marking is warning paint, not a collider.
	for index in Simulation.HAZARDS.size():
		var center: Vector3 = Simulation.HAZARDS[index]
		var radius := float(Simulation.HAZARD_RADIUS)
		var rotor := Node3D.new()
		rotor.name = "PaddedRotor%d" % index
		arena.add_child(rotor)
		var color := CORAL if index%2==0 else GOLD
		var bar := _capsule(rotor,Vector3.ZERO,.34,radius*2+.68,color)
		bar.rotation.z = PI/2
		for x in [-radius+.38,-radius+1.05,radius-1.05,radius-.38]:
			var band := _ring(rotor,Vector3(x,0,0),.342,.035,CREAM)
			band.rotation.z = PI/2
		_sphere(rotor,Vector3.ZERO,Vector3(.76,.76,.76),NAVY)
		_ring(rotor,Vector3(0,.36,0),.22,.045,color)
		_capsule(rotor,Vector3(0,-Simulation.HAZARD_HEIGHT*.5,0),.22,Simulation.HAZARD_HEIGHT,NAVY)
		for arc in 16:
			var angle := TAU*arc/16.0
			_floor_arc(center,radius+.52,angle,angle+TAU/16*.55,.12,CREAM)
		_terrain_disc(arena,center,0,.55,NAVY,.035)
		hazard_visuals.append({"node":rotor,"index":index})
	_present_hazards({"clock":0.0})

func _present_hazards(state: Dictionary) -> void:
	var match_clock := float(state.get("clock",0.0))
	for hazard in hazard_visuals:
		var index: int = hazard["index"]
		var endpoints: Array[Vector3] = Simulation.hazard_endpoints(index,match_clock)
		var node: Node3D = hazard["node"]
		node.position = (endpoints[0]+endpoints[1])*.5
		node.rotation.y = -Simulation.hazard_angle(index,match_clock)

func _build_booster(at: Vector3, launcher: bool) -> void:
	var body := Node3D.new()
	arena.add_child(body)
	var radius := 1.65 if launcher else 1.25
	if launcher:
		_terrain_disc(body, at, 0, radius, NAVY, .075)
		_terrain_disc(body, at, 0, radius - .2, GOLD, .10)
		_terrain_disc(body, at, 0, radius - .42, Color("f58b32"), .13)
		_terrain_disc(body, at, radius - .14, radius, CREAM, .15)
	else:
		# Wide flat strips mark a running route, distinct from round launchers.
		for x in [-1.08, 1.08]:
			_floor_line(at + Vector3(x, .055, -1.65), at + Vector3(x, .055, 1.65), .16, GOLD)
		for z in [-1.65, 1.65]:
			_floor_line(at + Vector3(-1.08, .055, z), at + Vector3(1.08, .055, z), .16, GOLD)
		_floor_line(at + Vector3(0, .035, -1.55), at + Vector3(0, .035, 1.55), 1.95, NAVY)
	var arrows := Node3D.new()
	body.add_child(arrows)
	arrows.position = _ground(at, .22)
	for row in (2 if launcher else 3):
		var z: float = .4 - row * .62 if launcher else .85 - row * .83
		_rod(arrows, Vector3(-.56, 0, z + .26), Vector3(0, 0, z - .21), .075, CREAM)
		_rod(arrows, Vector3(0, 0, z - .21), Vector3(.56, 0, z + .26), .075, CREAM)
	var halo := _ring(body, _ground(at, .18), radius + .15, .045, GOLD)
	halo.basis = Basis(Quaternion(Vector3.UP, _floor_normal(at.x, at.z)))
	halo.material_override = _mat(GOLD, .4, 0, .35)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.visible = launcher
	booster_visuals.append({"pos": at, "arrows": arrows, "halo": halo, "launcher": launcher})

func _present_boosters(players: Dictionary, local_id: int) -> void:
	var local_team := int(players.get(local_id, {}).get("team", 0)) if mode != "versus" else 0
	if local_team != booster_team:
		booster_team = local_team
		for booster in booster_visuals:
			var at: Vector3 = booster["pos"]
			var direction := Vector3(-signf(at.x) * .35, 0, 1.0 if local_team == 1 else -1.0).normalized()
			if floor_model.has_method("booster_direction"):
				floor_model.players = players
				floor_model.mode = mode
				direction = floor_model.call("booster_direction", at, local_id)
			var normal := _floor_normal(at.x, at.z)
			var axis_z := -direction.slide(normal).normalized()
			var axis_x := normal.cross(axis_z).normalized()
			booster["arrows"].basis = Basis(axis_x, axis_z.cross(axis_x), axis_z)
	for booster in booster_visuals:
		if bool(booster["launcher"]):
			var pulse := 1.0 + sin(clock_time * 3.5 + float(booster["pos"].z)) * .035
			booster["halo"].scale = Vector3.ONE * pulse
	for beacon in goal_beacons:
		var active := local_id > 0 and int(beacon["team"]) == local_team
		beacon["node"].position.y = float(beacon["height"]) + sin(clock_time * 2.5) * .12
		var distance_scale := 1.0
		if players.has(local_id):
			var local_position: Vector3 = players[local_id].get("pos", Vector3.ZERO)
			var delta: Vector3 = local_position - beacon["node"].global_position
			distance_scale = clampf(Vector2(delta.x, delta.z).length() / 15.0, .35, 1.0)
		beacon["node"].scale = Vector3.ONE * (1.15 if active else .8) * distance_scale

func _terrain_disc(parent: Node3D, at: Vector3, inner: float, outer: float, color: Color, lift: float) -> Node3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radial_steps := maxi(1, int(ceilf((outer - inner) / .15)))
	for i in 64:
		var a := TAU * i / 64.0
		var b := TAU * (i + 1) / 64.0
		for j in radial_steps:
			var r0 := lerpf(inner, outer, float(j) / radial_steps)
			var r1 := lerpf(inner, outer, float(j + 1) / radial_steps)
			var p := at + Vector3(cos(a), 0, sin(a)) * r0
			var q := at + Vector3(cos(a), 0, sin(a)) * r1
			var r := at + Vector3(cos(b), 0, sin(b)) * r1
			var s := at + Vector3(cos(b), 0, sin(b)) * r0
			for vertex in [p, q, r, p, r, s]:
				surface.set_normal(_floor_normal(vertex.x, vertex.z))
				surface.add_vertex(_ground(vertex, lift))
	var material := _mat(color, .38).duplicate() as StandardMaterial3D
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var result := _mesh(parent, surface.commit(), Vector3.ZERO, material)
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return result

func _build_kickoff_deck(side: int) -> void:
	var deck := Node3D.new()
	deck.name = "LaunchDeckNorth" if side < 0 else "LaunchDeckSouth"
	arena.add_child(deck)
	var y := Simulation.KICKOFF_Y
	var z := side*Simulation.KICKOFF_Z
	var color := BLUE if side > 0 else ORANGE
	var width := Simulation.KICKOFF_HALF_WIDTH*2
	var depth := Simulation.KICKOFF_HALF_DEPTH*2
	_box(deck,Vector3(0,y-.30,z),Vector3(width,.44,depth),NAVY)
	_box(deck,Vector3(0,y-.045,z),Vector3(width-.15,.09,depth-.15),color)
	# No middle pillar: the playable lane beneath the hoop stays clear.
	for x in [-6.7,6.7]:
		var ground := _floor_height(x,z)
		_box(deck,Vector3(x,(y+ground)*.5,z+.45*side),Vector3(.35,y-ground,.55),NAVY)
		_rod(deck,Vector3(x,y+.15,z-1.25),Vector3(x,y+.15,z+1.25),.15,CREAM)
	for x in [-5.0,0.0,5.0]:
		var pad := _ring(deck,Vector3(x,y+.02,z),.83,.085,CREAM)
		pad.scale.z = .7
		for offset in [-.35,.35]:
			_rod(deck,Vector3(x-.30,y+.045,z+offset+.17*side),Vector3(x,y+.045,z+offset-.17*side),.055,GOLD)
			_rod(deck,Vector3(x,y+.045,z+offset-.17*side),Vector3(x+.30,y+.045,z+offset+.17*side),.055,GOLD)
	_register_occluder(deck,Vector3(0,y,z),7.4)

func _build_hoop(side: int) -> void:
	var color: Color = ORANGE if side < 0 else BLUE
	var hoop_position: Vector3 = sim_constants.get("NORTH" if side < 0 else "SOUTH", Vector3(0, 4.6, side * 19))
	var hoop_y := hoop_position.y
	var z := hoop_position.z
	var board_z := side * _dimension("BACKBOARD_Z", 20.25)
	var assembly := Node3D.new()
	assembly.name = "NorthHoop" if side < 0 else "SouthHoop"
	arena.add_child(assembly)
	var backdrop := Node3D.new()
	backdrop.name = "PaddedBackboard"
	assembly.add_child(backdrop)
	# Broad padded base and a compact backplate replace the conventional glass board.
	var base_y := _floor_height(0, board_z)
	_capsule(backdrop, Vector3(0, base_y + 1.55, board_z + side * .30), .58, 3.5, NAVY)
	_capsule(backdrop, Vector3(0, base_y + 1.05, board_z + side * .30), .68, 2.2, color)
	_box(backdrop, Vector3(0, hoop_y + .8, board_z), Vector3(4.98, 2.18, .24), NAVY.lightened(.05), .68)
	# Rounded, visibly padded frame, with the face inside the physical backboard.
	for x in [-2.43, 2.43]:
		_capsule(backdrop, Vector3(x, hoop_y + .8, board_z), .19, 2.4, color)
	for y in [hoop_y - .21, hoop_y + 1.81]:
		var frame := _capsule(backdrop, Vector3(0, y, board_z), .19, 5.24, color)
		frame.rotation.z = PI / 2
	var target := _ring(backdrop, Vector3(0, hoop_y + .8, board_z - side * .14), .65, .05, CREAM)
	target.rotation.x = PI / 2
	# Support meets the outside rear edge. Extending it to the hoop center made
	# valid swishes appear to pass through a solid orange bar across the opening.
	var rear_edge := z+side*_dimension("RIM_RADIUS",1.65)
	var mount := _rod(backdrop, Vector3(0, hoop_y, board_z), Vector3(0, hoop_y, rear_edge), .18, color)
	mount.name = "RearRimMount"
	_register_occluder(backdrop,Vector3(0,hoop_y+.5,board_z),3.1)
	var radius := _dimension("RIM_RADIUS", 1.65)
	var tube := _dimension("RIM_TUBE", .28)
	# Separate visibility sections keep the far silhouette solid while clearing
	# only the foreground rim/net between the camera and the followed player.
	var sections: Array[Node3D] = []
	for index in 8:
		var section := Node3D.new()
		section.name = "BasketSection%d" % index
		assembly.add_child(section)
		sections.append(section)
	var rim_parts := _sectioned_ring(sections, Vector3(0, hoop_y, z), radius, tube, CREAM)
	_sectioned_ring(sections, Vector3(0, hoop_y + tube * .56, z), radius, tube * .38, color)
	_build_deep_net(assembly, Vector3(0, hoop_y, z), radius, tube, color, sections)
	for section in sections:
		_register_occluder(section,Vector3(0,hoop_y,z),radius+.4,true)
	for part in rim_parts: hoop_lights.append(part)
	var beacon := Node3D.new()
	assembly.add_child(beacon)
	beacon.position = Vector3(0, hoop_y + 3.2, z)
	if side > 0: beacon.rotation.y = PI
	for y in [.4, -.2]:
		_rod(beacon, Vector3(-.72, y + .38, 0), Vector3(0, y - .15, 0), .105, GOLD)
		_rod(beacon, Vector3(0, y - .15, 0), Vector3(.72, y + .38, 0), .105, GOLD)
	var beacon_ring := _ring(beacon, Vector3(0, .20, .045), 1.06, .055, color)
	beacon_ring.rotation.x = PI / 2
	beacon_ring.material_override = _mat(color, .4, 0, .3)
	goal_beacons.append({"node": beacon, "height": hoop_y + 3.2, "team": 0 if side < 0 else 1})

func _net_point(center: Vector3, radius: float, tube: float, row: int, index: int) -> Vector3:
	var progress := float(row) / 6.0
	var angle := TAU * (index + (row % 2) * .5) / 20.0
	var radial := Vector3(cos(angle), 0, sin(angle))
	var bottom := center + radial * radius * 1.12
	var point := center + radial * lerpf(radius - tube, radius * 1.12, progress)
	point.y = lerpf(center.y - .12, _floor_height(bottom.x, bottom.z) + .19, progress)
	return point

func _sectioned_ring(sections: Array[Node3D], at: Vector3, radius: float, width: float, color: Color) -> Array[MeshInstance3D]:
	# Reuse exactly the TorusMesh triangles/normals of the original whole rim.
	var shape := TorusMesh.new()
	shape.inner_radius = radius-width
	shape.outer_radius = radius+width
	shape.rings = 48
	shape.ring_segments = 8
	var arrays := shape.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var surfaces: Array[SurfaceTool] = []
	for section in sections:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces.append(surface)
	for index in range(0,indices.size(),3):
		var middle := (vertices[indices[index]]+vertices[indices[index+1]]+vertices[indices[index+2]])/3
		var angle := fposmod(atan2(middle.z,middle.x),TAU)
		var surface: SurfaceTool = surfaces[mini(sections.size()-1,int(angle/TAU*sections.size()))]
		for corner in 3:
			var vertex := indices[index+corner]
			surface.set_normal(normals[vertex])
			surface.add_vertex(vertices[vertex])
	var result: Array[MeshInstance3D] = []
	for index in sections.size():
		result.append(_mesh(sections[index],surfaces[index].commit(),at,_mat(color,.5)))
	return result

func _build_deep_net(parent: Node3D, center: Vector3, radius: float, tube: float, color: Color, sections: Array[Node3D]) -> void:
	var strands: Array[Array] = []
	var bases: Array[Array] = []
	for section in sections:
		strands.append([])
		bases.append([])
	for row in 6:
		for i in 20:
			var section := mini(sections.size()-1,int(float(i)/20*sections.size()))
			var start := _net_point(center, radius, tube, row, i)
			strands[section].append(start)
			strands[section].append(_net_point(center, radius, tube, row + 1, i))
			strands[section].append(start)
			strands[section].append(_net_point(center, radius, tube, row + 1, i + (1 if row % 2 else -1)))
	for i in 80:
		var section := mini(sections.size()-1,int(float(i)/80*sections.size()))
		for angle in [TAU * i / 80.0, TAU * (i + 1) / 80.0]:
			bases[section].append(_ground(center + Vector3(cos(angle), 0, sin(angle)) * radius * 1.12, .19))
	for index in sections.size():
		var net_points: Array[Vector3] = []
		var base_points: Array[Vector3] = []
		net_points.assign(strands[index])
		base_points.assign(bases[index])
		_tube_segments(sections[index],net_points,.026,CREAM)
		_tube_segments(sections[index],base_points,.12,color)
	_terrain_disc(parent, center, radius * 1.12 + .09, radius * 1.12 + .16, CREAM, .055)

func _tube_segments(parent: Node3D, points: Array[Vector3], radius: float, color: Color) -> void:
	# A complete net uses one draw call instead of one node per strand.
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.height = 1.0
	cylinder.radial_segments = 6
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.mesh = cylinder
	mesh.instance_count = points.size() / 2
	for i in mesh.instance_count:
		var start := points[i * 2]
		var end := points[i * 2 + 1]
		var delta := end - start
		var basis := Basis(Quaternion(Vector3.UP, delta.normalized())) * Basis.from_scale(Vector3(radius, delta.length(), radius))
		mesh.set_instance_transform(i, Transform3D(basis, (start + end) * .5))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mesh
	instance.material_override = _mat(color, .65)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

func _stadium_outline(offset: float, step: float = 2.0) -> PackedVector3Array:
	# Outward rounded offsets of the rectangular play area. The corner arcs
	# never cut across the playable rectangle, unlike an inset rounded box.
	var w := float(Simulation.HALF_WIDTH)
	var l := float(Simulation.HALF_LENGTH)
	var points := PackedVector3Array()
	for section in 4:
		var from: Vector3
		var to: Vector3
		var corner: Vector3
		match section:
			0:
				from=Vector3(w+offset,0,-l); to=Vector3(w+offset,0,l); corner=Vector3(w,0,l)
			1:
				from=Vector3(w,0,l+offset); to=Vector3(-w,0,l+offset); corner=Vector3(-w,0,l)
			2:
				from=Vector3(-w-offset,0,l); to=Vector3(-w-offset,0,-l); corner=Vector3(-w,0,-l)
			_:
				from=Vector3(-w,0,-l-offset); to=Vector3(w,0,-l-offset); corner=Vector3(w,0,-l)
		var count := maxi(2,int(ceilf(from.distance_to(to)/step)))
		for i in count: points.append(from.lerp(to,float(i)/count))
		var arc_count := maxi(6,int(ceilf(offset*PI*.5/step)))
		for i in arc_count:
			var angle := section*PI*.5+float(i)/arc_count*PI*.5
			points.append(corner+Vector3(cos(angle),0,sin(angle))*offset)
	return points

func _stadium_band(parent: Node3D, offset: float, low: float, high: float, color: Color, outward: float = 0.0) -> MeshInstance3D:
	var points := _stadium_outline(offset,3.0)
	var top := _stadium_outline(offset+outward,3.0)
	# A fixed angular/straight topology is required when offset changes counts.
	if outward!=0:
		top = points.duplicate()
		for i in points.size():
			var p := points[i]
			var nearest := Vector3(clampf(p.x,-Simulation.HALF_WIDTH,Simulation.HALF_WIDTH),0,clampf(p.z,-Simulation.HALF_LENGTH,Simulation.HALF_LENGTH))
			top[i] = p+(p-nearest).normalized()*outward
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size():
		var next := (i+1)%points.size()
		var a := points[i]+Vector3.UP*low
		var b := points[next]+Vector3.UP*low
		var c := top[i]+Vector3.UP*high
		var d := top[next]+Vector3.UP*high
		for at in [a,c,b,b,c,d]: surface.add_vertex(at)
	surface.generate_normals()
	var material := _mat(color,.57).duplicate() as StandardMaterial3D
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _mesh(parent,surface.commit(),Vector3.ZERO,material)

func _build_stands() -> void:
	var scenery := Node3D.new()
	scenery.name = "StadiumScenery"
	arena.add_child(scenery)
	var bowl := Node3D.new()
	bowl.name = "CrowdBowl"
	scenery.add_child(bowl)
	var crowd: Array[Dictionary] = []
	_stadium_band(bowl,.9,-.65,4.2,NAVY)
	_stadium_band(bowl,1.05,3.55,4.4,TEAL.darkened(.2))
	for tier in 3:
		for row in 5:
			var offset := 2.0+tier*8.0+row*1.2
			var floor_y := 4.2+tier*8.5+row*.82
			_stadium_band(bowl,offset-.55,floor_y-.82,floor_y,NAVY.lightened(tier*.035))
			_stadium_band(bowl,offset-.55,floor_y,floor_y,Color("457287") if row%2==0 else Color("94bbc2"),1.20)
			var seats := _stadium_outline(offset,1.60)
			for index in seats.size():
				var at := seats[index]
				# Purposeful corner plinths occupy the lower-tier seating gaps.
				if tier<2 and absf(absf(at.x)-(Simulation.HALF_WIDTH+12))<6.8 and absf(absf(at.z)-(Simulation.HALF_LENGTH+7))<7.0: continue
				at.y = floor_y+.13
				crowd.append({"pos":at,"yaw":atan2(at.x,at.z),"color":PALETTE[(index*3+row*2+tier)%PALETTE.size()]})
		var band_offset := 8.0+tier*8.0
		var band_y := 8.1+tier*8.5
		_stadium_band(bowl,band_offset,band_y-.3,band_y+1.9,NAVY)
		_stadium_band(bowl,band_offset-.08,band_y-.05,band_y+1.60,TEAL if tier%2==0 else ORANGE)
		_stadium_band(bowl,band_offset-.15,band_y-.15,band_y+.03,CREAM)
		_stadium_band(bowl,band_offset-.15,band_y+1.58,band_y+1.78,CREAM)
		# Sparse original diamond panels break the ribbon's scale, not ad copy.
		var ribbon_points := _stadium_outline(band_offset-.20,12.0)
		for i in ribbon_points.size():
			var at := ribbon_points[i]+Vector3.UP*(band_y+.8)
			var panel := _box(bowl,at,Vector3(.65,.65,.07),CREAM)
			panel.rotation.y = atan2(at.x,at.z)
			panel.rotate_object_local(Vector3.FORWARD,PI/4)
	_stadium_band(bowl,25.3,26.7,28.7,NAVY)
	_stadium_band(bowl,25.0,28.45,28.72,CREAM)
	_build_crowd(crowd,bowl)
	for side in [-1,1]:
		_build_goal_shell(scenery,side)
		for x_side in [-1,1]: _build_mascot(scenery,x_side,side)
	var screens := Node3D.new()
	screens.name = "RibbonScreens"
	scenery.add_child(screens)
	for side in [-1,1]:
		var sign := Node3D.new()
		screens.add_child(sign)
		sign.position = Vector3(side*(Simulation.HALF_WIDTH+16),19.5,0)
		sign.rotation.y = PI/2 if side<0 else -PI/2
		_box(sign,Vector3.ZERO,Vector3(15.5,5.8,.5),NAVY)
		_box(sign,Vector3(0,0,.29),Vector3(14.7,5.0,.08),Color("21496b"))
		_text(sign,"CROWN COURT",Vector3(0,.6,.36),96,.013,CREAM)
		for x in [-5.8,5.8]:
			var emblem := _ring(sign,Vector3(x,0,.40),.83,.08,TEAL if side>0 else GOLD)
			emblem.rotation.x = PI/2
			_rod(sign,Vector3(x-.8,0,.44),Vector3(x+.8,0,.44),.035,CREAM)
		for x in [-6.5,6.5]:
			_capsule(sign,Vector3(x,3.3,0),.10,1.0,CREAM)

func _goal_end_point(x: float, height: float, depth: float, side: int) -> Vector3:
	# Convex footprint is wholly beyond Z56. Curved shoulders avoid the old
	# rectangular quarter-pipe silhouette without inventing playable collision.
	return Vector3(x,height,side*(Simulation.HALF_LENGTH+depth+2.0*pow(x/18.0,2)))

func _goal_end_strip(parent: Node3D, side: int, width: float, low: float, high: float, front: float, back: float, color: Color) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 36:
		var x := lerpf(-width,width,float(i)/36)
		var next_x := lerpf(-width,width,float(i+1)/36)
		var a := _goal_end_point(x,low,front,side)
		var b := _goal_end_point(next_x,low,front,side)
		var c := _goal_end_point(x,high,back,side)
		var d := _goal_end_point(next_x,high,back,side)
		for at in [a,c,b,b,c,d]: surface.add_vertex(at)
	surface.generate_normals()
	var material := _mat(color,.65).duplicate() as StandardMaterial3D
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _mesh(parent,surface.commit(),Vector3.ZERO,material)

func _build_goal_shell(parent: Node3D, side: int) -> void:
	var shell := Node3D.new()
	shell.name = "GoalEndNorth" if side<0 else "GoalEndSouth"
	parent.add_child(shell)
	var color := ORANGE if side<0 else BLUE
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var arch_trim: Array[Vector3] = []
	var arch_highlight: Array[Vector3] = []
	var step_trim: Array[Vector3] = []
	# Wide semicircular team shell behind the basket. Every real triangle is
	# outside the playable boundary; the green scoring pocket stays open.
	for i in 48:
		var x := -18.0+i*.75
		var next_x := x+.75
		var y := 1.65+7.3*sqrt(maxf(0,1-pow(x/18.0,2)))
		var next_y := 1.65+7.3*sqrt(maxf(0,1-pow(next_x/18.0,2)))
		var a := _goal_end_point(x,1.65,1.4,side)
		var b := _goal_end_point(next_x,1.65,1.4,side)
		var c := _goal_end_point(x,y,1.4,side)
		var d := _goal_end_point(next_x,next_y,1.4,side)
		for index in [0,2,1,1,2,3]:
			surface.set_color(color.darkened(.08 if int(i/6)%2==0 else .18))
			surface.add_vertex([a,b,c,d][index])
		arch_trim.append_array([c,d])
		arch_highlight.append_array([c+Vector3.UP*.10-Vector3(0,0,side*.10),d+Vector3.UP*.10-Vector3(0,0,side*.10)])
	_tube_segments(shell,arch_trim,.25,NAVY)
	_tube_segments(shell,arch_highlight,.065,CREAM)
	surface.generate_normals()
	var material := _mat(Color.WHITE,.66).duplicate() as StandardMaterial3D
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var facade := _mesh(shell,surface.commit(),Vector3.ZERO,material)
	facade.name = "RoundedTeamShell"
	# Curved step treads/rises start above and behind the dome, reusing the
	# surrounding custom crowd bowl rather than reauthoring thousands of seats.
	for step in 8:
		var y := 9.2+step*.51
		var depth := 2.2+step*.64
		var width := 16.8-step*.20
		var tread := _goal_end_strip(shell,side,width,y,y,depth,depth+.64,color.lightened(.08 if step%2==0 else 0))
		tread.name = "CurvedTerrace%d" % step
		_goal_end_strip(shell,side,width,y-.51,y,depth,depth,color.darkened(.22))
		var previous := _goal_end_point(-width,y+.035,depth,side)
		for i in range(1,25):
			var next := _goal_end_point(lerpf(-width,width,float(i)/24),y+.035,depth,side)
			step_trim.append_array([previous,next])
			previous = next
	_tube_segments(shell,step_trim,.045,CREAM)
	# Original ball/comet emblem fills the backdrop without reference branding.
	var emblem := Node3D.new()
	emblem.name = "GoalBallMotif"
	shell.add_child(emblem)
	emblem.position = _goal_end_point(0,5.05,1.10,side)
	var motif := _ring(emblem,Vector3.ZERO,2.15,.095,color.lightened(.52))
	motif.rotation.x = PI/2
	_rod(emblem,Vector3(-2.12,0,-side*.035),Vector3(2.12,0,-side*.035),.055,CREAM)
	_rod(emblem,Vector3(0,-2.12,-side*.035),Vector3(0,2.12,-side*.035),.055,CREAM)
	for x_side in [-1,1]:
		var post := _capsule(shell,_goal_end_point(x_side*17.9,9.4,6.7,side),.32,7.5,NAVY)
		post.name = "TerraceEndPost"
		_sphere(shell,_goal_end_point(x_side*17.9,13.3,6.7,side),Vector3.ONE*1.05,color)
	_register_occluder(shell,_goal_end_point(0,7.7,4.8,side),20.0)

func _build_mascot(parent: Node3D, x_side: int, z_side: int) -> void:
	var statue := Node3D.new()
	statue.name = "Mascot"+("N" if z_side<0 else "S")+("W" if x_side<0 else "E")
	parent.add_child(statue)
	statue.position = Vector3(x_side*(Simulation.HALF_WIDTH+10),13,z_side*(Simulation.HALF_LENGTH+7))
	statue.rotation.y = atan2(statue.position.x,statue.position.z)
	var color := ORANGE if z_side<0 else BLUE
	_capsule(statue,Vector3(0,-6,0),5.4,13.0,NAVY)
	_sphere(statue,Vector3(0,0,0),Vector3(13.5,3.0,13.5),NAVY)
	_sphere(statue,Vector3(0,.9,0),Vector3(12.8,1.4,12.8),GOLD)
	_capsule(statue,Vector3(0,6.2,0),2.15,6.9,color)
	for side in [-1,1]:
		_sphere(statue,Vector3(side*1.3,2.2,-.25),Vector3(2.4,1.4,3.2),NAVY)
		_rod(statue,Vector3(side*1.85,6.8,0),Vector3(side*3.2,9.1,-.10),.63,color)
		_rod(statue,Vector3(side*3.2,9.1,-.1),Vector3(side*1.95,11.4,0),.63,color)
		_sphere(statue,Vector3(side*1.95,11.4,0),Vector3(1.8,1.8,1.8),CREAM)
	_sphere(statue,Vector3(0,7.0,-1.95),Vector3(3.5,2.55,.62),NAVY)
	for side in [-1,1]: _sphere(statue,Vector3(side*.60,7.1,-2.26),Vector3(.49,.91,.15),CREAM)
	_sphere(statue,Vector3(0,13.0,0),Vector3.ONE*4.8,GOLD)
	for axis in [0,1,2]:
		var seam := _ring(statue,Vector3(0,13,0),2.40,.08,NAVY)
		if axis==1: seam.rotation.x = PI/2
		if axis==2: seam.rotation.z = PI/2
	_register_occluder(statue,statue.position+Vector3.UP*9,7.0)

func _build_crowd(crowd: Array[Dictionary], parent: Node3D) -> void:
	var body_shape := CapsuleMesh.new()
	body_shape.radius = .29
	body_shape.height = .92
	body_shape.radial_segments = 8
	body_shape.rings = 3
	var head_shape := SphereMesh.new()
	head_shape.radius = .5
	head_shape.height = 1.0
	head_shape.radial_segments = 8
	head_shape.rings = 4
	for part in ["body", "face", "eyes"]:
		var mesh := MultiMesh.new()
		mesh.transform_format = MultiMesh.TRANSFORM_3D
		mesh.use_colors = part == "body"
		mesh.mesh = body_shape if part == "body" else head_shape
		mesh.instance_count = crowd.size() * (2 if part == "eyes" else 1)
		var index := 0
		for bean in crowd:
			var transform := Transform3D(Basis(Vector3.UP, float(bean["yaw"])), bean["pos"])
			if part == "body":
				mesh.set_instance_transform(index, transform * Transform3D(Basis.IDENTITY, Vector3(0, .51, 0)))
				mesh.set_instance_color(index, bean["color"])
				index += 1
			elif part == "face":
				mesh.set_instance_transform(index, transform * Transform3D(Basis.IDENTITY.scaled(Vector3(.42, .32, .13)), Vector3(0, .63, -.255)))
				index += 1
			else:
				for side in [-1, 1]:
					mesh.set_instance_transform(index, transform * Transform3D(Basis.IDENTITY.scaled(Vector3(.07, .13, .025)), Vector3(side * .09, .65, -.327)))
					index += 1
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = mesh
		var material := _mat(Color.WHITE if part == "body" else (NAVY if part == "face" else CREAM), .7).duplicate() as StandardMaterial3D
		material.vertex_color_use_as_albedo = part == "body"
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(instance)
func _build_ball() -> void:
	ball_root = Node3D.new()
	ball_root.name = "Basketball"
	add_child(ball_root)
	var radius := _dimension("BALL_RADIUS", .52)
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2
	shape.radial_segments = 64
	shape.rings = 24
	var arrays := shape.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray()
	for point in vertices:
		var sector := int(floor((atan2(point.z,point.x)+PI)/TAU*8.0)) % 4
		colors.append(CREAM if sector == 2 else (NAVY if sector == 3 else Color("ff9c3b")))
	arrays[Mesh.ARRAY_COLOR] = colors
	var panel_mesh := ArrayMesh.new()
	panel_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var panel_material := _mat(Color.WHITE,.62).duplicate() as StandardMaterial3D
	panel_material.vertex_color_use_as_albedo = true
	_mesh(ball_root,panel_mesh,Vector3.ZERO,panel_material)
	for axis in [0, 1, 2]:
		var seam := _ring(ball_root, Vector3.ZERO, radius - .006, .021, NAVY)
		if axis == 1:
			seam.rotation.x = PI / 2
		elif axis == 2:
			seam.rotation.z = PI / 2
	ball_shadow = _shadow(radius, Color(0.08, .16, .22, .24))
	ball_root.position = Vector3(0, radius, 0)

func _shadow(radius: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = .004
	mesh.radial_segments = 32
	var material := _mat(color).duplicate() as StandardMaterial3D
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var shadow := _mesh(self, mesh, Vector3(0, .075, 0), material)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return shadow

func _make_actor(id: int) -> Dictionary:
	var color: Color = PALETTE[(id - 1) % PALETTE.size()]
	var root := Node3D.new()
	root.name = "Player%d" % id
	actor_root.add_child(root)
	var rig := Node3D.new()
	root.add_child(rig)
	var body := _capsule(rig, Vector3(0, .97, 0), .48, 1.46, color)
	body.scale.z = .91
	var face := Node3D.new()
	face.name = "BeanFace"
	rig.add_child(face)
	# Face plate is distinct from the bright suit, with oversized expressive eyes.
	_sphere(face, Vector3(0, 1.14, -.407), Vector3(.68, .57, .19), NAVY, .16)
	for side in [-1, 1]:
		_sphere(face, Vector3(side * .15, 1.16, -.511), Vector3(.13, .23, .045), CREAM, .18)
		_sphere(face, Vector3(side * .15 - .023, 1.21, -.54), Vector3(.039, .059, .014), Color.WHITE, .1)
	var belt := _ring(rig, Vector3(0, .63, 0), .45, .047, CREAM)
	belt.scale.z = .89
	var jersey := _sphere(rig, Vector3(0, .85, .405), Vector3(.58, .60, .105), NAVY)
	var number := _text(rig, str(id), Vector3(0, .89, .469), 68, .0052, CREAM)
	var front_number := _text(rig, str(id), Vector3(0, .72, -.447), 44, .0038, CREAM)
	front_number.rotation.y = PI
	var cap := _sphere(rig, Vector3(0, 1.68, 0), Vector3(.24, .10, .28), CREAM)
	var left_arm := _capsule(rig, Vector3(-.44, .95, 0), .12, .5, color)
	var right_arm := _capsule(rig, Vector3(.44, .95, 0), .12, .5, color)
	var left_hand := _sphere(rig, Vector3(-.55, .85, -.04), Vector3(.31, .38, .34), color)
	var right_hand := _sphere(rig, Vector3(.55, .85, -.04), Vector3(.31, .38, .34), color)
	var left_foot := _sphere(rig, Vector3(-.24, .15, -.09), Vector3(.38, .29, .52), NAVY)
	var right_foot := _sphere(rig, Vector3(.24, .15, -.09), Vector3(.38, .29, .52), NAVY)
	_sphere(left_foot, Vector3(0, -.21, 0), Vector3(.96, .22, .98), CREAM)
	_sphere(right_foot, Vector3(0, -.21, 0), Vector3(.96, .22, .98), CREAM)
	var marker := _ring(root, Vector3(0, .085, 0), .73, .055, CREAM)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var arrow := _box(root, Vector3(0, .087, -.95), Vector3(.15, .026, .29), CREAM)
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var label := _text(root, "PLAYER %d" % id, Vector3(0, 2.15, 0), 28, .0058, CREAM, true)
	label.outline_size = 5
	var shadow := _shadow(.54, Color(.07, .14, .20, .17))
	var costume := Node3D.new()
	rig.add_child(costume)
	var dunk_ring := _ring(root, Vector3(0, 1.3, 0), .80, .038, GOLD)
	dunk_ring.material_override = _mat(GOLD, .3, .0, .7)
	dunk_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dunk_ring.visible = false
	var pass_marker := _ring(root, Vector3(0, .12, 0), 1.0, .055, GOLD)
	pass_marker.material_override = _mat(GOLD, .4, 0, .5)
	pass_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pass_marker.visible = false
	var catch_ring := _ring(rig, Vector3(0, 1.27, -.72), .55, .035, Color("6df069"))
	catch_ring.rotation.x = PI / 2
	catch_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	catch_ring.visible = false
	var streaks: Array[MeshInstance3D] = []
	for i in 3:
		var streak := _sphere(root, Vector3.ZERO, Vector3(.045, .045, 1.1), CREAM)
		streak.material_override = _mat(CREAM, .4, 0, .2)
		streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		streak.visible = false
		streaks.append(streak)
	var actor := {"root": root, "rig": rig, "face": face, "body": body, "left_arm": left_arm, "right_arm": right_arm, "left_hand": left_hand, "right_hand": right_hand, "left_foot": left_foot, "right_foot": right_foot, "marker": marker, "arrow": arrow, "label": label, "shadow": shadow, "jersey": jersey, "belt": belt, "number": number, "cap": cap, "front_number": front_number, "costume": costume, "equipment": "", "phase": float(id), "last_pos": Vector3.ZERO, "initialized": false, "grounded": true, "jump_count": 0, "heading": 0.0, "twirl": 0.0, "landing": 0.0, "landing_force": 0.0, "last_velocity": Vector3.ZERO, "team": 0 if id <= 3 else 1, "dunk_ring": dunk_ring, "last_dunk": 0.0, "pass_selected": false, "pass_marker": pass_marker, "catch_ring": catch_ring, "streaks": streaks}
	_update_team_material(actor, id)
	actors[id] = actor
	return actor

func _update_team_material(actor: Dictionary, id: int) -> void:
	var color: Color = PALETTE[(id - 1) % PALETTE.size()]
	var accent: Color = BLUE if int(actor.get("team", 0 if id <= 3 else 1)) == 0 else ORANGE
	if mode == "versus":
		accent = color
	actor["jersey"].material_override = _mat(accent.darkened(.30), .45)
	actor["cap"].material_override = _mat(accent, .4)
	actor["equipment"] = ""

func _equip_actor(actor: Dictionary, id: int, equipment: Dictionary, player_team: int = -999) -> void:
	if player_team != -999:
		actor["team"] = player_team
	var team_id := int(actor.get("team", 0 if id <= 3 else 1))
	var outfit := str(equipment.get("outfit", "blank"))
	var accessory := str(equipment.get("accessory", "none"))
	var character := str(equipment.get("character", "blank"))
	var key := character + ":" + outfit + ":" + accessory + ":" + str(team_id) + ":" + mode
	if key == str(actor["equipment"]):
		return
	actor["equipment"] = key
	var costume: Node3D = actor["costume"]
	for old in costume.get_children():
		costume.remove_child(old)
		old.queue_free()
	var color: Color = PALETTE[(id - 1) % PALETTE.size()] if mode == "versus" else (BLUE if team_id == 0 else ORANGE).lightened(((id - 1) % 3) * .035)
	var accent: Color = (BLUE if team_id == 0 else ORANGE) if mode != "versus" else color
	for item in ["jersey", "belt", "number", "front_number", "cap"]:
		actor[item].visible = outfit == "jersey" and item != "cap"
	actor["belt"].position.y = .63
	actor["belt"].scale = Vector3(1,.999,.89)
	actor["front_number"].position = Vector3(0,.72,-.447)
	actor["number"].position = Vector3(0,.89,.469)
	for item in ["body", "left_hand", "right_hand", "left_arm", "right_arm"]:
		actor[item].material_override = _mat(GOLD if outfit == "gold" else color, .24 if outfit == "gold" else .38, .55 if outfit == "gold" else .0)
	match outfit:
		"jersey":
			if character == "blank":
				_sphere(costume, Vector3(0, .76, -.403), Vector3(.60, .49, .08), accent.darkened(.3))
			else:
				actor["jersey"].visible = false
				actor["belt"].position.y = .51
				actor["belt"].scale = Vector3(1.14,.45,.88)
				actor["front_number"].position = Vector3(0,.85,-.424)
				actor["number"].position = Vector3(0,.85,.424)
			actor["front_number"].visible = true
		"stripes":
			for height in [.57, .78, .97]:
				var stripe := _ring(costume, Vector3(0, height, 0), .466 if character == "blank" else .524, .028, CREAM)
				stripe.scale.z = .9 if character == "blank" else .78
		"hoodie":
			if character == "blank":
				_sphere(costume, Vector3(0, 1.31, .13), Vector3(1.055, 1.01, .97), accent.darkened(.18))
			else:
				_sphere(costume, Vector3(0, .98, .19), Vector3(1.02, .32, .94), accent.darkened(.18))
			if character == "blank":
				_capsule(costume, Vector3(0, .69, .025), .491, .93, accent.darkened(.18))
				_sphere(costume, Vector3(0, .61, -.43), Vector3(.44, .25, .07), accent.darkened(.3))
			else:
				var pouch := ImmediateMesh.new()
				pouch.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
				var points := [Vector3(-.24,.55,-.425),Vector3(.24,.55,-.425),Vector3(.17,.78,-.425),Vector3(-.17,.78,-.425)]
				for index in [0,2,1,0,3,2]:
					pouch.surface_set_normal(Vector3.FORWARD)
					pouch.surface_add_vertex(points[index])
				pouch.surface_end()
				_mesh(costume,pouch,Vector3.ZERO,_mat(accent.darkened(.3),.85))
				for side in [-1,1]:
					_rod(costume,Vector3(side*.17,.78,-.431),Vector3(side*.24,.55,-.431),.008,accent.darkened(.42))
			for side in [-1, 1]:
				_rod(costume, Vector3(side * .15, 1.02, -.46), Vector3(side * .13, .77, -.49), .018, CREAM)
		"space":
			var collar := _ring(costume, Vector3(0, 1.0, 0), .475, .056, CREAM)
			collar.scale.z = .93
			_box(costume, Vector3(0, .73, -.465), Vector3(.40, .31, .09), CREAM)
			for side in [-1, 1]:
				_sphere(costume, Vector3(side * .10, .75, -.525), Vector3(.07, .07, .035), CORAL if side < 0 else TEAL)
			_capsule(costume, Vector3(-.19, .88, .48), .15, .68, CREAM)
			_capsule(costume, Vector3(.19, .88, .48), .15, .68, CREAM)
			_box(costume, Vector3(0, .88, .52), Vector3(.16, .45, .16), NAVY)
		"gold":
			var trim := _ring(costume, Vector3(0, .62, 0), .462, .03, CREAM)
			trim.scale.z = .9
	var headgear := Node3D.new()
	headgear.name = "Headgear"
	costume.add_child(headgear)
	match accessory:
		"cap":
			if character == "blank":
				_sphere(headgear, Vector3(0, 1.62, .015), Vector3(.77, .36, .73), accent.darkened(.3))
				_sphere(headgear, Vector3(0, 1.54, -.35), Vector3(.76, .09, .49), accent)
			else:
				var dome := SphereMesh.new()
				dome.radius = .46
				dome.height = .32
				dome.is_hemisphere = true
				dome.radial_segments = 32
				dome.rings = 12
				var hat := _mesh(headgear,dome,Vector3(0,1.90,.025),_mat(accent.darkened(.30),.85))
				hat.scale.z = .94
				_sphere(headgear,Vector3(0,1.92,-.34),Vector3(.84,.065,.56),accent,.85)
				_sphere(headgear,Vector3(0,2.23,.025),Vector3.ONE*.07,accent,.85)
		"sweatband":
			var band := _ring(headgear, Vector3(0, 1.48, 0), .40, .055, CREAM)
			band.scale.z = .91
		"shades":
			_box(headgear, Vector3(0, 1.17, -.54), Vector3(.60, .09, .06), GOLD)
			for side in [-1, 1]:
				_sphere(headgear, Vector3(side * .16, 1.15, -.556), Vector3(.27, .24, .06), Color("142744"), .08)
				_rod(headgear, Vector3(side * .10, 1.20, -.592), Vector3(side * .20, 1.13, -.592), .012, SKY)
		"headphones":
			if character == "blank":
				var band := _ring(headgear, Vector3(0, 1.24, .035), .505, .052, NAVY)
				band.rotation.x = PI / 2
			else:
				for i in 20:
					var a := PI*i/20.0
					var b := PI*(i+1)/20.0
					_rod(headgear,Vector3(cos(a)*.505,1.24+sin(a)*.505,.035),Vector3(cos(b)*.505,1.24+sin(b)*.505,.035),.052,NAVY)
			for side in [-1, 1]:
				_sphere(headgear, Vector3(side * .48, 1.2, .02), Vector3(.23, .40, .34), NAVY)
				_sphere(headgear, Vector3(side * .57, 1.2, .02), Vector3(.08, .27, .23), GOLD)
		"horns":
			for side in [-1, 1]:
				var cone := CylinderMesh.new()
				cone.top_radius = .025
				cone.bottom_radius = .145
				cone.height = .46
				cone.radial_segments = 16
				var horn := _mesh(headgear, cone, Vector3(side * .35, 1.75, 0), _mat(CREAM, .32))
				horn.rotation.z = -side * .40
		"crown":
			_ring(headgear, Vector3(0, 1.72, 0), .31, .075, GOLD)
			for i in 5:
				var angle := TAU * i / 5.0
				var cone := CylinderMesh.new()
				cone.top_radius = .0
				cone.bottom_radius = .13
				cone.height = .31
				cone.radial_segments = 3
				_mesh(headgear, cone, Vector3(cos(angle) * .29, 1.89, sin(angle) * .29), _mat(GOLD, .24, .4))
				_sphere(headgear, Vector3(cos(angle) * .29, 2.065, sin(angle) * .29), Vector3.ONE * .08, CREAM)
	FamilyVisual.apply(actor, character, outfit, accessory, headgear)

func present(state: Dictionary, local_id: int, dt: float, yaw: float, pitch: float) -> void:
	if not built:
		build(str(state.get("mode", "coop")))
	var next_mode := str(state.get("mode", mode))
	if next_mode != mode:
		build(next_mode)
	dt = clampf(dt, 0.0, .1)
	local_player_id = local_id
	clock_time += dt
	var players: Dictionary = state.get("players", {})
	var ball: Dictionary = state.get("ball", {})
	var names: Dictionary = state.get("names", {})
	var cosmetics: Dictionary = state.get("cosmetics", {})
	var owner := int(ball.get("owner", 0))
	var ball_pos: Vector3 = ball.get("pos", Vector3(0, .43, 0))
	var incoming_ball_pos := ball_pos
	catch_context_valid = not ball.is_empty() and float(state.get("reset_time",0)) <= 0
	for id in actors:
		actors[id]["root"].visible = players.has(id)
		actors[id]["shadow"].visible = players.has(id)
	for raw_id in players:
		var id := int(raw_id)
		var data: Dictionary = players[raw_id]
		var actor: Dictionary = actors[id] if actors.has(id) else _make_actor(id)
		actor["pass_selected"] = id == int(state.get("pass_target_preview", 0))
		_equip_actor(actor, id, cosmetics.get(id, {}), int(data.get("team", 0 if id <= 3 else 1)))
		_present_actor(actor, id, data, id == local_id, owner == id, ball_pos, str(names.get(id, "YOU" if id == local_id else ("RIVAL %d" % (id - 3) if id > 3 else "PLAYER %d" % id))), dt)
	if owner > 0 and actors.has(owner) and players.has(owner):
		# Carry attachment uses the same final root as both hands. The app has
		# already predicted the ball; this is only the actor's visual root offset.
		var incoming_carrier: Vector3 = players[owner].get("pos", Vector3.ZERO)
		carry_ball_offset = actors[owner].get("carry_offset", actors[owner]["root"].position - incoming_carrier)
		release_ball_offset = Vector3.ZERO
		release_input_time = 0.0
		ball_pos += carry_ball_offset
	else:
		if previous_ball_owner > 0:
			# Preserve the final carry attachment at release, then converge quickly
			# to the app's predicted flight without changing its trajectory.
			release_ball_offset = carry_ball_offset
			release_input_time = 0.0
		if ball.is_empty() or (float(state.get("reset_time", 0)) > 0 and float(state.get("celebration_time", 0)) <= 0):
			release_ball_offset = Vector3.ZERO
		# A quick catch/pass can still be gathering a metre in front of the
		# physical hand. An unconstrained exponential correction pulled that ball
		# backwards against its flight. Retire only this release offset within a
		# fraction of incoming travel; steady loose-ball motion is unfiltered.
		# When prediction reaches its age cap, a nonzero velocity does not imply
		# a moving target. Freeze the residual until another sample advances it.
		var flight_velocity: Vector3 = ball.get("vel",Vector3.ZERO)
		var incoming_step := incoming_ball_pos-previous_ball_input
		release_input_time += dt
		if previous_ball_owner == 0 and incoming_step.length_squared() > .00000001:
			var correction := release_ball_offset * (exp(-28.0*minf(release_input_time,.1))-1.0)
			correction = correction.limit_length(incoming_step.length()*.65)
			var horizontal := Vector3(flight_velocity.x,0,flight_velocity.z)
			if horizontal.length_squared() > .01:
				var direction := horizontal.normalized()
				var along := correction.dot(direction)
				var minimum := -maxf(0,incoming_step.dot(direction))*.65
				if along < minimum: correction += direction*(minimum-along)
			release_ball_offset += correction
			release_input_time = 0.0
		ball_pos += release_ball_offset
		carry_ball_offset = Vector3.ZERO
	previous_ball_owner = owner
	previous_ball_input = incoming_ball_pos
	ball_presented = not ball.is_empty()
	_present_pass_trail(ball_pos,owner == 0 and int(ball.get("pass_target",0)) > 0 and float(state.get("reset_time",0)) <= 0,dt)
	ball_root.visible = not ball.is_empty()
	ball_shadow.visible = not ball.is_empty()
	if not ball.is_empty():
		ball_root.position = ball_pos
		var velocity: Vector3 = ball.get("vel", Vector3.ZERO)
		if owner == 0 and velocity.length() > .01:
			ball_root.rotate(Vector3(velocity.z, .2, -velocity.x).normalized(), velocity.length() * dt / .43)
		ball_shadow.position = _ground(ball_pos, .07)
		ball_shadow.basis = Basis(Quaternion(Vector3.UP, _floor_normal(ball_pos.x, ball_pos.z)))
		ball_shadow.scale = Vector3.ONE * clampf(1.0 + (ball_pos.y - _floor_height(ball_pos.x, ball_pos.z)) * .12, 1.0, 2.3)
		ball_shadow.visible = ball_pos.y < 12.0
	_present_events(state, local_id, ball_pos)
	_present_powers(state, dt)
	_present_boosters(players, local_id)
	_present_hazards(state)
	var preview: Variant = state.get("aim_preview", PackedVector3Array())
	var preview_material := aim_bad_material if bool(state.get("aim_bad", false)) else aim_good_material
	for i in preview_dots.size():
		preview_dots[i].visible = i < preview.size()
		if i < preview.size():
			preview_dots[i].position = preview[i]
			preview_dots[i].material_override = preview_material
	_advance_effects(dt)
	_update_camera(players, local_id, dt, yaw, pitch, state)
	_update_occluders(local_id > 0 and players.has(local_id),dt)
	_layout_player_labels(players,local_id,owner,ball_pos)

func _present_pass_trail(at: Vector3, active: bool, dt: float) -> void:
	pass_trail_mesh.clear_surfaces()
	if not active:
		pass_history.clear()
		pass_sample_clock = 0
		return
	if not pass_history.is_empty() and pass_history[0].distance_to(at) > 8: pass_history.clear()
	pass_sample_clock += dt
	if pass_history.is_empty() or pass_sample_clock >= .025:
		pass_history.push_front(at)
		pass_sample_clock = 0
		if pass_history.size() > 13: pass_history.pop_back()
	if pass_history.size() < 2: return
	var drawing := false
	for i in range(pass_history.size()-1):
		var a := at if i == 0 else pass_history[i]
		var b := pass_history[i+1]
		var direction := b-a
		if direction.length_squared() < .00001: continue
		if not drawing:
			pass_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			drawing = true
		var across := direction.cross(camera.global_position-(a+b)*.5).normalized()
		var head := across*.19*(1.0-float(i)/13)
		var tail := across*.19*(1.0-float(i+1)/13)
		var ca := Color(1.0,.80,.16,.85*(1.0-float(i)/13))
		var cb := Color(1.0,.80,.16,.85*(1.0-float(i+1)/13))
		for vertex in [a-head,a+head,b-tail,b-tail,a+head,b+tail]:
			pass_trail_mesh.surface_set_color(ca if vertex == a-head or vertex == a+head else cb)
			pass_trail_mesh.surface_add_vertex(vertex)
	if drawing: pass_trail_mesh.surface_end()

func _present_powers(state: Dictionary, dt: float) -> void:
	var seen_pads: Array[String] = []
	for pad in state.get("power_pads", []):
		var at: Vector3 = pad.get("pos", Vector3.ZERO)
		var key := "%s_%s_%s" % [pad.get("owner", 0), snappedf(at.x, .01), snappedf(at.z, .01)]
		seen_pads.append(key)
		if not temporary_pads.has(key):
			var node := Node3D.new()
			effect_root.add_child(node)
			_terrain_disc(node, at, 0, 1.22, NAVY, .09)
			_terrain_disc(node, at, 0, 1.04, Color("b464ef"), .13)
			_terrain_disc(node, at, .94, 1.09, CREAM, .155)
			var spring := _ring(node, _ground(at, .24), .54, .065, GOLD)
			temporary_pads[key] = {"node": node, "spring": spring}
		var spring: Node3D = temporary_pads[key]["spring"]
		spring.scale.y = 1.0 + sin(clock_time * 8) * .3
		temporary_pads[key]["node"].visible = float(pad.get("time", 10.0)) > 2.0 or int(clock_time * 8) % 2 == 0
	for key in temporary_pads.keys():
		if key not in seen_pads:
			temporary_pads[key]["node"].queue_free()
			temporary_pads.erase(key)
	var seen_orbs: Array[int] = []
	var sample_clock := float(state.get("snapshot_clock",state.get("clock",0.0)))
	var render_clock := float(state.get("clock",sample_clock))
	var active := float(state.get("reset_time",0))<=0 and float(state.get("celebration_time",0))<=0 and int(state.get("winner",-1))<0
	var age := clampf(render_clock-sample_clock,0,.08) if active else 0.0
	for orb in state.get("power_balls", []):
		var id := int(orb.get("id", 0))
		var at: Vector3 = orb.get("pos", Vector3.ZERO)
		if id<=0 or float(orb.get("time",0))<=age: continue
		seen_orbs.append(id)
		if not power_orbs.has(id):
			var node := Node3D.new()
			effect_root.add_child(node)
			var shell := _sphere(node, Vector3.ZERO, Vector3.ONE * .63, Color("b57bff"))
			shell.material_override = _mat(Color("b57bff"), .15, .1, .7)
			_ring(node, Vector3.ZERO, .38, .045, CREAM)
			var trail: Array[Node3D] = []
			for index in 6:
				var mote := _sphere(effect_root, at, Vector3.ONE * (.25 - index * .028), Color("c297ff"))
				mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				trail.append(mote)
			power_orbs[id] = {"node": node, "trail": trail}
		var node: Node3D = power_orbs[id]["node"]
		at = _power_orb_position(power_orbs[id],orb,state,age,sample_clock,render_clock)
		node.position = at
		node.rotate_z(dt * 6)
		node.rotate_y(dt * 4)
		var previous := at
		for mote in power_orbs[id]["trail"]:
			mote.position = at if bool(power_orbs[id].get("reset_trail",false)) else mote.position.lerp(previous, 1 - exp(-18.0 * dt))
			previous = mote.position
	for id in power_orbs.keys():
		if id not in seen_orbs:
			power_orbs[id]["node"].visible = false
			power_orbs[id]["node"].queue_free()
			for mote in power_orbs[id]["trail"]:
				mote.visible = false
				mote.queue_free()
			power_orbs.erase(id)

func _power_orb_position(entry: Dictionary, orb: Dictionary, state: Dictionary, age: float, sample_clock: float, render_clock: float) -> Vector3:
	# Only the joined presentation carries snapshot_clock. Offline/host samples
	# stay exact; client velocity extrapolation shares the existing80ms clock.
	var position: Vector3 = orb.get("pos",Vector3.ZERO)
	var velocity: Vector3 = orb.get("vel",Vector3.ZERO)
	var predicted := position+velocity*age
	var round_id := str(state.get("match_id",""))
	var networked := state.has("snapshot_clock")
	var reset: bool = not entry.has("sample_clock") or str(entry.get("round_id",""))!=round_id or sample_clock<float(entry.get("sample_clock",sample_clock))-.0001
	entry["reset_trail"] = reset
	var correction := Vector3.ZERO
	if networked and not reset:
		var clock_step := clampf(render_clock-float(entry["render_clock"]),0,.08)
		var new_sample: bool = not is_equal_approx(sample_clock,float(entry["sample_clock"])) or position!=Vector3(entry["sample_position"])
		if new_sample:
			var expected: Vector3 = entry["position"]+Vector3(entry["velocity"])*clock_step
			correction = expected-predicted
			if correction.length()>2.0:
				correction = Vector3.ZERO
				entry["reset_trail"] = true
		else:
			correction = entry.get("correction",Vector3.ZERO)
			var travel := predicted-Vector3(entry["predicted"])
			var retirement := (-correction*(1-exp(-24*clock_step))).limit_length(travel.length()*.65)
			correction += retirement
	var shown := predicted+correction
	entry["sample_clock"] = sample_clock
	entry["render_clock"] = render_clock
	entry["round_id"] = round_id
	entry["sample_position"] = position
	entry["predicted"] = predicted
	entry["position"] = shown
	entry["velocity"] = velocity
	entry["correction"] = correction
	return shown

func _register_occluder(node: Node3D, center: Vector3, radius: float, basket_section: bool = false) -> void:
	var materials: Array[StandardMaterial3D] = []
	var bounds: Array[AABB] = []
	for child in node.find_children("*","GeometryInstance3D",true,false):
		if basket_section: bounds.append(child.global_transform*child.get_aabb())
		if child.material_override is StandardMaterial3D:
			var material := child.material_override.duplicate() as StandardMaterial3D
			child.material_override = material
			materials.append(material)
	occluders.append({"node":node,"center":center,"radius":radius,"materials":materials,"opacity":1.0,"basket_section":basket_section,"bounds":bounds})

func _update_occluders(following: bool, dt: float = 1.0 / 60) -> void:
	var ray := camera_target - camera.position
	var length_squared := ray.length_squared()
	var protected: Array[Vector3] = []
	if following and actors.has(local_player_id):
		protected.append(actors[local_player_id]["body"].global_position)
		if ball_root.visible and previous_ball_owner == local_player_id: protected.append(ball_root.global_position)
	for entry in occluders:
		var node: Node3D = entry["node"]
		node.visible = true
		var obstruction := false
		if following and bool(entry.get("basket_section",false)):
			for target in protected:
				# Stop before the target so the basket behind the bean stays solid.
				var end: Vector3 = target+(camera.position-target).normalized()*.22
				for bounds in entry["bounds"]:
					if bounds.grow(.20).intersects_segment(camera.position,end) != null:
						obstruction = true
						break
				if obstruction: break
		elif following and length_squared > .01:
			var center: Vector3 = entry["center"]
			var along := (center - camera.position).dot(ray) / length_squared
			if along > -.15 and along < .85:
				var closest := camera.position + ray * clampf(along, 0, 1)
				obstruction = closest.distance_to(center) < float(entry["radius"])
		var alpha := lerpf(float(entry.get("opacity",1.0)),.10 if obstruction else 1.0,1-exp(-16*dt))
		entry["opacity"] = alpha
		for material in entry.get("materials",[]):
			material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if alpha > .995 else BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color.a = alpha

func _label_font_height_px(label: Label3D) -> float:
	# Approximate the visible capital glyph (three quarters of the font em).
	var center := camera.unproject_position(label.global_position)
	var height_world := camera.global_basis.y * label.font_size * label.pixel_size * label.scale.y * .75
	return camera.unproject_position(label.global_position-height_world).distance_to(center)

func _label_screen_rect(label: Label3D) -> Rect2:
	var center := camera.unproject_position(label.global_position)
	var width := ThemeDB.fallback_font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.font_size).x * label.pixel_size * label.scale.x
	var half_world := camera.global_basis.x * width * .5
	var edge := camera.unproject_position(label.global_position+half_world)
	var pixels := maxf(8,absf(edge.x-center.x)*2)
	var height_world := camera.global_basis.y * label.font_size * label.pixel_size * label.scale.y
	var height := maxf(14,camera.unproject_position(label.global_position-height_world).distance_to(center))
	return Rect2(center-Vector2(pixels*.5+3,height*.5+3),Vector2(pixels+6,height+6))

func _layout_player_labels(players: Dictionary, local_id: int, owner: int, ball_pos: Vector3) -> void:
	var candidates: Array = []
	var occupied: Array[Rect2] = []
	if ball_root.visible and not camera.is_position_behind(ball_pos):
		var point := camera.unproject_position(ball_pos)
		var edge := camera.unproject_position(ball_pos+camera.global_basis.x*(_dimension("BALL_RADIUS",.52)+.16))
		var radius := maxf(10,point.distance_to(edge))+5
		occupied.append(Rect2(point-Vector2.ONE*radius,Vector2.ONE*radius*2))
		var hud_point := camera.unproject_position(ball_pos+Vector3.UP*.9)
		occupied.append(Rect2(hud_point-Vector2(18,18),Vector2(36,36)))
	for id in actors:
		var actor: Dictionary = actors[id]
		var label: Label3D = actor["label"]
		label.visible = false
		if not players.has(id) or id == local_id or local_id <= 0: continue
		var distance := camera.position.distance_to(actor["root"].position)
		var important: bool = bool(actor["pass_selected"]) or id == owner
		if distance > (65.0 if important else 38.0) or camera.is_position_behind(label.global_position): continue
		candidates.append({"id":id,"priority":distance-(100.0 if important else 0.0),"distance":distance})
	candidates.sort_custom(func(a,b):return a.priority < b.priority)
	var viewport := camera.get_viewport().get_visible_rect().grow(-12)
	for candidate in candidates:
		var actor: Dictionary = actors[candidate.id]
		var label: Label3D = actor["label"]
		var size: float = actor.get("visual_size",1.0)
		label.scale = Vector3.ONE
		label.scale *= clampf(14.5/maxf(.01,_label_font_height_px(label)),1.0,7.0)
		var accepted := false
		for rise in [0.0,.40,.80,1.20]:
			label.position = Vector3(0,(2.65 if actor.get("character", "blank") != "blank" else 2.15)*size+rise,0)
			var rect := _label_screen_rect(label)
			if not viewport.encloses(rect): continue
			var overlap := false
			for other in occupied:
				if rect.intersects(other.grow(3)): overlap = true; break
			if overlap: continue
			occupied.append(rect)
			accepted = true
			break
		label.visible = accepted

func _present_actor(actor: Dictionary, id: int, data: Dictionary, is_local: bool, holding: bool, ball_pos: Vector3, player_name: String, dt: float) -> void:
	var root: Node3D = actor["root"]
	var rig: Node3D = actor["rig"]
	var position: Vector3 = data.get("pos", Vector3.ZERO)
	var velocity: Vector3 = data.get("vel", Vector3.ZERO)
	var facing: Vector3 = data.get("facing", Vector3.FORWARD)
	var grounded := bool(data.get("grounded", true))
	var new_catch := holding and not bool(actor.get("was_holding",false))
	if new_catch:
		actor["catch_recoil"] = .24
	actor["catch_recoil"] = maxf(0,float(actor.get("catch_recoil",0)) - dt)
	if not bool(actor["grounded"]) and grounded:
		actor["landing"] = .24
		actor["landing_force"] = clampf(absf(actor["last_velocity"].y) / 22.0, .25, 1.0)
		if is_local:
			impact_shake = maxf(impact_shake, .025 + float(actor["landing_force"]) * .025)
	actor["landing"] = maxf(0, float(actor["landing"]) - dt)
	var stun := float(data.get("stun", 0.0))
	var knockback := float(data.get("knockback_time", 0.0))
	if knockback>float(actor.get("last_knockback",0))+.05:
		var local_impulse := root.basis.inverse()*velocity
		actor["impact_roll_side"] = signf(local_impulse.x) if absf(local_impulse.x)>.4 else (-1.0 if id%2==0 else 1.0)
	actor["last_knockback"] = knockback
	var dive := float(data.get("dive", 0.0))
	var dunk := float(data.get("dunk", 0.0))
	if dunk > 0:
		# The assisted approach owns its axis until follow-through finishes;
		# fresh look input may already differ from the committed basket contact.
		facing = data.get("dunk_direction", data.get("aim", facing))
	var boost_time := float(data.get("boost_time", 0))
	if boost_time > 0 and float(actor.get("last_boost", 0)) <= 0:
		_burst(_ground(position, .10), GOLD, "jump", 14)
		if is_local: impact_shake = .035
	actor["last_boost"] = boost_time
	var dunk_duration := float(data.get("dunk_duration", _dimension("DUNK_DURATION", 1.5)))
	var dunk_phase := 1.0 - dunk / dunk_duration
	var slam_at := dunk_duration * (1.0-Simulation.DUNK_RELEASE_PHASE)
	var catch_time := float(data.get("catch_time", 0))
	var request_time := float(data.get("request_time", 0))
	var giant := 1.8 if float(data.get("giant", 0.0)) > 0.0 else 1.0
	var visual_size := lerpf(float(actor.get("visual_size", 1.0)), giant, 1 - exp(-14.0 * dt))
	actor["visual_size"] = visual_size
	var dunk_ring: Node3D = actor["dunk_ring"]
	dunk_ring.visible = dunk > slam_at
	if dunk > slam_at:
		var windup := dunk_phase
		dunk_ring.scale = Vector3.ONE * (.8 + windup * .6) * giant
		dunk_ring.position.y = (1.15 + windup * .55) * giant
		dunk_ring.rotation = Vector3(sin(clock_time * 10) * .20, 0, cos(clock_time * 10) * .20)
	if float(actor["last_dunk"]) > slam_at and dunk <= slam_at and stun <= 0:
		var target: Vector3 = sim_constants["SOUTH"] if mode != "versus" and int(actor["team"]) == 1 else sim_constants["NORTH"]
		_slam_burst(target)
		if is_local: impact_shake = .16
	actor["last_dunk"] = dunk
	var jumps := int(data.get("jump_count", 0))
	if jumps > int(actor["jump_count"]): actor["takeoff"] = .18
	actor["takeoff"] = maxf(0,float(actor.get("takeoff",0)) - dt)
	if jumps > int(actor["jump_count"]) and jumps > 1:
		actor["twirl"] = .40
	actor["twirl"] = maxf(0.0, float(actor["twirl"]) - dt)
	var speed := Vector2(velocity.x, velocity.z).length()
	var intent: Vector3 = data.get("move",Vector3.ZERO)
	intent.y = 0
	var horizontal := Vector3(velocity.x,0,velocity.z)
	var traction_pose := grounded and stun <= 0 and dive <= 0 and dunk <= 0 and boost_time <= 0
	var effort := clampf(intent.length(),0,1) if traction_pose else 0.0
	var opposition := maxf(0,-intent.normalized().dot(horizontal.normalized())) if speed > .1 else 0.0
	var skid_target := opposition * smoothstep(1.0,5.5,speed) * effort
	var scramble_target := effort * (1.0-smoothstep(1.0,6.5,speed))
	actor["skid"] = lerpf(float(actor.get("skid",0)),skid_target,1-exp(-20*dt)) if traction_pose else 0.0
	actor["scramble"] = lerpf(float(actor.get("scramble",0)),scramble_target,1-exp(-18*dt)) if traction_pose else 0.0
	var skid: float = actor["skid"]
	var scramble: float = actor["scramble"]
	if facing.length_squared() > .01:
		actor["heading"] = atan2(-facing.x, -facing.z)
	if not bool(actor["initialized"]) or root.position.distance_to(position) > 6.0:
		root.position = position
		root.rotation.y = float(actor["heading"])
		actor["initialized"] = true
	else:
		root.position = root.position.lerp(position, 1.0 - exp(-22.0 * dt))
		root.rotation.y = lerp_angle(root.rotation.y, float(actor["heading"]), 1.0 - exp(-14.0 * dt))
	root.visible = true
	actor["phase"] = float(actor["phase"]) + dt * (7.0 + speed * 1.3 + 15.0*maxf(skid,scramble))
	var phase := float(actor["phase"])
	var running := maxf(clampf(speed / 7.0, 0.0, 1.0),scramble*.88)
	if stun>0: running = 0.0
	var bounce := absf(sin(phase)) * .09 * running if grounded else .0
	rig.position = Vector3(0, bounce, 0)
	var lean := clampf(speed * .013, 0, .12)
	var tilt := Vector3(-lean, 0, sin(phase) * running * .065)
	var squash := Vector3(1.0, 1.0, 1.0)
	if traction_pose:
		var local_intent := root.basis.inverse()*intent.normalized()
		tilt.x += local_intent.z * (.30*skid+.12*scramble)
		tilt.z -= local_intent.x * (.18*skid+.08*scramble)
		squash = Vector3(1+.07*skid,1-.11*skid,1+.045*skid)
		rig.position.y -= .055*skid
	if float(actor["landing"]) > 0:
		var landing := sin(float(actor["landing"]) / .24 * PI) * float(actor["landing_force"])
		squash = Vector3(1 + landing * .12, 1 - landing * .18, 1 + landing * .12)
	if not grounded:
		tilt.x = clampf(-velocity.y * .013, -.22, .18)
		var launch_stretch := sin(float(actor["takeoff"])/.18*PI)
		squash = Vector3(.98-launch_stretch*.05,1.02+launch_stretch*.10,.98-launch_stretch*.05)
	if float(actor["catch_recoil"]) > 0 and dunk <= 0:
		var absorb := sin(float(actor["catch_recoil"])/.24*PI)
		tilt.x += absorb * .16
		squash *= Vector3(1+absorb*.035,1-absorb*.045,1+absorb*.035)
	if dive > .0:
		var dive_elapsed := .34-dive
		var commitment := smoothstep(0,.065,dive_elapsed)*(1-smoothstep(.25,.34,dive_elapsed))
		tilt.x = -1.25*commitment
		rig.position.y += .30*commitment
		squash *= Vector3(1+.07*commitment,1-.12*commitment,1+.05*commitment)
	if stun > .0:
		# A tackle produces one impact roll and recovery. Clock-driven wobble
		# repeatedly shook the body while the physical recovery remained fixed.
		var recovery := 1.0-clampf(knockback/.65,0,1)
		var roll := sin(minf(recovery/.76,1)*PI)*1.85 if knockback>0 else .45
		var brace := 1.0-smoothstep(.52,1.0,recovery) if knockback>0 else 1.0
		tilt = Vector3(.42*brace,0,float(actor.get("impact_roll_side",1))*(roll+.25*brace))
		rig.position.y += .12*brace+.60*maxf(0,sin(roll))
	if dunk > .0:
		var gather := 1.0 - smoothstep(0, .18, dunk_phase)
		var reach := smoothstep(.08, Simulation.DUNK_REACH_PHASE, dunk_phase) * (1.0 - smoothstep(Simulation.DUNK_RELEASE_PHASE, 1.0, dunk_phase))
		var slam := smoothstep(Simulation.DUNK_RELEASE_PHASE-.08,Simulation.DUNK_RELEASE_PHASE+.12,dunk_phase)
		tilt.x = -.22 * gather - .23 * reach - .38 * slam
		# Rotate around the torso through the reach, then uncurl into the slam.
		var side_roll := smoothstep(.04, .22, dunk_phase) * (1 - smoothstep(.50, .79, dunk_phase))
		tilt.z = side_roll * 1.5 * (1.0 if id % 2 else -1.0)
		squash = Vector3(1 + gather * .06 - reach * .07, 1 - gather * .09 + reach * .10, 1 + gather * .06 - reach * .04)
	rig.rotation = rig.rotation.lerp(tilt, 1 - exp(-14.0 * dt))
	if dunk > 0:
		var torso_pivot := Vector3(0, .96, 0)
		rig.position += torso_pivot - Basis.from_euler(rig.rotation) * torso_pivot
	if float(actor["twirl"]) > 0 and not grounded and dive <= 0 and dunk <= 0:
		# A compact tuck keeps held-ball contact readable through the extra jump.
		var tuck := sin((1 - float(actor["twirl"]) / .4) * PI)
		rig.rotation.x -= tuck * .30
		rig.rotation.z = tuck * .16
	rig.scale = rig.scale.lerp(squash * giant, 1 - exp(-14.0 * dt))
	var left_foot: Node3D = actor["left_foot"]
	var right_foot: Node3D = actor["right_foot"]
	var left_target := Vector3(-.24, .15 + maxf(0, sin(phase)) * .18 * running, -.09 + cos(phase) * .24 * running)
	var right_target := Vector3(.24, .15 + maxf(0, -sin(phase)) * .18 * running, -.09 - cos(phase) * .24 * running)
	var foot_pitch := sin(phase) * .3 * running
	if traction_pose and maxf(skid,scramble) > .01:
		var churn := maxf(skid,scramble)
		var local_slide := root.basis.inverse()*horizontal.normalized()
		var plant := local_slide * (.16*skid)
		var left_churn := Vector3(-.27,.13+maxf(0,sin(phase))*.16,-.07+cos(phase)*.11)+plant
		var right_churn := Vector3(.27,.13+maxf(0,-sin(phase))*.16,-.07-cos(phase)*.11)+plant
		left_target = left_target.lerp(left_churn,churn)
		right_target = right_target.lerp(right_churn,churn)
		foot_pitch = lerpf(foot_pitch,sin(phase)*.48,churn)
	if not grounded:
		var tuck := clampf(velocity.y / 20.0, 0, 1)
		left_target = Vector3(-.25, .19 + tuck * .15, .10 + tuck * .25)
		right_target = Vector3(.25, .15 + tuck * .08, .05 + tuck * .16)
		foot_pitch = -.35 * tuck
	if dive > 0:
		left_target = Vector3(-.29,.25,.38)
		right_target = Vector3(.29,.38,.20)
		foot_pitch = -.70
	if dunk > 0:
		var knee := sin(clampf(dunk_phase / .85, 0, 1) * PI)
		left_target = Vector3(-.28, .17 + knee * .22, .15 + knee * .37)
		right_target = Vector3(.28, .16 + knee * .10, .07 + knee * .26)
		foot_pitch = -.45 * knee
	if stun>0 and knockback>0:
		left_target = Vector3(-.30,.31,.24)
		right_target = Vector3(.29,.24,.33)
		foot_pitch = -.48
	left_foot.position = left_foot.position.lerp(left_target, 1 - exp(-18 * dt))
	right_foot.position = right_foot.position.lerp(right_target, 1 - exp(-18 * dt))
	left_foot.rotation.x = lerp_angle(left_foot.rotation.x, foot_pitch, 1 - exp(-16 * dt))
	right_foot.rotation.x = lerp_angle(right_foot.rotation.x, -foot_pitch if grounded else foot_pitch, 1 - exp(-16 * dt))
	var hands: Array = [actor["left_hand"], actor["right_hand"]]
	# Grow the carried pose with the visible body; physical Giant activation is
	# instantaneous, but its presentation should not stretch the arms first.
	var held_ball := root.position + (ball_pos - position) * (visual_size / giant)
	if not holding or not catch_context_valid:
		actor["catch_active"] = false
	elif new_catch:
		# Catch contact begins where the loose ball was actually drawn. Both hands
		# and the ball share this short gather; ongoing loose flight is unfiltered.
		actor["catch_active"] = ball_presented and ball_root.position.distance_to(held_ball) < 3.5*giant
		actor["catch_anchor"] = ball_root.position
		actor["catch_progress"] = 0.0
	if holding and bool(actor.get("catch_active",false)):
		var gather_time: float = actor.get("catch_progress",0.0)
		held_ball = Vector3(actor["catch_anchor"]).lerp(held_ball,smoothstep(0,.10,gather_time))
		actor["catch_progress"] = gather_time + dt
		if gather_time >= .10: actor["catch_active"] = false
	actor["carry_offset"] = held_ball - ball_pos
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var hand: Node3D = hands[i]
		var target := Vector3(side * .56, .85 + sin(phase + i * PI) * .14 * running, -.04 + cos(phase + i * PI) * .19 * running)
		if holding:
			var local_ball := rig.to_local(held_ball)
			target = local_ball + Vector3(side * .32, -.08, .11)
		elif catch_time > 0:
			target = Vector3(side * .42,1.24 + .05*sin(clock_time*12),-.86)
		elif dive > 0:
			target = Vector3(side*.45,1.18+(i*.10),-.78)
		elif not grounded:
			target = Vector3(side * .62, 1.18 + .08*sin(phase+i), -.24)
		elif request_time > 0 and i == 1:
			target = Vector3(.52, 1.87 + sin(clock_time * 10) * .07, -.12)
		if dunk > 0:
			if holding:
				target = rig.to_local(held_ball) + Vector3(side * .30, -.06, .07)
			else:
				var hoop: Vector3 = sim_constants["SOUTH"] if mode != "versus" and int(actor["team"]) == 1 else sim_constants["NORTH"]
				var aim: Vector3 = data.get("dunk_direction", data.get("aim", facing))
				var across := Vector3(-aim.z, 0, aim.x).normalized()
				var contact := hoop - aim * _dimension("RIM_RADIUS", 1.65) + across * side * .32 + Vector3.UP * .06
				target = rig.to_local(contact).lerp(target,smoothstep(.91,1.0,dunk_phase))
		if stun > 0:
			target = Vector3(side * .67,1.06,-.19)
		# Held-ball contact is solved after body scale and rotation, including
		# Giant growth/shrink. The free-hand animation can still ease naturally.
		hand.position = target if holding else hand.position.lerp(target, 1 - exp(-20 * dt))
		var arm: Node3D = actor["left_arm"] if i == 0 else actor["right_arm"]
		var shoulder := Vector3(side * .40, 1.03, 0)
		var arm_direction := hand.position - shoulder
		arm.position = (shoulder + hand.position) * .5
		var axis_y := arm_direction.normalized()
		var helper := Vector3.RIGHT if absf(axis_y.dot(Vector3.UP)) > .98 else Vector3.UP
		var axis_x := helper.cross(axis_y).normalized()
		arm.basis = Basis(axis_x, axis_y, axis_x.cross(axis_y).normalized()) * Basis.from_scale(Vector3(1, maxf(.2, arm_direction.length() / .5), 1))
	var marker: MeshInstance3D = actor["marker"]
	marker.visible = true
	var team_color: Color = BLUE if int(actor["team"]) == 0 else ORANGE
	if mode == "versus": team_color = PALETTE[(id - 1) % PALETTE.size()]
	marker.material_override = _mat(CREAM if is_local else (GOLD if holding else team_color), .5, .0, .2)
	marker.position.y = Simulation.surface_height(root.position,root.position.y) + .085 - root.position.y
	marker.global_basis = Basis(Quaternion(Vector3.UP, _floor_normal(root.position.x, root.position.z))).scaled(Vector3.ONE * (1.0 + .04 * sin(clock_time * 5)) * sqrt(giant))
	var pass_marker: MeshInstance3D = actor["pass_marker"]
	pass_marker.visible = bool(actor["pass_selected"]) or request_time > 0
	pass_marker.position.y = marker.position.y + .025
	pass_marker.global_basis = marker.global_basis.scaled(Vector3.ONE * (1.05 + sin(clock_time * 7) * .05))
	actor["catch_ring"].visible = catch_time > 0 and not holding and stun <= 0
	actor["catch_ring"].scale = Vector3.ONE * (1.0 + sin(clock_time * 12) * .07)
	for i in 3:
		var streak: MeshInstance3D = actor["streaks"][i]
		streak.visible = speed > 14 and stun <= 0 and dunk <= 0
		if streak.visible:
			var direction := velocity.normalized()
			var side := Vector3(-direction.z, 0, direction.x).normalized()
			streak.global_position = root.global_position + Vector3.UP * (1.0 + i * .10) - direction * (1.0 + i * .35) + side * (i - 1) * .35
			streak.look_at(streak.global_position + direction, Vector3.UP if absf(direction.y) < .95 else Vector3.RIGHT)
			streak.scale = Vector3(.045, .045, .7 + speed * .04)
	actor["arrow"].visible = is_local
	actor["arrow"].position.y = marker.position.y
	var label: Label3D = actor["label"]
	label.position.y = (2.65 if actor.get("character", "blank") != "blank" else 2.15) * giant
	var shown_name := player_name.left(18)
	if label.text != shown_name: label.text = shown_name
	label.modulate = CREAM if is_local else team_color.lightened(.3)
	var shadow: Node3D = actor["shadow"]
	shadow.visible = true
	shadow.position = _ground(root.position, .07)
	shadow.basis = Basis(Quaternion(Vector3.UP, _floor_normal(root.position.x, root.position.z)))
	shadow.scale = Vector3.ONE * clampf(1.0 + (position.y - _floor_height(position.x, position.z)) * .12, 1.0, 1.7) * giant
	if bool(actor["grounded"]) == false and grounded and velocity.y <= .1:
		_burst(position + Vector3.UP * .07, Color("fff4d4"), "land", 7)
	if jumps > int(actor["jump_count"]) and jumps > 1:
		_burst(position + Vector3.UP * .25, PALETTE[(id - 1) % PALETTE.size()], "jump", 12)
	actor["grounded"] = grounded
	actor["jump_count"] = jumps
	actor["last_pos"] = position
	actor["last_velocity"] = velocity
	actor["was_holding"] = holding

func _present_events(state: Dictionary, local_id: int, ball_pos: Vector3) -> void:
	var event := int(state.get("event_id", -1))
	if event == last_event:
		return
	var previous := last_event
	last_event = event
	if previous < 0 or event < previous:
		return
	var kind := str(state.get("event_kind", ""))
	var position: Vector3 = state.get("event_pos", ball_pos)
	var event_player := int(state.get("event_player", local_id))
	if not state.has("event_pos") and kind in ["jump", "tackle"] and actors.has(event_player):
		position = actors[event_player]["root"].position + Vector3.UP * .1
	match kind:
		"boost":
			_burst(position + Vector3.UP * .12, GOLD, "jump", 14)
			if event_player == local_id: impact_shake = .035
		"jump":
			_burst(position, CREAM, kind, 7)
		"grab":
			_burst(position, GOLD, kind, 7)
		"throw":
			_burst(position, CREAM, kind, 5)
		"tackle":
			_burst(position + Vector3.UP * .2, CREAM, "contact_dust", 8)
			_tackle_flash(position + Vector3.UP * .35)
			if actors.has(local_id) and actors[local_id]["root"].position.distance_to(position) < 4:
				impact_shake = .15
		"dunk":
			_burst(position, GOLD, kind, 22)
			if event_player == local_id: impact_shake = .11
		"power":
			_burst(position + Vector3.UP, Color("c486ff"), "dunk", 24)
			if event_player == local_id: impact_shake = .12
		"score", "win":
			score_flash = 1.0
			_burst(position, GOLD, kind, 36)
			_burst(position + Vector3.UP * .3, TEAL, kind, 20)

func _burst(at: Vector3, color: Color, kind: String, count: int) -> void:
	var duration := .7 if kind in ["dunk", "score"] else .36
	if kind in ["jump", "land", "tackle", "dunk", "score"]:
		var ring := _ring(effect_root, at, .38, .034, color)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		effects.append({"node": ring, "life": duration, "total": duration, "vel": Vector3.ZERO, "ring": true})
	for i in count:
		var angle := TAU * float(i) / count + clock_time
		var up := 2.0 + float(i % 4) * .8 if kind in ["score", "dunk"] else .4 + float(i % 3) * .35
		var speed := 2.8 if kind in ["score", "dunk"] else 1.65
		var part: MeshInstance3D
		if kind in ["score", "dunk"]:
			part = _box(effect_root, at, Vector3(.12, .05, .18), color)
		else:
			part = _sphere(effect_root, at, Vector3.ONE * .1, color)
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		effects.append({"node": part, "life": duration, "total": duration, "vel": Vector3(cos(angle) * speed, up, sin(angle) * speed), "ring": false})

func _tackle_flash(at: Vector3) -> void:
	var flash := ImmediateMesh.new()
	flash.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 12:
		var a := TAU*i/12.0
		var b := TAU*(i+1)/12.0
		var first := Vector3(cos(a),sin(a),0)*(.72 if i%2==0 else .14)
		var second := Vector3(cos(b),sin(b),0)*(.72 if (i+1)%2==0 else .14)
		for point in [Vector3.ZERO,first,second]: flash.surface_add_vertex(point)
	flash.surface_end()
	var material := _mat(CREAM,1)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node := _mesh(effect_root,flash,at,material)
	node.look_at(camera.global_position)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effects.append({"node":node,"life":.16,"total":.16,"vel":Vector3.ZERO,"ring":false,"flash":true})

func _slam_burst(at: Vector3) -> void:
	_burst(at, GOLD, "dunk", 18)
	for i in 10:
		var angle := TAU * i / 10.0
		var radial := Vector3(cos(angle), 0, sin(angle))
		var shard := _rod(effect_root, at + radial * .45, at + radial * 1.35 + Vector3.DOWN * 1.0, .045, CREAM if i % 2 == 0 else GOLD)
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		effects.append({"node": shard, "life": .35, "total": .35, "vel": radial * 2.2 + Vector3.DOWN * 5.5, "ring": false})

func _advance_effects(dt: float) -> void:
	score_flash = maxf(0, score_flash - dt * 1.4)
	impact_shake = maxf(0, impact_shake - dt * .6)
	for hoop in hoop_lights:
		var material := hoop.material_override as StandardMaterial3D
		material.albedo_color = CREAM.lerp(GOLD, score_flash)
		material.emission_enabled = score_flash > 0
		material.emission = GOLD
		material.emission_energy_multiplier = score_flash * .8
	for i in range(effects.size() - 1, -1, -1):
		var effect: Dictionary = effects[i]
		effect["life"] = float(effect["life"]) - dt
		var node: Node3D = effect["node"]
		if float(effect["life"]) <= 0:
			node.queue_free()
			effects.remove_at(i)
			continue
		var progress := 1.0 - float(effect["life"]) / float(effect["total"])
		if bool(effect.get("flash",false)):
			node.scale = Vector3.ONE*(1-progress)
		elif bool(effect["ring"]):
			node.scale = Vector3.ONE * (1 + progress * 4.0)
			node.scale.y = 1.0 - progress
		else:
			var velocity: Vector3 = effect["vel"]
			velocity.y -= dt * 5.0
			effect["vel"] = velocity
			node.position += velocity * dt
			node.rotate_y(dt * 5)
			node.scale = Vector3.ONE * (1.0 - progress * .9)

func _overview_position() -> Vector3:
	return Vector3(_dimension("HALF_WIDTH", 20) * 2.45, _dimension("HALF_LENGTH", 36) * 1.3, _dimension("HALF_LENGTH", 36) * 1.3)

func _update_camera(players: Dictionary, local_id: int, dt: float, yaw: float, pitch: float, state: Dictionary = {}) -> void:
	if local_id <= 0 or not players.has(local_id):
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		camera_seat = -1
		camera_ready = false
		var overview := _overview_position()
		camera.position = camera.position.lerp(overview, 1 - exp(-3 * dt))
		camera.fov = lerpf(camera.fov, 72.0, 1 - exp(-5 * dt))
		camera.look_at(Vector3(0, .8, -1))
		return
	var player: Dictionary = players[local_id]
	var position: Vector3 = player.get("pos", Vector3.ZERO)
	var velocity: Vector3 = player.get("vel", Vector3.ZERO)
	var speed := Vector2(velocity.x, velocity.z).length()
	var rush := clampf((speed - _dimension("SPEED", 9.5)) / 8.5, 0.0, 1.0)
	if float(player.get("boost_time", 0)) > 0: rush = 1.0
	var behind := Vector3(sin(yaw), 0, cos(yaw))
	pitch = clampf(pitch, .15, .9)
	# Move both target and boom forward together: close framing, unchanged aim yaw.
	var target := position + Vector3.UP * lerpf(1.6, 1.7, rush) - behind * lerpf(1.1, 1.5, rush)
	var wanted_distance := lerpf(7.8, 10.5, rush)
	var wanted_fov := lerpf(72.0, 76.0, rush)
	if bool(state.get("ball_camera", false)) and state.get("camera_focus") is Vector3:
		var focus: Vector3 = state["camera_focus"]
		var forward := -behind * cos(pitch) - Vector3.UP * sin(pitch)
		var view_up := Vector3.UP * cos(pitch) - behind * sin(pitch)
		var points: Array[Vector3] = [position, position + Vector3.UP * 1.75, focus + Vector3.UP * .65, focus - Vector3.UP * .65]
		# Solve a vertical framing interval. A distant hoop already inside the view
		# causes no zoom; a ball above the player expands only as far as needed.
		for attempt in 36:
			var lower := -INF
			var upper := INF
			var tangent := tan(deg_to_rad(wanted_fov) * .5)
			for point in points:
				var relative := point - target
				var depth := maxf(.2, wanted_distance + relative.dot(forward))
				lower = maxf(lower, relative.dot(view_up) - .76 * depth * tangent)
				upper = minf(upper, relative.dot(view_up) + .78 * depth * tangent)
			if lower <= upper:
				target += view_up * clampf(0, lower, upper)
				break
			wanted_distance = minf(26, wanted_distance + .5)
			wanted_fov = minf(80, wanted_fov + .25)
	if not camera_ready or camera_seat != local_id or camera_target.distance_to(target) > 16:
		camera_target = target
		camera_distance = wanted_distance
		camera.fov = wanted_fov
		camera_ready = true
		camera_seat = local_id
	else:
		camera_target.x = lerpf(camera_target.x, target.x, 1 - exp(-14 * dt))
		camera_target.z = lerpf(camera_target.z, target.z, 1 - exp(-14 * dt))
		camera_target.y = lerpf(camera_target.y, target.y, 1 - exp(-(10.0 if velocity.y > 0 else 13.0) * dt))
		camera_distance = lerpf(camera_distance, wanted_distance, 1 - exp(-6 * dt))
		camera.fov = lerpf(camera.fov, wanted_fov, 1 - exp(-6 * dt))
	camera.position = camera_target + behind * cos(pitch) * camera_distance + Vector3.UP * sin(pitch) * camera_distance
	camera.position.y = maxf(camera.position.y, _floor_height(camera.position.x, camera.position.z) + .8)
	camera.look_at(camera_target)
	# Translation-only impact feedback never rotates the player's aim direction.
	camera.h_offset = sin(clock_time * 67.0) * impact_shake
	camera.v_offset = cos(clock_time * 79.0) * impact_shake * .65

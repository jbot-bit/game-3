extends RefCounted
## Authored curved atoll. One mesh and matching triangle collision replace the
## rectangular land slabs; established movement routes remain flat at y=2.
const Art=preload("res://game/world/block_art.gd")
const SECTORS: int=96
const BANDS: int=7
const HORIZONTAL_SCALE: float=0.42
static var _triangles: Array[PackedVector3Array]=[]

static func layout_point(at: Vector3) -> Vector3:
	return at*Vector3(HORIZONTAL_SCALE,1.0,HORIZONTAL_SCALE)

static func point(angle: float, band: int, flat_routes: Array[Rect2]) -> Vector3:
	var outward:=Vector2(cos(angle),sin(angle))
	var tide_bay: float=maxf(0.0,1.0-absf(wrapf(angle-0.28,-PI,PI))/0.38)
	var variation: float=sin(angle*3.0+0.5)*2.7+sin(angle*7.0)*1.2-tide_bay*20.0
	var outer:=outward*Vector2(106.0+variation,94.0+variation)
	# A rounded cove preserves water beneath the existing docks and boat.
	# An ellipse here swallowed the fishing water at the corner habitats.
	var inner_radius: float=1.0/pow(pow(absf(outward.x)/54.0,8.0)+pow(absf(outward.y)/47.5,8.0),0.125)
	var inner:=outward*inner_radius
	var position_2d: Vector2
	var height: float
	match band:
		0:
			position_2d=inner-outward*2.0; height=-0.35
		1:
			position_2d=inner; height=0.5
		2:
			position_2d=inner+outward*4.0; height=2.0
		3:
			position_2d=inner.lerp(outer,0.56); height=2.0
		4:
			position_2d=outer-outward*5.0; height=2.0
		5:
			position_2d=outer-outward; height=0.45
		_:
			position_2d=outer+outward*2.0; height=-0.35
	position_2d*=HORIZONTAL_SCALE
	if band in [3,4]:
		var on_route: bool=false
		for rect in flat_routes:
			# Coarse radial triangles interpolate from these hill vertices across
			# the route. Keep a full terrain-cell shoulder flat as well, rather
			# than letting a distant raised vertex lift the patrol floor.
			if rect.grow(5.0).has_point(position_2d): on_route=true; break
		if not on_route:
			height+=pow(maxf(0.0,sin(angle*3.0-0.8)),2.0)*(2.8 if band==4 else 1.2)
	return Vector3(position_2d.x,height,position_2d.y)

static func build(parent: Node3D, flat_routes: Array[Rect2]) -> void:
	_triangles.clear()
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sector in range(SECTORS):
		var first: float=float(sector)*TAU/float(SECTORS)
		var second: float=float(sector+1)*TAU/float(SECTORS)
		# The south opening is the real sailing channel, not a visual gap over land.
		if first<1.72 and second>1.42: continue
		for band in range(BANDS-1):
			var a: Vector3=point(first,band,flat_routes)
			var b: Vector3=point(second,band,flat_routes)
			var c: Vector3=point(second,band+1,flat_routes)
			var d: Vector3=point(first,band+1,flat_routes)
			_triangles.append(PackedVector3Array([a,c,b]))
			_triangles.append(PackedVector3Array([a,d,c]))
			var color: Color=Color("d9c69c") if band in [0,1,4,5] else Color("76974d")
			color=color.lightened(float(sector%3)*0.015)
			# Godot front faces use clockwise winding. The upward collision face
			# must match the visible surface, including the unpropped beach.
			for vertex in [a,c,b,a,d,c]:
				surface.set_color(color)
				surface.add_vertex(vertex)
	surface.generate_normals()
	var mesh:=MeshInstance3D.new()
	mesh.name="CurvedIsland"
	mesh.mesh=surface.commit()
	var material:=ShaderMaterial.new()
	material.shader=preload("res://game/world/coastal_ground.gdshader")
	mesh.material_override=material
	parent.add_child(mesh)
	mesh.create_trimesh_collision()

static func height_at(at: Vector3) -> float:
	# Build-time decoration placement against the same triangles as collision.
	# No terrain sampling is performed in the movement/render loop.
	var p:=Vector2(at.x,at.z)
	for triangle in _triangles:
		var a:=Vector2(triangle[0].x,triangle[0].z)
		var b:=Vector2(triangle[1].x,triangle[1].z)
		var c:=Vector2(triangle[2].x,triangle[2].z)
		var denominator: float=(b-a).cross(c-a)
		if absf(denominator)<0.00001: continue
		var u: float=(p-a).cross(c-a)/denominator
		var v: float=(b-a).cross(p-a)/denominator
		if u>=-0.0001 and v>=-0.0001 and u+v<=1.0001:
			return triangle[0].y*(1.0-u-v)+triangle[1].y*u+triangle[2].y*v
	return at.y

static func ridge(parent: Node3D, at: Vector3) -> void:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(8):
		var a: float=float(index)*TAU/8.0
		var b: float=float(index+1)*TAU/8.0
		var low_a:=layout_point(Vector3(cos(a)*13.0,0,sin(a)*5.0))
		var low_b:=layout_point(Vector3(cos(b)*13.0,0,sin(b)*5.0))
		var high_a:=layout_point(Vector3(cos(a)*7.0,4.8+sin(a*3.0)*0.5,sin(a)*2.7))
		var high_b:=layout_point(Vector3(cos(b)*7.0,4.8+sin(b*3.0)*0.5,sin(b)*2.7))
		surface.set_color(Color("859187").lightened(float(index%3)*0.035))
		for vertex in [low_a,high_b,high_a,low_a,low_b,high_b]: surface.add_vertex(vertex)
		surface.set_color(Color("76974d"))
		for vertex in [high_a,high_b,Vector3(0,5.3,0)]: surface.add_vertex(vertex)
	surface.generate_normals()
	var mesh:=MeshInstance3D.new()
	mesh.name="NorthRidge"
	mesh.mesh=surface.commit()
	mesh.position=at
	var material:=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.roughness=1.0
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	mesh.material_override=material
	parent.add_child(mesh)
	mesh.create_trimesh_collision()

class_name IslandWorld
extends Node3D
## An authored, walkable ring island. Ground is y=2; open water is y=0.
## Named markers are interaction positions, not the centres of solid props.

const Art = preload("res://game/world/block_art.gd")
const Coast = preload("res://game/world/coastal_art.gd")
const Terrain = preload("res://game/world/island_terrain.gd")
const GROUND_Y: float = 2.0
const LAYOUT_SCALE: float=Terrain.HORIZONTAL_SCALE
static func layout_point(at: Vector3) -> Vector3:
	return Terrain.layout_point(at)

const ROUTE_POINTS: Array[Vector3] = [
	Vector3(-27.72,2.05,-23.31),Vector3(-27.72,2.05,4.2),
	Vector3(-27.72,2.05,23.94),Vector3(27.72,2.05,23.94),
	Vector3(27.72,2.05,4.2),Vector3(27.72,2.05,-23.31),
	Vector3(-22.26,2.05,20.16),Vector3(-27.72,2.05,20.16),
	Vector3(-18.9,2.05,-17.64),Vector3(-18.9,2.05,-22.68),
	Vector3(22.68,2.05,-12.18),Vector3(27.3,2.05,-12.18),
	Vector3(-6.72,2.05,4.2),Vector3(6.72,2.05,4.2),
	# Approach the ridge by its open ends, and keep the north route clear of
	# the rock at (36,-50). These are walkable alternatives, not obstacle removal.
	Vector3(27.72,2.05,-24.36),Vector3(29.4,2.05,-23.94),
	Vector3(29.4,2.05,-18.9),Vector3(28.14,2.05,-16.8),
	Vector3(18.48,2.05,-23.94),Vector3(-27.72,2.05,-16.8),
	# The rounded cove leaves a beach below the Lido's north face. Reach its
	# platform over the supported western shoulder instead of dropping to sand.
	Vector3(-22.26,2.05,-19.404),Vector3(-21.42,2.05,-18.69),
	# Full-size rocks and cache crates keep their clearance in the compact layout.
	Vector3(-29.4,2.05,-10.5),Vector3(-29.4,2.05,-17),
	Vector3(26,2.05,15.5),Vector3(26,2.05,22),
	Vector3(-27.72,2.05,2.1),Vector3(29,2.05,6),Vector3(29,2.05,11.5),
	Vector3(-30,2.05,0),Vector3(29,2.05,-4),Vector3(29,2.05,-14),
]
## Conservatively flat route corridors inside the curved terrain. Beaches are
## excluded from hunter shortcuts. Validate real body traversal after edits.
const WALKABLE_SLABS: Array[Rect2] = [
	Rect2(-34.23,-27.72,10.5,54.6),Rect2(-32.34,-28.77,64.68,7.77),
	Rect2(23.73,-27.72,10.5,55.44),Rect2(-32.34,19.95,28.14,8.82),Rect2(4.2,19.95,28.14,8.82),
	Rect2(-27.72,17.16,6.72,6),Rect2(-21.84,18.52,2.52,1.6),Rect2(-21.84,-21.64,5.88,8),
	Rect2(21,-15.18,4.2,6),Rect2(-24.36,1.2,18.48,6),Rect2(5.88,1.2,18.48,6),
	Rect2(-24.36,-21,3.36,2.52),Rect2(-23.13,-22.18,3,5.2),
]
var markers: Dictionary = {
	"spawn": Vector3(-67.0, 2.05, 44.0),
	"boat": Vector3(-52.0, 2.05, 48.0),
	"jetty": Vector3(-66.0, 2.05, 5.0),
	"reeds": Vector3(65.0, 2.05, -30.0),
	"lens_cache": Vector3(-42.0, 2.05, -57.0),
	"rod_cache": Vector3(67.0, 2.05, 44.0),
	"repair_cache": Vector3(-70.0, 2.05, 14.0),
	"repair": Vector3(-15.0, 2.05, 10.0),
	"vote": Vector3(-60.0, 2.05, 42.0),
	"terraces": Vector3(-44,2.05,-43),
	"tidepools": Vector3(68,2.05,27),
	"beacon": Vector3(66,2.05,-53),
	"ridge_parts_cache": Vector3(-34,2.05,-55),
	"beacon_parts_cache": Vector3(66,2.05,-61),
	"engine_cache": Vector3(71,2.05,37),
	"reel_cache": Vector3(48,2.05,56),
	"workshop_repair": Vector3(-59,2.05,48),
	"ridge_repair": Vector3(66,2.05,-50),
	"beacon_repair": Vector3(69,2.05,-53),
	"engine_repair": Vector3(-52,2.05,48),
}
var _environment: Environment
var _sky_material: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _home_light: OmniLight3D
var _boat_light: OmniLight3D
var _water: MeshInstance3D
var _water_material: ShaderMaterial
var _repaired_span: Node3D
var _broken_barriers: Node3D
var _station_lights: Dictionary = {}
var _station_glows: Dictionary = {}
var _station_states: Dictionary = {"jetty": true, "reeds": true}
var _cache_nodes: Dictionary = {}
var _cache_states: Dictionary = {}
var _ripples: Array[MeshInstance3D] = []
var _repaired: bool = false
var _fog: bool = false
var _elapsed: float = 0.0
var _route_links: Array[Vector2i] = []
var _route_links_valid: bool = false
var _route_capsule: CapsuleShape3D
var _ridge_span: Node3D
var _ridge_repaired: bool=false
var _beacon_lamp: OmniLight3D
var _beacon_glass: MeshInstance3D
var _workshop_upgrade: Node3D
var _engine_upgrade: Node3D
var _beacon_powered: bool=false
var _shadows_requested: bool=true
var _reduced_effects: bool=false

func _init() -> void:
	for id: String in markers: markers[id]=layout_point(markers[id] as Vector3)
	markers["repair"]=Vector3(-7.2,2.05,4.2)
	markers["repair_cache"]=Vector3(-32,2.05,0)
	markers["rod_cache"]=Vector3(-31,2.05,8)
	markers["tidepools"]=Vector3(29,2.05,-3)
	markers["engine_cache"]=Vector3(31,2.05,-4)
	markers["reel_cache"]=Vector3(31,2.05,-16)
	markers["vote"]=Vector3(-33.5,2.05,20.5)
	markers["reeds_cast"]=markers["reeds"]+Vector3(0,0,9)
	markers["hunter_spawn"]=markers["reeds"]+Vector3(0,0,8)
	# Stable cinematic anchors keep consumers independent of island dimensions.
	markers["refuge_mooring"]=layout_point(Vector3(-10,1,20))
	markers["escape_channel"]=layout_point(Vector3(0,1,40))
	markers["escape_destination"]=layout_point(Vector3(0,1,112))

func _ready() -> void:
	name = "LastLightIsland"
	_build_light_and_sea()
	_build_land()
	_build_paths()
	_build_home()
	_build_lido()
	_build_reeds()
	_build_shortcut()
	_build_campaign()
	_build_landmarks()
	_build_station("jetty", markers["jetty"] as Vector3, "JETTY SHELTER")
	_build_station("reeds", markers["reeds"] as Vector3, "REEDS SHELTER")
	_build_cache("lens_cache", "WORKSHOP CACHE", Art.WATER)
	_build_cache("rod_cache", "SHORE CACHE", Color("dca66f"))
	_build_cache("repair_cache", "BRASS FITTING", Art.AMBER)
	_build_cache("ridge_parts_cache", "TERRACE BRACES", Art.CREAM)
	_build_cache("beacon_parts_cache", "BEACON COIL", Art.AMBER)
	_build_cache("engine_cache", "MOTH ENGINE PART", Color("d98167"))
	_build_cache("reel_cache", "REEL KIT", Art.WATER)
	_build_vote_board()
	Coast.meadow(self)
	Coast.camp(get_node("HomeCove"))
	set_repaired(_repaired)
	for station: String in _station_states.keys():
		set_station(station, bool(_station_states[station]))
	for cache_id: String in _cache_states.keys():
		set_cache_opened(cache_id, bool(_cache_states[cache_id]))
	set_time(_elapsed)
	set_fog(_fog)

func _node(node_name: String, at: Vector3 = Vector3.ZERO) -> Node3D:
	var item: Node3D = Node3D.new()
	item.name = node_name
	item.position = at
	add_child(item)
	return item

func _label(parent: Node3D, text: String, at: Vector3, large: bool = false) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = text
	label.position = at
	label.font_size = 48 if large else 32
	label.pixel_size = 0.006 if large else 0.0045
	label.modulate = Art.CREAM
	label.outline_modulate = Art.INK
	label.outline_size = 7
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	# Nearby floating signs must not fill the camera or obscure crew names.
	label.visibility_range_begin = 4.0 if large else 1.5
	label.visibility_range_begin_margin = 0.6
	label.visibility_range_end = 42.0 if large else 17.0
	label.visibility_range_end_margin = 2.0
	parent.add_child(label)
	return label

func _glow(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.9
	return mat

func _build_light_and_sea() -> void:
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.name = "IslandEnvironment"
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sky_top_color = Color("729bab")
	_sky_material.sky_horizon_color = Color("e5ccad")
	_sky_material.ground_horizon_color = Color("e5ccad")
	_sky_material.ground_bottom_color = Art.WATER
	_sky_material.sun_angle_max = 7.0
	sky.sky_material = _sky_material
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("a6c4cd")
	_environment.ambient_light_energy = 0.65
	_environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	_environment.fog_light_color = Color("7eabb7")
	_environment.fog_density = 0.00065
	_environment.fog_enabled = true
	world_environment.environment = _environment
	add_child(world_environment)
	_sun = DirectionalLight3D.new()
	_sun.name = "SunAndMoon"
	_sun.rotation_degrees = Vector3(-41.0, -32.0, 0.0)
	_sun.light_color = Color("f4e8d3")
	_sun.light_energy = 0.52
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 95.0
	add_child(_sun)
	_water = Art.box(self, Vector3(0.0, -0.15, 0.0), Vector3(1600.0, 0.3, 1600.0), Art.WATER)
	_water.name = "Sea"
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_water_material = ShaderMaterial.new()
	_water_material.shader=preload("res://game/world/coastal_water.gdshader")
	_water_material.set_shader_parameter("layout_scale",LAYOUT_SCALE)
	_water.material_override = _water_material

func _land(center: Vector3, size: Vector3) -> void:
	Art.box(self, center + Vector3(0.0, -0.32, 0.0), size + Vector3(1.0, 0.0, 1.0), Color("b7a886"))
	var ground: MeshInstance3D=Art.box(self, center, size, Color("659577"), true)
	var meadow_material=ShaderMaterial.new()
	meadow_material.shader=preload("res://game/world/coastal_ground.gdshader")
	ground.material_override=meadow_material
	Coast.shore(self,center,size)

func _build_land() -> void:
	Terrain.build(self,WALKABLE_SLABS)
	# A compact ridge separates the lido from the eastern reed pocket.
	Terrain.ridge(self,layout_point(Vector3(21,2,-64)))
	for at: Vector3 in [Vector3(-78, 2, 27), Vector3(-76, 2, -16), Vector3(-73, 2, -43), Vector3(-23, 2, -62), Vector3(7, 2, -65), Vector3(48, 2, -62), Vector3(77, 2, -44), Vector3(78, 2, -6), Vector3(76, 2, 31), Vector3(42, 2, 63), Vector3(11, 2, 64), Vector3(-33, 2, 63)]:
		_tree(at)
	for at: Vector3 in [Vector3(-74, 2, 6), Vector3(-61, 2, -32), Vector3(36, 2, -50), Vector3(60, 2, 23), Vector3(20, 2, 52)]:
		at=layout_point(at)
		var collider: MeshInstance3D=Art.box(self, at + Vector3(0.0, 0.75, 0.0), Vector3(3.2, 1.5, 2.4), Color("849292"), true)
		collider.visible=false
		Coast.prop(self,"nature","rock_largeA",at,Vector3(3.4,2.4,3.4),0.4)

func _tree(at: Vector3) -> void:
	at=layout_point(at)
	var trunk: MeshInstance3D=Art.box(self, at + Vector3(0.0, 2.2, 0.0), Vector3(0.9, 4.4, 0.9), Art.WOOD, true)
	trunk.visible=false
	Coast.prop(self,"nature","tree_oak" if int(absf(at.z))%2==0 else "tree_pineRoundA",at,Vector3.ONE*6.4,at.x*0.1)

func _path(a: Vector3, b: Vector3, width: float = 4.0) -> void:
	a=layout_point(a)
	b=layout_point(b)
	var delta: Vector3 = b - a
	var side:=Vector3(delta.z,0,-delta.x).normalized()
	var count: int=maxi(1,int(delta.length()/3.0))
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var previous: Array[Vector3]=[]
	for index in range(count+1):
		var at: Vector3=a.lerp(b,float(index)/float(count))+side*sin(float(index)*0.8)*0.28
		var half_width: float=width*0.3*(0.93+sin(float(index)*1.7)*0.07)
		var pair: Array[Vector3]=[at+side*half_width,at-side*half_width]
		for edge in range(2): pair[edge].y=Terrain.height_at(pair[edge])+0.028
		if not previous.is_empty():
			for vertex in [previous[0],pair[0],pair[1],previous[0],pair[1],previous[1]]: surface.add_vertex(vertex)
		previous=pair
		if index%4==1:
			at+=side*half_width*0.88*(1.0 if index%8==1 else -1.0)
			at.y=Terrain.height_at(at)+0.045
			Coast.stone(self,at,Vector3(0.34,0.055,0.23),Color("d9ccb0"))
	surface.generate_normals()
	var trail:=MeshInstance3D.new()
	trail.name="Footpath"
	trail.mesh=surface.commit()
	trail.material_override=Art.material(Color("cbbb93"))
	add_child(trail)

func _build_paths() -> void:
	_path(Vector3(-66, 2.025, 48), Vector3(-66, 2.025, -57))
	_path(Vector3(-66, 2.025, -57), Vector3(66, 2.025, -57))
	_path(Vector3(66, 2.025, -57), Vector3(66, 2.025, 57))
	_path(Vector3(66, 2.025, 57), Vector3(14, 2.025, 57))
	_path(Vector3(-14, 2.025, 57), Vector3(-66, 2.025, 57))
	_path(Vector3(-66, 2.025, 57), Vector3(-66, 2.025, 43))
	_path(Vector3(-66, 2.025, 10), Vector3(-57, 2.025, 10))
	_path(Vector3(57, 2.025, 10), Vector3(66, 2.025, 10))
	_sign(Vector3(-64, 2, -41), "LIDO  >", Art.WATER)
	_sign(Vector3(52, 2, -59), "REEDS  >", Art.WATER)
	_sign(Vector3(65, 2, 51), "HOME VIA WALKWAY  ^", Art.WOOD)
	_sign(Vector3(-62, 2, 26), "MOTH  v", Art.WOOD)

func _sign(at: Vector3, text: String, color: Color) -> void:
	at=layout_point(at)
	Art.box(self, at + Vector3(0.0, 0.9, 0.0), Vector3(0.19, 1.8, 0.19), Art.WOOD, true)
	Art.box(self, at + Vector3(0.0, 1.7, 0.0), Vector3(2.3, 0.68, 0.12), color)
	_label(self, text, at + Vector3(0.0, 1.76, 0.0))

func _build_home() -> void:
	var home: Node3D = _node("HomeCove")
	Art.box(home, layout_point(Vector3(-58,1.81,48)),Vector3(16*LAYOUT_SCALE,0.38,6),Art.WOOD,true)
	for i: int in range(11):
		Art.box(home,layout_point(Vector3(-65.2+float(i)*1.4,2.015,48)),Vector3(1.32*LAYOUT_SCALE,0.04,5.8),Art.WOOD.lightened(0.12))
	for x: float in [-63.0, -56.0, -50.5]:
		for z: float in [-2.5,2.5]:
			# North piles stop under the deck, leaving the arrival side open for cargo.
			Art.box(home,layout_point(Vector3(x,0.3,48))+Vector3(0,0,z),Vector3(0.5,3.0 if z<0 else 4.8,0.5),Art.WOOD,true)
	Art.box(home,layout_point(Vector3(-49,1.8,46)),Vector3(6*LAYOUT_SCALE,0.4,1.6),Art.WOOD,true)
	var skiff: Node3D = _node("MothSkiff",layout_point(Vector3(-47.4,1,43.8)))
	Coast.prop(skiff,"watercraft","boat-row-large",Vector3(0,-0.75,0),Vector3(1.8,1.7,1.8))
	Art.beam(skiff, Vector3(1.1, 0.6, 1.9), Vector3(0.75, 4.9, 1.9), 0.18, Art.WOOD)
	_lantern(skiff, Vector3(0.75, 4.7, 1.9), 1.2)
	_boat_light = OmniLight3D.new()
	_boat_light.position = Vector3(0.0, 3.5, 0.7)
	_boat_light.omni_range = 9.0
	_boat_light.light_color = Art.AMBER
	skiff.add_child(_boat_light)
	_home_light = OmniLight3D.new()
	_home_light.position = layout_point(Vector3(-53,5,48))
	_home_light.omni_range = 15.0
	_home_light.light_color = Art.AMBER
	home.add_child(_home_light)
	var bench: Vector3=layout_point(Vector3(-60,2.05,48))+Vector3(0,0,1.6)
	var bench_collision: MeshInstance3D=Art.box(home,bench+Vector3.UP*0.57,Vector3(2.8,1.24,1.1),Art.WATER,true)
	bench_collision.visible=false
	Coast.prop(home,"survival","workbench",bench,Vector3(2.8,2.5,2))
	_label(home,"MOTH / HOME",layout_point(Vector3(-54,4,48)),true)
	_label(home,"BANK  /  WORKSHOP  /  RECHARGE",bench+Vector3.UP*1.65)
	_build_tower(Vector3(-81,2,57),7.5,"LAST LIGHT")

func _lantern(parent: Node3D, at: Vector3, size: float = 1.0) -> MeshInstance3D:
	var glass: MeshInstance3D = Art.lantern(parent,at,size)
	glass.material_override = _glow(Art.AMBER)
	return glass

func _build_lido() -> void:
	var lido: Node3D = _node("OldLido")
	Art.box(lido,layout_point(Vector3(-45,2.015,-53)),Vector3(21*LAYOUT_SCALE,0.04,17*LAYOUT_SCALE),Color("b6ae98"))
	# A short, real wooden access joins the shore to the platform over the
	# curved beach. Its top stays continuous for players and the hunter capsule.
	var approach: MeshInstance3D=Art.box(lido,layout_point(Vector3(-51.5,1.86,-46.6)),Vector3(3,0.4,5.2),Art.WOOD,true)
	approach.name="LidoApproach"
	for z: float in [-2,-1.2,-0.4,0.4,1.2,2]:
		Art.box(lido,layout_point(Vector3(-51.5,2.064,-46.6))+Vector3(0,0,z),Vector3(2.95,0.006,0.04),Art.INK)
	Art.box(lido,layout_point(Vector3(-45,1.77,-42)),Vector3(14*LAYOUT_SCALE,0.4,8),Art.WATER,true)
	for i: int in range(7):
		Art.box(lido,layout_point(Vector3(-51+float(i)*2,1.98,-42)),Vector3(1.8*LAYOUT_SCALE,0.03,7.8),Color("b5a58a") if i%2 else Color("c1b398"))
	for at: Vector3 in [Vector3(-53,2,-63),Vector3(-43,2,-63)]:
		at=layout_point(at)
		Art.box(lido, at + Vector3(0.0, 1.35, 0.0), Vector3(3.3, 2.7, 3.0), Art.WATER, true)
		Art.box(lido, at + Vector3(0.0, 2.84, 0.0), Vector3(3.6, 0.24, 3.3), Art.CREAM)
		Art.box(lido, at + Vector3(0.0, 0.0, 1.55), Vector3(1.1, 0.05, 0.5), Art.WOOD)
	_build_tower(Vector3(-37.0, 2.0, -49.0), 6.0, "OLD LIDO")
	for i: int in range(8):
		Art.box(lido,layout_point(Vector3(-54+float(i)*2.4,0.18,-30)),Vector3(0.4,0.45,0.4),Art.CREAM if i%2==0 else Color("d98167"))
	Art.beam(lido,layout_point(Vector3(-55,0.15,-30)),layout_point(Vector3(-35,0.15,-30)),0.04,Art.CREAM)

func _build_tower(at: Vector3, height: float, text: String) -> void:
	at=layout_point(at)
	var tower: Node3D = _node("Tower_" + text.replace(" ", "_"), at)
	for x: float in [-1.35, 1.35]:
		for z: float in [-1.2, 1.2]:
			Art.beam(tower, Vector3(x, 0, z), Vector3(x - 0.5, height, z), 0.22, Art.WOOD, true)
	Art.box(tower, Vector3(-0.5, height, 0), Vector3(3.7, 0.3, 3.5), Art.CREAM)
	Art.box(tower, Vector3(-0.5, height + 0.05, -2.3), Vector3(1.1, 0.2, 3.0), Art.WATER)
	_lantern(tower, Vector3(-0.5, height + 1.0, 0.0), 1.1)
	for i: int in range(8):
		Art.box(tower, Vector3(1.65, 0.5 + float(i) * 0.7, 0.0), Vector3(0.12, 0.07, 0.9), Art.CREAM)
	_label(tower, text, Vector3(0.0, height + 2.0, 0.0), true)

func _build_reeds() -> void:
	var reeds: Node3D = _node("LanternReeds")
	Art.box(reeds,layout_point(Vector3(55,1.83,-29)),Vector3(10*LAYOUT_SCALE,0.4,6),Art.WOOD,true)
	for i: int in range(16):
		var at: Vector3 = layout_point(Vector3(53-float(i%4)*1.8,0,-47+float(i)*2.4))
		var height: float = 2.4 + float(i % 3) * 0.65
		Art.box(reeds, at + Vector3(0.0, height * 0.5, 0.0), Vector3(0.17, height, 0.2), Color("7d8e57"))
		Art.box(reeds, at + Vector3(0.0, height - 0.25, 0.0), Vector3(0.31, 0.6, 0.34), Art.WOOD)
	_label(reeds,"LANTERN REEDS",layout_point(Vector3(59,6,-36)),true)
	# A large square float makes the active fishing water legible at a distance.
	Art.box(reeds,layout_point(Vector3(48,0.3,-28)),Vector3(0.8,0.55,0.8),Art.AMBER)
	Art.box(reeds,layout_point(Vector3(48,0.73,-28)),Vector3(0.18,0.45,0.18),Art.INK)

func _build_shortcut() -> void:
	var fixed: Node3D = _node("OldBoardwalk")
	for x: float in [-36.0, 36.0]:
		Art.box(fixed,layout_point(Vector3(x,1.8,10)),Vector3(44*LAYOUT_SCALE,0.4,6),Art.WOOD,true)
		for step: int in range(11):
			Art.box(fixed,layout_point(Vector3(x-20+float(step)*4,2.01,10)),Vector3(0.07,0.025,5.8),Art.INK)
	for x: float in [-53, -35, -17, 17, 35, 53]:
		for z: float in [-2.5,2.5]:
			Art.box(fixed,layout_point(Vector3(x,0.7,10))+Vector3(0,0,z),Vector3(0.3,3.6,0.3),Art.WOOD,true)
	_repaired_span = _node("RepairedCrossing")
	Art.box(_repaired_span,layout_point(Vector3(0,1.8,10)),Vector3(28*LAYOUT_SCALE,0.4,6),Art.WOOD.lightened(0.15),true)
	for i: int in range(14):
		Art.box(_repaired_span,layout_point(Vector3(-13+float(i)*2,2.015,10)),Vector3(0.06,0.03,5.85),Art.CREAM)
	for z: float in [-2.85,2.85]:
		Art.box(_repaired_span,layout_point(Vector3(0,2.55,10))+Vector3(0,0,z),Vector3(28*LAYOUT_SCALE,0.15,0.15),Art.CREAM,true)
	_broken_barriers = _node("BrokenCrossing")
	for x: float in [-13.95, 13.95]:
		Art.box(_broken_barriers,layout_point(Vector3(x,2.62,10)),Vector3(0.22,1.25,6),Art.WATER,true)
		for z: float in [-2,0,2]:
			Art.box(_broken_barriers,layout_point(Vector3(x,2.63,10))+Vector3(0,0,z),Vector3(0.25,0.22,1.1),Art.AMBER)
	_label(_broken_barriers,"BROKEN WALKWAY\n1 BRASS FITTING",layout_point(Vector3(-16,3.9,10)))

func _build_station(station: String, at: Vector3, title: String) -> void:
	var node: Node3D = _node("Station_" + station, Vector3(at.x, 2.0, at.z))
	Art.box(node, Vector3.ZERO, Vector3(7.0, 0.07, 7.0), Art.CREAM)
	Art.box(node, Vector3(2.0, 2.1, 1.7), Vector3(0.28, 4.2, 0.28), Art.WOOD, true)
	var glass: MeshInstance3D = _lantern(node, Vector3(2.0, 4.35, 1.7), 1.1)
	_station_glows[station] = glass.material_override
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Light"
	light.position = Vector3(0.0, 4.5, 0.0)
	light.omni_range = 13.0
	light.light_color = Art.AMBER
	light.light_energy = 1.7
	node.add_child(light)
	_station_lights[station] = light
	Art.box(node, Vector3(2.0, 0.45, 1.7), Vector3(0.95, 0.9, 0.7), Art.INK, true)
	# Keep the north/south return lane wide enough for a crosswise whole fish.
	Art.box(node, Vector3(-2.8, 0.55, 2.4), Vector3(0.75, 0.25, 2.5), Art.WOOD, true)
	_label(node, title, Vector3(0, 5.5, 0))

func _build_cache(cache_id: String, title: String, color: Color) -> void:
	var at: Vector3 = markers[cache_id] as Vector3
	var node: Node3D = Art.cache_crate(color)
	node.name="Cache_"+cache_id
	node.position=Vector3(at.x,2.0,at.z-1.0)
	add_child(node)
	var collider: MeshInstance3D=Art.box(node, Vector3(0, 0.38, 0), Vector3(1.45, 0.75, 0.92), color, true)
	collider.visible=false
	var label: Label3D = _label(node, title, Vector3(0, 1.7, 0))
	label.name = "Label"
	node.set_meta("title", title)
	_cache_nodes[cache_id] = node

func _build_vote_board() -> void:
	var at: Vector3 = markers["vote"] as Vector3
	Art.box(self, at + Vector3(0, 0.7, -1.2), Vector3(2.8, 1.4, 0.9), Art.WATER, true)
	Art.box(self, at + Vector3(0, 1.1, -1.19), Vector3(2.5, 0.7, 0.94), Art.CREAM)
	_label(self, "ONE BATTERY\nJETTY  /  REEDS", at + Vector3(0, 2.2, -1.2))

func _build_landmarks() -> void:
	var ridge: Node3D = _node("BeaconRidge",layout_point(Vector3(76,2,-53)))
	var collider: MeshInstance3D=Art.box(ridge, Vector3(0, 2.7, 0), Vector3(3.8, 5.4, 3.8), Art.CREAM, true)
	collider.visible=false
	var lighthouse: Node3D=Art.lighthouse()
	ridge.add_child(lighthouse)
	_beacon_glass=lighthouse.get_node("Glass")
	_beacon_lamp=OmniLight3D.new()
	_beacon_lamp.position=Vector3(0,8,0)
	_beacon_lamp.light_color=Art.AMBER
	_beacon_lamp.omni_range=22
	_beacon_lamp.visible=false
	ridge.add_child(_beacon_lamp)
	_label(ridge,"BEACON / SIGNAL",Vector3(0,9,0),true)
	_label(self,"TIDE POOLS",Vector3(31,6,-3),true)
	_label(self,"SEA CHANNEL",layout_point(Vector3(0,5,69)),true)
	for i: int in range(4):
		var at: Vector3 = Vector3(34+float(i%2)*1.3,2.35,-6+float(i)*4)
		Art.box(self, at, Vector3(3.0, 0.7, 2.7), Color("788c91"), true)
	# Low distant silhouettes sit beyond the playable water boundary.
	for at: Vector3 in [Vector3(-260, 3, -250), Vector3(210, 4, -280), Vector3(270, 2, 180)]:
		Coast.stone(self,at,Vector3(95,18,40),Color("657f86"))

func set_time(elapsed_s: float) -> void:
	_elapsed = maxf(elapsed_s, 0.0)
	if _environment == null:
		return
	var dusk: float = smoothstep(165.0, 240.0, _elapsed)
	var dawn: float = smoothstep(570.0, 630.0, _elapsed)
	var night: float = dusk * (1.0 - dawn)
	var sunset: float = maxf(0.0, 1.0 - absf(_elapsed - 197.0) / 40.0) * (1.0 - dawn)
	_environment.ambient_light_color = Color("e1ece8").lerp(Color("7793c5"), night)
	_environment.ambient_light_energy = lerpf(0.43, 0.38, night)
	_sun.light_color = Color("f4e8d3").lerp(Color("b3cbe8"), night).lerp(Color("f6ac79"), sunset * 0.65)
	_sun.light_energy = lerpf(0.92, 0.23, night)
	_home_light.light_energy = lerpf(0.45, 1.8, night)
	_boat_light.light_energy = lerpf(0.35, 1.3, night)
	for light: OmniLight3D in _station_lights.values():
		light.light_energy = lerpf(0.35, 1.7, night)
	_sun.rotation_degrees.x = lerpf(-41.0, -26.0, night)
	_sky_material.sky_top_color = Color("69aac8").lerp(Color("10213d"), night)
	_sky_material.sky_horizon_color = Color("c9e1de").lerp(Color("30456a"), night).lerp(Color("e8a47a"), sunset * 0.65)
	_sky_material.ground_horizon_color = _sky_material.sky_horizon_color
	_environment.fog_light_color = Color("8babb2").lerp(Color("4b6483"), night)
	_water_material.set_shader_parameter("deep_color",Color("166a81").lerp(Color("152b49"),night))
	_water_material.set_shader_parameter("shallow_color",Color("45a99f").lerp(Color("2d586a"),night))
	for i: int in range(_ripples.size()):
		var stripe: MeshInstance3D = _ripples[i]
		var origin: Vector3 = stripe.get_meta("origin") as Vector3
		stripe.position = origin + Vector3(sin(_elapsed * 0.16 + float(i)) * 1.5, sin(_elapsed * 0.5 + float(i)) * 0.008, 0.0)

func set_repaired(value: bool) -> void:
	if value != _repaired:
		_route_links_valid = false
	_repaired = value
	if _repaired_span == null:
		return
	if _repaired_span.has_meta("repair_applied") and bool(_repaired_span.get_meta("repair_applied"))==value:
		return
	_repaired_span.set_meta("repair_applied",value)
	_repaired_span.visible = value
	_broken_barriers.visible = not value
	_set_collision(_repaired_span, value)
	_set_collision(_broken_barriers, not value)

func _set_collision(node: Node, enabled: bool) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).set_deferred("disabled", not enabled)
	for child: Node in node.get_children():
		_set_collision(child, enabled)

func set_station(station: String, powered: bool) -> void:
	if not _station_states.has(station):
		return
	_station_states[station] = powered
	if not _station_lights.has(station):
		return
	(_station_lights[station] as OmniLight3D).visible = powered
	var mat: StandardMaterial3D = _station_glows[station] as StandardMaterial3D
	mat.emission_enabled = powered
	mat.albedo_color = Art.AMBER if powered else Color("625d52")

func set_fog(value: bool) -> void:
	_fog = value
	if _environment != null:
		_environment.fog_density = 0.007 if value else 0.00065

func set_cache_opened(cache_id: String, value: bool) -> void:
	_cache_states[cache_id] = value
	if not _cache_nodes.has(cache_id):
		return
	var cache: Node3D = _cache_nodes[cache_id] as Node3D
	(cache.get_node("Lid") as Node3D).rotation.x = -1.25 if value else 0.0
	(cache.get_node("Label") as Label3D).text = "EMPTY CACHE" if value else str(cache.get_meta("title"))

func route_step(from: Vector3, to: Vector3) -> Vector3:
	## Return one ground-supported waypoint for the stable hunter controller.
	## This is a small authored graph, not a terrain or navigation bake system.
	var start: Vector3 = Vector3(from.x, 2.05, from.z)
	var target: Vector3 = Vector3(to.x, 2.05, to.z)
	if not _route_ground(start):
		return start
	if not _route_ground(target):
		# A briefly airborne/out-of-bounds player never pulls the hunter to sea.
		var best: float = INF
		var wanted: Vector3 = target
		for point: Vector3 in ROUTE_POINTS:
			var distance: float = point.distance_squared_to(wanted)
			if distance < best:
				best = distance
				target = point
	if _route_segment(start, target):
		return target
	if not _route_links_valid:
		_route_links.clear()
		for first: int in range(ROUTE_POINTS.size()):
			for second: int in range(first + 1, ROUTE_POINTS.size()):
				if _route_segment(ROUTE_POINTS[first], ROUTE_POINTS[second]):
					_route_links.append(Vector2i(first, second))
		_route_links_valid = true
	var points: Array[Vector3] = [start, target]
	points.append_array(ROUTE_POINTS)
	var links: Array[Vector2i] = []
	for link: Vector2i in _route_links:
		links.append(link + Vector2i(2, 2))
	for index: int in range(2, points.size()):
		# Do not return the graph vertex we have already reached. Its neighbors
		# are also checked directly from start, avoiding zero-length first hops.
		if start.distance_to(points[index])>0.2 and _route_segment(start, points[index]):
			links.append(Vector2i(0, index))
		if _route_segment(target, points[index]):
			links.append(Vector2i(1, index))
	var distances: PackedFloat32Array = PackedFloat32Array()
	distances.resize(points.size())
	distances.fill(INF)
	distances[0] = 0.0
	var previous: PackedInt32Array = PackedInt32Array()
	previous.resize(points.size())
	previous.fill(-1)
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(points.size())
	for iteration: int in range(points.size()):
		var current: int = -1
		var minimum: float = INF
		for index: int in range(points.size()):
			if visited[index] == 0 and distances[index] < minimum:
				current = index
				minimum = distances[index]
		if current < 0 or current == 1:
			break
		visited[current] = 1
		for link: Vector2i in links:
			var neighbor: int = -1
			if link.x == current:
				neighbor = link.y
			elif link.y == current:
				neighbor = link.x
			if neighbor < 0 or visited[neighbor] != 0:
				continue
			var cost: float = minimum + points[current].distance_to(points[neighbor])
			if cost < distances[neighbor]-0.0001:
				distances[neighbor] = cost
				previous[neighbor] = current
	if previous[1] < 0:
		return start
	var next: int = 1
	while previous[next] > 0:
		next = previous[next]
	return points[next]

func _route_segment(a: Vector3, b: Vector3) -> bool:
	var count: int = maxi(1, ceili(a.distance_to(b) / 0.5))
	for index: int in range(count + 1):
		# Extra mid-segment clearance covers the space between sample points;
		# valid endpoints may be closer to shore without permitting corner cuts.
		var clearance: float = 0.6 if index == 0 or index == count else 0.9
		if not _route_ground(a.lerp(b, float(index) / float(count)), clearance):
			return false
	return _route_solid_clear(a,b)

func _route_solid_clear(a: Vector3, b: Vector3) -> bool:
	# Geometry-only callers can inspect floor connectivity before adding the
	# island to a tree. Live routes must also fit the actual hunter capsule.
	if not is_inside_tree(): return true
	if _route_capsule==null:
		_route_capsule=CapsuleShape3D.new()
		_route_capsule.radius=0.5
		_route_capsule.height=3.8
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=_route_capsule
	query.collision_mask=1
	query.margin=0.01
	# A small floor gap excludes supporting slabs while retaining rails, rocks,
	# trunks and posts throughout the hunter's full height.
	query.transform=Transform3D(Basis.IDENTITY,a+Vector3.UP*1.95)
	var space: PhysicsDirectSpaceState3D=get_world_3d().direct_space_state
	if not space.intersect_shape(query,1).is_empty(): return false
	query.motion=b-a
	var travel: PackedFloat32Array=space.cast_motion(query)
	return travel.size()>0 and travel[0]>=0.999

func _route_ground(point: Vector3, clearance: float = 0.6) -> bool:
	# Reserve enough shore clearance for a 0.5 m character capsule, including
	# at slab seams. Checking the union preserves the narrow lido connection.
	var at: Vector2 = Vector2(point.x, point.z)
	for offset: Vector2 in [Vector2.ZERO, Vector2(clearance, 0), Vector2(-clearance, 0), Vector2(0, clearance), Vector2(0, -clearance)]:
		var supported: bool = false
		for slab: Rect2 in WALKABLE_SLABS:
			if slab.has_point(at + offset):
				supported = true
				break
		if not supported and _repaired:
			supported = Rect2(-5.88,1.2,11.76,6).has_point(at + offset)
		if not supported and _ridge_repaired:
			var closest: Vector2=Geometry2D.get_closest_point_to_segment(at+offset,Vector2(6.72,4.2),Vector2(27.72,-22.68))
			supported=closest.distance_to(at+offset)<2.5
		if not supported:
			return false
	return true

func _build_campaign() -> void:
	_ridge_span=_node("RidgeShortcut",layout_point(Vector3(41,1.83,-22)))
	_ridge_span.rotation.y=atan2(50.0,-64.0)
	Art.box(_ridge_span,Vector3.ZERO,Vector3(5,0.4,Vector2(50,64).length()*LAYOUT_SCALE+2),Art.WOOD.lightened(0.12),true)
	for z in range(-40,41,4):
		Art.box(_ridge_span,Vector3(0,0.215,float(z)*LAYOUT_SCALE),Vector3(4.8,0.03,0.08),Art.CREAM)
	for x in [-2.35,2.35]:
		# Leave a broad mouth where this diagonal meets the east-west boardwalk.
		Art.box(_ridge_span,Vector3(x,0.85,0),Vector3(0.15,0.18,24),Art.CREAM,true)
	_ridge_span.visible=false
	_set_collision(_ridge_span,false)
	_label(self,"RIDGE SHORTCUT\nREPAIR AT BEACON",layout_point(Vector3(62,4,-49)))
	_workshop_upgrade=_node("RestoredWorkshop",layout_point(Vector3(-60,2,48))+Vector3(0,0,2))
	for x in [-1.2,1.2]: Art.box(_workshop_upgrade,Vector3(x,1,0),Vector3(0.12,2,0.12),Art.CREAM)
	Art.box(_workshop_upgrade,Vector3(0,2.1,0),Vector3(3.2,0.18,2),Art.AMBER)
	_engine_upgrade=_node("RestoredEngine",layout_point(Vector3(-47.4,1.5,43.8))+Vector3(0,0,3.2))
	_engine_upgrade.reparent(get_node("MothSkiff"),true)
	Art.box(_engine_upgrade,Vector3.ZERO,Vector3(1,0.8,0.7),Art.WATER)
	Art.box(_engine_upgrade,Vector3(0,0.45,0),Vector3(0.55,0.14,0.6),Art.AMBER)
	_workshop_upgrade.visible=false
	_engine_upgrade.visible=false
	for x in [-6,6]:
		var buoy=_node("ChannelBuoy",layout_point(Vector3(x,0,71)))
		Art.box(buoy,Vector3(0,0.3,0),Vector3(1.4,0.6,1.4),Art.WATER)
		_lantern(buoy,Vector3(0,1.6,0),0.7)

func set_campaign(repairs: Dictionary) -> void:
	var value: bool=bool(repairs.get("ridge_steps",false))
	if value!=_ridge_repaired: _route_links_valid=false
	_ridge_repaired=value
	if _ridge_span!=null and (not _ridge_span.has_meta("repair_applied") or bool(_ridge_span.get_meta("repair_applied"))!=value):
		_ridge_span.set_meta("repair_applied",value)
		_ridge_span.visible=value
		_set_collision(_ridge_span,value)
	if _workshop_upgrade!=null: _workshop_upgrade.visible=bool(repairs.get("workshop",false))
	if _engine_upgrade!=null: _engine_upgrade.visible=bool(repairs.get("moth_engine",false))
	if _beacon_lamp!=null:
		var powered: bool=bool(repairs.get("beacon",false))
		if powered!=_beacon_powered:
			_beacon_powered=powered
			_beacon_lamp.visible=powered
			_beacon_glass.material_override=_glow(Art.AMBER) if powered else Art.material(Art.WATER)

func fishing_markers() -> Array[String]:
	return ["jetty","reeds","terraces","tidepools","beacon"]

func fishing_habitat(at: Vector3) -> String:
	# The compact east shore has lagoon-facing Reeds on its west side and
	# seaward Tidepools on its east side. Nearest shelter alone merges them.
	var reeds_at: Vector3=markers["reeds"]
	if at.x>=24.5 and at.x<28.3 and at.z>=reeds_at.z+7.5 and at.z<=reeds_at.z+12.0:
		return "reeds"
	var closest: String=""
	var distance: float=12.0
	for id in fishing_markers():
		var candidate: float=at.distance_to(markers[id])
		if candidate<distance:
			distance=candidate
			closest=id
	return closest

func fishing_focus(habitat: String) -> Vector3:
	if habitat=="tidepools": return Vector3(47.04,0.35,-3)
	return layout_point({"jetty":Vector3(-48,0.35,-4),"reeds":Vector3(46,0.35,-19),
		"terraces":Vector3(-44,0.35,-30),"tidepools":Vector3(112,0.35,0),"beacon":Vector3(43,0.35,-36)}.get(habitat,Vector3.ZERO) as Vector3)

func set_reduced_effects(value: bool) -> void:
	_reduced_effects=value
	if _sun!=null: _sun.shadow_enabled=_shadows_requested and not value
	if _water_material!=null: _water_material.set_shader_parameter("motion",0.0 if value else 1.0)
	for ripple in _ripples: ripple.visible=not value

func set_shadows_enabled(value: bool) -> void:
	_shadows_requested=value
	if _sun!=null: _sun.shadow_enabled=value and not _reduced_effects

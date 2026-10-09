class_name IslandWorld
extends Node3D
## An authored, walkable ring island. Ground is y=2; open water is y=0.
## Named markers are interaction positions, not the centres of solid props.

const Art = preload("res://game/world/block_art.gd")
const GROUND_Y: float = 2.0
const ROUTE_POINTS: Array[Vector3] = [
	Vector3(-66, 2.05, -55.5), Vector3(-66, 2.05, 10),
	Vector3(-66, 2.05, 57), Vector3(66, 2.05, 57),
	Vector3(66, 2.05, 10), Vector3(66, 2.05, -55.5),
	Vector3(-53, 2.05, 48), Vector3(-66, 2.05, 48),
	Vector3(-45, 2.05, -42), Vector3(-45, 2.05, -54),
	Vector3(54, 2.05, -29), Vector3(65, 2.05, -29),
	Vector3(-16, 2.05, 10), Vector3(16, 2.05, 10),
]
## These are the actual y=2 supporting slabs built below; decorative beaches
## are intentionally excluded. Update the route probe when changing a slab.
const WALKABLE_SLABS: Array[Rect2] = [
	Rect2(-81.5, -66, 25, 130), Rect2(-77, -68.5, 154, 23),
	Rect2(56.5, -66, 25, 132), Rect2(-77, 47.5, 67, 21), Rect2(10, 47.5, 67, 21),
	Rect2(-66, 45, 16, 6), Rect2(-52, 45.2, 6, 1.6), Rect2(-52, -46, 14, 8),
	Rect2(50, -32, 10, 6), Rect2(-58, 7, 44, 6), Rect2(14, 7, 44, 6),
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
var _water_material: StandardMaterial3D
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
var _ridge_span: Node3D
var _ridge_repaired: bool=false
var _beacon_lamp: OmniLight3D
var _beacon_glass: MeshInstance3D
var _workshop_upgrade: Node3D
var _engine_upgrade: Node3D
var _beacon_powered: bool=false

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
	_environment.ambient_light_energy = 0.32
	_environment.fog_light_color = Color("7eabb7")
	_environment.fog_density = 0.0016
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
	_water_material = StandardMaterial3D.new()
	_water_material.albedo_color = Art.WATER
	_water_material.roughness = 0.65
	_water.material_override = _water_material
	for i: int in range(32):
		var x: float = float((i * 37) % 230) - 115.0
		var z: float = float((i * 53) % 200) - 100.0
		var stripe: MeshInstance3D = Art.box(self, Vector3(x, 0.035, z), Vector3(2.0 + float(i % 4) * 1.8, 0.012, 0.13), Color("80b4b8"))
		stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stripe.set_meta("origin", stripe.position)
		_ripples.append(stripe)

func _land(center: Vector3, size: Vector3) -> void:
	Art.box(self, center + Vector3(0.0, -0.32, 0.0), size + Vector3(5.0, 0.0, 5.0), Art.CREAM.darkened(0.15))
	Art.box(self, center, size, Art.GRASS, true)

func _build_land() -> void:
	_land(Vector3(-69.0, 1.0, -1.0), Vector3(25.0, 2.0, 130.0))
	_land(Vector3(0.0, 1.0, -57.0), Vector3(154.0, 2.0, 23.0))
	_land(Vector3(69.0, 1.0, 0.0), Vector3(25.0, 2.0, 132.0))
	# A genuine channel keeps the escape route in water all the way to sea.
	_land(Vector3(-43.5, 1.0, 58.0), Vector3(67.0, 2.0, 21.0))
	_land(Vector3(43.5, 1.0, 58.0), Vector3(67.0, 2.0, 21.0))
	# Chunky shore shelves establish the full outline without navigable clutter.
	for item: Vector3 in [Vector3(-83.0, 0.4, -37.0), Vector3(83.0, 0.4, 23.0), Vector3(35.0, 0.4, 69.0), Vector3(-19.0, 0.4, -70.0)]:
		Art.box(self, item, Vector3(10.0, 1.3, 12.0), Art.CREAM.darkened(0.24), true)
	# A compact ridge separates the lido from the eastern reed pocket.
	Art.box(self, Vector3(21.0, 4.0, -64.0), Vector3(26.0, 4.0, 10.0), Color("7d8870"), true)
	Art.box(self, Vector3(22.0, 6.9, -65.0), Vector3(18.0, 1.8, 8.0), Art.GRASS, true)
	for at: Vector3 in [Vector3(-78, 2, 27), Vector3(-76, 2, -16), Vector3(-73, 2, -43), Vector3(-23, 2, -62), Vector3(7, 2, -65), Vector3(48, 2, -62), Vector3(77, 2, -44), Vector3(78, 2, -6), Vector3(76, 2, 31), Vector3(42, 2, 63), Vector3(11, 2, 64), Vector3(-33, 2, 63)]:
		_tree(at)
	for at: Vector3 in [Vector3(-74, 2, 6), Vector3(-61, 2, -32), Vector3(36, 2, -50), Vector3(60, 2, 23), Vector3(20, 2, 52)]:
		Art.box(self, at + Vector3(0.0, 0.75, 0.0), Vector3(3.2, 1.5, 2.4), Color("849292"), true)

func _tree(at: Vector3) -> void:
	Art.box(self, at + Vector3(0.0, 2.2, 0.0), Vector3(0.9, 4.4, 0.9), Art.WOOD, true)
	var crown: MeshInstance3D = Art.box(self, at + Vector3(0.0, 5.0, 0.0), Vector3(5.2, 3.8, 5.2), Color("5e7a53"))
	crown.rotation.y = 0.25

func _path(a: Vector3, b: Vector3, width: float = 4.0) -> void:
	var delta: Vector3 = b - a
	var pavement: MeshInstance3D = Art.box(self, (a + b) * 0.5, Vector3(width, 0.025, delta.length() + 0.3), Art.CREAM.darkened(0.035))
	pavement.rotation.y = atan2(delta.x, delta.z)

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
	Art.box(self, at + Vector3(0.0, 0.9, 0.0), Vector3(0.19, 1.8, 0.19), Art.WOOD, true)
	Art.box(self, at + Vector3(0.0, 1.7, 0.0), Vector3(2.3, 0.68, 0.12), color)
	_label(self, text, at + Vector3(0.0, 1.76, 0.0))

func _build_home() -> void:
	var home: Node3D = _node("HomeCove")
	Art.box(home, Vector3(-58.0, 1.81, 48.0), Vector3(16.0, 0.38, 6.0), Art.WOOD, true)
	for i: int in range(11):
		Art.box(home, Vector3(-65.2 + float(i) * 1.4, 2.015, 48.0), Vector3(1.32, 0.04, 5.8), Art.WOOD.lightened(0.12))
	for x: float in [-63.0, -56.0, -50.5]:
		for z: float in [45.5, 50.5]:
			Art.box(home, Vector3(x, 0.3, z), Vector3(0.5, 4.8, 0.5), Art.WOOD, true)
	Art.box(home, Vector3(-49.0, 1.8, 46.0), Vector3(6.0, 0.4, 1.6), Art.WOOD, true)
	var skiff: Node3D = _node("MothSkiff", Vector3(-47.4, 1.0, 43.8))
	Art.box(skiff, Vector3.ZERO, Vector3(3.5, 0.58, 6.8), Art.INK)
	Art.box(skiff, Vector3(0.0, 0.37, 0.0), Vector3(3.1, 0.3, 6.2), Art.WOOD)
	for x: float in [-1.63, 1.63]:
		Art.box(skiff, Vector3(x, 0.74, 0.0), Vector3(0.28, 0.88, 6.4), Art.CREAM)
	Art.box(skiff, Vector3(0.0, 0.7, -3.06), Vector3(3.3, 1.02, 0.4), Art.WATER)
	for z: float in [-1.8, 0.0, 1.8]:
		Art.box(skiff, Vector3(0.0, 0.92, z), Vector3(2.9, 0.2, 0.58), Art.WOOD.lightened(0.15))
	Art.beam(skiff, Vector3(1.1, 0.6, 1.9), Vector3(0.75, 4.9, 1.9), 0.18, Art.WOOD)
	_lantern(skiff, Vector3(0.75, 4.7, 1.9), 1.2)
	_boat_light = OmniLight3D.new()
	_boat_light.position = Vector3(0.0, 3.5, 0.7)
	_boat_light.omni_range = 9.0
	_boat_light.light_color = Art.AMBER
	skiff.add_child(_boat_light)
	_home_light = OmniLight3D.new()
	_home_light.position = Vector3(-53.0, 5.0, 48.0)
	_home_light.omni_range = 15.0
	_home_light.light_color = Art.AMBER
	home.add_child(_home_light)
	Art.box(home, Vector3(-60.0, 2.62, 49.6), Vector3(2.8, 1.24, 1.1), Art.WATER, true)
	Art.box(home, Vector3(-60.0, 3.28, 49.6), Vector3(3.05, 0.16, 1.35), Art.CREAM)
	_label(home, "MOTH / HOME", Vector3(-54.0, 4.0, 48.0), true)
	_label(home, "BANK  /  WORKSHOP  /  RECHARGE", Vector3(-60.0, 3.7, 49.6))
	_build_tower(Vector3(-71.0, 2.0, 51.0), 7.5, "LAST LIGHT")

func _lantern(parent: Node3D, at: Vector3, size: float = 1.0) -> MeshInstance3D:
	Art.box(parent, at, Vector3(0.8, 1.1, 0.8) * size, Art.INK)
	var glass: MeshInstance3D = Art.box(parent, at, Vector3(0.87, 0.72, 0.87) * size, Art.AMBER)
	glass.material_override = _glow(Art.AMBER)
	Art.box(parent, at + Vector3(0.0, 0.63, 0.0) * size, Vector3(1.1, 0.13, 1.1) * size, Art.INK)
	return glass

func _build_lido() -> void:
	var lido: Node3D = _node("OldLido")
	Art.box(lido, Vector3(-45.0, 2.015, -53.0), Vector3(21.0, 0.04, 17.0), Art.CREAM)
	Art.box(lido, Vector3(-45.0, 1.77, -42.0), Vector3(14.0, 0.4, 8.0), Art.WATER, true)
	for i: int in range(7):
		Art.box(lido, Vector3(-51.0 + float(i) * 2.0, 1.98, -42.0), Vector3(1.8, 0.03, 7.8), Art.CREAM)
	for at: Vector3 in [Vector3(-52, 2, -62), Vector3(-46, 2, -62)]:
		Art.box(lido, at + Vector3(0.0, 1.35, 0.0), Vector3(3.3, 2.7, 3.0), Art.WATER, true)
		Art.box(lido, at + Vector3(0.0, 2.84, 0.0), Vector3(3.6, 0.24, 3.3), Art.CREAM)
		Art.box(lido, at + Vector3(0.0, 0.0, 1.55), Vector3(1.1, 0.05, 0.5), Art.WOOD)
	_build_tower(Vector3(-37.0, 2.0, -49.0), 6.0, "OLD LIDO")
	for i: int in range(8):
		Art.box(lido, Vector3(-54.0 + float(i) * 2.4, 0.18, -36.0), Vector3(0.65, 0.45, 0.65), Art.CREAM if i % 2 == 0 else Color("d98167"))
	Art.beam(lido, Vector3(-55, 0.15, -36), Vector3(-35, 0.15, -36), 0.04, Art.CREAM)

func _build_tower(at: Vector3, height: float, text: String) -> void:
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
	Art.box(reeds, Vector3(55.0, 1.83, -29.0), Vector3(10.0, 0.4, 6.0), Art.WOOD, true)
	for i: int in range(23):
		var at: Vector3 = Vector3(53.0 - float(i % 4) * 1.8, 0.0, -47.0 + float(i) * 1.7)
		var height: float = 2.4 + float(i % 3) * 0.65
		Art.box(reeds, at + Vector3(0.0, height * 0.5, 0.0), Vector3(0.17, height, 0.2), Color("7d8e57"))
		Art.box(reeds, at + Vector3(0.0, height - 0.25, 0.0), Vector3(0.31, 0.6, 0.34), Art.WOOD)
	_label(reeds, "LANTERN REEDS", Vector3(59.0, 6.0, -36.0), true)
	# A large square float makes the active fishing water legible at a distance.
	Art.box(reeds, Vector3(48.0, 0.3, -28.0), Vector3(0.8, 0.55, 0.8), Art.AMBER)
	Art.box(reeds, Vector3(48.0, 0.73, -28.0), Vector3(0.18, 0.45, 0.18), Art.INK)

func _build_shortcut() -> void:
	var fixed: Node3D = _node("OldBoardwalk")
	for x: float in [-36.0, 36.0]:
		Art.box(fixed, Vector3(x, 1.8, 10.0), Vector3(44.0, 0.4, 6.0), Art.WOOD, true)
		for step: int in range(11):
			Art.box(fixed, Vector3(x - 20.0 + float(step) * 4.0, 2.01, 10.0), Vector3(0.07, 0.025, 5.8), Art.INK)
	for x: float in [-53, -35, -17, 17, 35, 53]:
		for z: float in [7.5, 12.5]:
			Art.box(fixed, Vector3(x, 0.7, z), Vector3(0.3, 3.6, 0.3), Art.WOOD, true)
	_repaired_span = _node("RepairedCrossing")
	Art.box(_repaired_span, Vector3(0.0, 1.8, 10.0), Vector3(28.0, 0.4, 6.0), Art.WOOD.lightened(0.15), true)
	for i: int in range(14):
		Art.box(_repaired_span, Vector3(-13.0 + float(i) * 2.0, 2.015, 10.0), Vector3(0.06, 0.03, 5.85), Art.CREAM)
	for z: float in [7.15, 12.85]:
		Art.box(_repaired_span, Vector3(0.0, 2.55, z), Vector3(28.0, 0.15, 0.15), Art.CREAM, true)
	_broken_barriers = _node("BrokenCrossing")
	for x: float in [-13.95, 13.95]:
		Art.box(_broken_barriers, Vector3(x, 2.62, 10.0), Vector3(0.22, 1.25, 6.0), Art.WATER, true)
		for z: float in [8.0, 10.0, 12.0]:
			Art.box(_broken_barriers, Vector3(x, 2.63, z), Vector3(0.25, 0.22, 1.1), Art.AMBER)
	_label(_broken_barriers, "BROKEN WALKWAY\n1 BRASS FITTING", Vector3(-16.0, 3.9, 10.0))

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
	Art.box(node, Vector3(-2.0, 0.55, 2.4), Vector3(2.5, 0.25, 0.75), Art.WOOD, true)
	_label(node, title, Vector3(0, 5.5, 0))

func _build_cache(cache_id: String, title: String, color: Color) -> void:
	var at: Vector3 = markers[cache_id] as Vector3
	var node: Node3D = _node("Cache_" + cache_id, Vector3(at.x, 2.0, at.z - 1.0))
	Art.box(node, Vector3(0, 0.38, 0), Vector3(1.45, 0.75, 0.92), color, true)
	Art.box(node, Vector3(0, 0.49, -0.01), Vector3(1.18, 0.45, 0.69), Art.INK)
	var lid: Node3D = Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0, 0.78, -0.46)
	node.add_child(lid)
	Art.box(lid, Vector3(0, 0, 0.46), Vector3(1.52, 0.16, 0.98), color.lightened(0.17))
	Art.box(lid, Vector3(0, 0.05, 0.46), Vector3(0.18, 0.2, 1.0), Art.CREAM)
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
	var ridge: Node3D = _node("BeaconRidge", Vector3(73, 2, -53))
	Art.box(ridge, Vector3(0, 2.7, 0), Vector3(3.8, 5.4, 3.8), Art.CREAM, true)
	Art.box(ridge, Vector3(0, 6.0, 0), Vector3(5.0, 1.2, 5.0), Art.INK)
	_beacon_glass=Art.box(ridge, Vector3(0, 7.2, 0), Vector3(2.3, 1.3, 2.3), Art.WATER)
	_beacon_lamp=OmniLight3D.new()
	_beacon_lamp.position=Vector3(0,8,0)
	_beacon_lamp.light_color=Art.AMBER
	_beacon_lamp.omni_range=22
	_beacon_lamp.visible=false
	ridge.add_child(_beacon_lamp)
	_label(ridge,"BEACON / SIGNAL",Vector3(0,9,0),true)
	_label(self,"TIDE POOLS",Vector3(70,6,26),true)
	_label(self,"SEA CHANNEL",Vector3(0,5,69),true)
	for i: int in range(7):
		var at: Vector3 = Vector3(76.0 + float(i % 2) * 3.0, 2.35, 20.0 + float(i) * 3.3)
		Art.box(self, at, Vector3(3.0, 0.7, 2.7), Color("788c91"), true)
	# Low distant silhouettes sit beyond the playable water boundary.
	for at: Vector3 in [Vector3(-260, 3, -250), Vector3(210, 4, -280), Vector3(270, 2, 180)]:
		Art.box(self, at, Vector3(95, 12, 40), Color("657f86"))

func set_time(elapsed_s: float) -> void:
	_elapsed = maxf(elapsed_s, 0.0)
	if _environment == null:
		return
	var dusk: float = smoothstep(165.0, 240.0, _elapsed)
	var dawn: float = smoothstep(570.0, 630.0, _elapsed)
	var night: float = dusk * (1.0 - dawn)
	var sunset: float = maxf(0.0, 1.0 - absf(_elapsed - 197.0) / 40.0) * (1.0 - dawn)
	_environment.ambient_light_color = Color("b2c6c8").lerp(Color("849dbd"), night)
	_environment.ambient_light_energy = lerpf(0.32, 0.4, night)
	_sun.light_color = Color("f4e8d3").lerp(Color("b3cbe8"), night).lerp(Color("f6ac79"), sunset * 0.65)
	_sun.light_energy = lerpf(0.52, 0.22, night)
	_home_light.light_energy = lerpf(0.45, 1.8, night)
	_boat_light.light_energy = lerpf(0.35, 1.3, night)
	for light: OmniLight3D in _station_lights.values():
		light.light_energy = lerpf(0.35, 1.7, night)
	_sun.rotation_degrees.x = lerpf(-41.0, -26.0, night)
	_sky_material.sky_top_color = Color("729bab").lerp(Color("14253e"), night)
	_sky_material.sky_horizon_color = Color("e5ccad").lerp(Color("3c526d"), night).lerp(Color("e8a47a"), sunset * 0.65)
	_sky_material.ground_horizon_color = _sky_material.sky_horizon_color
	_environment.fog_light_color = Color("8babb2").lerp(Color("4b6483"), night)
	_water_material.albedo_color = Art.WATER.lerp(Color("294d65"), night)
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
		_environment.fog_density = 0.007 if value else 0.0016

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
		if _route_segment(start, points[index]):
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
			if cost < distances[neighbor]:
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
	return true

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
			supported = Rect2(-14, 7, 28, 6).has_point(at + offset)
		if not supported and _ridge_repaired:
			var closest: Vector2=Geometry2D.get_closest_point_to_segment(at+offset,Vector2(16,10),Vector2(66,-54))
			supported=closest.distance_to(at+offset)<2.5
		if not supported:
			return false
	return true

func _build_campaign() -> void:
	_ridge_span=_node("RidgeShortcut",Vector3(41,1.83,-22))
	_ridge_span.rotation.y=atan2(50.0,-64.0)
	Art.box(_ridge_span,Vector3.ZERO,Vector3(5,0.4,Vector2(50,64).length()+2),Art.WOOD.lightened(0.12),true)
	for z in range(-40,41,4):
		Art.box(_ridge_span,Vector3(0,0.215,z),Vector3(4.8,0.03,0.08),Art.CREAM)
	for x in [-2.35,2.35]:
		# Leave a broad mouth where this diagonal meets the east-west boardwalk.
		Art.box(_ridge_span,Vector3(x,0.85,3.5),Vector3(0.15,0.18,75),Art.CREAM,true)
	_ridge_span.visible=false
	_set_collision(_ridge_span,false)
	_label(self,"RIDGE SHORTCUT\nREPAIR AT BEACON",Vector3(62,4,-49))
	_workshop_upgrade=_node("RestoredWorkshop",Vector3(-60,2,50))
	for x in [-1.2,1.2]: Art.box(_workshop_upgrade,Vector3(x,1,0),Vector3(0.12,2,0.12),Art.CREAM)
	Art.box(_workshop_upgrade,Vector3(0,2.1,0),Vector3(3.2,0.18,2),Art.AMBER)
	_engine_upgrade=_node("RestoredEngine",Vector3(-47.4,1.5,47))
	_engine_upgrade.reparent(get_node("MothSkiff"),true)
	Art.box(_engine_upgrade,Vector3.ZERO,Vector3(1,0.8,0.7),Art.WATER)
	Art.box(_engine_upgrade,Vector3(0,0.45,0),Vector3(0.55,0.14,0.6),Art.AMBER)
	_workshop_upgrade.visible=false
	_engine_upgrade.visible=false
	for x in [-6,6]:
		var buoy=_node("ChannelBuoy",Vector3(x,0,71))
		Art.box(buoy,Vector3(0,0.3,0),Vector3(1.4,0.6,1.4),Art.WATER)
		_lantern(buoy,Vector3(0,1.6,0),0.7)

func set_campaign(repairs: Dictionary) -> void:
	var value: bool=bool(repairs.get("ridge_steps",false))
	if value!=_ridge_repaired: _route_links_valid=false
	_ridge_repaired=value
	if _ridge_span!=null:
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
	var closest: String=""
	var distance: float=12.0
	for id in fishing_markers():
		var candidate: float=at.distance_to(markers[id])
		if candidate<distance:
			distance=candidate
			closest=id
	return closest

func fishing_focus(habitat: String) -> Vector3:
	return {"jetty":Vector3(-48,0.35,4.2),"reeds":Vector3(46,0.35,-19),
		"terraces":Vector3(-44,0.35,-32),"tidepools":Vector3(94,0.35,27),"beacon":Vector3(43,0.35,-36)}.get(habitat,Vector3.ZERO)

func set_reduced_effects(value: bool) -> void:
	if _sun!=null: _sun.shadow_enabled=not value
	for ripple in _ripples: ripple.visible=not value

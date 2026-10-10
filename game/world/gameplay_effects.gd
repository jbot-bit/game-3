class_name GameplayEffects
extends Node3D
## Snapshot-driven presentation only. Never moves game actors or catch bodies.
const Art = preload("res://game/world/block_art.gd")
const Crew = preload("res://game/player/animated_crew.gd")
const KEEPER_RADIUS: float = 4.5
var _casts: Dictionary = {}
var _focus: Dictionary = {}
var _keeper: Node3D
var _scout: Node3D
var _sighting: Node3D
var _odd_seen: Dictionary = {}
var _odd_reveals: Dictionary = {}
var _run_id: String = ""
var _clock: float = 0.0
var _boat: Node3D
var _boat_home: Transform3D
var _refuge: bool = false
var _passengers: Node3D
var _hidden: Dictionary = {}
var _trails: Dictionary={}
var _reduced_effects: bool=false

func set_reduced_effects(value: bool) -> void:
	_reduced_effects=value

func update_view(snapshot: Dictionary, avatars: Dictionary, world: Node3D, delta: float) -> void:
	if _keeper == null:
		_build_ability_cues()
	var run: Dictionary = snapshot.get("run", {})
	var next_run: String = str(run.get("run_id", ""))
	if next_run != _run_id:
		_run_id = next_run
		_odd_seen.clear()
		for entry: Dictionary in _odd_reveals.values():
			(entry.node as Node3D).queue_free()
		_odd_reveals.clear()
		for entry in _trails.values(): entry.node.queue_free()
		_trails.clear()
	var step: float = 0.0 if bool(run.get("paused", false)) else delta
	_clock += step
	_update_refuge(snapshot, avatars, world, step)
	_update_casts(snapshot, avatars, world)
	_update_abilities(snapshot,avatars,world)
	_update_odd(snapshot, avatars, step)
	_update_sighting(snapshot, avatars, world)

func cast_focus(profile_id: String) -> Vector3:
	return _focus.get(profile_id, Vector3.ZERO) as Vector3

func refuge_target() -> Node3D:
	return _boat if _refuge else null

func _unshaded(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

func _label(parent: Node3D, title: String, at: Vector3, color: Color) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = title
	label.position = at
	label.font_size = 36
	label.pixel_size = 0.009
	label.outline_size = 8
	label.modulate = color
	label.outline_modulate = Art.INK
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	return label

func _new_node(node_name: String, parent: Node3D = null) -> Node3D:
	var node: Node3D = Node3D.new()
	node.name = node_name
	(parent if parent != null else self).add_child(node)
	return node

func _update_casts(snapshot: Dictionary, avatars: Dictionary, world: Node3D) -> void:
	var active: Dictionary = snapshot.get("fishing", {}) if not _refuge else {}
	for id: String in _casts.keys():
		if not active.has(id) or not avatars.has(id) or str(_casts[id].get_meta("catch_id",""))!=str(active.get(id,{}).get("catch_id","")):
			(_casts[id] as Node3D).queue_free()
			_casts.erase(id)
			_focus.erase(id)
	var markers: Dictionary = world.get("markers")
	for id: String in active:
		if not avatars.has(id):
			continue
		var avatar: Node3D = avatars[id] as Node3D
		var state: Dictionary = active[id]
		if not _casts.has(id):
			var cast: Node3D = _new_node("Cast_" + id.validate_node_name())
			cast.set_meta("catch_id",str(state.get("catch_id","")))
			var bobber: Node3D = _new_node("Bobber", cast)
			Art.box(bobber, Vector3.ZERO, Vector3(0.56, 0.42, 0.56), Art.CREAM).material_override = _unshaded(Art.CREAM)
			Art.box(bobber, Vector3(0, 0.2, 0), Vector3(0.56, 0.18, 0.56), Color("e67c61")).material_override = _unshaded(Color("e67c61"))
			Art.box(bobber, Vector3(0, 0.49, 0), Vector3(0.08, 0.48, 0.08), Art.INK)
			var ripple: Node3D = _new_node("Ripple", cast)
			for side: int in range(4):
				var edge: MeshInstance3D = Art.box(ripple, Vector3(0, 0, 0.55), Vector3(1.1, 0.035, 0.045), Art.CREAM)
				edge.position = Basis(Vector3.UP, float(side) * PI / 2.0) * edge.position
				edge.rotation.y = float(side) * PI / 2.0
				edge.material_override = _unshaded(Art.CREAM)
			var line_material: StandardMaterial3D = _unshaded(Art.CREAM)
			cast.set_meta("line_color",Art.CREAM)
			for index: int in range(6):
				var line: MeshInstance3D = Art.box(cast, Vector3.ZERO, Vector3(0.025, 1, 0.025), Art.CREAM)
				line.name = "Line%s" % index
				line.material_override = line_material
				line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_casts[id] = cast
			var habitat: String=str(state.get("habitat_id",world.fishing_habitat(avatar.global_position)))
			_focus[id]=world.fishing_focus(habitat)
		var visual: Node3D = _casts[id] as Node3D
		var aim: Vector3 = _focus[id] as Vector3
		var bite: bool = float(state.get("elapsed", 0.0)) >= 0.8
		var end: Vector3 = aim + Vector3((float(state.get("fish_position", 0.5)) - 0.5) * 0.6, sin(_clock * (7.0 if bite else 2.0)) * (0.07 if bite else 0.025), 0)
		(visual.get_node("Bobber") as Node3D).position = end
		var ripple: Node3D = visual.get_node("Ripple") as Node3D
		ripple.position = Vector3(end.x, 0.07, end.z)
		ripple.scale = Vector3.ONE if _reduced_effects else Vector3.ONE * (1.0 + sin(_clock * 3.0) * 0.08)
		var tip: Node3D = avatar.visual.get_node_or_null("RightArm/HeldTool") as Node3D
		var start: Vector3 = tip.to_global(Vector3(0, 1.63, -0.54)) if tip != null else avatar.global_position + Vector3(0, 2.6, 0)
		var color: Color = Art.CREAM if not bite else (Color("68e1c2") if bool(state.get("tracking", false)) else Art.AMBER)
		if (visual.get_meta("line_color") as Color)!=color:
			visual.set_meta("line_color",color)
			var first_line: MeshInstance3D=visual.get_node("Line0")
			(first_line.material_override as StandardMaterial3D).albedo_color=color
		for index: int in range(6):
			var a: Vector3 = _line_point(start, end, float(index) / 6.0)
			var b: Vector3 = _line_point(start, end, float(index + 1) / 6.0)
			var line: MeshInstance3D = visual.get_node("Line%s" % index) as MeshInstance3D
			line.position = (a + b) * 0.5
			# Keep the uploaded unit mesh stable; only the instance transform moves.
			line.scale = Vector3(1, maxf(0.001, a.distance_to(b)), 1)
			line.quaternion = Quaternion(Vector3.UP, (b - a).normalized())

func _line_point(a: Vector3, b: Vector3, amount: float) -> Vector3:
	return a.lerp(b, amount) + Vector3.UP * sin(amount * PI) * 1.4

func _build_ability_cues() -> void:
	_keeper = _new_node("KeeperZone")
	var dome: MeshInstance3D = MeshInstance3D.new()
	var shape: SphereMesh = SphereMesh.new()
	shape.radius = KEEPER_RADIUS
	shape.height = KEEPER_RADIUS * 2.0
	shape.radial_segments = 20
	shape.rings = 10
	dome.mesh = shape
	dome.material_override = _unshaded(Color(1.0, 0.82, 0.44, 0.055))
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_keeper.add_child(dome)
	for index: int in range(20):
		var a: float = float(index) * TAU / 20.0
		var b: float = float(index + 1) * TAU / 20.0
		var edge: MeshInstance3D = Art.beam(_keeper, Vector3(cos(a) * KEEPER_RADIUS, 0.075, sin(a) * KEEPER_RADIUS), Vector3(cos(b) * KEEPER_RADIUS, 0.075, sin(b) * KEEPER_RADIUS), 0.065, Art.AMBER)
		edge.material_override = _unshaded(Art.AMBER)
	_scout = _new_node("ScoutCue")
	for side: int in [-1, 1]:
		Art.box(_scout, Vector3(float(side) * 0.58, 0, 0), Vector3(0.1, 0.55, 0.1), Color("62b9db")).material_override = _unshaded(Color("62b9db"))
	var label: Label3D = _label(_scout, "SCOUT / LIFEGUARD", Vector3(0, 0.6, 0), Color("9cdef2"))
	label.no_depth_test = true
	_keeper.visible = false
	_scout.visible = false

func _update_abilities(snapshot: Dictionary, avatars: Dictionary, world: Node3D) -> void:
	var run: Dictionary = snapshot.get("run", {})
	var now: float = float(run.get("elapsed_s", 0.0))
	var abilities: Dictionary = snapshot.get("abilities", {})
	_keeper.visible = not _refuge and float(abilities.get("keeper_until", 0.0)) > now
	_keeper.position = snapshot.get("keeper_position", Vector3.ZERO) as Vector3
	_keeper.scale=Vector3.ONE*float(abilities.get("keeper_radius",KEEPER_RADIUS))/KEEPER_RADIUS
	var ready: Dictionary = abilities.get("ready_at", {})
	var profiles: Dictionary = snapshot.get("progression", {}).get("profiles", {})
	var spotted: bool = false
	for id: String in ready:
		var activation: Dictionary=abilities.get("active",{}).get(id,{"role":profiles.get(id,{}).get("role_id",""),"mode":"standard","until":float(ready[id])-25.0})
		if activation.role=="scout" and now<float(activation.until) and activation.mode=="standard":
			spotted = true
		if activation.role=="scout" and now<float(activation.until) and activation.mode=="alternate" and avatars.has(id) and not _refuge and not _trails.has(id):
			_build_trail(id,avatars[id].global_position,world,float(activation.until))
	for id in _trails.keys():
		if now>=float(_trails[id].until) or _refuge:
			_trails[id].node.queue_free()
			_trails.erase(id)
	_scout.visible = spotted and not _refuge and snapshot.get("poses", {}).has("hunter")
	if _scout.visible:
		var pose: Transform3D = snapshot.poses.hunter as Transform3D
		_scout.position = pose.origin + Vector3(0, 5.1, 0)

func _build_trail(id: String, start: Vector3, world: Node3D, until: float) -> void:
	var trail: Node3D=_new_node("Trail_"+id)
	_trails[id]={"node":trail,"until":until}
	var at: Vector3=start
	var home: Vector3=world.markers.boat
	var count: int=0
	for segment in range(12):
		var next: Vector3=world.route_step(at,home)
		if at.distance_to(next)<0.5: break
		var steps: int=maxi(1,ceili(at.distance_to(next)/6.0))
		for step in range(1,steps+1):
			var point: Vector3=at.lerp(next,float(step)/steps)
			Art.box(trail,Vector3(point.x,2.12,point.z),Vector3(0.65,0.09,0.65),Color("9cdef2")).material_override=_unshaded(Color("9cdef2"))
			count+=1
			if count>=60: break
		at=next
		if at.distance_to(home)<1 or count>=60: break

func _update_odd(snapshot: Dictionary, avatars: Dictionary, delta: float) -> void:
	for event: Dictionary in snapshot.get("cosmetic_catches", []):
		var odd: bool=bool(event.get("odd",false))
		var id: String = str(event.get("catch_id", ""))
		var profile: String = str(event.get("profile_id", ""))
		var species: String = str(event.get("species_id", "penny_perch"))
		var body: Node3D = get_parent().get_node_or_null("Fish_" + id.validate_node_name()) as Node3D
		if body != null and odd:
			var fish: Node3D = body.get_node_or_null("BlockFish") as Node3D
			if fish != null:
				Art.add_odd_appearance(fish, species)
		if _odd_seen.has(id):
			continue
		_odd_seen[id] = true
		if body == null and avatars.has(profile) and not _refuge:
			var reveal: Node3D = _new_node("Odd_" + id.validate_node_name())
			var fish: Node3D = Art.fish(species,false,str(event.get("trait_id","none")))
			reveal.add_child(fish)
			if odd: Art.add_odd_appearance(fish, species)
			var title: String="ODD CATCH" if odd else str(event.get("trait_id","none")).to_upper()
			if title=="NONE": title=str(Species.catalog().get(species,{}).get("name",species))
			_label(reveal,title,Vector3(0,1.15,0),Art.AMBER)
			_odd_reveals[id] = {"node":reveal, "profile":profile, "left":2.6}
	for id: String in _odd_reveals.keys():
		var entry: Dictionary = _odd_reveals[id]
		entry.left = float(entry.left) - delta
		var reveal: Node3D = entry.node as Node3D
		if float(entry.left) <= 0.0 or not avatars.has(entry.profile) or _refuge:
			reveal.queue_free()
			_odd_reveals.erase(id)
			continue
		var avatar: Node3D = avatars[entry.profile] as Node3D
		reveal.position = avatar.global_position + Vector3(0, 2.75 + (0.0 if _reduced_effects else sin((2.6 - float(entry.left)) * 2.0) * 0.12), 0)
		reveal.rotation.y = 0.0 if _reduced_effects else _clock * 0.55

func _update_sighting(snapshot: Dictionary, avatars: Dictionary, world: Node3D) -> void:
	var active: bool = str(snapshot.get("director", "")) == "sighting" and not _refuge and not avatars.is_empty()
	if _sighting == null:
		_sighting = _new_node("Sighting")
		_sighting.add_child(Art.hunter())
		_label(_sighting, "A FIGURE ON THE SHORE", Vector3(0, 5.1, 0), Art.CREAM)
		_sighting.visible = false
	if active and not _sighting.visible:
		var first: Node3D = avatars.values()[0] as Node3D
		var destination: Vector3 = world.markers.beacon if first.global_position.z > world.markers.jetty.z else world.markers.boat
		var next: Vector3 = world.call("route_step", first.global_position, destination) as Vector3
		_sighting.position = first.global_position.move_toward(next, 12.0)
		_sighting.rotation.y = atan2(first.global_position.x - _sighting.position.x, first.global_position.z - _sighting.position.z) + PI
	_sighting.visible = active

func _remember_hidden(node: Node3D) -> void:
	if node == null:
		return
	if not _hidden.has(node):
		_hidden[node] = node.visible
	node.visible = false

func _update_refuge(snapshot: Dictionary, avatars: Dictionary, world: Node3D, delta: float=0.0) -> void:
	if _boat == null:
		_boat = world.get_node_or_null("MothSkiff") as Node3D
		if _boat != null:
			_boat_home = _boat.transform
	var run: Dictionary = snapshot.get("run", {})
	var active: bool = str(run.get("phase", "")) in ["refuge","escape"] and _boat != null
	if not active:
		if _refuge:
			_boat.transform = _boat_home
			if is_instance_valid(_passengers):
				_passengers.queue_free()
			# Banking may free a hidden catch body before the next dawn arrives.
			for remembered: Variant in _hidden:
				if is_instance_valid(remembered):
					(remembered as Node3D).visible = bool(_hidden[remembered])
			_hidden.clear()
		_refuge = false
		return
	var players: Dictionary = run.get("players", {})
	if not _refuge:
		_passengers = _new_node("RefugeCrew", _boat)
		var seat: int = 0
		for id: String in avatars:
			if not bool(players.get(id, {}).get("aboard", false)):
				continue
			var actor: Node3D = avatars[id] as Node3D
			var color: Color = Color("62b9db")
			var outfit: String = "harbour"
			var source: Node3D = actor.visual
			if source != null:
				color = source.get_meta("crew_color",color) as Color
				outfit = str(source.get_meta("outfit_id","harbour"))
			var clone: Node3D = Crew.new()
			clone.configure(color,outfit)
			clone.set_seated(true)
			clone.name = id.validate_node_name()
			_passengers.add_child(clone)
			# Seated thigh bottom rests on Moth's bench at local y=-0.036.
			clone.position = Vector3(-0.35 if seat % 2 == 0 else 0.35, 0.154, 1.8 - float(seat) * 1.8)
			clone.animate_motion(0.0,0.0)
			_clone_cargo(snapshot, id, clone)
			seat += 1
	_refuge = true
	for passenger: Node3D in _passengers.get_children():
		passenger.animate_motion(0.0,delta)
	for id: String in avatars:
		if bool(players.get(id, {}).get("aboard", false)):
			var avatar: Node3D = avatars[id] as Node3D
			_remember_hidden(avatar.get("visual") as Node3D)
			_remember_hidden(avatar.get("name_tag") as Node3D)
			_remember_hidden(avatar.get("lamp") as Node3D)
	var cargo: Dictionary = snapshot.get("cargo", {})
	for id: String in cargo:
		var entry: Dictionary = cargo[id]
		if str(entry.get("state", "")) == "whole_held" and bool(players.get(entry.get("carrier_id", ""), {}).get("aboard", false)):
			_remember_hidden(get_parent().get_node_or_null("Fish_" + id.validate_node_name()) as Node3D)
	var progress: float = clampf((20.0 - maxf(0.0, float(run.get("crossing_left", 20.0)))) / 20.0, 0.0, 1.0)
	var destination: Vector3 = world.markers.refuge_mooring
	var origin: Vector3=_boat_home.origin
	var initial_yaw: float=_boat_home.basis.get_euler().y
	if str(run.get("phase",""))=="escape":
		var channel: Vector3=world.markers.escape_channel
		if progress<0.45:
			destination=channel
			progress=progress/0.45
		else:
			origin=channel
			destination=world.markers.escape_destination
			var previous_heading: Vector3=channel-_boat_home.origin
			initial_yaw=atan2(-previous_heading.x,-previous_heading.z)
			progress=(progress-0.45)/0.55
	_boat.position = origin.lerp(destination, smoothstep(0, 1, progress))
	var heading: Vector3 = destination - origin
	_boat.rotation.y = lerp_angle(initial_yaw, atan2(-heading.x, -heading.z), smoothstep(0, 0.2, progress))

func _clone_cargo(snapshot: Dictionary, profile: String, clone: Node3D) -> void:
	var cargo: Dictionary = snapshot.get("cargo", {})
	for id: String in cargo:
		var entry: Dictionary = cargo[id]
		if str(entry.get("state", "")) != "whole_held" or str(entry.get("carrier_id", "")) != profile:
			continue
		var species: String = str(entry.get("catch_record", {}).get("species_id", "penny_perch"))
		var fish: Node3D = Art.fish(species, true,str(entry.get("catch_record",{}).get("trait_id","oversized")))
		clone.add_child(fish)
		fish.position = Vector3(0, 1, -0.8)
		for event: Dictionary in snapshot.get("cosmetic_catches", []):
			if str(event.get("catch_id", "")) == id and bool(event.get("odd", false)):
				Art.add_odd_appearance(fish, species)
		break

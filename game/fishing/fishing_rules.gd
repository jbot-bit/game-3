class_name FishingRules
extends RefCounted
const FishData = preload("res://game/fishing/species.gd")
const Gear = preload("res://game/progression/equipment.gd")
const BITE_SECONDS: float = 0.8
const BAR_SPEED: float = 0.6

var casts: Dictionary = {}

func start(profile_id: String, species_id: String, catch_id: String) -> Dictionary:
	var catalog: Dictionary = FishData.catalog()
	if not catalog.has(species_id):
		return {"ok":false, "code":"invalid_species"}
	if casts.has(profile_id):
		return {"ok":false, "code":"already_casting"}
	var rare: bool = FishData.is_rare(species_id)
	var width: float = 0.27 if rare else 0.34
	casts[profile_id] = {"species_id":species_id, "catch_id":catch_id, "profile_id":profile_id,
		"behavior":catalog[species_id].behavior, "path_index":catalog.keys().find(species_id), "rare":rare,
		"progress":0.2, "elapsed":0.0, "assists":[], "bar_position":0.5, "bar_width":width,
		"fish_position":0.5, "tracking":true, "base_width":width,
		"rod_width_multiplier":1.0, "outfit_width_multiplier":1.0, "progress_multiplier":1.0}
	return {"ok":true, "code":"cast"}

func configure_rod(profile_id: String, rod_id: String) -> bool:
	var rod: Dictionary = Gear.rod(rod_id)
	if not casts.has(profile_id) or rod.is_empty(): return false
	var cast: Dictionary = casts[profile_id]
	cast.rod_width_multiplier = rod.bar_width_multiplier
	cast.progress_multiplier = rod.get(str(cast.behavior) + "_progress_multiplier",1.0)
	_refresh_bar(cast)
	return true

func configure_outfit(profile_id: String, outfit_id: String) -> bool:
	var outfit: Dictionary = Gear.outfit(outfit_id)
	if not casts.has(profile_id) or outfit.is_empty(): return false
	var cast: Dictionary = casts[profile_id]
	cast.outfit_width_multiplier = outfit.bar_width_multiplier
	_refresh_bar(cast)
	return true

func _refresh_bar(cast: Dictionary) -> void:
	cast.bar_width = clampf(float(cast.base_width) * float(cast.rod_width_multiplier) * float(cast.outfit_width_multiplier),0.15,0.6)
	var half: float = float(cast.bar_width) * 0.5
	cast.bar_position = clampf(float(cast.bar_position),half,1.0-half)
	cast.tracking = absf(float(cast.fish_position) - float(cast.bar_position)) <= half

func step(profile_id: String, reel: bool, opposing_pull: float, delta_s: float) -> Dictionary:
	if not casts.has(profile_id):
		return {"ok":false, "code":"no_cast"}
	# Keep the old wire signature while making hold/release the only control.
	if not is_finite(opposing_pull) or not is_finite(delta_s) or delta_s <= 0:
		return {"ok":false, "code":"invalid_input"}
	var c: Dictionary = casts[profile_id]
	var previous: float = c.elapsed
	c.elapsed += minf(delta_s,0.25)
	if c.elapsed <= BITE_SECONDS:
		return {"ok":true, "code":"waiting"}
	var dt: float = float(c.elapsed) - maxf(previous,BITE_SECONDS)
	var half: float = float(c.bar_width) * 0.5
	c.bar_position = clampf(float(c.bar_position) + (BAR_SPEED if reel else -BAR_SPEED) * dt,half,1.0-half)
	c.fish_position = _fish_position(c,float(c.elapsed)-BITE_SECONDS)
	c.tracking = absf(float(c.fish_position) - float(c.bar_position)) <= half
	var gain: float = (0.085 if c.rare else 0.16) * float(c.progress_multiplier)
	c.progress = clampf(float(c.progress) + dt * (gain if c.tracking else -0.11),0.0,1.0)
	if c.progress >= 1.0:
		var result: Dictionary = c.duplicate(true)
		casts.erase(profile_id)
		return {"ok":true, "code":"caught", "catch":result}
	if c.progress <= 0.0 or c.elapsed >= (24.0 if c.rare else 18.0):
		casts.erase(profile_id)
		return {"ok":false, "code":"fish_escaped"}
	return {"ok":true, "code":"reeling"}

func _fish_position(cast: Dictionary, active_s: float) -> float:
	# Smooth, authored species paths are independent of the angler's input.
	# Every fish starts centered; rare fish move faster within the same rail.
	var index: float = float(cast.path_index)
	var t: float = active_s * (1.15 if cast.rare else 1.0)
	var offset: float
	match cast.behavior:
		"heavy": offset = 0.23 * sin(t * (0.95 + index * 0.015)) + 0.035 * sin(t * (1.6 + index * 0.04))
		"surge": offset = 0.25 * sin(t * (1.45 + index * 0.02)) + 0.06 * sin(t * (2.6 + index * 0.02))
		_: offset = 0.27 * sin(t * (1.32 + index * 0.02)) + 0.045 * sin(t * (2.65 + index * 0.03))
	return clampf(0.5 + offset,0.07,0.93)

func assist(helper_id: String, target_id: String, kind: String, alternate: bool = false) -> Dictionary:
	if helper_id == target_id or not casts.has(target_id) or kind not in ["generic","rigger"]:
		return {"ok":false, "code":"invalid_assist"}
	var c: Dictionary = casts[target_id]
	if c.assists.has(kind):
		return {"ok":false, "code":"already_assisted"}
	c.assists.append(kind)
	var boost: float = 0.20 if kind == "rigger" and not alternate else 0.10
	c.progress = maxf(float(c.progress),minf(0.95,float(c.progress)+boost))
	return {"ok":true, "code":"assisted"}

func cancel(profile_id: String) -> void:
	casts.erase(profile_id)

func snapshot() -> Dictionary:
	return casts.duplicate(true)

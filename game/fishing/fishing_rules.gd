class_name FishingRules
extends RefCounted

var casts: Dictionary = {}

func start(profile_id: String, species_id: String, catch_id: String) -> Dictionary:
	if species_id not in ["penny_perch", "bellgill", "lantern_eel"]:
		return {"ok":false, "code":"invalid_species"}
	if casts.has(profile_id):
		return {"ok":false, "code":"already_casting"}
	casts[profile_id] = {"species_id":species_id, "catch_id":catch_id, "profile_id":profile_id,
		"progress":0.0, "tension":0.18, "elapsed":0.0, "pull":0.0, "assists":[],
		"tension_multiplier":1.0, "progress_multiplier":1.0}
	return {"ok":true, "code":"cast"}

func step(profile_id: String, reel: bool, opposing_pull: float, delta_s: float) -> Dictionary:
	if not casts.has(profile_id):
		return {"ok":false, "code":"no_cast"}
	if not is_finite(opposing_pull) or not is_finite(delta_s) or delta_s <= 0:
		return {"ok":false, "code":"invalid_input"}
	var c: Dictionary = casts[profile_id]
	var dt: float = minf(delta_s, 0.25)
	c.elapsed += dt
	var heavy: bool = c.species_id == "bellgill"
	c.pull = sin(c.elapsed * (0.8 if heavy else 2.1))
	if c.elapsed < 1.2:
		return {"ok":true, "code":"waiting"}
	if reel:
		var control: float = clampf(opposing_pull, -1, 1)
		c.tension = clampf(c.tension + dt * (0.23 - control * 0.09) * c.tension_multiplier, 0, 1)
		c.progress = clampf(c.progress + dt * (0.052 if heavy else 0.09) * c.progress_multiplier, 0, 1)
	else:
		c.tension = maxf(0.0, c.tension - dt * 0.48)
	if c.tension >= 1.0:
		casts.erase(profile_id)
		return {"ok":false, "code":"line_broke"}
	if c.progress >= 1.0:
		var result: Dictionary = c.duplicate(true)
		casts.erase(profile_id)
		return {"ok":true, "code":"caught", "catch":result}
	return {"ok":true, "code":"reeling"}

func assist(helper_id: String, target_id: String, kind: String) -> Dictionary:
	if helper_id == target_id or not casts.has(target_id) or kind not in ["generic","rigger"]:
		return {"ok":false, "code":"invalid_assist"}
	var c: Dictionary = casts[target_id]
	if c.assists.has(kind):
		return {"ok":false, "code":"already_assisted"}
	c.assists.append(kind)
	c.progress = minf(0.95, c.progress + (0.20 if kind == "rigger" else 0.10))
	c.tension = maxf(0.0, c.tension - 0.15)
	return {"ok":true, "code":"assisted"}

func cancel(profile_id: String) -> void:
	casts.erase(profile_id)

func snapshot() -> Dictionary:
	return casts.duplicate(true)

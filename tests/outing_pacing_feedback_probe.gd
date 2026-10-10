extends SceneTree
## Read-only product investigation. Fixed positions isolate reward/context feedback;
## catches use real cast/reel intents and persisted rewards. No native renderer.
const Game = preload("res://game/main.gd")
const Guide = preload("res://game/ui/outing_guide.gd")
var app: Node3D
var serial: int = 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	app = Game.new()
	var fixture: String = "user://tests/outing-feedback-" + str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture))
	app.save_path = fixture + "/household.json"
	app.settings_path = fixture + "/settings.json"
	app.game_port = 24639
	root.add_child(app)
	await process_frame
	app._host("Feedback probe")
	app.set_process(false)
	app.set_physics_process(false)
	app.controller.set_physics_process(false)
	await physics_frame
	var c = app.controller
	_at("jetty")
	for species: String in ["penny_perch", "bellgill"]:
		for candidate in range(1000):
			var random = RandomNumberGenerator.new()
			random.seed = candidate
			var roll: Dictionary = CatchTable.roll("jetty", "day", 0, random.randf(), random.randf(), random.randf())
			if roll.species_id == species and roll.trait_id == "none":
				c.rng.seed = candidate
				break
		var started: Dictionary = _action("cast")
		if not started.ok:
			print("ERROR_CAST " + str(started)); quit(1); return
		for i in range(2000):
			if not c.fishing.casts.has("crew_1"): break
			var state: Dictionary = c.fishing.casts.crew_1
			var held: bool = float(state.get("fish_position", 0.5)) > float(state.get("bar_position", 0.5))
			_action("reel", {"held": held, "pull": 0.0})
			c._physics_process(0.05)
	var saved: Dictionary = c.progression.snapshot()
	print("OUTING_FEEDBACK_AFTER_TWO_SPECIES " + JSON.stringify({"discoveries": saved.discoveries, "angler_unlocked": Equipment.outfit_unlocked(saved, "angler"), "notes": c.notes}))
	_at("boat")
	print("OUTING_FEEDBACK_BANK " + str(_action("bank")))
	_at("rod_cache")
	print("OUTING_FEEDBACK_CACHE_ACTION " + str(_action("open_cache", {"cache_id": "shore_rod_cache"})))
	var data: Dictionary = c.snapshot()
	print("OUTING_FEEDBACK_ROD_FOUND " + JSON.stringify({"last_notice": c.notes.back(), "owned_rods": data.progression.owned_rods, "equipped_rod": data.progression.profiles.crew_1.rod_id, "next_step": Guide.next_step(data, "crew_1", {"position": app.world.markers.rod_cache, "markers": app.world.markers, "interact": "E"})}))
	_at("engine_cache")
	_action("open_cache", {"cache_id": "tide_engine_cache"})
	_at("boat")
	data = c.snapshot()
	print("OUTING_FEEDBACK_ENGINE_FOUND " + JSON.stringify({"engine_part": data.progression.campaign_flags.get("engine_part", false), "coins": data.progression.coins, "boat_context": app._boat_context(data, "crew_1", "E")}))
	print("OUTING_FEEDBACK_CATCH_TIMES " + JSON.stringify(_fish_times()))
	app.session.close()
	app.queue_free()
	await process_frame
	quit()

func _at(marker: String) -> void:
	var actor: Node3D = app.controller.avatars.crew_1
	actor.global_position = app.world.markers[marker]
	actor.last_dry = actor.global_position
	actor.velocity = Vector3.ZERO

func _action(action: String, payload: Dictionary = {}) -> Dictionary:
	serial += 1
	return app.controller.apply_intent(1, action, payload, "feedback-" + str(serial))

func _fish_times() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for rod: String in Equipment.rods_all():
		for species: String in ["penny_perch", "bellgill", "moss_skipper"]:
			var fishing = FishingRules.new()
			fishing.start("crew_1", species, "timing")
			fishing.configure_rod("crew_1", rod)
			var seconds: float = 0.0
			var held: bool = true
			var outcome: String = "timeout"
			for i in range(4000):
				var state: Dictionary = fishing.casts.crew_1
				held = float(state.get("fish_position", 0.5)) > float(state.get("bar_position", 0.5))
				var step: Dictionary = fishing.step("crew_1", held, 0.0, 0.05)
				seconds += 0.05
				if step.code in ["caught", "fish_escaped"]:
					outcome = step.code
					break
			result.append({"rod": rod, "species": species, "seconds": snappedf(seconds, 0.01), "outcome": outcome})
	return result

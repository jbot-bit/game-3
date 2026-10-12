extends SceneTree

const Profile = preload("res://profile.gd")
var checks = 0
var failures = 0
var paths: Array[String] = []

func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + title)

func fixture(value: Dictionary) -> String:
	var path = "user://family_profile_%d_%d.json" % [Time.get_ticks_usec(), paths.size()]
	paths.append(path)
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()
	return path

func collection(value: Dictionary) -> Dictionary:
	return {"inventory":value.inventory, "bags":value.bags, "equipped":value.equipped, "redeemed":value.redeemed}.duplicate(true)

func _initialize() -> void:
	var old = {"version":1, "bags":37, "inventory":[], "equipped":{"outfit":"gold", "accessory":"crown"}, "redeemed":["old-win-1", "old-win-2"]}
	for item in Profile.catalog(): old.inventory.append(item.id)
	var path = fixture(old)
	var profile = Profile.new(path)
	check(profile.data.version == 2 and profile.outfit().character == "blank", "Old save migrates to Fresh Bean schema v2")
	check(collection(profile.data) == collection(old), "Populated migration preserves every unlock, bag, equipped item and redeemed ID")
	check(Profile.characters() == [{"id":"blank", "name":"Fresh Bean"}, {"id":"evie", "name":"Evie"}, {"id":"tyler", "name":"Tyler"}, {"id":"dad", "name":"Dad"}], "Character order and names are stable")
	for character in Profile.characters():
		check(profile.select_character(character.id), "Free selection succeeds: " + character.id)
		profile = Profile.new(path)
		check(profile.outfit() == {"character":character.id, "outfit":"gold", "accessory":"crown"}, "Identity and equipped clothes persist: " + character.id)
		check(collection(profile.data) == collection(old), "Selection preserves collection: " + character.id)
	var before = profile.data.duplicate(true)
	check(not profile.select_character("unknown") and profile.data == before, "Unknown selection is rejected without changing profile")
	for invalid in [null, 12, true, {}, [], "EVIE", "unknown"]:
		check(Profile.valid_character(invalid) == "blank", "Malformed identity falls back to blank")
		check(Profile.valid_equipment({"character":invalid, "outfit":"gold", "accessory":"crown"}) == {"character":"blank", "outfit":"gold", "accessory":"crown"}, "Malformed network identity retains valid clothing")
	var malformed = old.duplicate(true)
	malformed.character = ["evie"]
	var recovered_invalid = Profile.new(fixture(malformed))
	check(recovered_invalid.outfit().character == "blank" and collection(recovered_invalid.data) == collection(old), "Malformed saved identity preserves old collection")
	# Corrupt current after a saved selection: the previous complete save is retained.
	check(profile.select_character("evie") and profile.select_character("tyler"), "Create selected-character backup")
	var corrupt = FileAccess.open(path, FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	profile = Profile.new(path)
	check(profile.outfit().character == "evie" and collection(profile.data) == collection(old), "Backup recovery retains identity and complete inventory")
	var starter = Profile.defaults()
	starter.bags = 11
	starter.redeemed = ["earned-before-family"]
	var fresh_path = fixture(starter)
	var fresh = Profile.new(fresh_path)
	check(fresh.select_character("dad") and not fresh.equip("gold"), "Free character choice does not unlock clothing")
	for index in 11:
		var reward = fresh.open_bag()
		check(reward.has("id") and fresh.outfit().character == "dad", "Bag reward preserves selected character")
	check(fresh.data.inventory.size() == 13 and fresh.data.bags == 0 and fresh.data.redeemed == starter.redeemed, "Identity does not enter the eleven collectible rewards")
	fresh = Profile.new(fresh_path)
	check(fresh.outfit().character == "dad" and fresh.data.inventory.size() == 13, "Reward and character survive reload together")
	# A parent that is a file cannot receive a save; selection must roll back.
	var failed = Profile.new(fresh_path + "/cannot-save.json")
	var failed_before = failed.data.duplicate(true)
	check(not failed.select_character("evie") and failed.data == failed_before and not failed.last_error.is_empty(), "Failed identity persistence rolls back in-memory state")
	for saved_path in paths:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(saved_path + suffix): DirAccess.remove_absolute(saved_path + suffix)
	print("FAMILY_PROFILE_RESULT %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)

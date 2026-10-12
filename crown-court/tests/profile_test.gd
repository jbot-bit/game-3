extends SceneTree

var checks = 0
var failures = 0
func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + title)

func _initialize() -> void:
	if not ResourceLoader.exists("res://profile.gd"):
		check(false, "Persistent wardrobe is missing")
		quit(1)
		return
	var Profile = load("res://profile.gd")
	var path = "user://test_closet_%d.json" % Time.get_ticks_usec()
	var p = Profile.new(path)
	check(p.data.inventory == ["blank", "none"] and p.data.bags == 0, "New player starts blank with no bags")
	check(p.open_bag().is_empty(), "No free opening without an earned bag")
	check(not p.equip("gold"), "Locked clothing cannot be equipped")
	check(p.award_win("round-1"), "A win earns a saved bag")
	check(not p.award_win("round-1") and p.data.bags == 1, "Repeated winner snapshots cannot grant duplicate bags")
	var reloaded = Profile.new(path)
	check(reloaded.data.bags == 1 and not reloaded.award_win("round-1"), "Pending bags and reward dedupe survive restart")
	var first = reloaded.open_bag()
	check(first.has("id") and reloaded.data.bags == 0 and reloaded.data.inventory.has(first.get("id", "missing")), "Opening consumes a bag and unlocks a real catalog item")
	check(reloaded.equip(first.id), "Unlocked reward can be equipped")
	p = Profile.new(path)
	check(p.outfit().get(first.slot) == first.id, "Equipped item persists across restart")
	for i in 10:
		p.award_win("round-%d" % (i + 2))
		check(p.open_bag().has("id"), "Each bag unlocks a new item until collection is complete")
	check(p.data.inventory.size() == Profile.catalog().size(), "All catalog items collectible without duplicates")
	p.award_win("complete")
	check(p.open_bag().get("complete", false) and p.data.bags == 1, "Completed collection does not waste pending bags")
	var sanitized = Profile.valid_equipment({"outfit":"crown","accessory":"unknown"})
	check(sanitized == {"character":"blank","outfit":"blank","accessory":"none"}, "Network outfits reject wrong slots and unknown IDs")
	# Simulate an interrupted or corrupt final write; previous atomic backup must load.
	var f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("broken data")
	f.close()
	var recovered = Profile.new(path)
	check(recovered.data.inventory.size() > 2, "Corrupt current profile recovers previous saved wardrobe")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PROFILE_RESULT %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)

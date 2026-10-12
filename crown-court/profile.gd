extends RefCounted

var path: String
var data: Dictionary
var last_error = ""

func _init(save_path: String = "user://closet.json") -> void:
	path = save_path
	data = defaults()
	load_profile()

static func defaults() -> Dictionary:
	return {"version": 2, "character": "blank", "bags": 0, "inventory": ["blank", "none"],
		"equipped": {"outfit": "blank", "accessory": "none"}, "redeemed": []}

static func characters() -> Array:
	return [{"id":"blank", "name":"Fresh Bean"}, {"id":"evie", "name":"Evie"},
		{"id":"tyler", "name":"Tyler"}, {"id":"dad", "name":"Dad"}]

static func valid_character(value) -> String:
	if value is String:
		for character in characters():
			if value == character.id: return character.id
	return "blank"

static func catalog() -> Array:
	return [
		{"id":"blank", "name":"Fresh Bean", "slot":"outfit", "rarity":"starter", "description":"Just you. Ready for the court."},
		{"id":"none", "name":"No Accessory", "slot":"accessory", "rarity":"starter", "description":"Keep it simple."},
		{"id":"jersey", "name":"Court Rookie", "slot":"outfit", "rarity":"common", "description":"Your first proper game-day jersey."},
		{"id":"stripes", "name":"Candy Stripes", "slot":"outfit", "rarity":"common", "description":"Sweet stripes. Serious buckets."},
		{"id":"cap", "name":"Backwards Cap", "slot":"accessory", "rarity":"common", "description":"Schoolyard legend in the making."},
		{"id":"sweatband", "name":"Sweat Equity", "slot":"accessory", "rarity":"common", "description":"Work hard. Dunk harder."},
		{"id":"hoodie", "name":"Street Hoodie", "slot":"outfit", "rarity":"rare", "description":"An oversized fit for oversized plays."},
		{"id":"shades", "name":"No-Look Shades", "slot":"accessory", "rarity":"rare", "description":"The future is offensively bright."},
		{"id":"headphones", "name":"Bassline", "slot":"accessory", "rarity":"rare", "description":"Every rebound gets its own beat."},
		{"id":"space", "name":"Orbit Suit", "slot":"outfit", "rarity":"epic", "description":"Low gravity is a state of mind."},
		{"id":"horns", "name":"Little Menace", "slot":"accessory", "rarity":"epic", "description":"Harmless horns. Questionable defence."},
		{"id":"gold", "name":"24 Carat", "slot":"outfit", "rarity":"legendary", "description":"A gleaming suit for a walking highlight."},
		{"id":"crown", "name":"Court Royalty", "slot":"accessory", "rarity":"legendary", "description":"Earned on the court. Worn everywhere."}
	]

static func rarity_color(rarity: String) -> Color:
	return {"starter":Color("b8c8d7"), "common":Color("9cd5d1"), "rare":Color("54b8ff"),
		"epic":Color("ce82ff"), "legendary":Color("ffd15b")}.get(rarity, Color.WHITE)

static func valid_equipment(value: Dictionary) -> Dictionary:
	var result = {"character":valid_character(value.get("character")), "outfit":"blank", "accessory":"none"}
	for item in catalog():
		if value.get(item.slot, "") == item.id: result[item.slot] = item.id
	return result

func load_profile() -> void:
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var parser = JSON.new()
		if parser.parse(FileAccess.get_file_as_string(candidate)) != OK: continue
		var parsed = parser.data
		if not parsed is Dictionary or not parsed.get("inventory") is Array or not parsed.get("redeemed") is Array: continue
		var clean = defaults()
		for item in catalog():
			if item.id in parsed.inventory and item.id not in clean.inventory: clean.inventory.append(item.id)
		clean.bags = clampi(int(parsed.get("bags", 0)), 0, 100000)
		var equipped = valid_equipment(parsed.get("equipped", {}) if parsed.get("equipped", {}) is Dictionary else {})
		# Identity is free and independent of collectible clothing, including in old saves.
		clean.character = valid_character(parsed.get("character", equipped.character))
		for slot in ["outfit", "accessory"]:
			if equipped[slot] in clean.inventory: clean.equipped[slot] = equipped[slot]
		for round_id in parsed.redeemed:
			if round_id is String and round_id.length() <= 160: clean.redeemed.append(round_id)
		data = clean
		return

func save_profile() -> bool:
	last_error = ""
	var temporary = path + ".tmp"
	var f = FileAccess.open(temporary, FileAccess.WRITE)
	if f == null:
		last_error = "Could not save wardrobe. Retry before closing."
		return false
	f.store_string(JSON.stringify(data))
	f.flush()
	var status = f.get_error()
	f.close()
	if status != OK:
		last_error = "Could not save wardrobe. Retry before closing."
		return false
	# A valid old profile is retained as backup before replacing the current file.
	if FileAccess.file_exists(path):
		var parser = JSON.new()
		parser.parse(FileAccess.get_file_as_string(path))
		var previous = parser.data
		if previous is Dictionary:
			if FileAccess.file_exists(path + ".bak"): DirAccess.remove_absolute(path + ".bak")
			if DirAccess.rename_absolute(path, path + ".bak") != OK:
				last_error = "Could not rotate wardrobe backup."
				return false
		else:
			if DirAccess.remove_absolute(path) != OK: return false
	if DirAccess.rename_absolute(temporary, path) != OK:
		last_error = "Could not finish saving wardrobe."
		return false
	return true

func award_win(match_id: String) -> bool:
	if match_id.is_empty() or match_id.length() > 160 or match_id in data.redeemed: return false
	var previous = data.duplicate(true)
	data.redeemed.append(match_id)
	data.bags += 1
	if save_profile(): return true
	data = previous
	return false

func open_bag() -> Dictionary:
	if data.bags <= 0: return {}
	var remaining = []
	var total = 0.0
	var weights = {"common":50.0, "rare":30.0, "epic":15.0, "legendary":5.0}
	var counts = {"common":0, "rare":0, "epic":0, "legendary":0}
	for item in catalog():
		if item.id not in data.inventory:
			remaining.append(item)
			counts[item.rarity] += 1
	if remaining.is_empty(): return {"complete":true}
	for rarity in counts:
		if counts[rarity] > 0: total += weights[rarity]
	var roll = randf() * total
	var reward = remaining.back()
	for item in remaining:
		roll -= weights[item.rarity] / counts[item.rarity]
		if roll <= 0:
			reward = item
			break
	var previous = data.duplicate(true)
	data.bags -= 1
	data.inventory.append(reward.id)
	if save_profile(): return reward.duplicate()
	data = previous
	return {}

func equip(id: String) -> bool:
	if id not in data.inventory: return false
	for item in catalog():
		if item.id != id: continue
		var previous = data.duplicate(true)
		data.equipped[item.slot] = id
		if save_profile(): return true
		data = previous
		return false
	return false

func outfit() -> Dictionary:
	var equipped: Dictionary = data.equipped.duplicate()
	equipped.character = valid_character(data.get("character"))
	return valid_equipment(equipped)

func select_character(id: String) -> bool:
	if valid_character(id) != id: return false
	var previous = data.duplicate(true)
	data.character = id
	if save_profile(): return true
	data = previous
	return false

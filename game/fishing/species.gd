class_name Species
extends RefCounted

static func catalog() -> Dictionary:
	return {
		"penny_perch": _entry("Penny Perch",10,"dart","common","Jetty; reeds", "d99b54","bd624d","perch"),
		"pebble_dab": _entry("Pebble Dab",11,"heavy","common","Flooded terraces, any time", "989e96","e4d4af","dab"),
		"ribbon_minnow": _entry("Ribbon Minnow",12,"dart","common","Flooded terraces, any time", "76b6ca","cfdfdd","minnow"),
		"moss_skipper": _entry("Moss Skipper",13,"surge","common","Terraces; beacon shore", "8c9e57","b6c874","skipper"),
		"cork_chub": _entry("Cork Chub",14,"heavy","common","Tidepools, any time", "b98768","e5c898","chub"),
		"kite_sprat": _entry("Kite Sprat",15,"surge","common","Tidepools; beacon shore", "c88eae","e4d4af","kite"),
		"bellgill": _entry("Bellgill",20,"heavy","uncommon","Jetty; reeds", "7ea8a3","e4d4af","bell"),
		"glass_roach": _entry("Glass Roach",22,"dart","uncommon","Terraces; tidepools; more after dusk", "a9ced0","5a919b","roach"),
		"copperfin": _entry("Copperfin",26,"surge","uncommon","Tidepools; beacon shore", "af7052","f3b766","copper"),
		"cloud_carp": _entry("Cloud Carp",28,"heavy","uncommon","Beacon shore; terraces after dusk", "b9b8cf","7979a6","carp"),
		"lantern_eel": _entry("Lantern Eel",40,"dart","rare","Reeds after dusk; 10% before dry-streak guarantee", "727899","ffd071","eel"),
		"crown_ray": _entry("Crown Ray",50,"surge","rare","Beacon shore after dusk; 10% before dry-streak guarantee", "826fa9","e6c878","ray")
	}

static func _entry(title: String, value: int, behavior: String, rarity: String, hint: String, color: String, accent: String, shape: String) -> Dictionary:
	return {"name":title,"value":value,"behavior":behavior,"rarity":rarity,"habitat_hint":hint,"color":color,"accent":accent,"shape":shape}

static func is_rare(species_id: String) -> bool:
	return catalog().get(species_id, {}).get("rarity", "") == "rare"

static func value_for(species_id: String, trait_id: String, whole: bool = false) -> int:
	## Host-canonical values. -1 rejects invalid records instead of rewarding them.
	var fish: Dictionary = catalog().get(species_id, {})
	var multipliers: Dictionary = {"":1.0,"none":1.0,"oversized":1.25,"moonlit":1.5,"stormmarked":1.75}
	if fish.is_empty() or not multipliers.has(trait_id) or (whole and trait_id != "oversized"):
		return -1
	return int(fish.value) * 2 if whole else floori(float(fish.value) * float(multipliers[trait_id]))

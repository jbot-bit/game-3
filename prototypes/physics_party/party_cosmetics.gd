extends RefCounted
## Cosmetic cards have no movement, power, or purchase effects.

const BASE_COLORS: Array[String] = ["orange", "blue", "lilac"]
const COLOR_VALUES: Dictionary = {
	"orange": Color("ff9c44"), "blue": Color("4dabf7"), "lilac": Color("b591ff"),
	"mint": Color("43d6cf"), "rose": Color("ee85a2"), "cream": Color("eee8dc"),
	"sky": Color("83d8ee"), "lime": Color("b0d76b"), "peach": Color("ffc2a6"),
	"midnight": Color("384464"), "lavender": Color("d4baff"), "prism": Color("dce8ef"),
}
const CARDS: Array[Dictionary] = [
	{"id": "paint_mint", "name": "Mint", "rarity": "common", "kind": "color", "value": "mint"},
	{"id": "paint_rose", "name": "Rose", "rarity": "common", "kind": "color", "value": "rose"},
	{"id": "paint_cream", "name": "Cream", "rarity": "common", "kind": "color", "value": "cream"},
	{"id": "paint_sky", "name": "Sky", "rarity": "common", "kind": "color", "value": "sky"},
	{"id": "paint_lime", "name": "Lime", "rarity": "common", "kind": "color", "value": "lime"},
	{"id": "paint_peach", "name": "Peach", "rarity": "common", "kind": "color", "value": "peach"},
	{"id": "gear_cap", "name": "Cap", "rarity": "rare", "kind": "accessory", "value": "cap"},
	{"id": "gear_beanie", "name": "Beanie", "rarity": "rare", "kind": "accessory", "value": "beanie"},
	{"id": "paint_midnight", "name": "Midnight", "rarity": "rare", "kind": "color", "value": "midnight"},
	{"id": "paint_lavender", "name": "Lavender", "rarity": "rare", "kind": "color", "value": "lavender"},
	{"id": "gear_sprout", "name": "Sprout", "rarity": "epic", "kind": "accessory", "value": "sprout"},
	{"id": "gear_headphones", "name": "Headphones", "rarity": "epic", "kind": "accessory", "value": "headphones"},
	{"id": "paint_prism", "name": "Prism", "rarity": "epic", "kind": "color", "value": "prism"},
	{"id": "gear_crown", "name": "Crown", "rarity": "legendary", "kind": "accessory", "value": "crown"},
	{"id": "gear_halo", "name": "Halo", "rarity": "legendary", "kind": "accessory", "value": "halo"},
]


static func default_style(slot: int) -> Dictionary:
	return {"color": BASE_COLORS[clampi(slot, 0, 2)], "accessory": "none"}


static func color_for(id: String) -> Color:
	return COLOR_VALUES.get(id, COLOR_VALUES.orange)


static func card_info(card_id: String) -> Dictionary:
	for card: Dictionary in CARDS:
		if card.id == card_id:
			return card.duplicate()
	return {}


static func colors(owned: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in BASE_COLORS:
		result.append({"id": id, "name": id.capitalize(), "unlocked": true, "rarity": "common"})
	for card: Dictionary in CARDS:
		if card.kind == "color":
			result.append({"id": card.value, "name": card.name, "unlocked": card.id in owned, "rarity": card.rarity})
	return result


static func accessories(owned: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"id": "none", "name": "Plain", "unlocked": true, "rarity": "common"}]
	for card: Dictionary in CARDS:
		if card.kind == "accessory":
			result.append({"id": card.value, "name": card.name, "unlocked": card.id in owned, "rarity": card.rarity})
	return result


static func sanitize(style: Dictionary, owned: Array, slot: int) -> Dictionary:
	var result: Dictionary = default_style(slot)
	for color: Dictionary in colors(owned):
		if color.unlocked and style.get("color") is String and style.color == color.id:
			result.color = color.id
	for accessory: Dictionary in accessories(owned):
		if accessory.unlocked and style.get("accessory") is String and style.accessory == accessory.id:
			result.accessory = accessory.id
	return result


static func draw_bag(owned: Array, rng: RandomNumberGenerator) -> Array[String]:
	var cards: Array[String] = []
	var seen: Array = owned.duplicate()
	for draw in 3:
		var roll: float = rng.randf()
		var rarity: String = "common" if roll < 0.60 else ("rare" if roll < 0.88 else ("epic" if roll < 0.98 else "legendary"))
		var all: Array[String] = []
		var fresh: Array[String] = []
		for card: Dictionary in CARDS:
			if card.rarity != rarity:
				continue
			all.append(card.id)
			if card.id not in seen:
				fresh.append(card.id)
		var pool: Array[String] = fresh if not fresh.is_empty() else all
		var selected: String = pool[rng.randi_range(0, pool.size() - 1)]
		cards.append(selected)
		seen.append(selected)
	return cards

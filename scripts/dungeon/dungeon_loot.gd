extends RefCounted
class_name DungeonLoot

const PREFIXES := ["Rusty", "Iron", "Steel", "Dark", "Ancient", "Cursed", "Blessed", "Swift"]
const WEAPON_NAMES := ["Sword", "Axe", "Mace", "Dagger", "Spear"]
const HELMET_NAMES := ["Helm", "Hood", "Crown", "Cap"]
const CHEST_NAMES := ["Plate", "Mail", "Vest", "Robe"]
const BOOT_NAMES := ["Boots", "Greaves", "Sandals"]
const ACCESSORY_NAMES := ["Ring", "Amulet", "Charm", "Pendant"]
const RARITY_COLORS := {
	"Common": Color(1.0, 1.0, 1.0, 1.0),
	"Uncommon": Color(0.45, 0.95, 0.45, 1.0),
	"Rare": Color(0.42, 0.68, 1.0, 1.0),
	"Epic": Color(0.82, 0.45, 1.0, 1.0),
	"Legendary": Color(1.0, 0.65, 0.1, 1.0),
}
const AFFIX_POOL := [
	{"label": "ATK", "stat": "attack", "min": 3, "max": 8},
	{"label": "DEF", "stat": "defense", "min": 2, "max": 6},
	{"label": "Max HP", "stat": "max_hp", "min": 10, "max": 30},
	{"label": "Speed", "stat": "speed_multiplier", "min": 5, "max": 15, "scale": 0.01, "suffix": "%"},
	{"label": "Crit Chance", "stat": "crit_chance", "min": 3, "max": 8, "scale": 0.01, "suffix": "%"},
	{"label": "Lifesteal", "stat": "lifesteal_ratio", "min": 3, "max": 5, "scale": 0.01, "suffix": "%"},
	{"label": "Gather Speed", "stat": "gather_bonus", "min": 1, "max": 3},
]
const QUALITY_MULTIPLIERS := {
	"Common": 1.0, "Uncommon": 1.3, "Rare": 1.6, "Epic": 2.0, "Legendary": 2.5,
}
const QUALITY_AFFIX_COUNT := {
	"Common": 0, "Uncommon": 1, "Rare": 2, "Epic": 3, "Legendary": 3,
}
const ITEM_DATABASE := preload("res://scripts/inventory/item_database.gd")


static func generate_dungeon_equipment(floor_number: int, rng: RandomNumberGenerator = null) -> Dictionary:
	var slot: String = _pick(["weapon", "helmet", "chest_armor", "boots", "accessory"], rng)
	var quality: String = _pick_quality(floor_number, rng)
	var quality_mult := float(QUALITY_MULTIPLIERS.get(quality, 1.0))
	var base_power := int(round((3 + floor_number * 2) * quality_mult))
	var num_affixes: int = QUALITY_AFFIX_COUNT.get(quality, 0)
	var durability := 50 + floor_number * 5
	var item := {
		"id": "dungeon_%s_%d" % [slot, _randi(rng)],
		"name": _generate_name(slot, quality, rng),
		"slot": slot,
		"type": "equipment",
		"max_stack": 1,
		"icon": ITEM_DATABASE.get_default_equipment_icon(slot),
		"stats": _generate_base_stats(slot, base_power),
		"affixes": _generate_affixes(num_affixes, floor_number, rng),
		"durability": durability,
		"max_durability": durability,
		"durability_current": durability,
		"durability_max": durability,
		"rarity": quality,
		"source": "dungeon",
		"floor_found": floor_number,
		"quantity": 1,
	}
	_apply_affixes_to_stats(item)
	item["color"] = get_rarity_color(str(item.get("rarity", "Common")))
	return item


static func determine_rarity(affix_count: int) -> String:
	return _determine_rarity(affix_count)


static func get_rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)


static func get_item_display_color(stack: Dictionary) -> Color:
	if str(stack.get("source", "")) == "dungeon":
		return get_rarity_color(str(stack.get("rarity", "Common")))
	if stack.has("color") and stack.get("color") is Color:
		return stack.get("color")
	return Color(0.3, 0.55, 0.95, 1.0)


static func _pick_quality(floor_number: int, rng: RandomNumberGenerator = null) -> String:
	var tiers := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
	var min_floors := [1, 3, 5, 8, 12]
	var weights := [
		max(70.0 - float(floor_number) * 4.0, 5.0),
		25.0,
		max(5.0 + float(floor_number) * 2.0, 0.0),
		max(float(floor_number - 7) * 3.0, 0.0),
		max(float(floor_number - 11) * 2.0, 0.0),
	]
	var total := 0.0
	for i in range(tiers.size()):
		if floor_number >= min_floors[i]:
			total += weights[i]
	if total <= 0.0:
		return "Common"
	var roll := _randf(rng) * total
	var running := 0.0
	for i in range(tiers.size()):
		if floor_number < min_floors[i]:
			continue
		running += weights[i]
		if roll <= running:
			return tiers[i]
	return "Common"


static func _generate_name(slot: String, quality: String = "Common", rng: RandomNumberGenerator = null) -> String:
	var prefix_a: String = _pick(PREFIXES, rng)
	var prefix_b: String = _pick(PREFIXES, rng)
	var noun: String
	match slot:
		"weapon":
			noun = _pick(WEAPON_NAMES, rng)
		"helmet":
			noun = _pick(HELMET_NAMES, rng)
		"chest_armor":
			noun = _pick(CHEST_NAMES, rng)
		"boots":
			noun = _pick(BOOT_NAMES, rng)
		_:
			noun = _pick(ACCESSORY_NAMES, rng)
	var base_name := "%s %s %s" % [prefix_a, prefix_b, noun]
	if quality != "Common":
		return "[%s] %s" % [quality, base_name]
	return base_name


static func _generate_base_stats(slot: String, base_power: int) -> Dictionary:
	match slot:
		"weapon":
			return {"attack": base_power + 2}
		"helmet":
			return {"defense": base_power, "max_hp": base_power * 2}
		"chest_armor":
			return {"defense": base_power + 2, "max_hp": base_power * 3}
		"boots":
			return {"defense": max(base_power - 1, 1), "speed_multiplier": 0.05}
		_:
			return {"crit_chance": 0.02, "max_hp": base_power * 2}


static func _generate_affixes(num_affixes: int, _floor_number: int, rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	var pool: Array = AFFIX_POOL.duplicate(true)
	_shuffle(pool, rng)
	var affixes: Array[Dictionary] = []
	for index in range(mini(num_affixes, pool.size())):
		var entry: Dictionary = pool[index]
		var roll: int = _randi_range(rng, int(entry.get("min", 1)), int(entry.get("max", 1)))
		var scale: float = float(entry.get("scale", 1.0))
		affixes.append({
			"label": str(entry.get("label", "")),
			"stat": str(entry.get("stat", "")),
			"value": float(roll) * scale,
			"display_value": roll,
			"suffix": str(entry.get("suffix", "")),
		})
	return affixes


static func _apply_affixes_to_stats(item: Dictionary) -> void:
	var stats: Dictionary = (item.get("stats", {}) as Dictionary).duplicate(true)
	for affix in item.get("affixes", []):
		var stat_name := str((affix as Dictionary).get("stat", ""))
		stats[stat_name] = float(stats.get(stat_name, 0.0)) + float((affix as Dictionary).get("value", 0.0))
	item["stats"] = stats


static func _determine_rarity(num_affixes: int) -> String:
	match num_affixes:
		0:
			return "Common"
		1:
			return "Uncommon"
		2:
			return "Rare"
		_:
			return "Epic"


static func _pick(values: Array, rng: RandomNumberGenerator = null):
	if values.is_empty():
		return null
	return values[_randi_range(rng, 0, values.size() - 1)]


static func _shuffle(values: Array, rng: RandomNumberGenerator = null) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := _randi_range(rng, 0, index)
		var temp = values[index]
		values[index] = values[swap_index]
		values[swap_index] = temp


static func _randi(rng: RandomNumberGenerator = null) -> int:
	return rng.randi() if rng != null else randi()


static func _randf(rng: RandomNumberGenerator = null) -> float:
	return rng.randf() if rng != null else randf()


static func _randi_range(rng: RandomNumberGenerator, min_value: int, max_value: int) -> int:
	if max_value < min_value:
		return min_value
	return rng.randi_range(min_value, max_value) if rng != null else randi_range(min_value, max_value)

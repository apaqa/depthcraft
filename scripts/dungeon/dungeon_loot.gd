extends RefCounted
class_name DungeonLoot

const ITEM_DATABASE = preload("res://scripts/inventory/item_database.gd")

const PREFIXES = ["Ancient", "Runed", "Iron", "Storm", "Shadow", "Wild", "Sunforged", "Deepstone", "Cursed", "Radiant", "Vile", "Frostbound", "Emberlit", "Voidtouched", "Serrated"]
const WEAPON_NAMES = ["Blade", "Sword", "Cleaver", "Saber", "Edge", "Dagger", "Staff", "Wand", "Axe", "Bow", "Reaper", "Fang"]
const HELMET_NAMES = ["Helm", "Crown", "Hood", "Greathelm", "Visage", "Circlet"]
const CHEST_NAMES = ["Mail", "Cuirass", "Vest", "Armor", "Plate", "Hauberk"]
const BOOT_NAMES = ["Boots", "Greaves", "Treads", "Sabatons", "Striders"]
const OFFHAND_NAMES = ["Shield", "Buckler", "Barrier", "Bulwark", "Ward"]
const ACCESSORY_NAMES = ["Ring", "Charm", "Talisman", "Band", "Amulet", "Pendant", "Sigil"]

const RARITY_ORDER = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const RARITY_ALIASES = {
	"Common": "Common",
	"Uncommon": "Uncommon",
	"Rare": "Rare",
	"Epic": "Epic",
	"Legendary": "Legendary",
}
const RARITY_COLORS = {
	"Common": Color(0.8, 0.8, 0.8, 1.0),
	"Uncommon": Color(0.0, 0.8, 0.0, 1.0),
	"Rare": Color(0.0, 0.4, 1.0, 1.0),
	"Epic": Color(0.6, 0.0, 0.8, 1.0),
	"Legendary": Color(1.0, 0.5, 0.0, 1.0),
}
const AFFIX_POOL = [
	{"label": "Savage", "stat": "attack", "min": 3, "max": 8},
	{"label": "Bulwark", "stat": "defense", "min": 2, "max": 6},
	{"label": "Vital", "stat": "max_hp", "min": 10, "max": 30},
	{"label": "Swift", "stat": "speed_multiplier", "min": 5, "max": 15, "scale": 0.01, "suffix": "%"},
	{"label": "Keen", "stat": "crit_chance", "min": 3, "max": 8, "scale": 0.01, "suffix": "%"},
	{"label": "Leeching", "stat": "lifesteal_ratio", "min": 3, "max": 5, "scale": 0.01, "suffix": "%"},
	{"label": "Gatherer's", "stat": "gather_bonus", "min": 1, "max": 3},
	{"label": "Thorned", "stat": "thorns_damage", "min": 2, "max": 7},
	{"label": "Elusive", "stat": "dodge_chance", "min": 3, "max": 8, "scale": 0.01, "suffix": "%"},
	{"label": "Quickcast", "stat": "cooldown_reduction", "min": 3, "max": 10, "scale": 0.01, "suffix": "%"},
	{"label": "Arcane", "stat": "spell_power", "min": 4, "max": 12},
	{"label": "Brutal", "stat": "crit_damage_multiplier", "min": 10, "max": 30, "scale": 0.01, "suffix": "%"},
	{"label": "Regenerating", "stat": "hp_regen", "min": 1, "max": 4},
	{"label": "Piercing", "stat": "armor_penetration", "min": 2, "max": 6},
	{"label": "Warding", "stat": "elemental_resistance", "min": 3, "max": 8},
]
const QUALITY_MULTIPLIERS = {
	"Common": 1.0,
	"Uncommon": 1.3,
	"Rare": 1.6,
	"Epic": 2.0,
	"Legendary": 2.5,
}
const QUALITY_AFFIX_COUNT = {
	"Common": 0,
	"Uncommon": 1,
	"Rare": 2,
	"Epic": 3,
	"Legendary": 4,
}
const QUALITY_SUB_STAT_COUNT: Dictionary = {
	"Common": 0,
	"Uncommon": 1,
	"Rare": 2,
	"Epic": 3,
	"Legendary": 3,
}
const QUALITY_MAX_FORGE: Dictionary = {
	"Common": 3,
	"Uncommon": 5,
	"Rare": 8,
	"Epic": 12,
	"Legendary": 15,
}
const MAIN_STAT_POOLS: Dictionary = {
	"weapon": ["attack", "crit_chance", "crit_damage_multiplier"],
	"helmet": ["defense", "max_hp"],
	"chest_armor": ["defense", "max_hp"],
	"boots": ["speed_multiplier", "dodge_chance", "defense"],
	"gloves": ["attack", "crit_chance"],
	"accessory": ["attack", "defense", "max_hp", "crit_chance", "crit_damage_multiplier", "speed_multiplier", "dodge_chance", "lifesteal_ratio"],
	"offhand": ["defense", "max_hp", "attack"],
}
const MAIN_STAT_RANGES: Dictionary = {
	"attack": {"Common": [5, 8], "Uncommon": [7, 12], "Rare": [10, 18], "Epic": [15, 25], "Legendary": [22, 35]},
	"defense": {"Common": [3, 6], "Uncommon": [5, 10], "Rare": [8, 15], "Epic": [12, 22], "Legendary": [18, 30]},
	"max_hp": {"Common": [10, 20], "Uncommon": [15, 35], "Rare": [25, 50], "Epic": [40, 75], "Legendary": [60, 100]},
	"crit_chance": {"Common": [1, 3], "Uncommon": [2, 5], "Rare": [4, 8], "Epic": [6, 12], "Legendary": [10, 18]},
	"crit_damage_multiplier": {"Common": [5, 10], "Uncommon": [8, 15], "Rare": [12, 25], "Epic": [20, 35], "Legendary": [30, 50]},
	"speed_multiplier": {"Common": [3, 6], "Uncommon": [5, 10], "Rare": [8, 15], "Epic": [12, 20], "Legendary": [18, 30]},
	"dodge_chance": {"Common": [1, 3], "Uncommon": [2, 5], "Rare": [3, 8], "Epic": [5, 12], "Legendary": [8, 18]},
	"lifesteal_ratio": {"Common": [1, 2], "Uncommon": [1, 3], "Rare": [2, 5], "Epic": [3, 7], "Legendary": [5, 10]},
}
const SUB_STAT_POOL: Array[String] = [
	"attack", "defense", "max_hp",
	"crit_chance", "crit_damage_multiplier",
	"speed_multiplier", "dodge_chance", "lifesteal_ratio",
]
# Stats that use percentage scale (0.01 multiplier)
const PERCENT_STATS: Array[String] = [
	"crit_chance", "crit_damage_multiplier", "speed_multiplier",
	"dodge_chance", "lifesteal_ratio",
]


static func generate_dungeon_equipment(floor_number: int, rng: RandomNumberGenerator = null) -> Dictionary:
	return _build_equipment(_pick_slot(rng), _pick_quality(floor_number, rng), floor_number, rng)


static func determine_rarity(affix_count: int) -> String:
	return _determine_rarity(affix_count)


static func get_rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(_normalize_rarity(rarity), Color.WHITE)


static func get_item_display_color(stack: Dictionary) -> Color:
	if str(stack.get("source", "")) == "dungeon":
		return get_rarity_color(str(stack.get("rarity", "Common")))
	if stack.has("color") and stack.get("color") is Color:
		return stack.get("color")
	return Color(0.3, 0.55, 0.95, 1.0)


static func generate_dungeon_equipment_min_rarity(floor_number: int, min_rarity: String, rng: RandomNumberGenerator = null) -> Dictionary:
	var normalized_min: String = _normalize_rarity(min_rarity)
	var min_index: int = maxi(RARITY_ORDER.find(normalized_min), 0)
	var quality: String = _pick_quality(floor_number, rng)
	var quality_index: int = maxi(RARITY_ORDER.find(quality), 0)
	if quality_index < min_index:
		quality = RARITY_ORDER[min_index]
	return _build_equipment(_pick_slot(rng), quality, floor_number, rng)


static func _build_equipment(slot: String, quality: String, floor_number: int, rng: RandomNumberGenerator = null) -> Dictionary:
	var resolved_floor: int = maxi(floor_number, 1)
	var normalized_quality: String = _normalize_rarity(quality)
	var quality_mult: float = float(QUALITY_MULTIPLIERS.get(normalized_quality, 1.0))
	var base_power: int = int(round((3 + resolved_floor * 2) * quality_mult))
	var num_affixes: int = int(QUALITY_AFFIX_COUNT.get(normalized_quality, 0))
	var durability: int = 50 + resolved_floor * 5
	# Generate main stat
	var main_stat_result: Dictionary = _generate_main_stat(slot, normalized_quality, rng)
	# Generate sub stats
	var sub_stats_result: Array[Dictionary] = _generate_sub_stats(normalized_quality, str(main_stat_result.get("type", "")), rng)
	var item: Dictionary = {
		"id": "dungeon_%s_%d" % [slot, _randi(rng)],
		"name": _generate_name(slot, normalized_quality, rng),
		"slot": slot,
		"type": "equipment",
		"max_stack": 1,
		"icon": ITEM_DATABASE.get_equipment_icon(slot, normalized_quality),
		"stats": _generate_base_stats(slot, base_power),
		"affixes": _generate_affixes(num_affixes, resolved_floor, rng),
		"main_stat_type": str(main_stat_result.get("type", "")),
		"main_stat_value": int(main_stat_result.get("value", 0)),
		"sub_stats": sub_stats_result,
		"forge_level": 0,
		"max_forge": int(QUALITY_MAX_FORGE.get(normalized_quality, 3)),
		"durability": durability,
		"max_durability": durability,
		"durability_current": durability,
		"durability_max": durability,
		"rarity": normalized_quality,
		"source": "dungeon",
		"floor_found": resolved_floor,
		"quantity": 1,
	}
	_apply_affixes_to_stats(item)
	_apply_main_and_sub_to_stats(item)
	item["color"] = get_rarity_color(str(item.get("rarity", "Common")))
	return item


static func _pick_quality(floor_number: int, rng: RandomNumberGenerator = null) -> String:
	var resolved_floor: int = maxi(floor_number, 1)
	var min_floors: Array[int] = [1, 3, 5, 8, 12]
	var weights: Array[float] = [
		max(70.0 - float(resolved_floor) * 4.0, 5.0),
		25.0,
		max(5.0 + float(resolved_floor) * 2.0, 0.0),
		max(float(resolved_floor - 7) * 3.0, 0.0),
		max(float(resolved_floor - 11) * 2.0, 0.0),
	]
	var total: float = 0.0
	for index in range(RARITY_ORDER.size()):
		if resolved_floor >= min_floors[index]:
			total += weights[index]
	if total <= 0.0:
		return "Common"
	var roll: float = _randf(rng) * total
	var running: float = 0.0
	for index in range(RARITY_ORDER.size()):
		if resolved_floor < min_floors[index]:
			continue
		running += weights[index]
		if roll <= running:
			return RARITY_ORDER[index]
	return "Common"


static func _pick_slot(rng: RandomNumberGenerator = null) -> String:
	return str(_pick(["weapon", "helmet", "chest_armor", "boots", "accessory", "offhand"], rng))


static func _generate_name(slot: String, quality: String = "Common", rng: RandomNumberGenerator = null) -> String:
	var prefix_a: String = str(_pick(PREFIXES, rng))
	var prefix_b: String = str(_pick(PREFIXES, rng))
	var noun: String
	match slot:
		"weapon":
			noun = str(_pick(WEAPON_NAMES, rng))
		"helmet":
			noun = str(_pick(HELMET_NAMES, rng))
		"chest_armor":
			noun = str(_pick(CHEST_NAMES, rng))
		"boots":
			noun = str(_pick(BOOT_NAMES, rng))
		"offhand":
			noun = str(_pick(OFFHAND_NAMES, rng))
		_:
			noun = str(_pick(ACCESSORY_NAMES, rng))
	var base_name: String = "%s %s %s" % [prefix_a, prefix_b, noun]
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
		"offhand":
			return {"defense": base_power + 1, "max_hp": base_power * 2, "thorns_damage": max(base_power / 3, 1)}
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
		var stat_name: String = str((affix as Dictionary).get("stat", ""))
		stats[stat_name] = float(stats.get(stat_name, 0.0)) + float((affix as Dictionary).get("value", 0.0))
	item["stats"] = stats


static func _apply_main_and_sub_to_stats(item: Dictionary) -> void:
	var stats: Dictionary = (item.get("stats", {}) as Dictionary).duplicate(true)
	var main_type: String = str(item.get("main_stat_type", ""))
	var main_value: int = int(item.get("main_stat_value", 0))
	if main_type != "" and main_value > 0:
		if PERCENT_STATS.has(main_type):
			stats[main_type] = float(stats.get(main_type, 0.0)) + float(main_value) * 0.01
		else:
			stats[main_type] = float(stats.get(main_type, 0.0)) + float(main_value)
	for sub_entry: Variant in item.get("sub_stats", []):
		var sub: Dictionary = sub_entry as Dictionary
		var sub_type: String = str(sub.get("type", ""))
		var sub_value: float = float(sub.get("value", 0.0))
		if sub_type == "":
			continue
		# Sub stats are always percentage: value is raw %, apply as 0.01 scale
		if PERCENT_STATS.has(sub_type):
			stats[sub_type] = float(stats.get(sub_type, 0.0)) + sub_value * 0.01
		else:
			# For flat stats like attack/defense/max_hp, apply as percentage of base
			var base_val: float = float(stats.get(sub_type, 0.0))
			stats[sub_type] = base_val + base_val * sub_value * 0.01
	item["stats"] = stats


static func _generate_main_stat(slot: String, quality: String, rng: RandomNumberGenerator = null) -> Dictionary:
	var pool: Array = (MAIN_STAT_POOLS.get(slot, MAIN_STAT_POOLS.get("accessory", [])) as Array).duplicate()
	if pool.is_empty():
		return {"type": "attack", "value": 5}
	var stat_type: String = str(_pick(pool, rng))
	var ranges: Dictionary = MAIN_STAT_RANGES.get(stat_type, {}) as Dictionary
	var quality_range: Array = (ranges.get(quality, ranges.get("Common", [5, 10])) as Array)
	var min_val: int = int(quality_range[0]) if quality_range.size() > 0 else 5
	var max_val: int = int(quality_range[1]) if quality_range.size() > 1 else 10
	var value: int = _randi_range(rng, min_val, max_val)
	return {"type": stat_type, "value": value}


static func _generate_sub_stats(quality: String, main_stat_type: String, rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	var count: int = int(QUALITY_SUB_STAT_COUNT.get(quality, 0))
	if count <= 0:
		return []
	var pool: Array[String] = []
	for s: String in SUB_STAT_POOL:
		if s != main_stat_type:
			pool.append(s)
	var pool_variant: Array = []
	for s: String in pool:
		pool_variant.append(s)
	_shuffle(pool_variant, rng)
	var result: Array[Dictionary] = []
	for i: int in range(mini(count, pool_variant.size())):
		var sub_type: String = str(pool_variant[i])
		var sub_value: float = float(_randi_range(rng, 1, 5))
		result.append({"type": sub_type, "value": sub_value})
	return result


static func _determine_rarity(num_affixes: int) -> String:
	match num_affixes:
		0:
			return "Common"
		1:
			return "Uncommon"
		2:
			return "Rare"
		3:
			return "Epic"
		_:
			return "Legendary"


static func _normalize_rarity(rarity: String) -> String:
	return str(RARITY_ALIASES.get(rarity, rarity if RARITY_ORDER.has(rarity) else "Common"))


static func _pick(values: Array, rng: RandomNumberGenerator = null):
	if values.is_empty():
		return null
	return values[_randi_range(rng, 0, values.size() - 1)]


static func _shuffle(values: Array, rng: RandomNumberGenerator = null) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index: int = _randi_range(rng, 0, index)
		var temp: Variant = values[index]
		values[index] = values[swap_index]
		values[swap_index] = temp


static func _randi(rng: RandomNumberGenerator = null) -> int:
	return rng.randi() if rng != null else randi()


static func _randf(rng: RandomNumberGenerator = null) -> float:
	return rng.randf() if rng != null else randf()


static func _randi_range(rng: RandomNumberGenerator = null, min_value: int = 0, max_value: int = 0) -> int:
	if max_value < min_value:
		return min_value
	return rng.randi_range(min_value, max_value) if rng != null else randi_range(min_value, max_value)

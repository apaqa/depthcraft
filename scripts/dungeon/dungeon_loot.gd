extends RefCounted
class_name DungeonLoot

const PREFIXES := ["?�鏽??, "?�製", "?�製", "?�影", "?�古", "被�??��?", "?��?福�?", "迅捷??]
const WEAPON_NAMES := ["?��?", "?�斧", "?�器", "?��?", "?��?"]
const HELMET_NAMES := ["?��?", "?�帽", "?��?", "便帽"]
const CHEST_NAMES := ["?�甲", "?��???, "?��?", "法�?"]
const BOOT_NAMES := ["?��?", "護腿", "涼�?"]
const ACCESSORY_NAMES := ["?��?", "護身�?, "飾�?", "?��?"]
const RARITY_COLORS := {
	"?��?: Color(1.0, 1.0, 1.0, 1.0),
	"?��?": Color(0.45, 0.95, 0.45, 1.0),
	"稀??: Color(0.42, 0.68, 1.0, 1.0),
	"?�詩": Color(0.82, 0.45, 1.0, 1.0),
	"?�說": Color(1.0, 0.65, 0.1, 1.0),
}
const AFFIX_POOL := [
	{"label": "?��?", "stat": "attack", "min": 3, "max": 8},
	{"label": "?�禦", "stat": "defense", "min": 2, "max": 6},
	{"label": "?�大�???, "stat": "max_hp", "min": 10, "max": 30},
	{"label": "移�?, "stat": "speed_multiplier", "min": 5, "max": 15, "scale": 0.01, "suffix": "%"},
	{"label": "?��???, "stat": "crit_chance", "min": 3, "max": 8, "scale": 0.01, "suffix": "%"},
	{"label": "?��?", "stat": "lifesteal_ratio", "min": 3, "max": 5, "scale": 0.01, "suffix": "%"},
	{"label": "?��??�度", "stat": "gather_bonus", "min": 1, "max": 3},
]
const QUALITY_MULTIPLIERS := {
	"?��?: 1.0, "?��?": 1.3, "稀??: 1.6, "?�詩": 2.0, "?�說": 2.5,
}
const QUALITY_AFFIX_COUNT := {
	"?��?: 0, "?��?": 1, "稀??: 2, "?�詩": 3, "?�說": 3,
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
	var tiers := ["?��?, "?��?", "稀??, "?�詩", "?�說"]
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
		return "?��?
	var roll := _randf(rng) * total
	var running := 0.0
	for i in range(tiers.size()):
		if floor_number < min_floors[i]:
			continue
		running += weights[i]
		if roll <= running:
			return tiers[i]
	return "?��?


static func _generate_name(slot: String, quality: String = "?��?, rng: RandomNumberGenerator = null) -> String:
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
	var base_name := "%s%s%s" % [prefix_a, prefix_b, noun]
	if quality != "?��?:
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
			return "?��?
		1:
			return "?��?"
		2:
			return "稀??
		_:
			return "?�詩"


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


static func generate_dungeon_equipment_min_rarity(floor_number: int, min_rarity: String, rng: RandomNumberGenerator = null) -> Dictionary:
	var tiers := ["普通", "良好", "稀有", "史詩", "傳說"]
	var min_index := tiers.find(min_rarity)
	if min_index < 0:
		min_index = 0
	var quality := _pick_quality(floor_number, rng)
	var q_index := tiers.find(quality)
	if q_index < min_index:
		quality = tiers[min_index]
	var slot: String = _pick(["weapon", "helmet", "chest_armor", "boots", "accessory"], rng)
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
	item["color"] = get_rarity_color(str(item.get("rarity", "普通")))
	return item


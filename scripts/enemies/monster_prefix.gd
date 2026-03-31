extends RefCounted
class_name MonsterPrefix

const PREFIX_DATA: Dictionary = {
	"frenzied": {
		"id": "frenzied",
		"zh_name": "狂暴",
		"en_name": "Frenzied",
		"attack_speed_mult": 1.5,
		"attack_mult": 1.2,
		"color": Color(1.0, 0.3, 0.1, 1.0),
	},
	"vampiric": {
		"id": "vampiric",
		"zh_name": "吸血",
		"en_name": "Vampiric",
		"lifesteal_ratio": 0.05,
		"color": Color(0.8, 0.1, 0.3, 1.0),
	},
	"venomous": {
		"id": "venomous",
		"zh_name": "劇毒",
		"en_name": "Venomous",
		"poison_damage_pct": 0.02,
		"poison_duration": 3.0,
		"color": Color(0.2, 0.85, 0.2, 1.0),
	},
	"explosive": {
		"id": "explosive",
		"zh_name": "爆裂",
		"en_name": "Explosive",
		"explosion_radius": 48.0,
		"explosion_damage_pct": 0.3,
		"color": Color(1.0, 0.55, 0.0, 1.0),
	},
	"splitting": {
		"id": "splitting",
		"zh_name": "分裂",
		"en_name": "Splitting",
		"split_hp_ratio": 0.4,
		"split_count": 2,
		"color": Color(0.4, 0.8, 1.0, 1.0),
	},
	"thorned": {
		"id": "thorned",
		"zh_name": "反擊",
		"en_name": "Thorned",
		"reflect_ratio": 0.15,
		"color": Color(0.2, 0.9, 0.5, 1.0),
	},
	"armored": {
		"id": "armored",
		"zh_name": "堅甲",
		"en_name": "Armored",
		"damage_reduction": 0.3,
		"color": Color(0.7, 0.7, 0.85, 1.0),
	},
	"shadowed": {
		"id": "shadowed",
		"zh_name": "暗影",
		"en_name": "Shadowed",
		"stealth_interval": 8.0,
		"stealth_duration": 2.0,
		"color": Color(0.6, 0.2, 0.9, 1.0),
	},
}

const ALL_PREFIX_IDS: Array[String] = [
	"frenzied", "vampiric", "venomous", "explosive",
	"splitting", "thorned", "armored", "shadowed"
]


static func get_prefix(prefix_id: String) -> Dictionary:
	if not PREFIX_DATA.has(prefix_id):
		return {}
	return PREFIX_DATA[prefix_id].duplicate(true)


static func get_prefix_display_name(prefix_id: String) -> String:
	if not PREFIX_DATA.has(prefix_id):
		return ""
	return str(PREFIX_DATA[prefix_id].get("zh_name", prefix_id))


static func get_prefix_color(prefix_id: String) -> Color:
	if not PREFIX_DATA.has(prefix_id):
		return Color(1.0, 0.6, 0.1, 1.0)
	var col: Variant = PREFIX_DATA[prefix_id].get("color", null)
	if col == null:
		return Color(1.0, 0.6, 0.1, 1.0)
	return col as Color


static func pick_random_prefixes(count: int, rng: RandomNumberGenerator) -> Array[String]:
	var shuffled: Array[String] = ALL_PREFIX_IDS.duplicate()
	# Simple shuffle using rng
	for i: int in range(shuffled.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var temp: String = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = temp
	var result: Array[String] = []
	for i: int in range(mini(count, shuffled.size())):
		result.append(shuffled[i])
	return result


static func apply_prefix_to_enemy(enemy: Enemy, prefix_id: String) -> void:
	var data: Dictionary = get_prefix(prefix_id)
	if data.is_empty():
		return
	match prefix_id:
		"frenzied":
			enemy.attack_cooldown /= float(data.get("attack_speed_mult", 1.5))
			enemy.damage = int(round(float(enemy.damage) * float(data.get("attack_mult", 1.2))))
		"armored":
			enemy.max_hp = int(round(float(enemy.max_hp) / (1.0 - float(data.get("damage_reduction", 0.3)))))
			enemy.current_hp = enemy.max_hp
	# Store prefix data on the enemy for runtime effects
	if enemy.has_method("set"):
		if not enemy.get("_prefixes"):
			enemy.set("_prefixes", [])
		var prefix_list: Array = enemy.get("_prefixes")
		prefix_list.append(prefix_id)
		enemy.set("_prefixes", prefix_list)

extends RefCounted
class_name BuffSystem

const BUFF_POOL := {
	"atk_up_1": {
		"id": "atk_up_1",
		"name": "Sharp Edge",
		"description": "Attack +15%",
		"category": "攻擊",
		"color": Color(0.92, 0.35, 0.35, 1.0),
	},
	"atk_up_2": {
		"id": "atk_up_2",
		"name": "Heavy Strikes",
		"description": "Attack +25%, Speed -10%",
		"category": "攻擊",
		"color": Color(0.86, 0.3, 0.24, 1.0),
	},
	"crit_chance": {
		"id": "crit_chance",
		"name": "Precise Eye",
		"description": "15% chance to deal 2x damage",
		"category": "攻擊",
		"color": Color(1.0, 0.82, 0.32, 1.0),
	},
	"atk_speed": {
		"id": "atk_speed",
		"name": "Quick Hands",
		"description": "Attack cooldown -30%",
		"category": "攻擊",
		"color": Color(0.95, 0.7, 0.3, 1.0),
	},
	"lifesteal": {
		"id": "lifesteal",
		"name": "Vampiric Touch",
		"description": "Heal 10% of damage dealt",
		"category": "攻擊",
		"color": Color(0.76, 0.24, 0.36, 1.0),
	},
	"hp_up": {
		"id": "hp_up",
		"name": "Tough Skin",
		"description": "Max HP +30",
		"category": "防禦",
		"color": Color(0.3, 0.85, 0.4, 1.0),
	},
	"armor": {
		"id": "armor",
		"name": "Iron Will",
		"description": "All damage taken -20%",
		"category": "防禦",
		"color": Color(0.45, 0.65, 0.95, 1.0),
	},
	"dodge_chance": {
		"id": "dodge_chance",
		"name": "Nimble Feet",
		"description": "15% chance to dodge attacks",
		"category": "防禦",
		"color": Color(0.4, 0.9, 0.85, 1.0),
	},
	"regen": {
		"id": "regen",
		"name": "Recovery",
		"description": "Regenerate 1 HP every 3 seconds",
		"category": "防禦",
		"color": Color(0.42, 0.88, 0.58, 1.0),
	},
	"speed_up": {
		"id": "speed_up",
		"name": "Swift Boots",
		"description": "Movement speed +25%",
		"category": "Utility",
		"color": Color(0.38, 0.72, 1.0, 1.0),
	},
	"loot_up": {
		"id": "loot_up",
		"name": "Treasure Sense",
		"description": "Double loot drop chance",
		"category": "Utility",
		"color": Color(0.72, 0.64, 1.0, 1.0),
	},
	"aoe_attack": {
		"id": "aoe_attack",
		"name": "Sweeping Strikes",
		"description": "Attacks hit in a wider area",
		"category": "攻擊",
		"color": Color(1.0, 0.58, 0.24, 1.0),
	},
}


static func get_buff_pool() -> Array[Dictionary]:
	var buffs: Array[Dictionary] = []
	for buff_id in BUFF_POOL.keys():
		buffs.append(BUFF_POOL[buff_id].duplicate(true))
	return buffs


static func get_buff(buff_id: String) -> Dictionary:
	if not BUFF_POOL.has(buff_id):
		return {}
	return BUFF_POOL[buff_id].duplicate(true)


static func generate_random_buffs(count: int = 3) -> Array[Dictionary]:
	var available_ids: Array[String] = []
	for buff_id in BUFF_POOL.keys():
		available_ids.append(buff_id)
	available_ids.shuffle()
	var results: Array[Dictionary] = []
	for index in range(min(count, available_ids.size())):
		results.append(get_buff(available_ids[index]))
	return results

extends RefCounted
class_name BuffSystem

const BUFF_POOL := {
	"atk_up_1": {
		"id": "atk_up_1",
		"name": "buff_atk_up_1_name",
		"description": "buff_atk_up_1_desc",
		"category": "buff_atk_up_1_cat",
		"color": Color(0.92, 0.35, 0.35, 1.0),
	},
	"atk_up_2": {
		"id": "atk_up_2",
		"name": "buff_atk_up_2_name",
		"description": "buff_atk_up_2_desc",
		"category": "buff_atk_up_2_cat",
		"color": Color(0.86, 0.3, 0.24, 1.0),
	},
	"crit_chance": {
		"id": "crit_chance",
		"name": "buff_crit_chance_name",
		"description": "buff_crit_chance_desc",
		"category": "buff_crit_chance_cat",
		"color": Color(1.0, 0.82, 0.32, 1.0),
	},
	"atk_speed": {
		"id": "atk_speed",
		"name": "buff_atk_speed_name",
		"description": "buff_atk_speed_desc",
		"category": "buff_atk_speed_cat",
		"color": Color(0.95, 0.7, 0.3, 1.0),
	},
	"lifesteal": {
		"id": "lifesteal",
		"name": "buff_lifesteal_name",
		"description": "buff_lifesteal_desc",
		"category": "buff_lifesteal_cat",
		"color": Color(0.76, 0.24, 0.36, 1.0),
	},
	"hp_up": {
		"id": "hp_up",
		"name": "buff_hp_up_name",
		"description": "buff_hp_up_desc",
		"category": "buff_hp_up_cat",
		"color": Color(0.3, 0.85, 0.4, 1.0),
	},
	"armor": {
		"id": "armor",
		"name": "buff_armor_name",
		"description": "buff_armor_desc",
		"category": "buff_armor_cat",
		"color": Color(0.45, 0.65, 0.95, 1.0),
	},
	"dodge_chance": {
		"id": "dodge_chance",
		"name": "buff_dodge_chance_name",
		"description": "buff_dodge_chance_desc",
		"category": "buff_dodge_chance_cat",
		"color": Color(0.4, 0.9, 0.85, 1.0),
	},
	"regen": {
		"id": "regen",
		"name": "buff_regen_name",
		"description": "buff_regen_desc",
		"category": "buff_regen_cat",
		"color": Color(0.42, 0.88, 0.58, 1.0),
	},
	"speed_up": {
		"id": "speed_up",
		"name": "buff_speed_up_name",
		"description": "buff_speed_up_desc",
		"category": "buff_speed_up_cat",
		"color": Color(0.38, 0.72, 1.0, 1.0),
	},
	"loot_up": {
		"id": "loot_up",
		"name": "buff_loot_up_name",
		"description": "buff_loot_up_desc",
		"category": "buff_loot_up_cat",
		"color": Color(0.72, 0.64, 1.0, 1.0),
	},
	"aoe_attack": {
		"id": "aoe_attack",
		"name": "buff_aoe_attack_name",
		"description": "buff_aoe_attack_desc",
		"category": "buff_aoe_attack_cat",
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

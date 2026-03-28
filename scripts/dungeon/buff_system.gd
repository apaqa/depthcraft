extends RefCounted
class_name BuffSystem

const BUFF_POOL: Dictionary = {
	"atk_up_1": {
		"id": "atk_up_1",
		"name": "buff_atk_up_1_name",
		"description": "buff_atk_up_1_desc",
		"category": "buff_atk_up_1_cat",
		"color": Color(0.92, 0.35, 0.35, 1.0),
		"tier": 0,
		"tag": "burst",
		"base_effect": 0.15,
	},
	"atk_up_2": {
		"id": "atk_up_2",
		"name": "buff_atk_up_2_name",
		"description": "buff_atk_up_2_desc",
		"category": "buff_atk_up_2_cat",
		"color": Color(0.86, 0.3, 0.24, 1.0),
		"tier": 1,
		"tag": "burst",
		"base_effect": 0.25,
	},
	"crit_chance": {
		"id": "crit_chance",
		"name": "buff_crit_chance_name",
		"description": "buff_crit_chance_desc",
		"category": "buff_crit_chance_cat",
		"color": Color(1.0, 0.82, 0.32, 1.0),
		"tier": 1,
		"tag": "crit",
		"base_effect": 0.15,
	},
	"atk_speed": {
		"id": "atk_speed",
		"name": "buff_atk_speed_name",
		"description": "buff_atk_speed_desc",
		"category": "buff_atk_speed_cat",
		"color": Color(0.95, 0.7, 0.3, 1.0),
		"tier": 1,
		"tag": "cooldown",
		"base_effect": 0.3,
	},
	"lifesteal": {
		"id": "lifesteal",
		"name": "buff_lifesteal_name",
		"description": "buff_lifesteal_desc",
		"category": "buff_lifesteal_cat",
		"color": Color(0.76, 0.24, 0.36, 1.0),
		"tier": 1,
		"tag": "lifesteal",
		"base_effect": 0.1,
	},
	"hp_up": {
		"id": "hp_up",
		"name": "buff_hp_up_name",
		"description": "buff_hp_up_desc",
		"category": "buff_hp_up_cat",
		"color": Color(0.3, 0.85, 0.4, 1.0),
		"tier": 0,
		"tag": "lifesteal",
		"base_effect": 30.0,
	},
	"armor": {
		"id": "armor",
		"name": "buff_armor_name",
		"description": "buff_armor_desc",
		"category": "buff_armor_cat",
		"color": Color(0.45, 0.65, 0.95, 1.0),
		"tier": 0,
		"tag": "counter",
		"base_effect": 0.2,
	},
	"dodge_chance": {
		"id": "dodge_chance",
		"name": "buff_dodge_chance_name",
		"description": "buff_dodge_chance_desc",
		"category": "buff_dodge_chance_cat",
		"color": Color(0.4, 0.9, 0.85, 1.0),
		"tier": 0,
		"tag": "counter",
		"base_effect": 0.15,
	},
	"regen": {
		"id": "regen",
		"name": "buff_regen_name",
		"description": "buff_regen_desc",
		"category": "buff_regen_cat",
		"color": Color(0.42, 0.88, 0.58, 1.0),
		"tier": 0,
		"tag": "lifesteal",
		"base_effect": 1.0,
	},
	"speed_up": {
		"id": "speed_up",
		"name": "buff_speed_up_name",
		"description": "buff_speed_up_desc",
		"category": "buff_speed_up_cat",
		"color": Color(0.38, 0.72, 1.0, 1.0),
		"tier": 0,
		"tag": "cooldown",
		"base_effect": 0.25,
	},
	"loot_up": {
		"id": "loot_up",
		"name": "buff_loot_up_name",
		"description": "buff_loot_up_desc",
		"category": "buff_loot_up_cat",
		"color": Color(0.72, 0.64, 1.0, 1.0),
		"tier": 0,
		"tag": "wealth",
		"base_effect": 1.0,
	},
	"aoe_attack": {
		"id": "aoe_attack",
		"name": "buff_aoe_attack_name",
		"description": "buff_aoe_attack_desc",
		"category": "buff_aoe_attack_cat",
		"color": Color(1.0, 0.58, 0.24, 1.0),
		"tier": 2,
		"tag": "burst",
		"base_effect": 0.5,
	},
}

# Tier weight: 0=common(70%), 1=rare(25%), 2=legendary(5%)
const TIER_WEIGHTS: Array[float] = [0.70, 0.25, 0.05]
const TIER_LABELS: Array[String] = ["普通", "稀有", "傳奇"]
const TIER_COLORS: Array[Color] = [
	Color(0.8, 0.8, 0.8, 1.0),
	Color(0.3, 0.7, 1.0, 1.0),
	Color(1.0, 0.75, 0.1, 1.0),
]


static func get_buff_pool() -> Array[Dictionary]:
	var buffs: Array[Dictionary] = []
	for buff_id: String in BUFF_POOL.keys():
		buffs.append(BUFF_POOL[buff_id].duplicate(true))
	return buffs


static func get_buff(buff_id: String) -> Dictionary:
	if not BUFF_POOL.has(buff_id):
		return {}
	return BUFF_POOL[buff_id].duplicate(true)


static func get_buff_tag(buff_id: String) -> String:
	if not BUFF_POOL.has(buff_id):
		return ""
	return str(BUFF_POOL[buff_id].get("tag", ""))


static func get_buff_tier(buff_id: String) -> int:
	if not BUFF_POOL.has(buff_id):
		return 0
	return int(BUFF_POOL[buff_id].get("tier", 0))


static func generate_random_buffs(count: int = 3) -> Array[Dictionary]:
	var pools: Array = [[], [], []]
	for buff_id: String in BUFF_POOL.keys():
		var tier: int = int(BUFF_POOL[buff_id].get("tier", 0))
		pools[tier].append(buff_id)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var chosen_ids: Array[String] = []
	var all_ids: Array[String] = []
	for buff_id: String in BUFF_POOL.keys():
		all_ids.append(buff_id)

	var attempts: int = 0
	while chosen_ids.size() < count and attempts < 100:
		attempts += 1
		var roll: float = rng.randf()
		var selected_pool: Array = []
		if roll < TIER_WEIGHTS[2] and not (pools[2] as Array).is_empty():
			selected_pool = pools[2]
		elif roll < TIER_WEIGHTS[2] + TIER_WEIGHTS[1] and not (pools[1] as Array).is_empty():
			selected_pool = pools[1]
		elif not (pools[0] as Array).is_empty():
			selected_pool = pools[0]
		else:
			selected_pool = all_ids

		if selected_pool.is_empty():
			continue
		var pick_index: int = rng.randi() % selected_pool.size()
		var pick_id: String = str(selected_pool[pick_index])
		if not chosen_ids.has(pick_id):
			chosen_ids.append(pick_id)

	# Fallback: fill from shuffled full pool
	if chosen_ids.size() < count:
		var shuffled: Array[String] = []
		for id: String in all_ids:
			if not chosen_ids.has(id):
				shuffled.append(id)
		shuffled.shuffle()
		for id: String in shuffled:
			if chosen_ids.size() >= count:
				break
			chosen_ids.append(id)

	var results: Array[Dictionary] = []
	for buff_id: String in chosen_ids:
		results.append(get_buff(buff_id))
	return results

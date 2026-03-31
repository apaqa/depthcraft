extends RefCounted
class_name LegendaryItems

const ITEM_DATABASE: Script = preload("res://scripts/inventory/item_database.gd")

# 10 unique legendary items with special effects.
# legendary_effect keys mirror player multipliers for easy application.
const LEGENDARY_POOL: Array[Dictionary] = [
	{
		"id": "legend_ragnarok",
		"name": "末日之刃",
		"slot": "weapon",
		"rarity": "Legendary",
		"type": "equipment",
		"max_stack": 1,
		"source": "dungeon",
		"quantity": 1,
		"description": "終焉的力量凝聚於此，每一擊都帶著毀滅。",
		"stats": {"attack": 80.0},
		"affixes": {"lifesteal_ratio": 0.05},
		"durability": 200,
		"max_durability": 200,
		"legendary_effect": "on_kill_aoe",
		"legendary_effect_desc": "擊殺時對周圍造成 40% 傷害爆炸",
	},
	{
		"id": "legend_aegis",
		"name": "神聖盾牌",
		"slot": "offhand",
		"rarity": "Legendary",
		"type": "equipment",
		"max_stack": 1,
		"source": "dungeon",
		"quantity": 1,
		"description": "神明護佑的盾牌，遠超凡物。",
		"stats": {"defense": 60.0, "max_hp": 50.0},
		"affixes": {"block_chance": 0.25},
		"durability": 200,
		"max_durability": 200,
		"legendary_effect": "block_heal",
		"legendary_effect_desc": "格擋時回復 5% 生命值",
	},
	{
		"id": "legend_crown_abyss",
		"name": "深淵王冠",
		"slot": "helmet",
		"rarity": "Legendary",
		"type": "equipment",
		"max_stack": 1,
		"source": "dungeon",
		"quantity": 1,
		"description": "深淵之眼的遺物，帶來黑暗視野。",
		"stats": {"defense": 35.0, "max_hp": 30.0},
		"affixes": {"crit_chance": 0.20},
		"durability": 200,
		"max_durability": 200,
		"legendary_effect": "crit_lifesteal",
		"legendary_effect_desc": "暴擊時額外吸血 10%",
	},
	{
		"id": "legend_phoenix_vest",
		"name": "鳳凰鎧甲",
		"slot": "chest_armor",
		"rarity": "Legendary",
		"type": "equipment",
		"max_stack": 1,
		"source": "dungeon",
		"quantity": 1,
		"description": "不死之鳥的羽毛鑄造，死時浴火重生。",
		"stats": {"defense": 50.0, "max_hp": 80.0},
		"affixes": {},
		"durability": 200,
		"max_durability": 200,
		"legendary_effect": "undying_will",
		"legendary_effect_desc": "死亡時以 30% 生命重生（每次下地牢僅一次）",
	},
	{
		"id": "legend_hermes_boots",
		"name": "赫米斯靴",
		"slot": "boots",
		"rarity": "Legendary",
		"type": "equipment",
		"max_stack": 1,
		"source": "dungeon",
		"quantity": 1,
		"description": "神使之靴，腳踏風雷。",
		"stats": {"defense": 20.0, "speed": 40.0},
		"affixes": {"speed_multiplier": 0.25},
		"durability": 200,
		"max_durability": 200,
		"legendary_effect": "dodge_on_sprint",
		"legendary_effect_desc": "衝刺期間閃避率 +30%",
	},
	{
		"id": "legend_amulet_eternity",
		"name": "永恆護符",
		"slot": "accessory",
		"rarity": "Legendary",
		"type": "equipment",
		"max_stack": 1,
		"source": "dungeon",
		"quantity": 1,
		"description": "時間本身為其加護，屬性緩慢增長。",
		"stats": {"attack": 20.0, "defense": 20.0, "max_hp": 40.0},
		"affixes": {},
		"durability": 200,
		"max_durability": 200,
		"legendary_effect": "all_stats_bonus",
		"legendary_effect_desc": "所有基礎屬性 +15%",
	},
	{
		"id": "legend_eclipse_blade",
		"name": "日蝕之刃",
		"slot": "weapon",
		"rarity": "Legendary",
		"type": "equipment",
		"max_stack": 1,
		"source": "dungeon",
		"quantity": 1,
		"description": "光與暗的融合，交替詛咒與祝福。",
		"stats": {"attack": 65.0},
		"affixes": {"crit_chance": 0.15, "lifesteal_ratio": 0.08},
		"durability": 200,
		"max_durability": 200,
		"legendary_effect": "eclipse_crit",
		"legendary_effect_desc": "暴擊時造成雙倍效果",
	},
	{
		"id": "legend_necro_tome",
		"name": "死靈法典",
		"slot": "offhand",
		"rarity": "Legendary",
		"type": "equipment",
		"max_stack": 1,
		"source": "dungeon",
		"quantity": 1,
		"description": "古老的魔典，記載召喚死者之術。",
		"stats": {"attack": 30.0, "defense": 15.0},
		"affixes": {"lifesteal_ratio": 0.12},
		"durability": 200,
		"max_durability": 200,
		"legendary_effect": "kill_count_bonus",
		"legendary_effect_desc": "每擊殺 10 個敵人 ATK +2%（最高 +50%）",
	},
	{
		"id": "legend_titan_helm",
		"name": "泰坦頭盔",
		"slot": "helmet",
		"rarity": "Legendary",
		"type": "equipment",
		"max_stack": 1,
		"source": "dungeon",
		"quantity": 1,
		"description": "古代巨人的戰盔，重如磐石。",
		"stats": {"defense": 55.0, "max_hp": 100.0},
		"affixes": {},
		"durability": 200,
		"max_durability": 200,
		"legendary_effect": "damage_reduction_passive",
		"legendary_effect_desc": "所受傷害減少 20%",
	},
	{
		"id": "legend_storm_gauntlet",
		"name": "暴風拳套",
		"slot": "accessory",
		"rarity": "Legendary",
		"type": "equipment",
		"max_stack": 1,
		"source": "dungeon",
		"quantity": 1,
		"description": "雷霆之力匯聚於手，每擊都是風暴。",
		"stats": {"attack": 45.0},
		"affixes": {"attack_speed_bonus": 0.30},
		"durability": 200,
		"max_durability": 200,
		"legendary_effect": "chain_lightning",
		"legendary_effect_desc": "攻擊時 20% 機率對附近敵人造成 50% 連鎖傷害",
	},
]


static func get_all_legendary_ids() -> Array[String]:
	var result: Array[String] = []
	for item: Dictionary in LEGENDARY_POOL:
		result.append(str(item.get("id", "")))
	return result


static func get_legendary(item_id: String) -> Dictionary:
	for item: Dictionary in LEGENDARY_POOL:
		if str(item.get("id", "")) == item_id:
			var copy: Dictionary = item.duplicate(true)
			copy["color"] = Color(1.0, 0.5, 0.0, 1.0)
			if not copy.has("floor_found"):
				copy["floor_found"] = 30
			return copy
	return {}


static func get_random_legendary(rng: RandomNumberGenerator) -> Dictionary:
	if LEGENDARY_POOL.is_empty():
		return {}
	var idx: int = rng.randi() % LEGENDARY_POOL.size()
	return get_legendary(str(LEGENDARY_POOL[idx].get("id", "")))


static func get_legendary_for_slot(slot_name: String, rng: RandomNumberGenerator) -> Dictionary:
	var matches: Array[String] = []
	for item: Dictionary in LEGENDARY_POOL:
		if str(item.get("slot", "")) == slot_name:
			matches.append(str(item.get("id", "")))
	if matches.is_empty():
		return get_random_legendary(rng)
	var idx: int = rng.randi() % matches.size()
	return get_legendary(matches[idx])


static func apply_legendary_passive(player: Node, item: Dictionary) -> void:
	var effect: String = str(item.get("legendary_effect", ""))
	match effect:
		"undying_will":
			if player.has_method("set") and player.get("player_stats") != null:
				var ps: Node = player.get("player_stats")
				if ps != null:
					ps.set("undying_will", true)
		"all_stats_bonus":
			if player.has_method("set") and player.get("player_stats") != null:
				var ps: Node = player.get("player_stats")
				if ps != null:
					ps.set("base_attack", int(ps.get("base_attack")) + int(round(float(ps.get("base_attack")) * 0.15)))
					ps.set("base_defense", int(ps.get("base_defense")) + int(round(float(ps.get("base_defense")) * 0.15)))
					ps.set("base_max_hp", int(ps.get("base_max_hp")) + int(round(float(ps.get("base_max_hp")) * 0.15)))
		"damage_reduction_passive":
			if player.get("armor_reduction") != null:
				player.set("armor_reduction", minf(float(player.get("armor_reduction")) + 0.20, 0.85))
		"on_kill_aoe":
			if player.get("legend_on_kill_aoe") != null:
				player.set("legend_on_kill_aoe", true)
		"block_heal":
			if player.get("legend_block_heal") != null:
				player.set("legend_block_heal", true)
		"crit_lifesteal":
			if player.get("legend_crit_lifesteal") != null:
				player.set("legend_crit_lifesteal", true)
		"dodge_on_sprint":
			if player.get("legend_dodge_on_sprint") != null:
				player.set("legend_dodge_on_sprint", true)
		"eclipse_crit":
			if player.get("legend_eclipse_crit") != null:
				player.set("legend_eclipse_crit", true)
		"chain_lightning":
			if player.get("legend_chain_lightning") != null:
				player.set("legend_chain_lightning", true)
		"kill_count_bonus":
			if player.get("legend_kill_count_bonus") != null:
				player.set("legend_kill_count_bonus", true)

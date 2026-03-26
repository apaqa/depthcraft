extends Node

const BRANCH_ORDER := ["offense", "defense", "support"]

const BRANCH_LABELS := {
	"offense": "branch_offense",
	"defense": "branch_defense",
	"support": "branch_support",
}

const TALENTS := {
	"O1": {"id": "O1", "name": "talent_O1_name", "branch": "offense", "cost": 2, "prerequisite": "", "description": "talent_O1_desc", "effects": {"attack": 3}},
	"O2": {"id": "O2", "name": "talent_O2_name", "branch": "offense", "cost": 3, "prerequisite": "O1", "description": "talent_O2_desc", "effects": {"attack": 5}},
	"O3": {"id": "O3", "name": "talent_O3_name", "branch": "offense", "cost": 4, "prerequisite": "O2", "description": "talent_O3_desc", "effects": {"attack_speed": 0.1}},
	"O4": {"id": "O4", "name": "talent_O4_name", "branch": "offense", "cost": 5, "prerequisite": "O3", "description": "talent_O4_desc", "effects": {"crit_chance": 0.05}},
	"O5": {"id": "O5", "name": "talent_O5_name", "branch": "offense", "cost": 8, "prerequisite": "O4", "description": "talent_O5_desc", "effects": {"skill_whirlwind": 1}, "is_milestone": true, "skill_unlock": "Whirlwind"},
	"O6": {"id": "O6", "name": "talent_O6_name", "branch": "offense", "cost": 6, "prerequisite": "O5", "description": "talent_O6_desc", "effects": {"attack": 8}},
	"O7": {"id": "O7", "name": "talent_O7_name", "branch": "offense", "cost": 7, "prerequisite": "O6", "description": "talent_O7_desc", "effects": {"bleed_on_hit": 1}},
	"O8": {"id": "O8", "name": "talent_O8_name", "branch": "offense", "cost": 8, "prerequisite": "O7", "description": "talent_O8_desc", "effects": {"frenzy": 1}},
	"O9": {"id": "O9", "name": "talent_O9_name", "branch": "offense", "cost": 9, "prerequisite": "O8", "description": "talent_O9_desc", "effects": {"crit_damage": 0.5}},
	"O10": {"id": "O10", "name": "talent_O10_name", "branch": "offense", "cost": 12, "prerequisite": "O9", "description": "talent_O10_desc", "effects": {"execute_bonus": 2.0, "skill_execute": 1}, "is_milestone": true, "skill_unlock": "Execute"},
	"O11": {"id": "O11", "name": "talent_O11_name", "branch": "offense", "cost": 10, "prerequisite": "O10", "description": "talent_O11_desc", "effects": {"attack": 12}},
	"O12": {"id": "O12", "name": "talent_O12_name", "branch": "offense", "cost": 11, "prerequisite": "O11", "description": "talent_O12_desc", "effects": {"armor_pierce": 0.2}},
	"O13": {"id": "O13", "name": "talent_O13_name", "branch": "offense", "cost": 12, "prerequisite": "O12", "description": "talent_O13_desc", "effects": {"kill_heal_ratio": 0.05}},
	"O14": {"id": "O14", "name": "talent_O14_name", "branch": "offense", "cost": 13, "prerequisite": "O13", "description": "talent_O14_desc", "effects": {"low_hp_attack_bonus": 0.5}},
	"O15": {"id": "O15", "name": "talent_O15_name", "branch": "offense", "cost": 15, "prerequisite": "O14", "description": "talent_O15_desc", "effects": {"skill_blade_storm": 1}, "is_milestone": true, "skill_unlock": "Blade Storm"},
	"D1": {"id": "D1", "name": "talent_D1_name", "branch": "defense", "cost": 2, "prerequisite": "", "description": "talent_D1_desc", "effects": {"max_hp": 15}},
	"D2": {"id": "D2", "name": "talent_D2_name", "branch": "defense", "cost": 3, "prerequisite": "D1", "description": "talent_D2_desc", "effects": {"defense": 3}},
	"D3": {"id": "D3", "name": "talent_D3_name", "branch": "defense", "cost": 4, "prerequisite": "D2", "description": "talent_D3_desc", "effects": {"block_chance": 0.10}},
	"D4": {"id": "D4", "name": "talent_D4_name", "branch": "defense", "cost": 5, "prerequisite": "D3", "description": "talent_D4_desc", "effects": {"regen_amount": 1, "regen_interval": 5.0}},
	"D5": {"id": "D5", "name": "talent_D5_name", "branch": "defense", "cost": 8, "prerequisite": "D4", "description": "talent_D5_desc", "effects": {"skill_war_cry": 1}, "is_milestone": true, "skill_unlock": "War Cry"},
	"D6": {"id": "D6", "name": "talent_D6_name", "branch": "defense", "cost": 6, "prerequisite": "D5", "description": "talent_D6_desc", "effects": {"defense": 6}},
	"D7": {"id": "D7", "name": "talent_D7_name", "branch": "defense", "cost": 7, "prerequisite": "D6", "description": "talent_D7_desc", "effects": {"second_wind": 1}},
	"D8": {"id": "D8", "name": "talent_D8_name", "branch": "defense", "cost": 8, "prerequisite": "D7", "description": "talent_D8_desc", "effects": {"fortify": 1}},
	"D9": {"id": "D9", "name": "talent_D9_name", "branch": "defense", "cost": 9, "prerequisite": "D8", "description": "talent_D9_desc", "effects": {"damage_reflect": 0.1}},
	"D10": {"id": "D10", "name": "talent_D10_name", "branch": "defense", "cost": 12, "prerequisite": "D9", "description": "talent_D10_desc", "effects": {"undying_will": 1, "skill_undying_will": 1}, "is_milestone": true, "skill_unlock": "Undying Will"},
	"D11": {"id": "D11", "name": "talent_D11_name", "branch": "defense", "cost": 10, "prerequisite": "D10", "description": "talent_D11_desc", "effects": {"max_hp": 30}},
	"D12": {"id": "D12", "name": "talent_D12_name", "branch": "defense", "cost": 11, "prerequisite": "D11", "description": "talent_D12_desc", "effects": {"thorns_damage": 5}},
	"D13": {"id": "D13", "name": "talent_D13_name", "branch": "defense", "cost": 12, "prerequisite": "D12", "description": "talent_D13_desc", "effects": {"life_shield": 1}},
	"D14": {"id": "D14", "name": "talent_D14_name", "branch": "defense", "cost": 13, "prerequisite": "D13", "description": "talent_D14_desc", "effects": {"status_resist": 0.5}},
	"D15": {"id": "D15", "name": "talent_D15_name", "branch": "defense", "cost": 15, "prerequisite": "D14", "description": "talent_D15_desc", "effects": {"skill_invincible": 1}, "is_milestone": true, "skill_unlock": "Invincible"},
	"S1": {"id": "S1", "name": "talent_S1_name", "branch": "support", "cost": 2, "prerequisite": "", "description": "talent_S1_desc", "effects": {"speed_multiplier": 0.08}},
	"S2": {"id": "S2", "name": "talent_S2_name", "branch": "support", "cost": 3, "prerequisite": "S1", "description": "talent_S2_desc", "effects": {"gather_bonus": 1}},
	"S3": {"id": "S3", "name": "talent_S3_name", "branch": "support", "cost": 4, "prerequisite": "S2", "description": "talent_S3_desc", "effects": {"loot_bonus": 0.10}},
	"S4": {"id": "S4", "name": "talent_S4_name", "branch": "support", "cost": 5, "prerequisite": "S3", "description": "talent_S4_desc", "effects": {"craft_cost_multiplier": -0.15}},
	"S5": {"id": "S5", "name": "talent_S5_name", "branch": "support", "cost": 8, "prerequisite": "S4", "description": "talent_S5_desc", "effects": {"skill_treasure_hunter": 1}, "is_milestone": true, "skill_unlock": "Treasure Hunter"},
	"S6": {"id": "S6", "name": "talent_S6_name", "branch": "support", "cost": 6, "prerequisite": "S5", "description": "talent_S6_desc", "effects": {"loot_pickup_range": 50.0}},
	"S7": {"id": "S7", "name": "talent_S7_name", "branch": "support", "cost": 7, "prerequisite": "S6", "description": "talent_S7_desc", "effects": {"speed_multiplier": 0.15}},
	"S8": {"id": "S8", "name": "talent_S8_name", "branch": "support", "cost": 8, "prerequisite": "S7", "description": "talent_S8_desc", "effects": {"merchant_discount": 0.2}},
	"S9": {"id": "S9", "name": "talent_S9_name", "branch": "support", "cost": 9, "prerequisite": "S8", "description": "talent_S9_desc", "effects": {"full_minimap": 1}},
	"S10": {"id": "S10", "name": "talent_S10_name", "branch": "support", "cost": 12, "prerequisite": "S9", "description": "talent_S10_desc", "effects": {"skill_sprint": 1}, "is_milestone": true, "skill_unlock": "Sprint"},
	"S11": {"id": "S11", "name": "talent_S11_name", "branch": "support", "cost": 10, "prerequisite": "S10", "description": "talent_S11_desc", "effects": {"gather_speed": 0.3}},
	"S12": {"id": "S12", "name": "talent_S12_name", "branch": "support", "cost": 11, "prerequisite": "S11", "description": "talent_S12_desc", "effects": {"double_loot_chance": 0.05}},
	"S13": {"id": "S13", "name": "talent_S13_name", "branch": "support", "cost": 12, "prerequisite": "S12", "description": "talent_S13_desc", "effects": {"low_hp_speed_bonus": 0.25}},
	"S14": {"id": "S14", "name": "talent_S14_name", "branch": "support", "cost": 13, "prerequisite": "S13", "description": "talent_S14_desc", "effects": {"second_chance_loot": 0.3}},
	"S15": {"id": "S15", "name": "talent_S15_name", "branch": "support", "cost": 15, "prerequisite": "S14", "description": "talent_S15_desc", "effects": {"skill_time_warp": 1}, "is_milestone": true, "skill_unlock": "Time Warp"},
}


static func get_all_talents() -> Array[Dictionary]:
	var talents: Array[Dictionary] = []
	for talent_id in TALENTS.keys():
		talents.append(get_talent(talent_id))
	talents.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _sort_value(str(a.get("id", ""))) < _sort_value(str(b.get("id", ""))))
	return talents


static func get_talent(talent_id: String) -> Dictionary:
	if not TALENTS.has(talent_id):
		return {}
	return TALENTS[talent_id].duplicate(true)


static func get_branch_ids() -> PackedStringArray:
	return PackedStringArray(BRANCH_ORDER)


static func get_branch_label(branch_id: String) -> String:
	return str(BRANCH_LABELS.get(branch_id, branch_id.capitalize()))


static func get_branch_talents(branch_id: String) -> Array[Dictionary]:
	var talents: Array[Dictionary] = []
	for talent in get_all_talents():
		if str(talent.get("branch", "")) == branch_id:
			talents.append(talent)
	return talents


static func can_unlock(unlocked_talents: Array[String], talent_shards: int, talent_id: String) -> bool:
	var talent := get_talent(talent_id)
	if talent.is_empty():
		return false
	if unlocked_talents.has(talent_id):
		return false
	if talent_shards < int(talent.get("cost", 0)):
		return false
	var prerequisite := str(talent.get("prerequisite", ""))
	return prerequisite == "" or unlocked_talents.has(prerequisite)


static func _sort_value(talent_id: String) -> int:
	if talent_id.length() < 2:
		return 999
	var prefix := talent_id.substr(0, 1)
	var branch_index := BRANCH_ORDER.find(_prefix_to_branch(prefix))
	var numeric := int(talent_id.substr(1))
	return branch_index * 100 + numeric


static func _prefix_to_branch(prefix: String) -> String:
	match prefix:
		"O":
			return "offense"
		"D":
			return "defense"
		_:
			return "support"

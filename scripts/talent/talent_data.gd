extends Node

const BRANCH_ORDER := ["offense", "defense", "support"]

const BRANCH_LABELS := {
	"offense": "攻擊",
	"defense": "防禦",
	"support": "輔助",
}

const TALENTS := {
	"O1": {"id": "O1", "name": "銳利之刃", "branch": "offense", "cost": 2, "prerequisite": "", "description": "攻擊 +3", "effects": {"attack": 3}},
	"O2": {"id": "O2", "name": "重擊", "branch": "offense", "cost": 3, "prerequisite": "O1", "description": "攻擊 +5", "effects": {"attack": 5}},
	"O3": {"id": "O3", "name": "迅捷之手", "branch": "offense", "cost": 4, "prerequisite": "O2", "description": "攻速 +10%", "effects": {"attack_speed": 0.1}},
	"O4": {"id": "O4", "name": "致命之眼", "branch": "offense", "cost": 5, "prerequisite": "O3", "description": "暴擊 +5%", "effects": {"crit_chance": 0.05}},
	"O5": {"id": "O5", "name": "旋風斬", "branch": "offense", "cost": 8, "prerequisite": "O4", "description": "周圍AOE傷害", "effects": {"skill_whirlwind": 1}, "is_milestone": true, "skill_unlock": "Whirlwind"},
	"O6": {"id": "O6", "name": "更銳之刃", "branch": "offense", "cost": 6, "prerequisite": "O5", "description": "攻擊 +8", "effects": {"attack": 8}},
	"O7": {"id": "O7", "name": "深層傷口", "branch": "offense", "cost": 7, "prerequisite": "O6", "description": "攻擊附帶3秒流血", "effects": {"bleed_on_hit": 1}},
	"O8": {"id": "O8", "name": "狂暴", "branch": "offense", "cost": 8, "prerequisite": "O7", "description": "連殺提升攻速20%", "effects": {"frenzy": 1}},
	"O9": {"id": "O9", "name": "暴擊傷害", "branch": "offense", "cost": 9, "prerequisite": "O8", "description": "暴擊傷害 +50%", "effects": {"crit_damage": 0.5}},
	"O10": {"id": "O10", "name": "處決", "branch": "offense", "cost": 12, "prerequisite": "O9", "description": "對低血敵人3倍傷害", "effects": {"execute_bonus": 2.0, "skill_execute": 1}, "is_milestone": true, "skill_unlock": "Execute"},
	"O11": {"id": "O11", "name": "武器大師", "branch": "offense", "cost": 10, "prerequisite": "O10", "description": "攻擊 +12", "effects": {"attack": 12}},
	"O12": {"id": "O12", "name": "護甲穿透", "branch": "offense", "cost": 11, "prerequisite": "O11", "description": "無視敵人 20% 防禦", "effects": {"armor_pierce": 0.2}},
	"O13": {"id": "O13", "name": "嗜血", "branch": "offense", "cost": 12, "prerequisite": "O12", "description": "擊殺時回復 5% 最大血量", "effects": {"kill_heal_ratio": 0.05}},
	"O14": {"id": "O14", "name": "狂戰士之怒", "branch": "offense", "cost": 13, "prerequisite": "O13", "description": "血量低於 30% 時，攻擊 +50%", "effects": {"low_hp_attack_bonus": 0.5}},
	"O15": {"id": "O15", "name": "劍刃風暴", "branch": "offense", "cost": 15, "prerequisite": "O14", "description": "解鎖技能：劍刃風暴（大範圍持續 AOE）", "effects": {"skill_blade_storm": 1}, "is_milestone": true, "skill_unlock": "Blade Storm"},

	"D1": {"id": "D1", "name": "堅韌皮膚", "branch": "defense", "cost": 2, "prerequisite": "", "description": "血量 +15", "effects": {"max_hp": 15}},
	"D2": {"id": "D2", "name": "鐵壁", "branch": "defense", "cost": 3, "prerequisite": "D1", "description": "防禦 +3", "effects": {"defense": 3}},
	"D3": {"id": "D3", "name": "盾牆", "branch": "defense", "cost": 4, "prerequisite": "D2", "description": "格擋10%傷害", "effects": {"block_chance": 0.10}},
	"D4": {"id": "D4", "name": "再生", "branch": "defense", "cost": 5, "prerequisite": "D3", "description": "每5秒回1血", "effects": {"regen_amount": 1, "regen_interval": 5.0}},
	"D5": {"id": "D5", "name": "戰吼", "branch": "defense", "cost": 8, "prerequisite": "D4", "description": "周圍敵人減速50%", "effects": {"skill_war_cry": 1}, "is_milestone": true, "skill_unlock": "War Cry"},
	"D6": {"id": "D6", "name": "厚重護甲", "branch": "defense", "cost": 6, "prerequisite": "D5", "description": "防禦 +6", "effects": {"defense": 6}},
	"D7": {"id": "D7", "name": "緩過氣來", "branch": "defense", "cost": 7, "prerequisite": "D6", "description": "血量低於 25% 時，每秒回復 3 血量", "effects": {"second_wind": 1}},
	"D8": {"id": "D8", "name": "加固", "branch": "defense", "cost": 8, "prerequisite": "D7", "description": "站立不動時，防禦 +30%", "effects": {"fortify": 1}},
	"D9": {"id": "D9", "name": "傷害反射", "branch": "defense", "cost": 9, "prerequisite": "D8", "description": "反射 10% 受到的傷害", "effects": {"damage_reflect": 0.1}},
	"D10": {"id": "D10", "name": "不屈意志", "branch": "defense", "cost": 12, "prerequisite": "D9", "description": "解鎖技能：不屈意志（抵擋一次致死傷害）", "effects": {"undying_will": 1, "skill_undying_will": 1}, "is_milestone": true, "skill_unlock": "Undying Will"},
	"D11": {"id": "D11", "name": "鋼鐵堡壘", "branch": "defense", "cost": 10, "prerequisite": "D10", "description": "最大血量 +30", "effects": {"max_hp": 30}},
	"D12": {"id": "D12", "name": "荊棘", "branch": "defense", "cost": 11, "prerequisite": "D11", "description": "攻擊者受到 5 點傷害", "effects": {"thorns_damage": 5}},
	"D13": {"id": "D13", "name": "生命護盾", "branch": "defense", "cost": 12, "prerequisite": "D12", "description": "每 30 秒獲得一個 20 點傷害的護盾", "effects": {"life_shield": 1}},
	"D14": {"id": "D14", "name": "韌性", "branch": "defense", "cost": 13, "prerequisite": "D13", "description": "控制效果持續時間 -50%", "effects": {"status_resist": 0.5}},
	"D15": {"id": "D15", "name": "無敵", "branch": "defense", "cost": 15, "prerequisite": "D14", "description": "解鎖技能：無敵（3秒無敵時間）", "effects": {"skill_invincible": 1}, "is_milestone": true, "skill_unlock": "Invincible"},

	"S1": {"id": "S1", "name": "疾步", "branch": "support", "cost": 2, "prerequisite": "", "description": "移速 +8%", "effects": {"speed_multiplier": 0.08}},
	"S2": {"id": "S2", "name": "採集者", "branch": "support", "cost": 3, "prerequisite": "S1", "description": "採集 +1", "effects": {"gather_bonus": 1}},
	"S3": {"id": "S3", "name": "幸運發現", "branch": "support", "cost": 4, "prerequisite": "S2", "description": "掉落率 +10%", "effects": {"loot_bonus": 0.10}},
	"S4": {"id": "S4", "name": "高效製作", "branch": "support", "cost": 5, "prerequisite": "S3", "description": "製作成本 -15%", "effects": {"craft_cost_multiplier": -0.15}},
	"S5": {"id": "S5", "name": "尋寶者", "branch": "support", "cost": 8, "prerequisite": "S4", "description": "顯示寶箱位置", "effects": {"skill_treasure_hunter": 1}, "is_milestone": true, "skill_unlock": "Treasure Hunter"},
	"S6": {"id": "S6", "name": "磁石", "branch": "support", "cost": 6, "prerequisite": "S5", "description": "拾取範圍 +50", "effects": {"loot_pickup_range": 50.0}},
	"S7": {"id": "S7", "name": "輕盈之靴", "branch": "support", "cost": 7, "prerequisite": "S6", "description": "移動速度 +15%", "effects": {"speed_multiplier": 0.15}},
	"S8": {"id": "S8", "name": "討價還價", "branch": "support", "cost": 8, "prerequisite": "S7", "description": "商店價格 -20%", "effects": {"merchant_discount": 0.2}},
	"S9": {"id": "S9", "name": "探險家", "branch": "support", "cost": 9, "prerequisite": "S8", "description": "全地圖迷霧解鎖", "effects": {"full_minimap": 1}},
	"S10": {"id": "S10", "name": "衝刺", "branch": "support", "cost": 12, "prerequisite": "S9", "description": "解鎖技能：衝刺（3秒內 +100% 速度）", "effects": {"skill_sprint": 1}, "is_milestone": true, "skill_unlock": "Sprint"},
	"S11": {"id": "S11", "name": "資源專家", "branch": "support", "cost": 10, "prerequisite": "S10", "description": "採集速度 +30%", "effects": {"gather_speed": 0.3}},
	"S12": {"id": "S12", "name": "幸運一擊", "branch": "support", "cost": 11, "prerequisite": "S11", "description": "5% 機率獲得雙倍掉落", "effects": {"double_loot_chance": 0.05}},
	"S13": {"id": "S13", "name": "生存本能", "branch": "support", "cost": 12, "prerequisite": "S12", "description": "低血量時，移動速度 +25%", "effects": {"low_hp_speed_bonus": 0.25}},
	"S14": {"id": "S14", "name": "一線生機", "branch": "support", "cost": 13, "prerequisite": "S13", "description": "死亡時有 30% 機率保留一半掉落物", "effects": {"second_chance_loot": 0.3}},
	"S15": {"id": "S15", "name": "時間扭曲", "branch": "support", "cost": 15, "prerequisite": "S14", "description": "解鎖技能：時間扭曲（凍結周圍敵人）", "effects": {"skill_time_warp": 1}, "is_milestone": true, "skill_unlock": "Time Warp"},
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

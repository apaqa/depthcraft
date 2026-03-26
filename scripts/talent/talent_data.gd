extends Node

const BRANCH_ORDER := ["offense", "defense", "support"]

const BRANCH_LABELS := {
	"offense": "branch_offense",
	"defense": "branch_defense",
	"support": "branch_support",
}

const SUB_BRANCH_ORDER := {
	"offense": ["crit", "dot"],
	"defense": ["block", "regen"],
	"support": ["speed", "explore"],
}

const SUB_BRANCH_LABELS := {
	"offense": {
		"crit": "暴擊流",
		"dot": "持續傷害流",
	},
	"defense": {
		"block": "格擋流",
		"regen": "回復流",
	},
	"support": {
		"speed": "速度流",
		"explore": "探索流",
	},
}

const BRANCH_DATA := {
	"offense": {
		"prefix": "O",
		"main": [
			{"name": "重擊起手", "description": "攻擊 +3", "effects": {"attack": 3}},
			{"name": "兵器熟練", "description": "攻擊 +4", "effects": {"attack": 4}},
			{"name": "獵手直覺", "description": "暴擊率 +2%", "effects": {"crit_chance": 0.02}},
			{"name": "壓迫揮砍", "description": "攻擊 +5", "effects": {"attack": 5}},
			{"name": "狂戰分岔", "description": "攻擊 +4，解鎖旋風斬並開啟兩條分支", "effects": {"attack": 4}, "is_milestone": true, "skill_unlock": "Whirlwind"},
			{"name": "斬擊精研", "description": "攻擊 +6", "effects": {"attack": 6}},
			{"name": "追獵節奏", "description": "速度 +6", "effects": {"speed": 6}},
			{"name": "凶刃加壓", "description": "攻擊 +7", "effects": {"attack": 7}},
			{"name": "弱點洞察", "description": "暴擊率 +4%", "effects": {"crit_chance": 0.04}},
			{"name": "戰神姿態", "description": "攻擊 +10，暴擊率 +2%", "effects": {"attack": 10, "crit_chance": 0.02}, "is_milestone": true},
		],
		"sub_branches": {
			"crit": {
				"nodes": [
					{"name": "致命校準", "description": "暴擊率 +4%", "effects": {"crit_chance": 0.04}},
					{"name": "破心追擊", "description": "攻擊 +4", "effects": {"attack": 4}},
					{"name": "狙殺本能", "description": "暴擊率 +5%", "effects": {"crit_chance": 0.05}},
					{"name": "臨界獵殺", "description": "處決傷害 +20%", "effects": {"execute_bonus": 0.20}},
					{"name": "鋒芒鎖定", "description": "暴擊率 +6%", "effects": {"crit_chance": 0.06}},
					{"name": "處決步伐", "description": "速度 +6", "effects": {"speed": 6}},
					{"name": "死線預判", "description": "處決傷害 +35%", "effects": {"execute_bonus": 0.35}},
					{"name": "行刑宣判", "description": "暴擊率 +8%，處決傷害 +25%，解鎖處決", "effects": {"crit_chance": 0.08, "execute_bonus": 0.25}, "is_milestone": true, "skill_unlock": "Execute"},
				],
			},
			"dot": {
				"nodes": [
					{"name": "連斬起勢", "description": "速度倍率 +4%", "effects": {"speed_multiplier": 0.04}},
					{"name": "裂傷加深", "description": "攻擊 +4", "effects": {"attack": 4}},
					{"name": "壓制節奏", "description": "速度倍率 +5%", "effects": {"speed_multiplier": 0.05}},
					{"name": "深割擴散", "description": "攻擊 +5", "effects": {"attack": 5}},
					{"name": "不息攻勢", "description": "速度倍率 +6%", "effects": {"speed_multiplier": 0.06}},
					{"name": "血潮追砍", "description": "攻擊 +6", "effects": {"attack": 6}},
					{"name": "無盡追獵", "description": "速度倍率 +8%", "effects": {"speed_multiplier": 0.08}},
					{"name": "刀輪風暴", "description": "攻擊 +8，速度倍率 +8%，解鎖刀輪風暴", "effects": {"attack": 8, "speed_multiplier": 0.08}, "is_milestone": true, "skill_unlock": "Blade Storm"},
				],
			},
		},
	},
	"defense": {
		"prefix": "D",
		"main": [
			{"name": "硬皮訓練", "description": "最大生命 +15", "effects": {"max_hp": 15}},
			{"name": "穩固架式", "description": "防禦 +2", "effects": {"defense": 2}},
			{"name": "鋼骨耐性", "description": "最大生命 +20", "effects": {"max_hp": 20}},
			{"name": "盾前呼吸", "description": "格擋率 +5%", "effects": {"block_chance": 0.05}},
			{"name": "堡壘分岔", "description": "防禦 +3，最大生命 +10，解鎖戰吼並開啟兩條分支", "effects": {"defense": 3, "max_hp": 10}, "is_milestone": true, "skill_unlock": "War Cry"},
			{"name": "重甲熟習", "description": "防禦 +4", "effects": {"defense": 4}},
			{"name": "重心穩固", "description": "格擋率 +5%", "effects": {"block_chance": 0.05}},
			{"name": "堅韌心肺", "description": "最大生命 +25", "effects": {"max_hp": 25}},
			{"name": "守勢反壓", "description": "防禦 +5", "effects": {"defense": 5}},
			{"name": "鐵壁姿態", "description": "防禦 +6，最大生命 +20", "effects": {"defense": 6, "max_hp": 20}, "is_milestone": true},
		],
		"sub_branches": {
			"block": {
				"nodes": [
					{"name": "盾面導流", "description": "格擋率 +6%", "effects": {"block_chance": 0.06}},
					{"name": "反震站位", "description": "防禦 +3", "effects": {"defense": 3}},
					{"name": "精準格擋", "description": "格擋率 +7%", "effects": {"block_chance": 0.07}},
					{"name": "強固護面", "description": "防禦 +4", "effects": {"defense": 4}},
					{"name": "封線守備", "description": "格擋率 +8%", "effects": {"block_chance": 0.08}},
					{"name": "鎮守反擊", "description": "防禦 +5", "effects": {"defense": 5}},
					{"name": "無缺防衛", "description": "格擋率 +10%", "effects": {"block_chance": 0.10}},
					{"name": "不屈壁壘", "description": "防禦 +6，最大生命 +30，解鎖不屈意志", "effects": {"defense": 6, "max_hp": 30}, "is_milestone": true, "skill_unlock": "Undying Will"},
				],
			},
			"regen": {
				"nodes": [
					{"name": "回春脈動", "description": "每次回復 +1", "effects": {"regen_amount": 1}},
					{"name": "穩態呼吸", "description": "最大生命 +15", "effects": {"max_hp": 15}},
					{"name": "血脈循環", "description": "每次回復 +1，回復間隔變為 4 秒", "effects": {"regen_amount": 1, "regen_interval": 4.0}},
					{"name": "養生屏障", "description": "防禦 +3", "effects": {"defense": 3}},
					{"name": "深層調息", "description": "每次回復 +1", "effects": {"regen_amount": 1}},
					{"name": "復甦軀殼", "description": "最大生命 +20", "effects": {"max_hp": 20}},
					{"name": "不斷再生", "description": "每次回復 +2", "effects": {"regen_amount": 2}},
					{"name": "不滅回流", "description": "每次回復 +2，最大生命 +25，解鎖無敵", "effects": {"regen_amount": 2, "max_hp": 25}, "is_milestone": true, "skill_unlock": "Invincible"},
				],
			},
		},
	},
	"support": {
		"prefix": "S",
		"main": [
			{"name": "輕步啟程", "description": "速度倍率 +8%", "effects": {"speed_multiplier": 0.08}},
			{"name": "採集手法", "description": "採集額外掉落 +1", "effects": {"gather_bonus": 1}},
			{"name": "整裝上路", "description": "拾取範圍 +20", "effects": {"loot_pickup_range": 20}},
			{"name": "省工工法", "description": "製作成本 -10%", "effects": {"craft_cost_multiplier": -0.10}},
			{"name": "旅途分岔", "description": "掉落率 +5%，解鎖尋寶獵人並開啟兩條分支", "effects": {"loot_bonus": 0.05}, "is_milestone": true, "skill_unlock": "Treasure Hunter"},
			{"name": "行軍熟習", "description": "速度倍率 +10%", "effects": {"speed_multiplier": 0.10}},
			{"name": "補給規劃", "description": "拾取範圍 +30", "effects": {"loot_pickup_range": 30}},
			{"name": "工匠直覺", "description": "製作成本 -10%", "effects": {"craft_cost_multiplier": -0.10}},
			{"name": "遠征眼界", "description": "掉落率 +10%", "effects": {"loot_bonus": 0.10}},
			{"name": "行旅大師", "description": "速度倍率 +10%，拾取範圍 +30", "effects": {"speed_multiplier": 0.10, "loot_pickup_range": 30}, "is_milestone": true},
		],
		"sub_branches": {
			"speed": {
				"nodes": [
					{"name": "風行步", "description": "速度倍率 +10%", "effects": {"speed_multiplier": 0.10}},
					{"name": "短跑熱身", "description": "速度 +6", "effects": {"speed": 6}},
					{"name": "流線姿態", "description": "速度倍率 +12%", "effects": {"speed_multiplier": 0.12}},
					{"name": "敏捷調整", "description": "速度 +8", "effects": {"speed": 8}},
					{"name": "節奏衝刺", "description": "速度倍率 +15%", "effects": {"speed_multiplier": 0.15}},
					{"name": "疾行路線", "description": "速度 +10", "effects": {"speed": 10}},
					{"name": "閃身本能", "description": "速度倍率 +18%", "effects": {"speed_multiplier": 0.18}},
					{"name": "音速衝刺", "description": "速度倍率 +20%，速度 +10，解鎖衝刺", "effects": {"speed_multiplier": 0.20, "speed": 10}, "is_milestone": true, "skill_unlock": "Sprint"},
				],
			},
			"explore": {
				"nodes": [
					{"name": "拾荒直覺", "description": "拾取範圍 +40", "effects": {"loot_pickup_range": 40}},
					{"name": "遠征背包", "description": "掉落率 +10%", "effects": {"loot_bonus": 0.10}},
					{"name": "資源辨識", "description": "採集額外掉落 +1", "effects": {"gather_bonus": 1}},
					{"name": "路徑標記", "description": "拾取範圍 +50", "effects": {"loot_pickup_range": 50}},
					{"name": "勘探手冊", "description": "掉落率 +12%", "effects": {"loot_bonus": 0.12}},
					{"name": "野外工法", "description": "製作成本 -10%", "effects": {"craft_cost_multiplier": -0.10}},
					{"name": "全域視野", "description": "解鎖全圖視野", "effects": {"full_minimap": 1}},
					{"name": "時間勘探", "description": "掉落率 +15%，拾取範圍 +60，解鎖時間扭曲", "effects": {"loot_bonus": 0.15, "loot_pickup_range": 60}, "is_milestone": true, "skill_unlock": "Time Warp"},
				],
			},
		},
	},
}


static func get_all_talents() -> Array[Dictionary]:
	var built_talents := _build_talents()
	var talents: Array[Dictionary] = []
	for talent_data in built_talents.values():
		talents.append((talent_data as Dictionary).duplicate(true))
	talents.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _sort_value(a) < _sort_value(b))
	return talents


static func get_talent(talent_id: String) -> Dictionary:
	var built_talents := _build_talents()
	if not built_talents.has(talent_id):
		return {}
	return (built_talents[talent_id] as Dictionary).duplicate(true)


static func get_branch_ids() -> PackedStringArray:
	return PackedStringArray(BRANCH_ORDER)


static func get_branch_label(branch_id: String) -> String:
	return str(BRANCH_LABELS.get(branch_id, branch_id.capitalize()))


static func get_sub_branch_ids(branch_id: String) -> PackedStringArray:
	return PackedStringArray(SUB_BRANCH_ORDER.get(branch_id, []))


static func get_sub_branch_label(branch_id: String, sub_branch_id: String) -> String:
	var branch_labels: Dictionary = SUB_BRANCH_LABELS.get(branch_id, {})
	return str(branch_labels.get(sub_branch_id, sub_branch_id.capitalize()))


static func get_branch_talents(branch_id: String) -> Array[Dictionary]:
	var talents: Array[Dictionary] = []
	for talent in get_all_talents():
		if str(talent.get("branch", "")) == branch_id:
			talents.append(talent)
	return talents


static func get_sub_branch_talents(branch_id: String, sub_branch_id: String) -> Array[Dictionary]:
	var talents: Array[Dictionary] = []
	for talent in get_all_talents():
		if str(talent.get("branch", "")) != branch_id:
			continue
		if str(talent.get("sub_branch", "")) != sub_branch_id:
			continue
		talents.append(talent)
	talents.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("sequence", 0)) < int(b.get("sequence", 0)))
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


static func _build_talents() -> Dictionary:
	var talents: Dictionary = {}
	for branch_id in BRANCH_ORDER:
		var branch_data: Dictionary = BRANCH_DATA.get(branch_id, {})
		var prefix := str(branch_data.get("prefix", branch_id.substr(0, 1).to_upper()))
		var main_nodes: Array = branch_data.get("main", [])
		for index in range(main_nodes.size()):
			var sequence := index + 1
			var id := "%s%d" % [prefix, sequence]
			var prerequisite := "" if sequence == 1 else "%s%d" % [prefix, sequence - 1]
			talents[id] = _create_talent_entry(id, branch_id, "main", sequence, _main_cost(sequence), prerequisite, main_nodes[index] as Dictionary)

		var sub_branch_index := 0
		var sub_branch_order: Array = SUB_BRANCH_ORDER.get(branch_id, [])
		var sub_branch_map: Dictionary = branch_data.get("sub_branches", {})
		for sub_branch_id_variant in sub_branch_order:
			var sub_branch_id := str(sub_branch_id_variant)
			var sub_branch_data: Dictionary = sub_branch_map.get(sub_branch_id, {})
			var nodes: Array = sub_branch_data.get("nodes", [])
			var start_number := 11 + sub_branch_index * 8
			for index in range(nodes.size()):
				var sequence := index + 1
				var id := "%s%d" % [prefix, start_number + index]
				var prerequisite := "%s5" % prefix if sequence == 1 else "%s%d" % [prefix, start_number + index - 1]
				talents[id] = _create_talent_entry(id, branch_id, sub_branch_id, sequence, _sub_cost(sequence), prerequisite, nodes[index] as Dictionary)
			sub_branch_index += 1
	return talents


static func _create_talent_entry(
		talent_id: String,
		branch_id: String,
		sub_branch_id: String,
		sequence: int,
		cost: int,
		prerequisite: String,
		node_data: Dictionary
	) -> Dictionary:
	var talent := {
		"id": talent_id,
		"name": str(node_data.get("name", talent_id)),
		"branch": branch_id,
		"sub_branch": sub_branch_id,
		"sequence": sequence,
		"cost": cost,
		"prerequisite": prerequisite,
		"description": str(node_data.get("description", "")),
		"effects": (node_data.get("effects", {}) as Dictionary).duplicate(true),
	}
	if bool(node_data.get("is_milestone", false)):
		talent["is_milestone"] = true
	if str(node_data.get("skill_unlock", "")) != "":
		talent["skill_unlock"] = str(node_data.get("skill_unlock", ""))
	return talent


static func _main_cost(sequence: int) -> int:
	return 1 if sequence <= 5 else 2


static func _sub_cost(sequence: int) -> int:
	return 3 if sequence <= 5 else 5


static func _sort_value(talent: Dictionary) -> int:
	var branch_id := str(talent.get("branch", ""))
	var branch_index := BRANCH_ORDER.find(branch_id)
	var sub_branch_id := str(talent.get("sub_branch", "main"))
	var sub_branch_index := 0
	if sub_branch_id != "main":
		sub_branch_index = (SUB_BRANCH_ORDER.get(branch_id, []) as Array).find(sub_branch_id) + 1
	return branch_index * 1000 + sub_branch_index * 100 + int(talent.get("sequence", 0))

extends Node

const BRANCH_ORDER: Array[String] = ["offense", "defense", "support", "skill", "mobility", "ultimate"]

const BRANCH_LABELS: Dictionary = {
	"offense": "branch_offense",
	"defense": "branch_defense",
	"support": "branch_support",
	"skill": "branch_skill",
	"mobility": "branch_mobility",
	"ultimate": "branch_ultimate",
}

const SUB_BRANCH_ORDER: Dictionary = {
	"offense": ["crit", "dot"],
	"defense": ["block", "regen"],
	"support": ["speed", "explore"],
	"skill": ["skill_crit", "skill_charges"],
	"mobility": ["dash_mastery", "speed_mastery"],
	"ultimate": [],
}

const SUB_BRANCH_LABELS: Dictionary = {
	"offense": {
		"crit": "sub_branch_offense_crit",
		"dot": "sub_branch_offense_dot",
	},
	"defense": {
		"block": "sub_branch_defense_block",
		"regen": "sub_branch_defense_regen",
	},
	"support": {
		"speed": "sub_branch_support_speed",
		"explore": "sub_branch_support_explore",
	},
	"skill": {
		"skill_crit": "sub_branch_skill_crit",
		"skill_charges": "sub_branch_skill_charges",
	},
	"mobility": {
		"dash_mastery": "sub_branch_mobility_dash",
		"speed_mastery": "sub_branch_mobility_speed",
	},
	"ultimate": {},
}

const BRANCH_DATA: Dictionary = {
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
					{"name": "致命強化", "description": "暴擊率 +3%", "effects": {"crit_chance": 0.03}, "gem_type": "gem_blue", "cost": 2},
					{"name": "暴斬精通", "description": "暴擊傷害 +10%", "effects": {"crit_damage_bonus": 0.10}, "gem_type": "gem_purple", "cost": 1},
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
					{"name": "鋒芒強化", "description": "攻擊力 +5%", "effects": {"attack_pct": 0.05}, "gem_type": "gem_blue", "cost": 1},
					{"name": "破甲精通", "description": "攻擊力 +8%", "effects": {"attack_pct": 0.08}, "gem_type": "gem_purple", "cost": 1},
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
					{"name": "鐵壁強化", "description": "防禦力 +5%", "effects": {"defense_pct": 0.05}, "gem_type": "gem_blue", "cost": 1},
					{"name": "磐石護身", "description": "受傷減免 +5%", "effects": {"damage_reduction_pct": 0.05}, "gem_type": "gem_purple", "cost": 2},
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
					{"name": "生命強化", "description": "血量上限 +8%", "effects": {"max_hp_pct": 0.08}, "gem_type": "gem_blue", "cost": 2},
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
					{"name": "疾風強化", "description": "移動速度 +5%", "effects": {"speed_multiplier": 0.05}, "gem_type": "gem_blue", "cost": 2},
					{"name": "祝福共鳴", "description": "祝福效果 +10%", "effects": {"blessing_effectiveness": 0.10}, "gem_type": "gem_purple", "cost": 2},
				],
			},
			"explore": {
				"nodes": [
					{"name": "拾荒直覺", "description": "拾取範圍 +40", "effects": {"loot_pickup_range": 40}},
					{"name": "擴充背包", "description": "背包 +4 格，掉落率 +5%", "effects": {"inventory_slots": 4, "loot_bonus": 0.05}},
					{"name": "資源辨識", "description": "採集額外掉落 +1", "effects": {"gather_bonus": 1}},
					{"name": "路徑標記", "description": "拾取範圍 +50", "effects": {"loot_pickup_range": 50}},
					{"name": "勘探手冊", "description": "掉落率 +12%", "effects": {"loot_bonus": 0.12}},
					{"name": "野外工法", "description": "製作成本 -10%", "effects": {"craft_cost_multiplier": -0.10}},
					{"name": "全域視野", "description": "解鎖全圖視野", "effects": {"full_minimap": 1}},
					{"name": "時間勘探", "description": "掉落率 +15%，拾取範圍 +60，解鎖時間扭曲", "effects": {"loot_bonus": 0.15, "loot_pickup_range": 60}, "is_milestone": true, "skill_unlock": "Time Warp"},
					{"name": "空間強化", "description": "背包 +2 格", "effects": {"inventory_slots": 2}, "gem_type": "gem_blue", "cost": 3},
					{"name": "精英剋星", "description": "精英怪經驗與掉落 +15%", "effects": {"elite_bonus": 0.15}, "gem_type": "gem_purple", "cost": 2},
				],
			},
		},
	},
	"skill": {
		"prefix": "SK",
		"main": [
			{"name": "術法覺醒", "description": "技能傷害 +8%", "effects": {"skill_damage_pct": 0.08}},
			{"name": "靈能敏銳", "description": "技能冷卻 -8%", "effects": {"skill_cd_pct": 0.08}},
			{"name": "魔力湧現", "description": "技能傷害 +10%", "effects": {"skill_damage_pct": 0.10}},
			{"name": "精準法則", "description": "技能冷卻 -10%", "effects": {"skill_cd_pct": 0.10}},
			{"name": "法力共鳴", "description": "技能傷害 +10%，解鎖兩條技能分支", "effects": {"skill_damage_pct": 0.10}, "is_milestone": true},
			{"name": "連環術式", "description": "技能冷卻 -12%", "effects": {"skill_cd_pct": 0.12}},
		],
		"sub_branches": {
			"skill_crit": {
				"nodes": [
					{"name": "暴裂術式", "description": "技能暴擊率 +5%", "effects": {"skill_crit_pct": 0.05}},
					{"name": "催化衝擊", "description": "技能傷害 +8%", "effects": {"skill_damage_pct": 0.08}},
					{"name": "術式爆燃", "description": "技能暴擊率 +6%", "effects": {"skill_crit_pct": 0.06}},
					{"name": "強化衝鋒", "description": "技能傷害 +10%", "effects": {"skill_damage_pct": 0.10}},
					{"name": "死亡之觸", "description": "技能暴擊率 +8%，技能傷害 +10%", "effects": {"skill_crit_pct": 0.08, "skill_damage_pct": 0.10}, "is_milestone": true},
					{"name": "虛空回饋", "description": "技能暴擊時回血 +5", "effects": {"skill_crit_heal": 5.0}},
					{"name": "法力精通", "description": "技能暴擊率 +8%", "effects": {"skill_crit_pct": 0.08}, "gem_type": "gem_blue", "cost": 2},
					{"name": "天命術式", "description": "技能傷害 +15%", "effects": {"skill_damage_pct": 0.15}, "gem_type": "gem_purple", "cost": 1},
				],
			},
			"skill_charges": {
				"nodes": [
					{"name": "技能蓄積", "description": "技能冷卻 -8%", "effects": {"skill_cd_pct": 0.08}},
					{"name": "急速連發", "description": "技能傷害 +6%", "effects": {"skill_damage_pct": 0.06}},
					{"name": "極限催動", "description": "技能冷卻 -10%", "effects": {"skill_cd_pct": 0.10}},
					{"name": "雙重充能", "description": "技能額外充能 +1", "effects": {"skill_extra_charge": 1.0}},
					{"name": "絕招重置", "description": "技能冷卻 -15%", "effects": {"skill_cd_pct": 0.15}, "is_milestone": true},
					{"name": "秒速歸位", "description": "技能傷害 +8%", "effects": {"skill_damage_pct": 0.08}},
					{"name": "術式強化", "description": "技能冷卻 -15%", "effects": {"skill_cd_pct": 0.15}, "gem_type": "gem_blue", "cost": 2},
					{"name": "天命輪轉", "description": "技能冷卻 -20%", "effects": {"skill_cd_pct": 0.20}, "gem_type": "gem_purple", "cost": 1},
				],
			},
		},
	},
	"mobility": {
		"prefix": "MB",
		"main": [
			{"name": "輕盈步伐", "description": "移動速度 +5%", "effects": {"move_speed_pct": 0.05}},
			{"name": "疾風準備", "description": "衝刺冷卻 -10%", "effects": {"dash_cd_mult": 0.10}},
			{"name": "身法精研", "description": "移動速度 +6%", "effects": {"move_speed_pct": 0.06}},
			{"name": "瞬移蓄勢", "description": "衝刺距離 +15%", "effects": {"dash_distance_mult": 0.15}},
			{"name": "疾影分岔", "description": "移動速度 +6%，解鎖兩條移動分支", "effects": {"move_speed_pct": 0.06}, "is_milestone": true},
			{"name": "流風強化", "description": "衝刺冷卻 -12%", "effects": {"dash_cd_mult": 0.12}},
		],
		"sub_branches": {
			"dash_mastery": {
				"nodes": [
					{"name": "急速衝刺", "description": "衝刺冷卻 -12%", "effects": {"dash_cd_mult": 0.12}},
					{"name": "爆發前衝", "description": "衝刺距離 +15%", "effects": {"dash_distance_mult": 0.15}},
					{"name": "神速縮退", "description": "衝刺冷卻 -15%", "effects": {"dash_cd_mult": 0.15}},
					{"name": "瞬息萬里", "description": "衝刺距離 +20%", "effects": {"dash_distance_mult": 0.20}},
					{"name": "無敵庇護", "description": "衝刺無敵 0.2 秒", "effects": {"dash_invuln_secs": 0.20}, "is_milestone": true},
					{"name": "流影速決", "description": "衝刺冷卻 -10%", "effects": {"dash_cd_mult": 0.10}},
					{"name": "疾影精通", "description": "衝刺距離 +20%", "effects": {"dash_distance_mult": 0.20}, "gem_type": "gem_blue", "cost": 2},
					{"name": "神域奔逸", "description": "衝刺無敵 +0.2 秒，衝刺冷卻 -15%", "effects": {"dash_invuln_secs": 0.20, "dash_cd_mult": 0.15}, "gem_type": "gem_purple", "cost": 1},
				],
			},
			"speed_mastery": {
				"nodes": [
					{"name": "戰鬥節奏", "description": "移動速度 +6%", "effects": {"move_speed_pct": 0.06}},
					{"name": "迅捷身形", "description": "衝刺冷卻 -8%", "effects": {"dash_cd_mult": 0.08}},
					{"name": "追風步法", "description": "移動速度 +8%", "effects": {"move_speed_pct": 0.08}},
					{"name": "速度加乘", "description": "速度倍率 +6%", "effects": {"speed_multiplier": 0.06}},
					{"name": "超速戰法", "description": "移動速度 +10%", "effects": {"move_speed_pct": 0.10}, "is_milestone": true},
					{"name": "疾光飛影", "description": "移動速度 +8%", "effects": {"move_speed_pct": 0.08}},
					{"name": "迅影強化", "description": "速度倍率 +8%", "effects": {"speed_multiplier": 0.08}, "gem_type": "gem_blue", "cost": 2},
					{"name": "最速傳說", "description": "移動速度 +12%，速度倍率 +10%", "effects": {"move_speed_pct": 0.12, "speed_multiplier": 0.10}, "gem_type": "gem_purple", "cost": 1},
				],
			},
		},
	},
	"ultimate": {
		"prefix": "U",
		"main": [
			{"name": "技能存量+1", "description": "所有技能基礎多存一次施放（TODO：技能系統完成後生效）", "effects": {"skill_extra_charge": 1}, "gem_type": "gem_red", "cost": 1, "no_prerequisite": true},
			{"name": "精英必觸祝福", "description": "精英怪死亡時必定觸發祝福選擇（原本 50% 機率）", "effects": {"elite_blessing_guaranteed": 1}, "gem_type": "gem_red", "cost": 1, "no_prerequisite": true},
			{"name": "死亡保護", "description": "死亡時：非鎖定裝備各有 50% 機率保留，銅幣保留 50%", "effects": {"death_protection": 1}, "gem_type": "gem_red", "cost": 1, "no_prerequisite": true},
		],
		"sub_branches": {},
	},
}


static func get_all_talents() -> Array[Dictionary]:
	var built_talents: Dictionary = _build_talents()
	var talents: Array[Dictionary] = []
	for talent_data in built_talents.values():
		talents.append((talent_data as Dictionary).duplicate(true))
	talents.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _sort_value(a) < _sort_value(b))
	return talents


static func get_talent(talent_id: String) -> Dictionary:
	var built_talents: Dictionary = _build_talents()
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


static func can_unlock(unlocked_talents: Array[String], gem_counts: Dictionary, talent_id: String) -> bool:
	var talent: Dictionary = get_talent(talent_id)
	if talent.is_empty():
		return false
	if unlocked_talents.has(talent_id):
		return false
	var gem_type: String = str(talent.get("gem_type", "talent_shard"))
	var available: int = int(gem_counts.get(gem_type, 0))
	if available < int(talent.get("cost", 0)):
		return false
	var prerequisite: String = str(talent.get("prerequisite", ""))
	return prerequisite == "" or unlocked_talents.has(prerequisite)


static func _build_talents() -> Dictionary:
	var talents: Dictionary = {}
	for branch_id in BRANCH_ORDER:
		var branch_data: Dictionary = BRANCH_DATA.get(branch_id, {})
		var prefix: String = str(branch_data.get("prefix", branch_id.substr(0, 1).to_upper()))
		var main_nodes: Array = branch_data.get("main", [])
		for index in range(main_nodes.size()):
			var sequence: int = index + 1
			var id: String = "%s%d" % [prefix, sequence]
			var node_entry: Dictionary = main_nodes[index] as Dictionary
			var auto_prereq: String = "" if sequence == 1 else "%s%d" % [prefix, sequence - 1]
			var prerequisite: String = "" if bool(node_entry.get("no_prerequisite", false)) else auto_prereq
			talents[id] = _create_talent_entry(id, branch_id, "main", sequence, _main_cost(sequence), prerequisite, node_entry)

		var sub_branch_index: int = 0
		var sub_branch_order: Array = SUB_BRANCH_ORDER.get(branch_id, [])
		var sub_branch_map: Dictionary = branch_data.get("sub_branches", {})
		for sub_branch_id_variant in sub_branch_order:
			var sub_branch_id: String = str(sub_branch_id_variant)
			var sub_branch_data: Dictionary = sub_branch_map.get(sub_branch_id, {})
			var nodes: Array = sub_branch_data.get("nodes", [])
			var start_number: int = 11
			for prev_index: int in range(sub_branch_index):
				var prev_sub_id: String = str(sub_branch_order[prev_index])
				var prev_nodes: Array = (sub_branch_map.get(prev_sub_id, {}) as Dictionary).get("nodes", []) as Array
				start_number += prev_nodes.size()
			for index in range(nodes.size()):
				var sequence: int = index + 1
				var id: String = "%s%d" % [prefix, start_number + index]
				var prerequisite: String = "%s5" % prefix if sequence == 1 else "%s%d" % [prefix, start_number + index - 1]
				talents[id] = _create_talent_entry(id, branch_id, sub_branch_id, sequence, _sub_cost(sequence), prerequisite, nodes[index] as Dictionary)
			sub_branch_index += 1
	return talents


static func _create_talent_entry(
		talent_id: String,
		branch_id: String,
		sub_branch_id: String,
		sequence: int,
		auto_cost: int,
		prerequisite: String,
		node_data: Dictionary
	) -> Dictionary:
	var fallback_name: String = "未命名天賦 %s" % talent_id
	var fallback_description: String = "尚無描述"
	var final_cost: int = int(node_data.get("cost", auto_cost))
	var gem_type: String = str(node_data.get("gem_type", "talent_shard"))
	var talent: Dictionary = {
		"id": talent_id,
		"name": str(node_data.get("name", fallback_name)),
		"branch": branch_id,
		"sub_branch": sub_branch_id,
		"sequence": sequence,
		"cost": final_cost,
		"gem_type": gem_type,
		"prerequisite": prerequisite,
		"description": str(node_data.get("description", fallback_description)),
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
	var branch_id: String = str(talent.get("branch", ""))
	var branch_index: int = BRANCH_ORDER.find(branch_id)
	var sub_branch_id: String = str(talent.get("sub_branch", "main"))
	var sub_branch_index: int = 0
	if sub_branch_id != "main":
		sub_branch_index = (SUB_BRANCH_ORDER.get(branch_id, []) as Array).find(sub_branch_id) + 1
	return branch_index * 1000 + sub_branch_index * 100 + int(talent.get("sequence", 0))

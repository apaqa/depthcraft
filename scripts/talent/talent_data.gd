extends Node

const BRANCH_ORDER := ["offense", "defense", "support"]

const BRANCH_LABELS := {
	"offense": "攻擊",
	"defense": "防禦",
	"support": "輔助",
}

const SUB_ORDER := {
	"offense": ["main", "crit", "dot"],
	"defense": ["main", "block", "regen"],
	"support": ["main", "speed", "explore"],
}

const SUB_BRANCH_LABELS := {
	"offense": {"main": "攻擊主線", "crit": "暴擊流", "dot": "持續傷害流"},
	"defense": {"main": "防禦主線", "block": "格擋流", "regen": "回復流"},
	"support": {"main": "輔助主線", "speed": "速度流", "explore": "探索流"},
}

# cost tiers: main seq 1-5 → 1, main seq 6-10 → 2, branch seq 1-5 → 3, branch seq 6-8 → 5
const TALENTS := {
	# ── Offense Main (O1–O10) ──────────────────────────────────────────────
	"O1":  {"id": "O1",  "name": "銳利之刃", "branch": "offense", "sub": "main", "sequence": 1,  "cost": 1, "prerequisite": "",    "description": "攻擊 +3",              "effects": {"attack": 3},                                     "class_id": "all"},
	"O2":  {"id": "O2",  "name": "力量",     "branch": "offense", "sub": "main", "sequence": 2,  "cost": 1, "prerequisite": "O1",  "description": "攻擊 +5",              "effects": {"attack": 5},                                     "class_id": "all"},
	"O3":  {"id": "O3",  "name": "迅捷之刃", "branch": "offense", "sub": "main", "sequence": 3,  "cost": 1, "prerequisite": "O2",  "description": "攻速 +10%",            "effects": {"attack_speed": 0.1},                             "class_id": "all"},
	"O4":  {"id": "O4",  "name": "致命之眼", "branch": "offense", "sub": "main", "sequence": 4,  "cost": 1, "prerequisite": "O3",  "description": "暴擊率 +5%",           "effects": {"crit_chance": 0.05},                             "class_id": "all"},
	"O5":  {"id": "O5",  "name": "旋風",     "branch": "offense", "sub": "main", "sequence": 5,  "cost": 1, "prerequisite": "O4",  "description": "解鎖 AOE 旋風技能",   "effects": {"skill_whirlwind": 1}, "is_milestone": true, "skill_unlock": "Whirlwind", "class_id": "all"},
	"O6":  {"id": "O6",  "name": "犀銳之心", "branch": "offense", "sub": "main", "sequence": 6,  "cost": 2, "prerequisite": "O5",  "description": "攻擊 +8",              "effects": {"attack": 8},                                     "class_id": "all"},
	"O7":  {"id": "O7",  "name": "深層傷口", "branch": "offense", "sub": "main", "sequence": 7,  "cost": 2, "prerequisite": "O6",  "description": "命中帶 3 秒流血",      "effects": {"bleed_on_hit": 1},                               "class_id": "all"},
	"O8":  {"id": "O8",  "name": "狂暴",     "branch": "offense", "sub": "main", "sequence": 8,  "cost": 2, "prerequisite": "O7",  "description": "連擊觸發狂暴 +30%",    "effects": {"frenzy": 1},                                     "class_id": "all"},
	"O9":  {"id": "O9",  "name": "超暴傷害", "branch": "offense", "sub": "main", "sequence": 9,  "cost": 2, "prerequisite": "O8",  "description": "暴擊傷害 +50%",        "effects": {"crit_damage": 0.5},                              "class_id": "all"},
	"O10": {"id": "O10", "name": "斬決",     "branch": "offense", "sub": "main", "sequence": 10, "cost": 2, "prerequisite": "O9",  "description": "對低血敵人造成 3× 傷害","effects": {"execute_bonus": 2.0, "skill_execute": 1}, "is_milestone": true, "skill_unlock": "Execute", "class_id": "all"},

	# ── Offense Crit (OC1–OC8) ────────────────────────────────────────────
	"OC1": {"id": "OC1", "name": "精準射擊", "branch": "offense", "sub": "crit", "sequence": 1, "cost": 3, "prerequisite": "O5",  "description": "暴擊率 +3%",                     "effects": {"crit_chance": 0.03},              "class_id": "all"},
	"OC2": {"id": "OC2", "name": "命中心臟", "branch": "offense", "sub": "crit", "sequence": 2, "cost": 3, "prerequisite": "OC1", "description": "暴擊傷害 +20%",                  "effects": {"crit_damage": 0.2},               "class_id": "all"},
	"OC3": {"id": "OC3", "name": "貫穿護甲", "branch": "offense", "sub": "crit", "sequence": 3, "cost": 3, "prerequisite": "OC2", "description": "忽視敵人 10% 防禦",              "effects": {"armor_pierce": 0.1},              "class_id": "all"},
	"OC4": {"id": "OC4", "name": "連鎖暴擊", "branch": "offense", "sub": "crit", "sequence": 4, "cost": 3, "prerequisite": "OC3", "description": "暴擊後下一擊必暴",              "effects": {"chain_crit": 1},                  "class_id": "all"},
	"OC5": {"id": "OC5", "name": "血怒",     "branch": "offense", "sub": "crit", "sequence": 5, "cost": 3, "prerequisite": "OC4", "description": "殺敵後暴擊率 +5%（最多 +15%）", "effects": {"kill_crit_bonus": 0.05},          "class_id": "all"},
	"OC6": {"id": "OC6", "name": "脆弱打擊", "branch": "offense", "sub": "crit", "sequence": 6, "cost": 5, "prerequisite": "OC5", "description": "暴擊令敵人受傷增加 15%",        "effects": {"vulnerable_strike": 0.15},        "class_id": "all"},
	"OC7": {"id": "OC7", "name": "無情",     "branch": "offense", "sub": "crit", "sequence": 7, "cost": 5, "prerequisite": "OC6", "description": "暴擊傷害 +30%",                  "effects": {"crit_damage": 0.3},               "class_id": "all"},
	"OC8": {"id": "OC8", "name": "絕殺",     "branch": "offense", "sub": "crit", "sequence": 8, "cost": 5, "prerequisite": "OC7", "description": "【終極】暴擊率 +25%，解鎖劍刃風暴", "effects": {"crit_chance": 0.25, "skill_blade_storm": 1}, "is_milestone": true, "skill_unlock": "Blade Storm", "class_id": "all"},

	# ── Offense DoT (OD1–OD8) ─────────────────────────────────────────────
	"OD1": {"id": "OD1", "name": "毒液塗抹", "branch": "offense", "sub": "dot", "sequence": 1, "cost": 3, "prerequisite": "O5",  "description": "命中帶中毒效果",             "effects": {"poison_on_hit": 1},           "class_id": "all"},
	"OD2": {"id": "OD2", "name": "燃燒打擊", "branch": "offense", "sub": "dot", "sequence": 2, "cost": 3, "prerequisite": "OD1", "description": "命中帶燃燒效果",             "effects": {"burn_on_hit": 1},             "class_id": "all"},
	"OD3": {"id": "OD3", "name": "傷口惡化", "branch": "offense", "sub": "dot", "sequence": 3, "cost": 3, "prerequisite": "OD2", "description": "持續傷害持續 +2 秒",         "effects": {"dot_duration": 2},            "class_id": "all"},
	"OD4": {"id": "OD4", "name": "積毒之體", "branch": "offense", "sub": "dot", "sequence": 4, "cost": 3, "prerequisite": "OD3", "description": "中毒傷害 +50%",              "effects": {"poison_damage": 0.5},         "class_id": "all"},
	"OD5": {"id": "OD5", "name": "連鎖毒素", "branch": "offense", "sub": "dot", "sequence": 5, "cost": 3, "prerequisite": "OD4", "description": "中毒擴散至相鄰敵人",         "effects": {"dot_spread": 1},              "class_id": "all"},
	"OD6": {"id": "OD6", "name": "侵蝕",     "branch": "offense", "sub": "dot", "sequence": 6, "cost": 5, "prerequisite": "OD5", "description": "持續傷害期間敵人防禦 -20%", "effects": {"dot_defense_shred": 0.2},     "class_id": "all"},
	"OD7": {"id": "OD7", "name": "毒爆",     "branch": "offense", "sub": "dot", "sequence": 7, "cost": 5, "prerequisite": "OD6", "description": "敵人死亡時觸發毒爆",         "effects": {"poison_explode": 1},          "class_id": "all"},
	"OD8": {"id": "OD8", "name": "瘟疫之主", "branch": "offense", "sub": "dot", "sequence": 8, "cost": 5, "prerequisite": "OD7", "description": "【終極】所有持續傷害 +100%", "effects": {"dot_multiplier": 1.0},        "is_milestone": true, "class_id": "all"},

	# ── Defense Main (D1–D10) ─────────────────────────────────────────────
	"D1":  {"id": "D1",  "name": "厚實皮膚", "branch": "defense", "sub": "main", "sequence": 1,  "cost": 1, "prerequisite": "",    "description": "血量 +15",              "effects": {"max_hp": 15},                                     "class_id": "all"},
	"D2":  {"id": "D2",  "name": "鐵石心腸", "branch": "defense", "sub": "main", "sequence": 2,  "cost": 1, "prerequisite": "D1",  "description": "防禦 +3",               "effects": {"defense": 3},                                     "class_id": "all"},
	"D3":  {"id": "D3",  "name": "格擋",     "branch": "defense", "sub": "main", "sequence": 3,  "cost": 1, "prerequisite": "D2",  "description": "格擋 10% 傷害",         "effects": {"block_chance": 0.10},                             "class_id": "all"},
	"D4":  {"id": "D4",  "name": "恢復",     "branch": "defense", "sub": "main", "sequence": 4,  "cost": 1, "prerequisite": "D3",  "description": "每 5 秒回 1 血",        "effects": {"regen_amount": 1, "regen_interval": 5.0},         "class_id": "all"},
	"D5":  {"id": "D5",  "name": "戰吼",     "branch": "defense", "sub": "main", "sequence": 5,  "cost": 1, "prerequisite": "D4",  "description": "解鎖戰吼技能，敵人減傷", "effects": {"skill_war_cry": 1}, "is_milestone": true, "skill_unlock": "War Cry", "class_id": "all"},
	"D6":  {"id": "D6",  "name": "精鋼護甲", "branch": "defense", "sub": "main", "sequence": 6,  "cost": 2, "prerequisite": "D5",  "description": "防禦 +6",               "effects": {"defense": 6},                                     "class_id": "all"},
	"D7":  {"id": "D7",  "name": "緩衝反彈", "branch": "defense", "sub": "main", "sequence": 7,  "cost": 2, "prerequisite": "D6",  "description": "低血量時每秒回復 3 血",  "effects": {"second_wind": 1},                                 "class_id": "all"},
	"D8":  {"id": "D8",  "name": "穩固",     "branch": "defense", "sub": "main", "sequence": 8,  "cost": 2, "prerequisite": "D7",  "description": "站立不動時防禦 +30%",   "effects": {"fortify": 1},                                     "class_id": "all"},
	"D9":  {"id": "D9",  "name": "傷害轉化", "branch": "defense", "sub": "main", "sequence": 9,  "cost": 2, "prerequisite": "D8",  "description": "反彈 10% 受到傷害",      "effects": {"damage_reflect": 0.1},                            "class_id": "all"},
	"D10": {"id": "D10", "name": "不屈意志", "branch": "defense", "sub": "main", "sequence": 10, "cost": 2, "prerequisite": "D9",  "description": "解鎖不屈意志（抵擋一次致死傷害）", "effects": {"undying_will": 1, "skill_undying_will": 1}, "is_milestone": true, "skill_unlock": "Undying Will", "class_id": "all"},

	# ── Defense Block (DB1–DB8) ───────────────────────────────────────────
	"DB1": {"id": "DB1", "name": "盾牆",     "branch": "defense", "sub": "block", "sequence": 1, "cost": 3, "prerequisite": "D5",  "description": "格擋率 +5%",              "effects": {"block_chance": 0.05},           "class_id": "all"},
	"DB2": {"id": "DB2", "name": "堅盾",     "branch": "defense", "sub": "block", "sequence": 2, "cost": 3, "prerequisite": "DB1", "description": "格擋傷害減少 50%",        "effects": {"block_damage_reduction": 0.5},  "class_id": "all"},
	"DB3": {"id": "DB3", "name": "反擊",     "branch": "defense", "sub": "block", "sequence": 3, "cost": 3, "prerequisite": "DB2", "description": "格擋後反擊 +20% 傷害",    "effects": {"block_counter": 0.2},           "class_id": "all"},
	"DB4": {"id": "DB4", "name": "鐵壁",     "branch": "defense", "sub": "block", "sequence": 4, "cost": 3, "prerequisite": "DB3", "description": "血量 +20",                 "effects": {"max_hp": 20},                   "class_id": "all"},
	"DB5": {"id": "DB5", "name": "破陣",     "branch": "defense", "sub": "block", "sequence": 5, "cost": 3, "prerequisite": "DB4", "description": "格擋後下一擊穿透 20% 防禦", "effects": {"armor_pierce": 0.2},           "class_id": "all"},
	"DB6": {"id": "DB6", "name": "護盾強化", "branch": "defense", "sub": "block", "sequence": 6, "cost": 5, "prerequisite": "DB5", "description": "最大血量 +30",             "effects": {"max_hp": 30},                   "class_id": "all"},
	"DB7": {"id": "DB7", "name": "保命護盾", "branch": "defense", "sub": "block", "sequence": 7, "cost": 5, "prerequisite": "DB6", "description": "每 30 秒獲得 20 點護盾",   "effects": {"life_shield": 1},               "class_id": "all"},
	"DB8": {"id": "DB8", "name": "無敵",     "branch": "defense", "sub": "block", "sequence": 8, "cost": 5, "prerequisite": "DB7", "description": "【終極】解鎖無敵技能",     "effects": {"skill_invincible": 1}, "is_milestone": true, "skill_unlock": "Invincible", "class_id": "all"},

	# ── Defense Regen (DR1–DR8) ───────────────────────────────────────────
	"DR1": {"id": "DR1", "name": "生命之源", "branch": "defense", "sub": "regen", "sequence": 1, "cost": 3, "prerequisite": "D5",  "description": "每 3 秒回 1 血",             "effects": {"regen_amount": 1, "regen_interval": 3.0}, "class_id": "all"},
	"DR2": {"id": "DR2", "name": "傷口癒合", "branch": "defense", "sub": "regen", "sequence": 2, "cost": 3, "prerequisite": "DR1", "description": "HP 回復效果 +50%",           "effects": {"regen_multiplier": 0.5},                  "class_id": "all"},
	"DR3": {"id": "DR3", "name": "戰鬥本能", "branch": "defense", "sub": "regen", "sequence": 3, "cost": 3, "prerequisite": "DR2", "description": "受傷後 2 秒觸發小回復",      "effects": {"combat_regen": 1},                        "class_id": "all"},
	"DR4": {"id": "DR4", "name": "強韌之體", "branch": "defense", "sub": "regen", "sequence": 4, "cost": 3, "prerequisite": "DR3", "description": "血量 +25",                    "effects": {"max_hp": 25},                             "class_id": "all"},
	"DR5": {"id": "DR5", "name": "不死之軀", "branch": "defense", "sub": "regen", "sequence": 5, "cost": 3, "prerequisite": "DR4", "description": "低血量時回復加倍",             "effects": {"low_hp_regen": 1},                        "class_id": "all"},
	"DR6": {"id": "DR6", "name": "再生之力", "branch": "defense", "sub": "regen", "sequence": 6, "cost": 5, "prerequisite": "DR5", "description": "每秒回復 2 血",               "effects": {"regen_amount": 2},                        "class_id": "all"},
	"DR7": {"id": "DR7", "name": "狀態抵抗", "branch": "defense", "sub": "regen", "sequence": 7, "cost": 5, "prerequisite": "DR6", "description": "狀態效果持續時間 -50%",       "effects": {"status_resist": 0.5},                     "class_id": "all"},
	"DR8": {"id": "DR8", "name": "涅槃重生", "branch": "defense", "sub": "regen", "sequence": 8, "cost": 5, "prerequisite": "DR7", "description": "【終極】每地城滿血復活一次", "effects": {"phoenix_revival": 1},                     "is_milestone": true, "class_id": "all"},

	# ── Support Main (S1–S10) ─────────────────────────────────────────────
	"S1":  {"id": "S1",  "name": "步伐",     "branch": "support", "sub": "main", "sequence": 1,  "cost": 1, "prerequisite": "",    "description": "移速 +8%",              "effects": {"speed_multiplier": 0.08},                          "class_id": "all"},
	"S2":  {"id": "S2",  "name": "採集者",   "branch": "support", "sub": "main", "sequence": 2,  "cost": 1, "prerequisite": "S1",  "description": "採集 +1",               "effects": {"gather_bonus": 1},                                 "class_id": "all"},
	"S3":  {"id": "S3",  "name": "幸運顯現", "branch": "support", "sub": "main", "sequence": 3,  "cost": 1, "prerequisite": "S2",  "description": "掉落率 +10%",           "effects": {"loot_bonus": 0.10},                                "class_id": "all"},
	"S4":  {"id": "S4",  "name": "高效製作", "branch": "support", "sub": "main", "sequence": 4,  "cost": 1, "prerequisite": "S3",  "description": "製作成本 -15%",         "effects": {"craft_cost_multiplier": -0.15},                    "class_id": "all"},
	"S5":  {"id": "S5",  "name": "尋寶術",   "branch": "support", "sub": "main", "sequence": 5,  "cost": 1, "prerequisite": "S4",  "description": "解鎖尋寶術，顯示寶箱位置", "effects": {"skill_treasure_hunter": 1}, "is_milestone": true, "skill_unlock": "Treasure Hunter", "class_id": "all"},
	"S6":  {"id": "S6",  "name": "磁石",     "branch": "support", "sub": "main", "sequence": 6,  "cost": 2, "prerequisite": "S5",  "description": "拾取範圍 +50",          "effects": {"loot_pickup_range": 50.0},                         "class_id": "all"},
	"S7":  {"id": "S7",  "name": "輕盈之靴", "branch": "support", "sub": "main", "sequence": 7,  "cost": 2, "prerequisite": "S6",  "description": "移速 +15%",             "effects": {"speed_multiplier": 0.15},                          "class_id": "all"},
	"S8":  {"id": "S8",  "name": "討價還價", "branch": "support", "sub": "main", "sequence": 8,  "cost": 2, "prerequisite": "S7",  "description": "商店價格 -20%",         "effects": {"merchant_discount": 0.2},                          "class_id": "all"},
	"S9":  {"id": "S9",  "name": "冒險家",   "branch": "support", "sub": "main", "sequence": 9,  "cost": 2, "prerequisite": "S8",  "description": "地圖全亮",              "effects": {"full_minimap": 1},                                 "class_id": "all"},
	"S10": {"id": "S10", "name": "衝刺",     "branch": "support", "sub": "main", "sequence": 10, "cost": 2, "prerequisite": "S9",  "description": "解鎖衝刺技能（3 秒 +100% 速度）", "effects": {"skill_sprint": 1}, "is_milestone": true, "skill_unlock": "Sprint", "class_id": "all"},

	# ── Support Speed (SS1–SS8) ───────────────────────────────────────────
	"SS1": {"id": "SS1", "name": "疾風步",   "branch": "support", "sub": "speed", "sequence": 1, "cost": 3, "prerequisite": "S5",  "description": "移速 +10%",                 "effects": {"speed_multiplier": 0.10},       "class_id": "all"},
	"SS2": {"id": "SS2", "name": "閃避反應", "branch": "support", "sub": "speed", "sequence": 2, "cost": 3, "prerequisite": "SS1", "description": "閃避後移速 +20%",           "effects": {"dodge_speed_bonus": 0.2},       "class_id": "all"},
	"SS3": {"id": "SS3", "name": "輕裝上陣", "branch": "support", "sub": "speed", "sequence": 3, "cost": 3, "prerequisite": "SS2", "description": "移速 +12%",                 "effects": {"speed_multiplier": 0.12},       "class_id": "all"},
	"SS4": {"id": "SS4", "name": "迅雷不及", "branch": "support", "sub": "speed", "sequence": 4, "cost": 3, "prerequisite": "SS3", "description": "衝刺冷卻 -30%",             "effects": {"sprint_cooldown_reduction": 0.3},"class_id": "all"},
	"SS5": {"id": "SS5", "name": "風靈化身", "branch": "support", "sub": "speed", "sequence": 5, "cost": 3, "prerequisite": "SS4", "description": "移速 +20%",                 "effects": {"speed_multiplier": 0.20},       "class_id": "all"},
	"SS6": {"id": "SS6", "name": "瞬息萬變", "branch": "support", "sub": "speed", "sequence": 6, "cost": 5, "prerequisite": "SS5", "description": "閃避距離 +50%",             "effects": {"dodge_distance": 0.5},          "class_id": "all"},
	"SS7": {"id": "SS7", "name": "低血暴走", "branch": "support", "sub": "speed", "sequence": 7, "cost": 5, "prerequisite": "SS6", "description": "低血量移速 +25%",           "effects": {"low_hp_speed_bonus": 0.25},     "class_id": "all"},
	"SS8": {"id": "SS8", "name": "時間扭曲", "branch": "support", "sub": "speed", "sequence": 8, "cost": 5, "prerequisite": "SS7", "description": "【終極】解鎖時間扭曲技能", "effects": {"skill_time_warp": 1}, "is_milestone": true, "skill_unlock": "Time Warp", "class_id": "all"},

	# ── Support Explore (SE1–SE8) ─────────────────────────────────────────
	"SE1": {"id": "SE1", "name": "採集速度", "branch": "support", "sub": "explore", "sequence": 1, "cost": 3, "prerequisite": "S5",  "description": "採集速度 +30%",              "effects": {"gather_speed": 0.3},            "class_id": "all"},
	"SE2": {"id": "SE2", "name": "幸運一擊", "branch": "support", "sub": "explore", "sequence": 2, "cost": 3, "prerequisite": "SE1", "description": "5% 機率雙倍掉落",           "effects": {"double_loot_chance": 0.05},     "class_id": "all"},
	"SE3": {"id": "SE3", "name": "遠見",     "branch": "support", "sub": "explore", "sequence": 3, "cost": 3, "prerequisite": "SE2", "description": "視野範圍 +30%",              "effects": {"vision_range": 0.3},            "class_id": "all"},
	"SE4": {"id": "SE4", "name": "寶物感知", "branch": "support", "sub": "explore", "sequence": 4, "cost": 3, "prerequisite": "SE3", "description": "顯示附近寶箱位置",           "effects": {"treasure_sense": 1},            "class_id": "all"},
	"SE5": {"id": "SE5", "name": "資源專家", "branch": "support", "sub": "explore", "sequence": 5, "cost": 3, "prerequisite": "SE4", "description": "採集 +1",                    "effects": {"gather_bonus": 1},              "class_id": "all"},
	"SE6": {"id": "SE6", "name": "死亡一線", "branch": "support", "sub": "explore", "sequence": 6, "cost": 5, "prerequisite": "SE5", "description": "死亡時 30% 機率保留一件物品", "effects": {"second_chance_loot": 0.3},      "class_id": "all"},
	"SE7": {"id": "SE7", "name": "連鎖採集", "branch": "support", "sub": "explore", "sequence": 7, "cost": 5, "prerequisite": "SE6", "description": "採集時 10% 機率觸發雙倍採集", "effects": {"chain_gather": 0.1},            "class_id": "all"},
	"SE8": {"id": "SE8", "name": "探索大師", "branch": "support", "sub": "explore", "sequence": 8, "cost": 5, "prerequisite": "SE7", "description": "【終極】掉落率 +30%，採集 +2","effects": {"loot_bonus": 0.3, "gather_bonus": 2}, "is_milestone": true, "class_id": "all"},
}


static func get_all_talents() -> Array[Dictionary]:
	var talents: Array[Dictionary] = []
	for talent_id in TALENTS.keys():
		talents.append(get_talent(talent_id))
	talents.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _talent_sort_key(a) < _talent_sort_key(b))
	return talents


static func get_talent(talent_id: String) -> Dictionary:
	if not TALENTS.has(talent_id):
		return {}
	return TALENTS[talent_id].duplicate(true)


static func get_branch_ids() -> PackedStringArray:
	return PackedStringArray(BRANCH_ORDER)


static func get_branch_label(branch_id: String) -> String:
	return str(BRANCH_LABELS.get(branch_id, branch_id.capitalize()))


static func get_sub_branch_ids(branch_id: String) -> PackedStringArray:
	var order: Array = SUB_ORDER.get(branch_id, ["main"])
	return PackedStringArray(order.filter(func(s): return s != "main"))


static func get_sub_branch_label(branch_id: String, sub_id: String) -> String:
	var branch_map: Dictionary = SUB_BRANCH_LABELS.get(branch_id, {})
	return str(branch_map.get(sub_id, sub_id.capitalize()))


static func get_branch_talents(branch_id: String) -> Array[Dictionary]:
	var talents: Array[Dictionary] = []
	for talent in get_all_talents():
		if str(talent.get("branch", "")) == branch_id:
			talents.append(talent)
	return talents


static func get_sub_branch_talents(branch_id: String, sub_id: String) -> Array[Dictionary]:
	var talents: Array[Dictionary] = []
	for talent in get_all_talents():
		if str(talent.get("branch", "")) == branch_id and str(talent.get("sub", "")) == sub_id:
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


static func _talent_sort_key(talent: Dictionary) -> int:
	var branch := str(talent.get("branch", ""))
	var branch_idx := BRANCH_ORDER.find(branch)
	if branch_idx < 0:
		branch_idx = 99
	var sub := str(talent.get("sub", "main"))
	var sub_list: Array = SUB_ORDER.get(branch, ["main"])
	var sub_idx := sub_list.find(sub)
	if sub_idx < 0:
		sub_idx = 99
	var seq := int(talent.get("sequence", 0))
	return branch_idx * 10000 + sub_idx * 100 + seq

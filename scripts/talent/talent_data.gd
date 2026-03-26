extends Node

const BRANCH_ORDER := ["offense", "defense", "support"]

const BRANCH_LABELS := {
	"offense": "?»æ?",
	"defense": "?²ç¦¦",
	"support": "è¼”åŠ©",
}

const TALENTS := {
	"O1": {"id": "O1", "name": "?³åˆ©ä¹‹å?", "branch": "offense", "cost": 2, "prerequisite": "", "description": "?»æ? +3", "effects": {"attack": 3}},
	"O2": {"id": "O2", "name": "?æ?", "branch": "offense", "cost": 3, "prerequisite": "O1", "description": "?»æ? +5", "effects": {"attack": 5}},
	"O3": {"id": "O3", "name": "è¿…æ·ä¹‹æ?", "branch": "offense", "cost": 4, "prerequisite": "O2", "description": "?»é€?+10%", "effects": {"attack_speed": 0.1}},
	"O4": {"id": "O4", "name": "?´å‘½ä¹‹çœ¼", "branch": "offense", "cost": 5, "prerequisite": "O3", "description": "?´æ? +5%", "effects": {"crit_chance": 0.05}},
	"O5": {"id": "O5", "name": "?‹é¢¨??, "branch": "offense", "cost": 8, "prerequisite": "O4", "description": "?¨å?AOE?·å®³", "effects": {"skill_whirlwind": 1}, "is_milestone": true, "skill_unlock": "Whirlwind"},
	"O6": {"id": "O6", "name": "?´éŠ³ä¹‹å?", "branch": "offense", "cost": 6, "prerequisite": "O5", "description": "?»æ? +8", "effects": {"attack": 8}},
	"O7": {"id": "O7", "name": "æ·±å±¤?·å£", "branch": "offense", "cost": 7, "prerequisite": "O6", "description": "?»æ??„å¸¶3ç§’æ?è¡€", "effects": {"bleed_on_hit": 1}},
	"O8": {"id": "O8", "name": "?‚æš´", "branch": "offense", "cost": 8, "prerequisite": "O7", "description": "??®º?å??»é€?0%", "effects": {"frenzy": 1}},
	"O9": {"id": "O9", "name": "?´æ??·å®³", "branch": "offense", "cost": 9, "prerequisite": "O8", "description": "?´æ??·å®³ +50%", "effects": {"crit_damage": 0.5}},
	"O10": {"id": "O10", "name": "?•æ±º", "branch": "offense", "cost": 12, "prerequisite": "O9", "description": "å°ä?è¡€?µäºº3?å‚·å®?, "effects": {"execute_bonus": 2.0, "skill_execute": 1}, "is_milestone": true, "skill_unlock": "Execute"},
	"O11": {"id": "O11", "name": "æ­¦å™¨å¤§å¸«", "branch": "offense", "cost": 10, "prerequisite": "O10", "description": "?»æ? +12", "effects": {"attack": 12}},
	"O12": {"id": "O12", "name": "è­·ç”²ç©¿é€?, "branch": "offense", "cost": 11, "prerequisite": "O11", "description": "?¡è??µäºº 20% ?²ç¦¦", "effects": {"armor_pierce": 0.2}},
	"O13": {"id": "O13", "name": "?œè?", "branch": "offense", "cost": 12, "prerequisite": "O12", "description": "?Šæ®º?‚å?å¾?5% ?€å¤§è???, "effects": {"kill_heal_ratio": 0.05}},
	"O14": {"id": "O14", "name": "?‚æˆ°å£«ä???, "branch": "offense", "cost": 13, "prerequisite": "O13", "description": "è¡€?ä???30% ?‚ï??»æ? +50%", "effects": {"low_hp_attack_bonus": 0.5}},
	"O15": {"id": "O15", "name": "?å?é¢¨æš´", "branch": "offense", "cost": 15, "prerequisite": "O14", "description": "è§???€?½ï??å?é¢¨æš´ï¼ˆå¤§ç¯„å??ç? AOEï¼?, "effects": {"skill_blade_storm": 1}, "is_milestone": true, "skill_unlock": "Blade Storm"},

	"D1": {"id": "D1", "name": "?…é??®è?", "branch": "defense", "cost": 2, "prerequisite": "", "description": "è¡€??+15", "effects": {"max_hp": 15}},
	"D2": {"id": "D2", "name": "?µå?", "branch": "defense", "cost": 3, "prerequisite": "D1", "description": "?²ç¦¦ +3", "effects": {"defense": 3}},
	"D3": {"id": "D3", "name": "?¾ç?", "branch": "defense", "cost": 4, "prerequisite": "D2", "description": "?¼æ?10%?·å®³", "effects": {"block_chance": 0.10}},
	"D4": {"id": "D4", "name": "?ç?", "branch": "defense", "cost": 5, "prerequisite": "D3", "description": "æ¯?ç§’å?1è¡€", "effects": {"regen_amount": 1, "regen_interval": 5.0}},
	"D5": {"id": "D5", "name": "?°å¼", "branch": "defense", "cost": 8, "prerequisite": "D4", "description": "?¨å??µäººæ¸›é€?0%", "effects": {"skill_war_cry": 1}, "is_milestone": true, "skill_unlock": "War Cry"},
	"D6": {"id": "D6", "name": "?šé?è­·ç”²", "branch": "defense", "cost": 6, "prerequisite": "D5", "description": "?²ç¦¦ +6", "effects": {"defense": 6}},
	"D7": {"id": "D7", "name": "ç·©é?æ°??", "branch": "defense", "cost": 7, "prerequisite": "D6", "description": "è¡€?ä???25% ?‚ï?æ¯ç??žå¾© 3 è¡€??, "effects": {"second_wind": 1}},
	"D8": {"id": "D8", "name": "? å›º", "branch": "defense", "cost": 8, "prerequisite": "D7", "description": "ç«™ç?ä¸å??‚ï??²ç¦¦ +30%", "effects": {"fortify": 1}},
	"D9": {"id": "D9", "name": "?·å®³?å?", "branch": "defense", "cost": 9, "prerequisite": "D8", "description": "?å? 10% ?—åˆ°?„å‚·å®?, "effects": {"damage_reflect": 0.1}},
	"D10": {"id": "D10", "name": "ä¸å??å?", "branch": "defense", "cost": 12, "prerequisite": "D9", "description": "è§???€?½ï?ä¸å??å?ï¼ˆæŠµ?‹ä?æ¬¡è‡´æ­»å‚·å®³ï?", "effects": {"undying_will": 1, "skill_undying_will": 1}, "is_milestone": true, "skill_unlock": "Undying Will"},
	"D11": {"id": "D11", "name": "?¼éµ?¡å?", "branch": "defense", "cost": 10, "prerequisite": "D10", "description": "?€å¤§è???+30", "effects": {"max_hp": 30}},
	"D12": {"id": "D12", "name": "?Šæ?", "branch": "defense", "cost": 11, "prerequisite": "D11", "description": "?»æ??…å???5 é»žå‚·å®?, "effects": {"thorns_damage": 5}},
	"D13": {"id": "D13", "name": "?Ÿå‘½è­·ç›¾", "branch": "defense", "cost": 12, "prerequisite": "D12", "description": "æ¯?30 ç§’ç²å¾—ä???20 é»žå‚·å®³ç?è­·ç›¾", "effects": {"life_shield": 1}},
	"D14": {"id": "D14", "name": "?Œæ€?, "branch": "defense", "cost": 13, "prerequisite": "D13", "description": "?§åˆ¶?ˆæ??ç??‚é? -50%", "effects": {"status_resist": 0.5}},
	"D15": {"id": "D15", "name": "?¡æ•µ", "branch": "defense", "cost": 15, "prerequisite": "D14", "description": "è§???€?½ï??¡æ•µï¼?ç§’ç„¡?µæ??“ï?", "effects": {"skill_invincible": 1}, "is_milestone": true, "skill_unlock": "Invincible"},

	"S1": {"id": "S1", "name": "?¾æ­¥", "branch": "support", "cost": 2, "prerequisite": "", "description": "ç§»é€?+8%", "effects": {"speed_multiplier": 0.08}},
	"S2": {"id": "S2", "name": "?¡é???, "branch": "support", "cost": 3, "prerequisite": "S1", "description": "?¡é? +1", "effects": {"gather_bonus": 1}},
	"S3": {"id": "S3", "name": "å¹¸é??¼ç¾", "branch": "support", "cost": 4, "prerequisite": "S2", "description": "?‰è½??+10%", "effects": {"loot_bonus": 0.10}},
	"S4": {"id": "S4", "name": "é«˜æ?è£½ä?", "branch": "support", "cost": 5, "prerequisite": "S3", "description": "è£½ä??æœ¬ -15%", "effects": {"craft_cost_multiplier": -0.15}},
	"S5": {"id": "S5", "name": "å°‹å¯¶??, "branch": "support", "cost": 8, "prerequisite": "S4", "description": "é¡¯ç¤ºå¯¶ç®±ä½ç½®", "effects": {"skill_treasure_hunter": 1}, "is_milestone": true, "skill_unlock": "Treasure Hunter"},
	"S6": {"id": "S6", "name": "ç£çŸ³", "branch": "support", "cost": 6, "prerequisite": "S5", "description": "?¾å?ç¯„å? +50", "effects": {"loot_pickup_range": 50.0}},
	"S7": {"id": "S7", "name": "è¼•ç?ä¹‹é´", "branch": "support", "cost": 7, "prerequisite": "S6", "description": "ç§»å??Ÿåº¦ +15%", "effects": {"speed_multiplier": 0.15}},
	"S8": {"id": "S8", "name": "è¨Žåƒ¹?„åƒ¹", "branch": "support", "cost": 8, "prerequisite": "S7", "description": "?†å??¹æ ¼ -20%", "effects": {"merchant_discount": 0.2}},
	"S9": {"id": "S9", "name": "?¢éšªå®?, "branch": "support", "cost": 9, "prerequisite": "S8", "description": "?¨åœ°?–è¿·?§è§£??, "effects": {"full_minimap": 1}},
	"S10": {"id": "S10", "name": "è¡åˆº", "branch": "support", "cost": 12, "prerequisite": "S9", "description": "è§???€?½ï?è¡åˆºï¼?ç§’å…§ +100% ?Ÿåº¦ï¼?, "effects": {"skill_sprint": 1}, "is_milestone": true, "skill_unlock": "Sprint"},
	"S11": {"id": "S11", "name": "è³‡æ?å°ˆå®¶", "branch": "support", "cost": 10, "prerequisite": "S10", "description": "?¡é??Ÿåº¦ +30%", "effects": {"gather_speed": 0.3}},
	"S12": {"id": "S12", "name": "å¹¸é?ä¸€??, "branch": "support", "cost": 11, "prerequisite": "S11", "description": "5% æ©Ÿç??²å??™å€æ???, "effects": {"double_loot_chance": 0.05}},
	"S13": {"id": "S13", "name": "?Ÿå??¬èƒ½", "branch": "support", "cost": 12, "prerequisite": "S12", "description": "ä½Žè??æ?ï¼Œç§»?•é€Ÿåº¦ +25%", "effects": {"low_hp_speed_bonus": 0.25}},
	"S14": {"id": "S14", "name": "ä¸€ç·šç?æ©?, "branch": "support", "cost": 13, "prerequisite": "S13", "description": "æ­»äº¡?‚æ? 30% æ©Ÿç?ä¿ç?ä¸€?Šæ??½ç‰©", "effects": {"second_chance_loot": 0.3}},
	"S15": {"id": "S15", "name": "?‚é??­æ›²", "branch": "support", "cost": 15, "prerequisite": "S14", "description": "è§???€?½ï??‚é??­æ›²ï¼ˆå?çµå‘¨?æ•µäººï?", "effects": {"skill_time_warp": 1}, "is_milestone": true, "skill_unlock": "Time Warp"},
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


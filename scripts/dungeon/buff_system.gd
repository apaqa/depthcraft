extends RefCounted
class_name BuffSystem

const BUFF_POOL := {
	"atk_up_1": {
		"id": "atk_up_1",
		"name": "?»æ?å¼·å? I",
		"description": "?»æ???+15%",
		"category": "?»æ?",
		"color": Color(0.92, 0.35, 0.35, 1.0),
	},
	"atk_up_2": {
		"id": "atk_up_2",
		"name": "?»æ?å¼·å? II",
		"description": "?»æ???+25%ï¼Œé€Ÿåº¦ -10%",
		"category": "?»æ?",
		"color": Color(0.86, 0.3, 0.24, 1.0),
	},
	"crit_chance": {
		"id": "crit_chance",
		"name": "?´æ?å¼·å?",
		"description": "15%æ©Ÿç?? æ??™å€å‚·å®?,
		"category": "?»æ?",
		"color": Color(1.0, 0.82, 0.32, 1.0),
	},
	"atk_speed": {
		"id": "atk_speed",
		"name": "?»é€Ÿå¼·??,
		"description": "?»æ??·å» -30%",
		"category": "?»æ?",
		"color": Color(0.95, 0.7, 0.3, 1.0),
	},
	"lifesteal": {
		"id": "lifesteal",
		"name": "?¸è??ˆæ?",
		"description": "? æ??·å®³??0%è½‰å??ºæ²»??,
		"category": "?»æ?",
		"color": Color(0.76, 0.24, 0.36, 1.0),
	},
	"hp_up": {
		"id": "hp_up",
		"name": "?Ÿå‘½å¼·å?",
		"description": "?€å¤§è???+30",
		"category": "?²ç¦¦",
		"color": Color(0.3, 0.85, 0.4, 1.0),
	},
	"armor": {
		"id": "armor",
		"name": "?²ç¦¦å¼·å?",
		"description": "?—åˆ°?·å®³ -20%",
		"category": "?²ç¦¦",
		"color": Color(0.45, 0.65, 0.95, 1.0),
	},
	"dodge_chance": {
		"id": "dodge_chance",
		"name": "?ƒé¿å¼·å?",
		"description": "15%æ©Ÿç??ƒé¿",
		"category": "?²ç¦¦",
		"color": Color(0.4, 0.9, 0.85, 1.0),
	},
	"regen": {
		"id": "regen",
		"name": "?Ÿå‘½?ç?",
		"description": "æ¯?ç§’å?å¾?è¡€??,
		"category": "?²ç¦¦",
		"color": Color(0.42, 0.88, 0.58, 1.0),
	},
	"speed_up": {
		"id": "speed_up",
		"name": "ç§»é€Ÿæ???,
		"description": "ç§»å??Ÿåº¦ +25%",
		"category": "è¼”åŠ©",
		"color": Color(0.38, 0.72, 1.0, 1.0),
	},
	"loot_up": {
		"id": "loot_up",
		"name": "?‰è½?å?",
		"description": "?‰è½?‡ç¿»??,
		"category": "è¼”åŠ©",
		"color": Color(0.72, 0.64, 1.0, 1.0),
	},
	"aoe_attack": {
		"id": "aoe_attack",
		"name": "ç¯„å?å¼·å?",
		"description": "?»æ?ç¯„å??´å¤§",
		"category": "?»æ?",
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


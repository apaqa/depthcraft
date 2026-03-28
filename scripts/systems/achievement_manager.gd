extends Node

signal achievement_unlocked(id: String)

const SAVE_PATH: String = "user://achievements.json"

var achievements: Dictionary = {}
var unlocked_achievements: Dictionary = {}
var stats: Dictionary = {}


func _ready() -> void:
	_build_achievements()
	_load_data()
	_refresh_all()


func check_achievement(id: String) -> bool:
	if not achievements.has(id):
		return false
	if is_unlocked(id):
		return true
	var achievement: Dictionary = achievements[id]
	match str(achievement.get("condition_type", "")):
		"stat_at_least":
			var stat_key: String = str(achievement.get("stat", ""))
			var target: int = int(achievement.get("target", 0))
			if int(stats.get(stat_key, 0)) >= target:
				return unlock_achievement(id)
		"equipment_slots_filled":
			var slot_target: int = int(achievement.get("target", 0))
			if int(stats.get("equipped_slot_count", 0)) >= slot_target:
				return unlock_achievement(id)
	return false


func unlock_achievement(id: String) -> bool:
	if not achievements.has(id) or is_unlocked(id):
		return false
	unlocked_achievements[id] = true
	_save_data()
	AudioManager.play_sfx("achievement")
	achievement_unlocked.emit(id)
	return true


func is_unlocked(id: String) -> bool:
	return bool(unlocked_achievements.get(id, false))


func get_achievement(id: String) -> Dictionary:
	if not achievements.has(id):
		return {}
	var achievement: Dictionary = (achievements[id] as Dictionary).duplicate(true)
	achievement["id"] = id
	achievement["unlocked"] = is_unlocked(id)
	return achievement


func get_achievement_list() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for id in achievements.keys():
		list.append(get_achievement(str(id)))
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("order", 0)) < int(b.get("order", 0)))
	return list


func set_stat(stat_name: String, value: int, allow_decrease: bool = false) -> void:
	var current_value: int = int(stats.get(stat_name, 0))
	if not allow_decrease:
		value = max(value, current_value)
	stats[stat_name] = value


func increment_stat(stat_name: String, amount: int = 1) -> void:
	stats[stat_name] = int(stats.get(stat_name, 0)) + amount


func record_dungeon_entry() -> void:
	increment_stat("dungeon_entries")
	check_achievement("dungeon_first_entry")


func start_dungeon_run() -> void:
	set_stat("survival_floors_without_death", 0, true)
	record_dungeon_entry()


func record_player_died() -> void:
	set_stat("survival_floors_without_death", 0, true)


func record_enemy_kill(kind: String) -> void:
	increment_stat("enemies_killed")
	check_achievement("first_kill")
	check_achievement("kill_1000_enemies")
	match kind:
		"elite":
			increment_stat("elite_kills")
			check_achievement("first_elite_kill")
			check_achievement("kill_100_elites")
		"boss":
			increment_stat("boss_kills")
			check_achievement("first_boss_kill")
			check_achievement("kill_10_bosses")


func record_floor_reached(floor_number: int) -> void:
	if floor_number <= 0:
		return
	set_stat("deepest_floor_reached", floor_number)
	set_stat("survival_floors_without_death", floor_number)
	check_achievement("reach_floor_10")
	check_achievement("reach_floor_20")
	check_achievement("reach_floor_30")
	check_achievement("survive_10_floors")
	check_achievement("survive_30_floors")


func record_equipment_state(inventory, equipment_system) -> void:
	var total_equipment_owned: int = 0
	if inventory != null and inventory.get("items") != null:
		for stack in inventory.items:
			if str((stack as Dictionary).get("type", "")) == "equipment":
				total_equipment_owned += int((stack as Dictionary).get("quantity", 0))
	var equipped_slot_count: int = 0
	if equipment_system != null and equipment_system.has_method("get_slot_order"):
		for slot_name in equipment_system.get_slot_order():
			var equipped: Dictionary = equipment_system.get_equipped(str(slot_name))
			if not equipped.is_empty():
				equipped_slot_count += 1
				total_equipment_owned += 1
	set_stat("equipment_owned", total_equipment_owned)
	set_stat("equipped_slot_count", equipped_slot_count)
	check_achievement("collect_5_equipment")
	check_achievement("collect_10_equipment")
	check_achievement("collect_20_equipment")
	check_achievement("full_equipment_loadout")


func record_currency_gain(item_id: String, amount: int) -> void:
	if amount <= 0:
		return
	var copper_value: int = 0
	match item_id:
		"wooden_coin":
			copper_value = int(amount / 10)
		"copper":
			copper_value = amount
		"silver":
			copper_value = amount * 10
		"gold":
			copper_value = amount * 1000
		_:
			return
	if copper_value <= 0:
		return
	increment_stat("copper_earned_total", copper_value)
	check_achievement("earn_1000_copper")
	check_achievement("earn_10000_copper")


func record_victory(current_cycle: int) -> void:
	increment_stat("total_victories")
	set_stat("current_cycle", current_cycle)
	check_achievement("first_victory")
	check_achievement("victory_3")
	check_achievement("victory_10")
	check_achievement("cycle_2")


func record_forge() -> void:
	increment_stat("forge_count")
	check_achievement("forge_10")


func record_building_placed() -> void:
	increment_stat("buildings_built")
	check_achievement("build_10")
	check_achievement("build_50")


func record_recipe_crafted(recipe: Dictionary) -> void:
	if recipe.is_empty():
		return
	increment_stat("recipes_crafted")
	if str(recipe.get("station", "")) == "cooking" or str(recipe.get("category", "")) == "Cooking":
		increment_stat("cooking_count")
		check_achievement("cook_10")
		check_achievement("cook_50")


func record_talent_unlocked(current_total: int) -> void:
	set_stat("talents_unlocked", current_total)
	check_achievement("talent_10")
	check_achievement("talent_25")
	check_achievement("talent_45")


func _refresh_all() -> void:
	for id in achievements.keys():
		check_achievement(str(id))


func _load_data() -> void:
	unlocked_achievements.clear()
	stats.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var payload: Dictionary = parsed
	var unlocked_payload: Dictionary = payload.get("unlocked", {})
	for id in unlocked_payload.keys():
		unlocked_achievements[str(id)] = bool(unlocked_payload[id])
	var stats_payload: Dictionary = payload.get("stats", {})
	for stat_name in stats_payload.keys():
		stats[str(stat_name)] = int(stats_payload[stat_name])


func _save_data() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"unlocked": unlocked_achievements,
		"stats": stats,
	}, "\t"))


func _build_achievements() -> void:
	achievements = {
		"dungeon_first_entry": {"order": 1, "name": "\u521d\u51fa\u8305\u5e90", "description": "\u7b2c\u4e00\u6b21\u8fdb\u5165\u5730\u7262\u3002", "reward": "\u5956\u52b1\uff1a\u5192\u9669\u8005\u540d\u671b +10", "condition_type": "stat_at_least", "stat": "dungeon_entries", "target": 1},
		"first_kill": {"order": 2, "name": "\u5c0f\u8bd5\u725b\u5200", "description": "\u51fb\u6740\u7b2c\u4e00\u4e2a\u654c\u4eba\u3002", "reward": "\u5956\u52b1\uff1a\u6218\u6597\u540d\u671b +10", "condition_type": "stat_at_least", "stat": "enemies_killed", "target": 1},
		"first_elite_kill": {"order": 3, "name": "\u7cbe\u82f1\u730e\u624b", "description": "\u51fb\u6740\u7b2c\u4e00\u4e2a\u7cbe\u82f1\u602a\u3002", "reward": "\u5956\u52b1\uff1a\u7cbe\u82f1\u5956\u7ae0", "condition_type": "stat_at_least", "stat": "elite_kills", "target": 1},
		"first_boss_kill": {"order": 4, "name": "\u5f11\u738b\u8005", "description": "\u51fb\u6740\u7b2c\u4e00\u4e2a Boss\u3002", "reward": "\u5956\u52b1\uff1a\u738b\u8005\u5fbd\u5370", "condition_type": "stat_at_least", "stat": "boss_kills", "target": 1},
		"reach_floor_10": {"order": 5, "name": "\u6df1\u5165\u5341\u5c42", "description": "\u5230\u8fbe\u5730\u7262\u7b2c 10 \u5c42\u3002", "reward": "\u5956\u52b1\uff1a\u6df1\u6f5c\u8005\u540d\u671b +20", "condition_type": "stat_at_least", "stat": "deepest_floor_reached", "target": 10},
		"reach_floor_20": {"order": 6, "name": "\u6df1\u5165\u4e8c\u5341\u5c42", "description": "\u5230\u8fbe\u5730\u7262\u7b2c 20 \u5c42\u3002", "reward": "\u5956\u52b1\uff1a\u6df1\u6f5c\u8005\u540d\u671b +40", "condition_type": "stat_at_least", "stat": "deepest_floor_reached", "target": 20},
		"reach_floor_30": {"order": 7, "name": "\u6df1\u5165\u4e09\u5341\u5c42", "description": "\u5230\u8fbe\u5730\u7262\u7b2c 30 \u5c42\u3002", "reward": "\u5956\u52b1\uff1a\u6df1\u6e0a\u8fdc\u5f81\u8bc1", "condition_type": "stat_at_least", "stat": "deepest_floor_reached", "target": 30},
		"collect_5_equipment": {"order": 8, "name": "\u6536\u85cf\u65b0\u624b", "description": "\u62e5\u6709 5 \u4ef6\u88c5\u5907\u3002", "reward": "\u5956\u52b1\uff1a\u6536\u85cf\u8005\u540d\u671b +10", "condition_type": "stat_at_least", "stat": "equipment_owned", "target": 5},
		"collect_10_equipment": {"order": 9, "name": "\u6536\u85cf\u5bb6", "description": "\u62e5\u6709 10 \u4ef6\u88c5\u5907\u3002", "reward": "\u5956\u52b1\uff1a\u6536\u85cf\u8005\u540d\u671b +20", "condition_type": "stat_at_least", "stat": "equipment_owned", "target": 10},
		"collect_20_equipment": {"order": 10, "name": "\u88c5\u5907\u5927\u5e08", "description": "\u62e5\u6709 20 \u4ef6\u88c5\u5907\u3002", "reward": "\u5956\u52b1\uff1a\u88c5\u5907\u5927\u5e08\u5fbd\u7ae0", "condition_type": "stat_at_least", "stat": "equipment_owned", "target": 20},
		"earn_1000_copper": {"order": 11, "name": "\u5c0f\u5bcc\u7fc1", "description": "\u7d2f\u8ba1\u83b7\u5f97 1000 \u94dc\u5e01\u3002", "reward": "\u5956\u52b1\uff1a\u8d22\u5bcc\u540d\u671b +10", "condition_type": "stat_at_least", "stat": "copper_earned_total", "target": 1000},
		"earn_10000_copper": {"order": 12, "name": "\u5927\u5bcc\u7fc1", "description": "\u7d2f\u8ba1\u83b7\u5f97 10000 \u94dc\u5e01\u3002", "reward": "\u5956\u52b1\uff1a\u8d22\u5bcc\u540d\u671b +30", "condition_type": "stat_at_least", "stat": "copper_earned_total", "target": 10000},
		"build_10": {"order": 13, "name": "\u5efa\u7b51\u65b0\u624b", "description": "\u5efa\u9020 10 \u4e2a\u5efa\u7b51\u3002", "reward": "\u5956\u52b1\uff1a\u5de5\u5320\u540d\u671b +10", "condition_type": "stat_at_least", "stat": "buildings_built", "target": 10},
		"build_50": {"order": 14, "name": "\u5efa\u7b51\u5927\u5e08", "description": "\u5efa\u9020 50 \u4e2a\u5efa\u7b51\u3002", "reward": "\u5956\u52b1\uff1a\u5de5\u5320\u51a0\u5195", "condition_type": "stat_at_least", "stat": "buildings_built", "target": 50},
		"cook_10": {"order": 15, "name": "\u7f8e\u98df\u5bb6", "description": "\u70f9\u996a 10 \u6b21\u3002", "reward": "\u5956\u52b1\uff1a\u6599\u7406\u8fbe\u4eba\u79f0\u53f7", "condition_type": "stat_at_least", "stat": "cooking_count", "target": 10},
		"talent_10": {"order": 16, "name": "\u5929\u8d4b\u521d\u63a2", "description": "\u89e3\u9501 10 \u4e2a\u5929\u8d4b\u3002", "reward": "\u5956\u52b1\uff1a\u5929\u8d4b\u540d\u671b +10", "condition_type": "stat_at_least", "stat": "talents_unlocked", "target": 10},
		"talent_25": {"order": 17, "name": "\u5929\u8d4b\u4e13\u7cbe", "description": "\u89e3\u9501 25 \u4e2a\u5929\u8d4b\u3002", "reward": "\u5956\u52b1\uff1a\u5929\u8d4b\u540d\u671b +20", "condition_type": "stat_at_least", "stat": "talents_unlocked", "target": 25},
		"talent_45": {"order": 18, "name": "\u5929\u8d4b\u5927\u5e08", "description": "\u89e3\u9501 45 \u4e2a\u5929\u8d4b\u3002", "reward": "\u5956\u52b1\uff1a\u5929\u8d4b\u5927\u5e08\u5fbd\u5370", "condition_type": "stat_at_least", "stat": "talents_unlocked", "target": 45},
		"survive_10_floors": {"order": 19, "name": "\u751f\u5b58\u4e13\u5bb6", "description": "\u8fde\u7eed\u901a\u8fc7 10 \u5c42\u4e0d\u6b7b\u4ea1\u3002", "reward": "\u5956\u52b1\uff1a\u751f\u5b58\u4e13\u5bb6\u79f0\u53f7", "condition_type": "stat_at_least", "stat": "survival_floors_without_death", "target": 10},
		"full_equipment_loadout": {"order": 20, "name": "\u5168\u88c5\u6ee1\u914d", "description": "7 \u4e2a\u88c5\u5907\u680f\u5168\u90e8\u88c5\u5907\u3002", "reward": "\u5956\u52b1\uff1a\u6ee1\u914d\u6218\u58eb\u5fbd\u7ae0", "condition_type": "equipment_slots_filled", "target": 7},
		# ─── 30-floor clear & cycle achievements ──────────────────────────────
		"first_victory": {"order": 21, "name": "初次通關", "description": "完成第一次 30 層通關。", "reward": "解鎖輪迴系統", "condition_type": "stat_at_least", "stat": "total_victories", "target": 1},
		"victory_3": {"order": 22, "name": "三度傳說", "description": "完成 3 次 30 層通關。", "reward": "解鎖輪迴稱號", "condition_type": "stat_at_least", "stat": "total_victories", "target": 3},
		"victory_10": {"order": 23, "name": "永恆征服者", "description": "完成 10 次 30 層通關。", "reward": "永恆戰士稱號", "condition_type": "stat_at_least", "stat": "total_victories", "target": 10},
		"cycle_2": {"order": 24, "name": "第二輪迴", "description": "進入輪迴 2。", "reward": "前綴怪物系統解鎖", "condition_type": "stat_at_least", "stat": "current_cycle", "target": 2},
		"kill_100_elites": {"order": 25, "name": "精英終結者", "description": "累計擊殺 100 個精英怪。", "reward": "精英獵手稱號", "condition_type": "stat_at_least", "stat": "elite_kills", "target": 100},
		"kill_10_bosses": {"order": 26, "name": "弑王者", "description": "累計擊殺 10 個 Boss。", "reward": "王者殺手稱號", "condition_type": "stat_at_least", "stat": "boss_kills", "target": 10},
		"kill_1000_enemies": {"order": 27, "name": "戰場屠夫", "description": "累計擊殺 1000 個敵人。", "reward": "血染者稱號", "condition_type": "stat_at_least", "stat": "enemies_killed", "target": 1000},
		"survive_30_floors": {"order": 28, "name": "不死傳說", "description": "不死亡通關 30 層。", "reward": "不死稱號 + 特殊祝福", "condition_type": "stat_at_least", "stat": "survival_floors_without_death", "target": 30},
		"forge_10": {"order": 29, "name": "鍛造狂人", "description": "成功鍛造 10 次裝備。", "reward": "鍛造大師稱號", "condition_type": "stat_at_least", "stat": "forge_count", "target": 10},
		"cook_50": {"order": 30, "name": "料理傳說", "description": "烹飪 50 次。", "reward": "美食達人稱號", "condition_type": "stat_at_least", "stat": "cooking_count", "target": 50},
	}

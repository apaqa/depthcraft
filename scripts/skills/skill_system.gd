extends Node

const SKILL_DEFS := {
	"whirlwind": {"id": "whirlwind", "name": "旋風斬", "short_name": "旋風", "cooldown": 5.0, "passive": false, "effect_method": "_cast_whirlwind", "desc": "對周圍敵人造成 80% 物理傷害並擊退", "allowed_classes": ["warrior", "ranger"]},
	"execute": {"id": "execute", "name": "斬殺", "short_name": "斬殺", "cooldown": 10.0, "passive": false, "effect_method": "_cast_execute", "desc": "下次攻擊對低血量敵人造成額外傷害", "allowed_classes": ["warrior"]},
	"war_cry": {"id": "war_cry", "name": "戰吼", "short_name": "戰吼", "cooldown": 12.0, "passive": false, "effect_method": "_cast_war_cry", "desc": "使周圍敵人減速 50%，持續 3 秒", "allowed_classes": ["warrior"]},
	"undying_will": {"id": "undying_will", "name": "不屈意志", "short_name": "不屈", "cooldown": 0.0, "passive": true, "effect_method": "_passive_undying", "desc": "（被動）瀕死觸發護盾", "allowed_classes": ["warrior", "ranger"]},
	"treasure_hunter": {"id": "treasure_hunter", "name": "尋寶術", "short_name": "尋寶", "cooldown": 30.0, "passive": false, "effect_method": "_cast_treasure_hunter", "desc": "在地圖上標記附近寶物，持續 10 秒", "allowed_classes": []},
	"sprint": {"id": "sprint", "name": "衝刺", "short_name": "衝刺", "cooldown": 15.0, "passive": false, "effect_method": "_cast_sprint", "desc": "大幅提升移動速度，持續 3 秒", "allowed_classes": []},
	"blade_storm": {"id": "blade_storm", "name": "刃風", "short_name": "刃風", "cooldown": 20.0, "passive": false, "effect_method": "_coming_soon", "desc": "（即將推出）快速旋轉攻擊敵人", "allowed_classes": ["warrior", "ranger"]},
	"invincible": {"id": "invincible", "name": "無敵", "short_name": "無敵", "cooldown": 60.0, "passive": false, "effect_method": "_coming_soon", "desc": "（即將推出）暫時進入無敵狀態", "allowed_classes": ["warrior", "ranger"]},
	"time_warp": {"id": "time_warp", "name": "時間扭曲", "short_name": "時扭", "cooldown": 30.0, "passive": false, "effect_method": "_coming_soon", "desc": "（即將推出）讓時間短暫停滯", "allowed_classes": []},
}
const TALENT_TO_SKILL := {
	"O5": "whirlwind",
	"O18": "execute",
	"O26": "blade_storm",
	"D5": "war_cry",
	"D18": "undying_will",
	"D26": "invincible",
	"S5": "treasure_hunter",
	"S18": "sprint",
	"S26": "time_warp",
}
const SKILL_VFX_SCENE := preload("res://scripts/skills/skill_vfx.gd")

signal skills_changed

var player = null
var current_level = null
var current_level_id: String = ""
var unlocked_skill_ids: Array[String] = []
var equipped_skill_ids: Array[String] = ["", "", ""]
var skills := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rebuild_skill_runtime()


func _process(delta: float) -> void:
	for skill_id in skills.keys():
		var skill: Dictionary = skills[skill_id]
		var current_cd: float = maxf(float(skill.get("current_cooldown", 0.0)) - delta, 0.0)
		skill["current_cooldown"] = current_cd
		skills[skill_id] = skill


func bind_player(target_player) -> void:
	player = target_player
	sync_from_player_talents()


func bind_level(level, level_id: String) -> void:
	current_level = level
	current_level_id = level_id


func sync_from_player_talents() -> void:
	if player == null:
		return
	_rebuild_skill_runtime()
	unlocked_skill_ids.clear()
	for talent_id in player.get_unlocked_talents():
		var skill_id := str(TALENT_TO_SKILL.get(talent_id, ""))
		if skill_id == "":
			continue
		unlock_skill(skill_id, false)
	skills_changed.emit()


func _is_allowed_for_current_class(skill_id: String) -> bool:
	var allowed: Array = (SKILL_DEFS.get(skill_id, {}) as Dictionary).get("allowed_classes", [])
	if allowed.is_empty():
		return true
	var class_system = get_node_or_null("/root/ClassSystem")
	if class_system == null:
		return true
	var current_class: String = str(class_system.current_class_id)
	return allowed.has(current_class)


func unlock_skill(skill_id: String, auto_equip: bool = true) -> void:
	if skill_id == "" or not SKILL_DEFS.has(skill_id):
		return
	if not _is_allowed_for_current_class(skill_id):
		return
	if not unlocked_skill_ids.has(skill_id):
		unlocked_skill_ids.append(skill_id)
	if auto_equip and not _is_passive(skill_id):
		_equip_first_free_slot(skill_id)
	skills_changed.emit()


func unlock_skill_from_talent(talent_id: String) -> void:
	unlock_skill(str(TALENT_TO_SKILL.get(talent_id, "")))


func clear_dungeon_cooldowns() -> void:
	for skill_id in skills.keys():
		var skill: Dictionary = skills[skill_id]
		skill["current_cooldown"] = 0.0
		skills[skill_id] = skill
	skills_changed.emit()


func use_skill_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= equipped_skill_ids.size():
		return false
	var skill_id := equipped_skill_ids[slot_index]
	if skill_id == "" or not skills.has(skill_id):
		if player != null:
			player.show_status_message(LocaleManager.L("skill_slot_empty"), Color(0.7, 0.7, 0.7, 1.0))
		return false
	var skill: Dictionary = skills[skill_id]
	if float(skill.get("current_cooldown", 0.0)) > 0.0:
		return false
	var effect_method := str(skill.get("effect_method", ""))
	if effect_method == "" or not has_method(effect_method):
		return false
	var did_cast: bool = call(effect_method, skill_id)
	if did_cast and float(skill.get("cooldown", 0.0)) > 0.0:
		var class_system = get_node_or_null("/root/ClassSystem")
		var cd_mult: float = class_system.get_cd_multiplier() if class_system != null else 1.0
		skill["current_cooldown"] = float(skill.get("cooldown", 0.0)) * cd_mult
		skills[skill_id] = skill
		skills_changed.emit()
	return did_cast


func get_equipped_skill_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for skill_id in equipped_skill_ids:
		if skill_id == "" or not skills.has(skill_id):
			result.append({})
			continue
		result.append((skills[skill_id] as Dictionary).duplicate(true))
	return result


func set_equipped_skill_ids(skill_ids: Array) -> void:
	for index in range(equipped_skill_ids.size()):
		equipped_skill_ids[index] = str(skill_ids[index]) if index < skill_ids.size() else ""
	skills_changed.emit()


func _cast_whirlwind(_skill_id: String) -> bool:
	if player == null:
		return false
	var center: Vector2 = player.global_position
	var total_damage := int(round(player.get_attack_damage() * 0.8))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if center.distance_to(enemy.global_position) > 40.0:
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(total_damage, (enemy.global_position - center).normalized())
			if enemy.has_method("apply_knockback"):
				enemy.apply_knockback((enemy.global_position - center).normalized(), 90.0)
	_spawn_vfx("whirlwind", center)
	return true


func _cast_execute(_skill_id: String) -> bool:
	if player == null:
		return false
	if player.has_method("arm_execute_skill"):
		player.arm_execute_skill()
		player.show_status_message(LocaleManager.L("skill_execute_armed"), Color(1.0, 0.6, 0.35, 1.0))
	return true


func _cast_war_cry(_skill_id: String) -> bool:
	if player == null:
		return false
	var center: Vector2 = player.global_position
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if center.distance_to(enemy.global_position) > 60.0:
			continue
		if enemy.has_method("apply_slow"):
			enemy.apply_slow(0.5, 3.0)
	_spawn_vfx("war_cry", center)
	return true


func _cast_treasure_hunter(_skill_id: String) -> bool:
	if current_level != null and current_level.has_method("reveal_treasure_hunter"):
		current_level.reveal_treasure_hunter(10.0)
		if player != null:
			player.show_status_message(LocaleManager.L("skill_treasure_hunter_active"), Color(1.0, 0.9, 0.4, 1.0))
		return true
	return false


func _cast_sprint(_skill_id: String) -> bool:
	if player != null and player.has_method("activate_sprint_skill"):
		player.activate_sprint_skill(3.0, 2.0)
		return true
	return false


func _coming_soon(skill_id: String) -> bool:
	if player != null:
		var skill_name := LocaleManager.L(str((skills.get(skill_id, {}) as Dictionary).get("name", "skill_name_fallback")))
		player.show_status_message(LocaleManager.L("skill_coming_soon") % skill_name, Color(0.9, 0.9, 0.9, 1.0))
	return true


func _passive_undying(_skill_id: String) -> bool:
	return false


func _rebuild_skill_runtime() -> void:
	skills.clear()
	for skill_id in SKILL_DEFS.keys():
		var runtime := (SKILL_DEFS[skill_id] as Dictionary).duplicate(true)
		runtime["name"] = "skill_%s_name" % skill_id
		runtime["short_name"] = "skill_%s_short" % skill_id
		runtime["desc"] = "skill_%s_desc" % skill_id
		runtime["current_cooldown"] = 0.0
		runtime["effect_func"] = Callable(self, str(runtime.get("effect_method", "")))
		skills[skill_id] = runtime


func equip_to_slot(skill_id: String, slot_index: int) -> void:
	if slot_index < 0 or slot_index >= equipped_skill_ids.size():
		return
	if skill_id == "" or not unlocked_skill_ids.has(skill_id):
		return
	if _is_passive(skill_id):
		return
	# Clear the skill from any other slot it currently occupies
	for index in range(equipped_skill_ids.size()):
		if equipped_skill_ids[index] == skill_id and index != slot_index:
			equipped_skill_ids[index] = ""
	equipped_skill_ids[slot_index] = skill_id
	skills_changed.emit()


func unequip_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= equipped_skill_ids.size():
		return
	equipped_skill_ids[slot_index] = ""
	skills_changed.emit()


func _equip_first_free_slot(skill_id: String) -> void:
	if equipped_skill_ids.has(skill_id):
		return
	for index in range(equipped_skill_ids.size()):
		if equipped_skill_ids[index] == "":
			equipped_skill_ids[index] = skill_id
			return


func _is_passive(skill_id: String) -> bool:
	return bool((SKILL_DEFS.get(skill_id, {}) as Dictionary).get("passive", false))


func _spawn_vfx(mode: String, world_position: Vector2) -> void:
	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root
	var vfx := Node2D.new()
	vfx.set_script(SKILL_VFX_SCENE)
	vfx.mode = mode
	vfx.global_position = world_position
	root.add_child(vfx)

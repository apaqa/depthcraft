extends Node

const SKILL_DEFS := {
	"whirlwind": {"id": "whirlwind", "name": "?‹é¢¨??, "short_name": "?‹é¢¨", "cooldown": 5.0, "passive": false, "effect_method": "_cast_whirlwind", "desc": "å°å‘¨?æ•µäººé€ æ? 80% ?»æ??·å®³ä¸¦æ??€"},
	"execute": {"id": "execute", "name": "?¬æ®º", "short_name": "?¬æ®º", "cooldown": 10.0, "passive": false, "effect_method": "_cast_execute", "desc": "ä¸‹æ¬¡?»æ?å°ä?è¡€?æ•µäººé€ æ?é¡å??·å®³"},
	"war_cry": {"id": "war_cry", "name": "?°å¼", "short_name": "?°å¼", "cooldown": 12.0, "passive": false, "effect_method": "_cast_war_cry", "desc": "ä½¿é?è¿‘æ•µäººæ???50%ï¼Œæ?çº?3 ç§?},
	"undying_will": {"id": "undying_will", "name": "ä¸å??å?", "short_name": "ä¸å?", "cooldown": 0.0, "passive": true, "effect_method": "_passive_undying", "desc": "ï¼ˆè¢«?•ï??•æ­»?‚è§¸?¼ä?è­·æ???},
	"treasure_hunter": {"id": "treasure_hunter", "name": "å°‹å¯¶è¡?, "short_name": "å°‹å¯¶", "cooldown": 30.0, "passive": false, "effect_method": "_cast_treasure_hunter", "desc": "?¨åœ°?–ä?æ¨™è??„è?å¯¶ç‰©ï¼Œæ?çº?10 ç§?},
	"sprint": {"id": "sprint", "name": "?¾è?", "short_name": "?¾è?", "cooldown": 15.0, "passive": false, "effect_method": "_cast_sprint", "desc": "å¤§å??å?ç§»å??Ÿåº¦ï¼Œæ?çº?3 ç§?},
	"blade_storm": {"id": "blade_storm", "name": "?ƒé¢¨", "short_name": "?ƒé¢¨", "cooldown": 20.0, "passive": false, "effect_method": "_coming_soon", "desc": "ï¼ˆå³å°‡æŽ¨?ºï??¬å??‹è??€?ƒæ”»?Šæ•µäº?},
	"invincible": {"id": "invincible", "name": "?¡æ•µ", "short_name": "?¡æ•µ", "cooldown": 60.0, "passive": false, "effect_method": "_coming_soon", "desc": "ï¼ˆå³å°‡æŽ¨?ºï??­æš«?²å…¥?¡æ•µ?€??},
	"time_warp": {"id": "time_warp", "name": "?‚é??­æ›²", "short_name": "?‚æ‰­", "cooldown": 30.0, "passive": false, "effect_method": "_coming_soon", "desc": "ï¼ˆå³å°‡æŽ¨?ºï?è®“æ??“çŸ­?«å?æ­?},
}
const TALENT_TO_SKILL := {
	"O5": "whirlwind",
	"O10": "execute",
	"O15": "blade_storm",
	"D5": "war_cry",
	"D10": "undying_will",
	"D15": "invincible",
	"S5": "treasure_hunter",
	"S10": "sprint",
	"S15": "time_warp",
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
		var current_cd := maxf(float(skill.get("current_cooldown", 0.0)) - delta, 0.0)
		skill["current_cooldown"] = current_cd
		skills[skill_id] = skill
	skills_changed.emit()


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


func unlock_skill(skill_id: String, auto_equip: bool = true) -> void:
	if skill_id == "" or not SKILL_DEFS.has(skill_id):
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
			player.show_status_message("Skill slot empty", Color(0.7, 0.7, 0.7, 1.0))
		return false
	var skill: Dictionary = skills[skill_id]
	if float(skill.get("current_cooldown", 0.0)) > 0.0:
		return false
	var effect_method := str(skill.get("effect_method", ""))
	if effect_method == "" or not has_method(effect_method):
		return false
	var did_cast: bool = call(effect_method, skill_id)
	if did_cast and float(skill.get("cooldown", 0.0)) > 0.0:
		skill["current_cooldown"] = float(skill.get("cooldown", 0.0))
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
		player.show_status_message("Execute armed", Color(1.0, 0.6, 0.35, 1.0))
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
			player.show_status_message("Treasure Hunter active", Color(1.0, 0.9, 0.4, 1.0))
		return true
	return false


func _cast_sprint(_skill_id: String) -> bool:
	if player != null and player.has_method("activate_sprint_skill"):
		player.activate_sprint_skill(3.0, 2.0)
		return true
	return false


func _coming_soon(skill_id: String) -> bool:
	if player != null:
		var skill_name := str((skills.get(skill_id, {}) as Dictionary).get("name", "Skill"))
		player.show_status_message("%s Coming Soon" % skill_name, Color(0.9, 0.9, 0.9, 1.0))
	return true


func _passive_undying(_skill_id: String) -> bool:
	return false


func _rebuild_skill_runtime() -> void:
	skills.clear()
	for skill_id in SKILL_DEFS.keys():
		var runtime := (SKILL_DEFS[skill_id] as Dictionary).duplicate(true)
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


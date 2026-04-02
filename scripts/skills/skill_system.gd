extends Node

# ─── Balance Audit (Part 6.3) ──────────────────────────────────────────────────
# Skill DPS contributions (damage per cooldown cycle, expressed as x atk/s):
# warrior_z: 0.5x atk / 5s  = 0.10x atk/s
# warrior_x: 0 direct DPS (slow utility: 50% slow for 3s / 8s)
# warrior_v: 2.0x atk / 12s = 0.17x atk/s
# ranger_z:  0 direct DPS (dash+invuln defensive skill)
# ranger_x:  0.3x atk × 6 ticks / 10s = 0.18x atk/s
# ranger_v:  1.5x atk / 15s = 0.10x atk/s  (+ slow utility)
# mage_z:    0 direct DPS (teleport mobility skill)
# mage_x:    1.2x atk / 8s  = 0.15x atk/s  (+ freeze utility)
# mage_v:    3.0x atk / 15s = 0.20x atk/s
# Note: skill damage uses get_attack_damage() directly; crit multiplier is NOT
# applied to skill hits (they call enemy.take_damage() directly, not via
# _apply_single_hit). Max theoretical single hit: mage_v 3.0x base atk.
# ─────────────────────────────────────────────────────────────────────────────

# Class-based skill definitions — 3 skills per class (z/x/v slot)
const SKILL_DEFS: Dictionary = {
	# === Warrior ===
	"warrior_z": {
		"id": "warrior_z", "class": "warrior", "slot": "z",
		"name": "skill_shield_bash_name", "short_name": "skill_shield_bash_short",
		"desc": "skill_shield_bash_desc", "passive": false,
		"cooldown": 5.0, "effect_method": "_cast_shield_bash",
		"damage_mult": 0.5, "range": 60.0, "angle": 90.0, "stun_duration": 1.0,
	},
	"warrior_x": {
		"id": "warrior_x", "class": "warrior", "slot": "x",
		"name": "skill_war_cry_name", "short_name": "skill_war_cry_short",
		"desc": "skill_war_cry_desc", "passive": false,
		"cooldown": 8.0, "effect_method": "_cast_war_cry",
		"slow_range": 60.0, "slow_pct": 0.5, "slow_duration": 3.0,
	},
	"warrior_v": {
		"id": "warrior_v", "class": "warrior", "slot": "v",
		"name": "skill_leap_slam_name", "short_name": "skill_leap_slam_short",
		"desc": "skill_leap_slam_desc", "passive": false,
		"cooldown": 12.0, "effect_method": "_cast_leap_slam",
		"damage_mult": 2.0, "range": 150.0, "aoe_radius": 80.0,
	},
	# === Ranger ===
	"ranger_z": {
		"id": "ranger_z", "class": "ranger", "slot": "z",
		"name": "skill_dodge_roll_name", "short_name": "skill_dodge_roll_short",
		"desc": "skill_dodge_roll_desc", "passive": false,
		"cooldown": 4.0, "effect_method": "_cast_dodge_roll",
		"dash_distance": 100.0, "invuln_duration": 0.3,
	},
	"ranger_x": {
		"id": "ranger_x", "class": "ranger", "slot": "x",
		"name": "skill_rain_of_arrows_name", "short_name": "skill_rain_of_arrows_short",
		"desc": "skill_rain_of_arrows_desc", "passive": false,
		"cooldown": 10.0, "effect_method": "_cast_rain_of_arrows",
		"damage_per_tick": 0.3, "tick_interval": 0.5, "duration": 3.0,
		"aoe_radius": 70.0, "range": 200.0,
	},
	"ranger_v": {
		"id": "ranger_v", "class": "ranger", "slot": "v",
		"name": "skill_trap_name", "short_name": "skill_trap_short",
		"desc": "skill_trap_desc", "passive": false,
		"cooldown": 15.0, "effect_method": "_cast_trap",
		"damage_mult": 1.5, "slow_pct": 0.5, "slow_duration": 3.0, "trap_duration": 30.0,
	},
	# === Mage ===
	"mage_z": {
		"id": "mage_z", "class": "mage", "slot": "z",
		"name": "skill_blink_name", "short_name": "skill_blink_short",
		"desc": "skill_blink_desc", "passive": false,
		"cooldown": 6.0, "effect_method": "_cast_blink",
		"range": 150.0,
	},
	"mage_x": {
		"id": "mage_x", "class": "mage", "slot": "x",
		"name": "skill_frost_nova_name", "short_name": "skill_frost_nova_short",
		"desc": "skill_frost_nova_desc", "passive": false,
		"cooldown": 8.0, "effect_method": "_cast_frost_nova",
		"damage_mult": 1.2, "aoe_radius": 90.0, "freeze_duration": 2.0,
	},
	"mage_v": {
		"id": "mage_v", "class": "mage", "slot": "v",
		"name": "skill_meteor_name", "short_name": "skill_meteor_short",
		"desc": "skill_meteor_desc", "passive": false,
		"cooldown": 15.0, "effect_method": "_cast_meteor",
		"damage_mult": 3.0, "delay": 1.0, "aoe_radius": 100.0, "range": 200.0,
	},
}

# Slot-index to slot-key mapping
const SLOT_KEYS: Array[String] = ["z", "x", "v"]

signal skills_changed

var player: Variant = null
var current_level: Variant = null
var current_level_id: String = ""
var current_class: String = ""

# Slot runtime data — keyed by "z"/"x"/"v"
var skill_slots: Dictionary = {
	"z": {"skill_id": "", "cooldown": 0.0, "max_cooldown": 5.0},
	"x": {"skill_id": "", "cooldown": 0.0, "max_cooldown": 8.0},
	"v": {"skill_id": "", "cooldown": 0.0, "max_cooldown": 12.0},
}

# Legacy-compatible fields used by HUD and skill_equip_ui
var unlocked_skill_ids: Array[String] = []
var equipped_skill_ids: Array[String] = ["", "", ""]
var skills: Dictionary = {}
var _skill_bonuses: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rebuild_skills_dict()
	# Connect blessing changes so bonuses stay in sync
	var bs: Node = get_node_or_null("/root/BlessingSystem")
	if bs != null and bs.has_signal("blessings_changed"):
		bs.blessings_changed.connect(_refresh_skill_bonuses)


func _process(delta: float) -> void:
	for slot_key: String in SLOT_KEYS:
		var data: Dictionary = skill_slots[slot_key] as Dictionary
		var cd: float = float(data.get("cooldown", 0.0))
		if cd > 0.0:
			cd -= delta
			if cd <= 0.0:
				cd = 0.0
				var current_charges: int = int(data.get("current_charges", 1))
				var max_charges: int = int(data.get("max_charges", 1))
				if current_charges < max_charges:
					current_charges += 1
					data["current_charges"] = current_charges
					# If still below max, restart cooldown to charge next
					if current_charges < max_charges:
						var sid: String = str(data.get("skill_id", ""))
						if sid != "" and SKILL_DEFS.has(sid):
							cd = float((SKILL_DEFS[sid] as Dictionary).get("cooldown", 5.0))
			data["cooldown"] = cd
		skill_slots[slot_key] = data
		# Keep skills dict in sync for HUD
		var skill_id: String = str(data.get("skill_id", ""))
		if skill_id != "" and skills.has(skill_id):
			(skills[skill_id] as Dictionary)["current_cooldown"] = cd


# --- Binding ---

func bind_player(target_player: Variant) -> void:
	player = target_player
	sync_from_player_class()


func bind_level(level: Variant, level_id: String) -> void:
	current_level = level
	current_level_id = level_id


# --- Class-based equip ---

func sync_from_player_class() -> void:
	var class_system: Node = get_node_or_null("/root/ClassSystem")
	if class_system == null:
		return
	var class_id: String = str(class_system.current_class_id)
	if class_id == "":
		return
	_equip_class_skills(class_id)


func _equip_class_skills(player_class: String) -> void:
	current_class = player_class
	for i: int in range(SLOT_KEYS.size()):
		var slot_key: String = SLOT_KEYS[i]
		var skill_id: String = player_class + "_" + slot_key
		if not SKILL_DEFS.has(skill_id):
			skill_id = ""
		var cd_max: float = 5.0
		if skill_id != "":
			cd_max = float((SKILL_DEFS[skill_id] as Dictionary).get("cooldown", 5.0))
		(skill_slots[slot_key] as Dictionary)["skill_id"] = skill_id
		(skill_slots[slot_key] as Dictionary)["max_cooldown"] = cd_max
		(skill_slots[slot_key] as Dictionary)["cooldown"] = 0.0
		(skill_slots[slot_key] as Dictionary)["max_charges"] = 1
		(skill_slots[slot_key] as Dictionary)["current_charges"] = 1
		equipped_skill_ids[i] = skill_id
	_rebuild_unlocked_ids()
	_rebuild_skills_dict()
	skills_changed.emit()


func _rebuild_unlocked_ids() -> void:
	unlocked_skill_ids.clear()
	for slot_key: String in SLOT_KEYS:
		var skill_id: String = str((skill_slots[slot_key] as Dictionary).get("skill_id", ""))
		if skill_id != "":
			unlocked_skill_ids.append(skill_id)


func _rebuild_skills_dict() -> void:
	skills.clear()
	for skill_id: String in SKILL_DEFS.keys():
		var runtime: Dictionary = (SKILL_DEFS[skill_id] as Dictionary).duplicate(true)
		var slot_key: String = str(runtime.get("slot", "z"))
		var cd: float = float((skill_slots.get(slot_key, {}) as Dictionary).get("cooldown", 0.0))
		runtime["current_cooldown"] = cd
		skills[skill_id] = runtime


# Stub for talent-based unlock (kept for backward compat with talent tree)
func sync_from_player_talents() -> void:
	sync_from_player_class()


func unlock_skill_from_talent(_talent_id: String) -> void:
	pass


# --- Skill use ---

func use_skill_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= SLOT_KEYS.size():
		return false
	var slot_key: String = SLOT_KEYS[slot_index]
	return try_use_skill(slot_key)


func try_use_skill(slot_key: String) -> bool:
	if not skill_slots.has(slot_key):
		return false
	var data: Dictionary = skill_slots[slot_key] as Dictionary
	var skill_id: String = str(data.get("skill_id", ""))
	if skill_id == "":
		if player != null and player.has_method("show_status_message"):
			player.show_status_message(LocaleManager.L("skill_slot_empty"), Color(0.7, 0.7, 0.7, 1.0))
		return false
	var current_charges: int = int(data.get("current_charges", 1))
	if current_charges <= 0:
		return false
	var def: Dictionary = SKILL_DEFS.get(skill_id, {}) as Dictionary
	var effect_method: String = str(def.get("effect_method", ""))
	if effect_method == "" or not has_method(effect_method):
		return false
	var modified_def: Dictionary = def.duplicate(true)
	_apply_bonuses_to_def(modified_def)
	var did_cast: bool = call(effect_method, modified_def)
	if did_cast:
		var class_system: Node = get_node_or_null("/root/ClassSystem")
		var cd_mult: float = 1.0
		if class_system != null and class_system.has_method("get_cd_multiplier"):
			cd_mult = float(class_system.get_cd_multiplier())
		data["cooldown"] = float(modified_def.get("cooldown", 5.0)) * cd_mult
		data["current_charges"] = maxi(current_charges - 1, 0)
		skill_slots[slot_key] = data
		if skill_id != "" and skills.has(skill_id):
			(skills[skill_id] as Dictionary)["current_cooldown"] = float(data.get("cooldown", 0.0))
		_apply_post_cast_bonuses()
		skills_changed.emit()
	return did_cast


func get_skill_def(slot_key: String) -> Dictionary:
	if not skill_slots.has(slot_key):
		return {}
	var skill_id: String = str((skill_slots[slot_key] as Dictionary).get("skill_id", ""))
	if skill_id == "" or not SKILL_DEFS.has(skill_id):
		return {}
	return SKILL_DEFS[skill_id] as Dictionary


func reset_cooldowns() -> void:
	clear_dungeon_cooldowns()


func clear_dungeon_cooldowns() -> void:
	for slot_key: String in SLOT_KEYS:
		(skill_slots[slot_key] as Dictionary)["cooldown"] = 0.0
		var max_ch: int = int((skill_slots[slot_key] as Dictionary).get("max_charges", 1))
		(skill_slots[slot_key] as Dictionary)["current_charges"] = max_ch
	for skill_id: String in skills.keys():
		(skills[skill_id] as Dictionary)["current_cooldown"] = 0.0
	skills_changed.emit()


# --- Skill blessing bonuses ---

func get_skill_blessing_bonuses() -> Dictionary:
	var bs: Node = get_node_or_null("/root/BlessingSystem")
	if bs == null:
		return {}
	var bonuses: Dictionary = {}
	for slot_name: String in ["primary", "secondary", "skill"]:
		if str(bs.get_slot_theme(slot_name)) != "skill_boost":
			continue
		for entry: Dictionary in bs.get_slot_sub_blessings(slot_name):
			var eff: float = float(entry.get("effectiveness", 1.0))
			var bid: String = str(entry.get("id", ""))
			if not BlessingSystem.BLESSING_DEFS.has(bid):
				continue
			var def: Dictionary = BlessingSystem.BLESSING_DEFS[bid] as Dictionary
			match str(def.get("effect", "")):
				"skill_cd_reduction":
					bonuses["cd_reduction"] = float(bonuses.get("cd_reduction", 0.0)) + float(def.get("value", 0.0)) * eff
				"skill_damage_bonus", "skill_damage_transfer":
					bonuses["damage_bonus"] = float(bonuses.get("damage_bonus", 0.0)) + float(def.get("value", 0.0)) * eff
				"skill_range_bonus":
					bonuses["range_bonus"] = float(bonuses.get("range_bonus", 0.0)) + float(def.get("value", 0.0)) * eff
				"skill_extra_charge":
					bonuses["extra_charge"] = int(bonuses.get("extra_charge", 0)) + 1
				"skill_crit_bonus":
					bonuses["crit_bonus"] = float(bonuses.get("crit_bonus", 0.0)) + float(def.get("value", 0.0)) * eff
				"skill_heal_on_hit":
					bonuses["heal_on_hit"] = float(bonuses.get("heal_on_hit", 0.0)) + float(def.get("value", 0.0)) * eff
				"skill_invincibility":
					bonuses["invincibility"] = float(bonuses.get("invincibility", 0.0)) + float(def.get("value", 0.0)) * eff
	return bonuses


func _refresh_skill_bonuses() -> void:
	_skill_bonuses = get_skill_blessing_bonuses()
	var extra_charges: int = int(_skill_bonuses.get("extra_charge", 0))
	for slot_key: String in SLOT_KEYS:
		var data: Dictionary = skill_slots[slot_key] as Dictionary
		var base_max: int = 1
		if player != null and "has_skill_extra_charge" in player and bool(player.has_skill_extra_charge):
			base_max = 2
		var new_max: int = base_max + extra_charges
		var old_max: int = int(data.get("max_charges", 1))
		data["max_charges"] = new_max
		if new_max > old_max:
			var current: int = int(data.get("current_charges", 1))
			data["current_charges"] = mini(current + (new_max - old_max), new_max)
		skill_slots[slot_key] = data


func _apply_bonuses_to_def(modified_def: Dictionary) -> void:
	if _skill_bonuses.is_empty():
		return
	var dmg_bonus: float = float(_skill_bonuses.get("damage_bonus", 0.0))
	var range_bonus: float = float(_skill_bonuses.get("range_bonus", 0.0))
	var cd_reduction: float = float(_skill_bonuses.get("cd_reduction", 0.0))
	var crit_bonus: float = float(_skill_bonuses.get("crit_bonus", 0.0))
	var total_dmg_mult: float = (1.0 + dmg_bonus) * (1.0 + crit_bonus)
	if total_dmg_mult != 1.0:
		if modified_def.has("damage_mult"):
			modified_def["damage_mult"] = float(modified_def["damage_mult"]) * total_dmg_mult
		if modified_def.has("damage_per_tick"):
			modified_def["damage_per_tick"] = float(modified_def["damage_per_tick"]) * total_dmg_mult
	if range_bonus > 0.0:
		for key: String in ["range", "aoe_radius", "slow_range", "dash_distance"]:
			if modified_def.has(key):
				modified_def[key] = float(modified_def[key]) * (1.0 + range_bonus)
	if cd_reduction > 0.0:
		var cd: float = float(modified_def.get("cooldown", 5.0))
		modified_def["cooldown"] = cd * maxf(0.1, 1.0 - cd_reduction)


func _apply_post_cast_bonuses() -> void:
	if player == null:
		return
	var heal_pct: float = float(_skill_bonuses.get("heal_on_hit", 0.0))
	if heal_pct > 0.0 and player.has_method("heal"):
		var heal_amount: int = maxi(int(round(float(_get_player_attack_damage()) * heal_pct)), 1)
		player.heal(heal_amount)
	var invuln: float = float(_skill_bonuses.get("invincibility", 0.0))
	if invuln > 0.0 and "invincible_time_left" in player:
		player.invincible_time_left = maxf(float(player.invincible_time_left), invuln)


# --- Legacy UI compatibility ---

func get_equipped_skill_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i: int in range(SLOT_KEYS.size()):
		var slot_key: String = SLOT_KEYS[i]
		var data: Dictionary = skill_slots[slot_key] as Dictionary
		var skill_id: String = str(data.get("skill_id", ""))
		if skill_id == "" or not skills.has(skill_id):
			result.append({})
			continue
		result.append((skills[skill_id] as Dictionary).duplicate(true))
	return result


func set_equipped_skill_ids(skill_ids: Array) -> void:
	# No-op in class-based system; class auto-equips
	pass


func equip_to_slot(_skill_id: String, _slot_index: int) -> void:
	# No-op in class-based system
	pass


func unequip_slot(_slot_index: int) -> void:
	# No-op in class-based system
	pass


# --- Combat helpers ---

func _get_enemies_in_radius(center: Vector2, radius: float) -> Array:
	var result: Array = []
	for enemy: Variant in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var enemy_node: Node2D = enemy as Node2D
		if enemy_node == null:
			continue
		if center.distance_to(enemy_node.global_position) <= radius:
			result.append(enemy_node)
	return result


func _get_enemies_in_arc(center: Vector2, direction: Vector2, radius: float, angle_deg: float) -> Array:
	var result: Array = []
	var half_angle: float = deg_to_rad(angle_deg * 0.5)
	for enemy: Variant in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var enemy_node: Node2D = enemy as Node2D
		if enemy_node == null:
			continue
		var to_enemy: Vector2 = enemy_node.global_position - center
		if to_enemy.length() > radius:
			continue
		if absf(direction.angle_to(to_enemy.normalized())) <= half_angle:
			result.append(enemy_node)
	return result


func _spawn_ring_vfx(center: Vector2, radius: float, color: Color, duration: float) -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		return
	var vfx_node: Node2D = Node2D.new()
	vfx_node.set_script(load("res://scripts/skills/skill_vfx.gd"))
	root.add_child(vfx_node)
	vfx_node.global_position = center
	vfx_node.set("mode", "ring")
	vfx_node.set("max_radius", radius)
	vfx_node.set("duration", duration)
	vfx_node.set("ring_color", color)


func _get_player_attack_damage() -> int:
	if player == null:
		return 10
	if player.has_method("get_attack_damage"):
		return int(player.get_attack_damage())
	return 10


func _get_player_mouse_pos() -> Vector2:
	if player == null:
		return Vector2.ZERO
	return player.get_global_mouse_position()


# --- Audio ---

func _play_skill_sound(skill_id: String) -> void:
	var audio_manager: Node = get_node_or_null("/root/AudioManager")
	if audio_manager == null:
		return
	if audio_manager.has_method("play_sfx"):
		audio_manager.play_sfx("skill_" + skill_id)


# --- Skill effects ---

func _cast_shield_bash(def: Dictionary) -> bool:
	if player == null:
		return false
	_play_skill_sound("shield_bash")
	var range_px: float = float(def.get("range", 60.0))
	var angle_deg: float = float(def.get("angle", 90.0))
	var stun_dur: float = float(def.get("stun_duration", 1.0))
	var dmg_mult: float = float(def.get("damage_mult", 0.5))
	var dmg: int = maxi(int(round(float(_get_player_attack_damage()) * dmg_mult)), 1)
	var face_dir: Vector2 = (_get_player_mouse_pos() - player.global_position).normalized()
	if face_dir == Vector2.ZERO:
		face_dir = Vector2.RIGHT
	var enemies: Array = _get_enemies_in_arc(player.global_position, face_dir, range_px, angle_deg)
	for enemy: Variant in enemies:
		var e: Node = enemy as Node
		if e.has_method("take_damage"):
			e.take_damage(dmg, (e.global_position - player.global_position).normalized())
		if e.has_method("apply_stun"):
			e.apply_stun(stun_dur)
		elif e.has_method("apply_slow"):
			e.apply_slow(0.0, stun_dur)
	_spawn_ring_vfx(player.global_position, range_px, Color(0.9, 0.6, 0.2, 0.7), 0.3)
	return true


func _cast_war_cry(def: Dictionary) -> bool:
	if player == null:
		return false
	_play_skill_sound("war_cry")
	var slow_range: float = float(def.get("slow_range", 60.0))
	var slow_pct: float = float(def.get("slow_pct", 0.5))
	var slow_dur: float = float(def.get("slow_duration", 3.0))
	var enemies: Array = _get_enemies_in_radius(player.global_position, slow_range)
	for enemy: Variant in enemies:
		var e: Node = enemy as Node
		if e.has_method("apply_slow"):
			e.apply_slow(1.0 - slow_pct, slow_dur)
	_spawn_ring_vfx(player.global_position, slow_range, Color(1.0, 0.85, 0.2, 0.6), 0.4)
	if player.has_method("show_status_message"):
		player.show_status_message(LocaleManager.L("skill_war_cry_active"), Color(1.0, 0.85, 0.2, 1.0))
	return true


func _cast_leap_slam(def: Dictionary) -> bool:
	if player == null:
		return false
	_play_skill_sound("leap_slam")
	var leap_range: float = float(def.get("range", 150.0))
	var aoe_radius: float = float(def.get("aoe_radius", 80.0))
	var dmg_mult: float = float(def.get("damage_mult", 2.0))
	var target_pos: Vector2 = _get_player_mouse_pos()
	var dir: Vector2 = (target_pos - player.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var final_pos: Vector2 = player.global_position + dir * leap_range

	# Disable physics during dash, tween to final pos, then AOE
	if player.has_method("set_physics_process"):
		player.set_physics_process(false)
	var tween: Tween = player.create_tween()
	tween.tween_property(player, "global_position", final_pos, 0.2)
	tween.tween_callback(func() -> void:
		if player.has_method("set_physics_process"):
			player.set_physics_process(true)
		var dmg: int = maxi(int(round(float(_get_player_attack_damage()) * dmg_mult)), 1)
		var hit_enemies: Array = _get_enemies_in_radius(player.global_position, aoe_radius)
		for enemy: Variant in hit_enemies:
			var e: Node = enemy as Node
			if e.has_method("take_damage"):
				e.take_damage(dmg, (e.global_position - player.global_position).normalized())
			if e.has_method("apply_knockback"):
				e.apply_knockback((e.global_position - player.global_position).normalized(), 120.0)
		_spawn_ring_vfx(player.global_position, aoe_radius, Color(1.0, 0.35, 0.1, 0.8), 0.3)
	)
	return true


func _cast_dodge_roll(def: Dictionary) -> bool:
	if player == null:
		return false
	_play_skill_sound("dodge_roll")
	var distance: float = float(def.get("dash_distance", 100.0))
	var invuln: float = float(def.get("invuln_duration", 0.3))
	var direction: Vector2 = (_get_player_mouse_pos() - player.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var final_pos: Vector2 = player.global_position + direction * distance

	# Set invulnerable
	if "invincible_time_left" in player:
		player.invincible_time_left = maxf(float(player.invincible_time_left), invuln + 0.15)

	if player.has_method("set_physics_process"):
		player.set_physics_process(false)
	var tween: Tween = player.create_tween()
	var sprite_node: Node = player.get_node_or_null("AnimatedSprite2D")
	if sprite_node != null:
		tween.tween_property(sprite_node, "modulate:a", 0.5, 0.05)
	tween.tween_property(player, "global_position", final_pos, 0.15)
	tween.tween_callback(func() -> void:
		if player.has_method("set_physics_process"):
			player.set_physics_process(true)
		var sprite2: Node = player.get_node_or_null("AnimatedSprite2D")
		if sprite2 != null:
			var fade: Tween = player.create_tween()
			fade.tween_property(sprite2, "modulate:a", 1.0, 0.1)
	)
	return true


func _cast_rain_of_arrows(def: Dictionary) -> bool:
	if player == null:
		return false
	_play_skill_sound("rain_of_arrows")
	var max_range: float = float(def.get("range", 200.0))
	var aoe_radius: float = float(def.get("aoe_radius", 70.0))
	var duration: float = float(def.get("duration", 3.0))
	var tick_interval: float = float(def.get("tick_interval", 0.5))
	var dmg_per_tick: float = float(_get_player_attack_damage()) * float(def.get("damage_per_tick", 0.3))

	var target_pos: Vector2 = _get_player_mouse_pos()
	var dist: float = player.global_position.distance_to(target_pos)
	if dist > max_range:
		target_pos = player.global_position + (target_pos - player.global_position).normalized() * max_range

	_spawn_ground_aoe_zone(target_pos, aoe_radius, duration, tick_interval, maxi(int(round(dmg_per_tick)), 1))
	return true


func _spawn_ground_aoe_zone(pos: Vector2, radius: float, duration: float, interval: float, dmg: int) -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		return
	var zone: Area2D = Area2D.new()
	zone.global_position = pos
	zone.collision_layer = 0
	zone.collision_mask = 4
	var col: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = radius
	col.shape = shape
	zone.add_child(col)
	# Visual
	var visual: Polygon2D = Polygon2D.new()
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(32):
		var angle: float = float(i) * TAU / 32.0
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	visual.polygon = pts
	visual.color = Color(1.0, 0.3, 0.3, 0.25)
	zone.add_child(visual)
	root.add_child(zone)

	var elapsed: float = 0.0
	var timer: Timer = Timer.new()
	timer.wait_time = interval
	timer.autostart = true
	zone.add_child(timer)
	var player_ref: Variant = player
	timer.timeout.connect(func() -> void:
		elapsed += interval
		if elapsed >= duration or not is_instance_valid(zone):
			if is_instance_valid(zone):
				zone.queue_free()
			return
		for body: Variant in zone.get_overlapping_bodies():
			if is_instance_valid(body) and (body as Node).has_method("take_damage"):
				(body as Node).take_damage(dmg, Vector2.ZERO)
	)
	get_tree().create_timer(duration + 0.5).timeout.connect(func() -> void:
		if is_instance_valid(zone):
			zone.queue_free()
	)


func _cast_trap(def: Dictionary) -> bool:
	if player == null:
		return false
	_play_skill_sound("trap")
	var dmg_mult: float = float(def.get("damage_mult", 1.5))
	var slow_pct: float = float(def.get("slow_pct", 0.5))
	var slow_dur: float = float(def.get("slow_duration", 3.0))
	var trap_dur: float = float(def.get("trap_duration", 30.0))
	var trap_pos: Vector2 = player.global_position

	var root: Node = get_tree().current_scene
	if root == null:
		return false
	var trap: Area2D = Area2D.new()
	trap.global_position = trap_pos
	trap.collision_layer = 0
	trap.collision_mask = 4
	var col: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 30.0
	col.shape = shape
	trap.add_child(col)
	# Visual
	var visual: Polygon2D = Polygon2D.new()
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(16):
		var angle: float = float(i) * TAU / 16.0
		pts.append(Vector2(cos(angle), sin(angle)) * 30.0)
	visual.polygon = pts
	visual.color = Color(0.8, 0.6, 0.2, 0.5)
	trap.add_child(visual)
	root.add_child(trap)

	var triggered: bool = false
	var player_ref: Variant = player
	trap.body_entered.connect(func(body: Node2D) -> void:
		if triggered:
			return
		if not body.has_method("take_damage"):
			return
		triggered = true
		var dmg: int = maxi(int(round(float(_get_player_attack_damage()) * dmg_mult)), 1)
		body.take_damage(dmg, (body.global_position - trap.global_position).normalized())
		if body.has_method("apply_slow"):
			body.apply_slow(1.0 - slow_pct, slow_dur)
		visual.color = Color(1.0, 0.5, 0.0, 0.8)
		var tween: Tween = trap.create_tween()
		tween.tween_property(visual, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func() -> void:
			if is_instance_valid(trap):
				trap.queue_free()
		)
	)
	get_tree().create_timer(trap_dur).timeout.connect(func() -> void:
		if is_instance_valid(trap):
			trap.queue_free()
	)
	return true


func _cast_blink(def: Dictionary) -> bool:
	if player == null:
		return false
	_play_skill_sound("blink")
	var max_range: float = float(def.get("range", 150.0))
	var target_pos: Vector2 = _get_player_mouse_pos()
	var dist: float = player.global_position.distance_to(target_pos)
	if dist > max_range:
		target_pos = player.global_position + (target_pos - player.global_position).normalized() * max_range

	var sprite_node: Node = player.get_node_or_null("AnimatedSprite2D")
	if sprite_node != null:
		sprite_node.modulate.a = 0.3
	player.global_position = target_pos
	var tween: Tween = player.create_tween()
	if sprite_node != null:
		tween.tween_property(sprite_node, "modulate:a", 1.0, 0.2)
	return true


func _cast_frost_nova(def: Dictionary) -> bool:
	if player == null:
		return false
	_play_skill_sound("frost_nova")
	var dmg_mult: float = float(def.get("damage_mult", 1.2))
	var aoe_radius: float = float(def.get("aoe_radius", 90.0))
	var freeze_dur: float = float(def.get("freeze_duration", 2.0))
	var dmg: int = maxi(int(round(float(_get_player_attack_damage()) * dmg_mult)), 1)

	var enemies: Array = _get_enemies_in_radius(player.global_position, aoe_radius)
	for enemy: Variant in enemies:
		var e: Node = enemy as Node
		if e.has_method("take_damage"):
			e.take_damage(dmg, (e.global_position - player.global_position).normalized())
		if e.has_method("apply_chill"):
			e.apply_chill(1, freeze_dur)
		elif e.has_method("apply_slow"):
			e.apply_slow(0.0, freeze_dur)
	_spawn_ring_vfx(player.global_position, aoe_radius, Color(0.3, 0.7, 1.0, 0.7), 0.35)
	return true


func _cast_meteor(def: Dictionary) -> bool:
	if player == null:
		return false
	_play_skill_sound("meteor")
	var max_range: float = float(def.get("range", 200.0))
	var delay: float = float(def.get("delay", 1.0))
	var dmg_mult: float = float(def.get("damage_mult", 3.0))
	var aoe_radius: float = float(def.get("aoe_radius", 100.0))

	var target_pos: Vector2 = _get_player_mouse_pos()
	var dist: float = player.global_position.distance_to(target_pos)
	if dist > max_range:
		target_pos = player.global_position + (target_pos - player.global_position).normalized() * max_range

	var root: Node = get_tree().current_scene
	if root == null:
		return false

	# Warning indicator
	var warning: Polygon2D = Polygon2D.new()
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(32):
		var angle: float = float(i) * TAU / 32.0
		pts.append(Vector2(cos(angle), sin(angle)) * aoe_radius)
	warning.polygon = pts
	warning.color = Color(1.0, 0.2, 0.0, 0.2)
	warning.global_position = target_pos
	root.add_child(warning)

	var tween: Tween = warning.create_tween()
	tween.tween_property(warning, "color:a", 0.6, delay * 0.5)
	tween.tween_property(warning, "color:a", 0.2, delay * 0.5)
	tween.tween_callback(func() -> void:
		if not is_instance_valid(warning):
			return
		var dmg: int = maxi(int(round(float(_get_player_attack_damage()) * dmg_mult)), 1)
		var hit_enemies: Array = _get_enemies_in_radius(target_pos, aoe_radius)
		for enemy: Variant in hit_enemies:
			var e: Node = enemy as Node
			if e.has_method("take_damage"):
				e.take_damage(dmg, (e.global_position - target_pos).normalized())
		warning.color = Color(1.0, 0.5, 0.0, 0.8)
		var fade: Tween = warning.create_tween()
		fade.tween_property(warning, "modulate:a", 0.0, 0.4)
		fade.tween_callback(func() -> void:
			if is_instance_valid(warning):
				warning.queue_free()
		)
	)
	return true

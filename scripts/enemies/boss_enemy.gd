extends Enemy
class_name BossEnemy

const DUNGEON_LOOT = preload("res://scripts/dungeon/dungeon_loot.gd")
const LEGENDARY_ITEMS: Script = preload("res://scripts/dungeon/legendary_items.gd")
const ITEM_DATABASE: Script = preload("res://scripts/inventory/item_database.gd")

const BOSS_IDLE_FRAMES: Dictionary = {
	"boss_skeleton_king": [
		"res://assets/big_zombie_idle_anim_f0.png",
		"res://assets/big_zombie_idle_anim_f1.png",
		"res://assets/big_zombie_idle_anim_f2.png",
		"res://assets/big_zombie_idle_anim_f3.png",
	],
	"boss_slime_mother": [
		"res://assets/big_demon_idle_anim_f0.png",
		"res://assets/big_demon_idle_anim_f1.png",
		"res://assets/big_demon_idle_anim_f2.png",
		"res://assets/big_demon_idle_anim_f3.png",
	],
	"boss_shadow_mage": [
		"res://assets/necromancer_anim_f0.png",
		"res://assets/necromancer_anim_f1.png",
		"res://assets/necromancer_anim_f2.png",
		"res://assets/necromancer_anim_f3.png",
	],
	"boss_lava_golem": [
		"res://assets/big_demon_idle_anim_f0.png",
		"res://assets/big_demon_idle_anim_f1.png",
		"res://assets/big_demon_idle_anim_f2.png",
		"res://assets/big_demon_idle_anim_f3.png",
	],
	"boss_abyss_warden": [
		"res://assets/big_zombie_idle_anim_f0.png",
		"res://assets/big_zombie_idle_anim_f1.png",
		"res://assets/big_zombie_idle_anim_f2.png",
		"res://assets/big_zombie_idle_anim_f3.png",
	],
	"boss_lord_of_abyss": [
		"res://assets/big_demon_idle_anim_f0.png",
		"res://assets/big_demon_idle_anim_f1.png",
		"res://assets/big_demon_idle_anim_f2.png",
		"res://assets/big_demon_idle_anim_f3.png",
	],
}

const BOSS_RUN_FRAMES: Dictionary = {
	"boss_skeleton_king": [
		"res://assets/big_zombie_run_anim_f0.png",
		"res://assets/big_zombie_run_anim_f1.png",
		"res://assets/big_zombie_run_anim_f2.png",
		"res://assets/big_zombie_run_anim_f3.png",
	],
	"boss_slime_mother": [
		"res://assets/big_demon_run_anim_f0.png",
		"res://assets/big_demon_run_anim_f1.png",
		"res://assets/big_demon_run_anim_f2.png",
		"res://assets/big_demon_run_anim_f3.png",
	],
	"boss_lava_golem": [
		"res://assets/big_demon_run_anim_f0.png",
		"res://assets/big_demon_run_anim_f1.png",
		"res://assets/big_demon_run_anim_f2.png",
		"res://assets/big_demon_run_anim_f3.png",
	],
	"boss_abyss_warden": [
		"res://assets/big_zombie_run_anim_f0.png",
		"res://assets/big_zombie_run_anim_f1.png",
		"res://assets/big_zombie_run_anim_f2.png",
		"res://assets/big_zombie_run_anim_f3.png",
	],
	"boss_lord_of_abyss": [
		"res://assets/big_demon_run_anim_f0.png",
		"res://assets/big_demon_run_anim_f1.png",
		"res://assets/big_demon_run_anim_f2.png",
		"res://assets/big_demon_run_anim_f3.png",
	],
}

const BOSS_SCALE: Dictionary = {
	"boss_skeleton_king": 2.0,
	"boss_slime_mother": 2.5,
	"boss_shadow_mage": 1.8,
	"boss_lava_golem": 2.8,
	"boss_abyss_warden": 2.5,
	"boss_lord_of_abyss": 3.0,
}

var floor_value: int = 1
var _aoe_cooldown: float = 5.0
var _aoe_radius: float = 56.0
var _aoe_cooldown_left: float = 5.0
var rewards_granted: bool = false
var buff_selection_requested: bool = false
var _boss_abilities: Array[String] = ["melee_slam"]
var _ability_cooldowns: Dictionary = {}
var _split_triggered: bool = false
var boss_name_key: String = ""


func _ready() -> void:
	super._ready()
	scale = Vector2.ONE * 1.72
	if animated_sprite != null:
		animated_sprite.modulate = Color(1.0, 0.55, 0.55, 1.0)
	AudioManager.play_sfx("boss_appear")


func configure_for_floor(player_target: CharacterBody2D, floor_number: int, loot_root: Node) -> void:
	target = player_target
	loot_parent = loot_root
	floor_value = floor_number
	var normal_stats: Dictionary = _get_normal_enemy_stats(floor_number)
	var boss_info: Dictionary = BossData.get_boss_data(floor_number)
	var hp_mult: float = float(boss_info.get("hp_mult", 1.0))
	var atk_mult: float = float(boss_info.get("atk_mult", 1.0))
	max_hp = int(round(float(int(normal_stats["hp"])) * 10.0 * hp_mult))
	current_hp = max_hp
	damage = int(round(float(int(normal_stats["damage"])) * 1.8 * atk_mult))
	speed = float(boss_info.get("speed", 32.0))
	detection_range = 190.0
	attack_range = 32.0
	attack_cooldown = 1.1
	_aoe_cooldown = float(boss_info.get("aoe_cooldown", 5.0))
	_aoe_radius = float(boss_info.get("aoe_radius", 56.0))
	_aoe_cooldown_left = _aoe_cooldown
	drop_table.clear()
	boss_name_key = str(boss_info.get("name_key", ""))
	_setup_boss_visual(boss_name_key)
	# Apply boss color (after visual setup so modulate applies correctly)
	var boss_color: Variant = boss_info.get("color", null)
	if boss_color is Color and animated_sprite != null:
		animated_sprite.modulate = boss_color
	# Set abilities
	var abilities_raw: Variant = boss_info.get("abilities", [])
	_boss_abilities.clear()
	for ab: Variant in (abilities_raw as Array):
		_boss_abilities.append(str(ab))
	_ability_cooldowns = {
		"teleport": 0.0,
		"dash_attack": 0.0,
		"ground_slam": 0.0,
		"summon_minions": 0.0,
		"projectile_burst": 0.0,
	}
	_update_hp_bar()


func _physics_process(delta: float) -> void:
	_aoe_cooldown_left = max(_aoe_cooldown_left - delta, 0.0)
	for key: String in _ability_cooldowns.keys():
		_ability_cooldowns[key] = maxf(float(_ability_cooldowns[key]) - delta, 0.0)
	if not ai_paused and not is_dead:
		if _aoe_cooldown_left <= 0.0:
			_perform_boss_ability()
			_aoe_cooldown_left = _aoe_cooldown
		_check_split()
	super._physics_process(delta)


func is_boss_enemy() -> bool:
	return true


func apply_knockback(direction: Vector2, force: float = 120.0) -> void:
	super.apply_knockback(direction, force * 0.08)


func die() -> void:
	if rewards_granted:
		return
	rewards_granted = true
	AudioManager.play_sfx("boss_death")
	_grant_rewards_to_players()
	super.die()
	_request_buff_selection()


func _drop_loot() -> void:
	pass


func _drop_gold_loot() -> void:
	if loot_parent == null:
		return
	var amount: int = randi_range(15, 30)
	var coin_type: String = "copper"
	if floor_value > 20:
		coin_type = "silver"
		amount = randi_range(1, 3)
	var drop = LOOT_DROP_SCENE.instantiate()
	drop.setup(coin_type, amount)
	drop.global_position = global_position + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
	loot_parent.add_child(drop)


func _perform_boss_ability() -> void:
	if target == null or not is_instance_valid(target):
		return
	if global_position.distance_to(target.global_position) > detection_range * 1.2:
		return
	# Pick an available ability
	for ab: String in _boss_abilities:
		if ab == "melee_slam":
			_perform_aoe()
			return
		if ab == "teleport" and float(_ability_cooldowns.get("teleport", 0.0)) <= 0.0:
			_perform_teleport()
			return
		if ab == "dash_attack" and float(_ability_cooldowns.get("dash_attack", 0.0)) <= 0.0:
			_perform_dash()
			return
		if ab == "ground_slam" and float(_ability_cooldowns.get("ground_slam", 0.0)) <= 0.0:
			_perform_ground_slam()
			return
		if ab == "summon_minions" and float(_ability_cooldowns.get("summon_minions", 0.0)) <= 0.0:
			_perform_summon()
			return
		if ab == "projectile_burst" and float(_ability_cooldowns.get("projectile_burst", 0.0)) <= 0.0:
			_perform_projectile_burst()
			return
	# Fallback to basic AOE
	_perform_aoe()


func _check_split() -> void:
	if _split_triggered:
		return
	if not _boss_abilities.has("split_on_half"):
		return
	if current_hp <= max_hp / 2:
		_split_triggered = true
		_perform_split()


func _perform_aoe() -> void:
	if target == null or not is_instance_valid(target):
		return
	if global_position.distance_to(target.global_position) > detection_range * 1.1:
		return
	_spawn_aoe_indicator(_aoe_radius)
	for player_ref in get_tree().get_nodes_in_group("player"):
		if player_ref == null or not is_instance_valid(player_ref):
			continue
		if player_ref.global_position.distance_to(global_position) > _aoe_radius:
			continue
		if player_ref.has_method("take_damage"):
			player_ref.take_damage(int(round(damage * 0.9)), (player_ref.global_position - global_position).normalized())


func _perform_teleport() -> void:
	_ability_cooldowns["teleport"] = 5.0
	var offset: Vector2 = Vector2(randf_range(-80, 80), randf_range(-80, 80))
	global_position += offset
	# Visual flash
	if animated_sprite != null:
		var tween: Tween = create_tween()
		tween.tween_property(animated_sprite, "modulate:a", 0.2, 0.1)
		tween.tween_property(animated_sprite, "modulate:a", 1.0, 0.15)
	# Fire projectile burst after teleport
	if _boss_abilities.has("projectile_burst"):
		_perform_projectile_burst()


func _perform_dash() -> void:
	_ability_cooldowns["dash_attack"] = 6.0
	if target == null or not is_instance_valid(target):
		return
	var dash_dir: Vector2 = (target.global_position - global_position).normalized()
	var dash_dist: float = 200.0
	# Damage players in path
	for player_ref in get_tree().get_nodes_in_group("player"):
		if player_ref == null or not is_instance_valid(player_ref):
			continue
		var to_player: Vector2 = player_ref.global_position - global_position
		var proj: float = to_player.dot(dash_dir)
		if proj < 0.0 or proj > dash_dist:
			continue
		var perp_dist: float = absf(to_player.cross(dash_dir))
		if perp_dist < 24.0 and player_ref.has_method("take_damage"):
			player_ref.take_damage(int(round(damage * 1.2)), dash_dir)
	global_position += dash_dir * dash_dist
	_spawn_aoe_indicator(32.0)


func _perform_ground_slam() -> void:
	_ability_cooldowns["ground_slam"] = 8.0
	_spawn_aoe_indicator(_aoe_radius * 1.5)
	for player_ref in get_tree().get_nodes_in_group("player"):
		if player_ref == null or not is_instance_valid(player_ref):
			continue
		if player_ref.global_position.distance_to(global_position) > _aoe_radius * 1.5:
			continue
		if player_ref.has_method("take_damage"):
			player_ref.take_damage(int(round(damage * 1.5)), (player_ref.global_position - global_position).normalized())
	# Spawn fire patches
	for i: int in range(3):
		_spawn_fire_patch(global_position + Vector2(randf_range(-48, 48), randf_range(-48, 48)))


func _perform_summon() -> void:
	_ability_cooldowns["summon_minions"] = 15.0
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	for i: int in range(2):
		var minion: Node = preload("res://scenes/enemies/melee_enemy.tscn").instantiate()
		minion.global_position = global_position + Vector2(randf_range(-32, 32), randf_range(-32, 32))
		if minion.has_method("configure_for_floor") and target != null:
			minion.configure_for_floor(target, floor_value, loot_parent)
		minion.modulate = Color(0.6, 0.6, 0.8, 1.0)
		parent_node.add_child(minion)


func _perform_projectile_burst() -> void:
	_ability_cooldowns["projectile_burst"] = 4.0
	if target == null or not is_instance_valid(target):
		return
	var base_dir: Vector2 = (target.global_position - global_position).normalized()
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	for i: int in range(3):
		var angle_offset: float = deg_to_rad(float(i - 1) * 20.0)
		var proj_dir: Vector2 = base_dir.rotated(angle_offset)
		_fire_boss_projectile(proj_dir, float(damage) * 0.5)


func _fire_boss_projectile(dir: Vector2, dmg: float) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	# Use enemy projectile scene if available
	if PROJECTILE_SCENE != null:
		var proj: Node2D = PROJECTILE_SCENE.instantiate() as Node2D
		if proj != null:
			proj.global_position = global_position
			if proj.has_method("setup"):
				proj.setup(dir, 180.0, 160.0, int(round(dmg)), self)
			elif "direction" in proj:
				proj.set("direction", dir)
				proj.set("speed", 180.0)
				proj.set("damage", int(round(dmg)))
			parent_node.add_child(proj)
			return
	# Fallback: instant line damage
	for player_ref in get_tree().get_nodes_in_group("player"):
		if player_ref == null or not is_instance_valid(player_ref):
			continue
		var to_player: Vector2 = player_ref.global_position - global_position
		if to_player.dot(dir) > 0 and to_player.length() < 150.0:
			var perp: float = absf(to_player.cross(dir))
			if perp < 16.0 and player_ref.has_method("take_damage"):
				player_ref.take_damage(int(round(dmg)), dir)


func _perform_split() -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	for i: int in range(2):
		var mini_boss: Node = preload("res://scenes/enemies/boss_enemy.tscn").instantiate()
		mini_boss.global_position = global_position + Vector2(randf_range(-24, 24), randf_range(-24, 24))
		if mini_boss.has_method("configure_for_floor") and target != null:
			mini_boss.configure_for_floor(target, floor_value, loot_parent)
		# Half-size, quarter HP, no further splitting
		mini_boss.scale = Vector2.ONE * 1.1
		mini_boss.set("max_hp", int(max_hp / 4))
		mini_boss.set("current_hp", int(max_hp / 4))
		mini_boss.set("damage", int(damage / 2))
		mini_boss.set("_split_triggered", true)
		mini_boss.modulate = Color(0.5, 0.9, 0.5, 1.0)
		if mini_boss.has_signal("died"):
			var level: Variant = get_parent()
			while level != null and not level.has_method("_on_enemy_died"):
				level = level.get_parent()
			if level != null:
				mini_boss.died.connect(level._on_enemy_died.bind(mini_boss))
		parent_node.add_child(mini_boss)


func _spawn_fire_patch(pos: Vector2) -> void:
	var patch: Polygon2D = Polygon2D.new()
	patch.color = Color(1.0, 0.3, 0.1, 0.6)
	var fire_radius: float = 20.0
	var fire_points: PackedVector2Array = PackedVector2Array()
	for i: int in range(12):
		fire_points.append(Vector2.RIGHT.rotated(TAU * float(i) / 12.0) * fire_radius)
	patch.polygon = fire_points
	patch.global_position = pos
	var parent_node: Node = get_parent()
	if parent_node != null:
		parent_node.add_child(patch)
	# Fire damage tick
	var timer_count: int = 0
	var fire_timer: Timer = Timer.new()
	fire_timer.wait_time = 0.5
	fire_timer.autostart = true
	fire_timer.timeout.connect(func() -> void:
		timer_count += 1
		if timer_count >= 6:
			patch.queue_free()
			return
		for player_ref in get_tree().get_nodes_in_group("player"):
			if player_ref == null or not is_instance_valid(player_ref):
				continue
			if player_ref.global_position.distance_to(pos) <= fire_radius and player_ref.has_method("take_damage"):
				player_ref.take_damage(int(round(damage * 0.3)), Vector2.ZERO)
	)
	patch.add_child(fire_timer)


func _spawn_aoe_indicator(radius: float) -> void:
	var ring: Line2D = Line2D.new()
	ring.width = 3.0
	ring.default_color = Color(1.0, 0.78, 0.2, 0.95)
	ring.closed = true
	var points: PackedVector2Array = PackedVector2Array()
	for index in range(24):
		var angle: float = TAU * float(index) / 24.0
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	ring.points = points
	ring.global_position = global_position
	get_parent().add_child(ring)
	var tween: Tween = create_tween()
	tween.tween_property(ring, "modulate:a", 0.0, 0.35)
	tween.tween_callback(ring.queue_free)


func _grant_rewards_to_players() -> void:
	var equipment_reward: Dictionary = _generate_boss_equipment()
	var silver_amount: int = 10 + floor_value * 2
	var gold_amount: int = 1 if randf() <= minf(0.08 + float(floor_value) * 0.005, 0.22) else 0
	var shard_amount: int = 4 + int(floor_value / 5)
	var gem_drops: Array[String] = _roll_boss_gem_drops()
	for player_ref in get_tree().get_nodes_in_group("player"):
		if player_ref == null or not is_instance_valid(player_ref):
			continue
		var inventory: Variant = player_ref.get("inventory")
		if inventory == null:
			continue
		_grant_stack(inventory, equipment_reward.duplicate(true))
		_grant_item(inventory, "silver", silver_amount)
		if gold_amount > 0:
			_grant_item(inventory, "gold", gold_amount)
		_grant_item(inventory, "talent_shard", shard_amount)
		for gem_id: String in gem_drops:
			_grant_item(inventory, gem_id, 1)
			if player_ref.has_method("record_dungeon_loot"):
				player_ref.record_dungeon_loot(gem_id, 1)
		if player_ref.has_method("record_dungeon_loot"):
			player_ref.record_dungeon_loot(str(equipment_reward.get("id", "")), 1)
			player_ref.record_dungeon_loot("silver", silver_amount)
			if gold_amount > 0:
				player_ref.record_dungeon_loot("gold", gold_amount)
			player_ref.record_dungeon_loot("talent_shard", shard_amount)
		if player_ref.has_method("_show_floating_text"):
			player_ref._show_floating_text(player_ref.global_position, "Boss Reward!", Color(1.0, 0.9, 0.3, 1.0))


func _grant_item(inventory, item_id: String, amount: int) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		var achievement_manager: Variant = tree.root.get_node_or_null("/root/AchievementManager")
		if achievement_manager != null:
			achievement_manager.record_currency_gain(item_id, amount)
	if inventory.add_item(item_id, amount):
		return
	var fallback_stack: Dictionary = {
		"id": item_id,
		"name": item_id.replace("_", " ").capitalize(),
		"type": "resource",
		"quantity": amount,
		"max_stack": 9999,
	}
	_force_add_stack(inventory, fallback_stack)


func _grant_stack(inventory, stack: Dictionary) -> void:
	if inventory.add_stack(stack):
		return
	_force_add_stack(inventory, stack)


func _force_add_stack(inventory, stack: Dictionary) -> void:
	inventory.items.append(stack.duplicate(true))
	inventory.mark_dirty()


func _roll_boss_gem_drops() -> Array[String]:
	var drops: Array[String] = []
	var cycle_manager: Node = get_node_or_null("/root/CycleManager")
	var cycle: int = 1
	if cycle_manager != null:
		cycle = int(cycle_manager.get("current_cycle"))
	if floor_value >= 30 and randf() < 0.01:
		drops.append("gem_red")
	if cycle >= 2 and floor_value >= 20 and randf() < 0.20:
		drops.append("gem_purple")
	if cycle >= 2 and floor_value >= 15 and randf() < 0.30:
		drops.append("gem_blue")
	return drops


func _generate_boss_equipment() -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("%s:%s:%s" % [name, floor_value, Time.get_ticks_usec()])
	if floor_value >= 30:
		var legendary: Dictionary = LEGENDARY_ITEMS.get_random_legendary(rng)
		if not legendary.is_empty():
			return legendary
	var boss_set_drop: Dictionary = ITEM_DATABASE.get_random_boss_set_item(floor_value, rng)
	if not boss_set_drop.is_empty() and rng.randf() <= 0.5:
		return boss_set_drop
	for _attempt in range(16):
		var reward: Dictionary = DUNGEON_LOOT.generate_dungeon_equipment(floor_value + 2, rng)
		var rarity: String = str(reward.get("rarity", "Common"))
		if rarity == "Epic" or rarity == "Legendary":
			return reward
	var fallback: Dictionary = DUNGEON_LOOT.generate_dungeon_equipment(floor_value + 3, rng)
	fallback["rarity"] = "Epic"
	fallback["color"] = DUNGEON_LOOT.get_rarity_color("Epic")
	return fallback


func _setup_boss_visual(name_key: String) -> void:
	if animated_sprite == null:
		return
	var idle_list: Array = BOSS_IDLE_FRAMES.get(name_key, []) as Array
	if idle_list.is_empty():
		return
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 5.0)
	for raw_path: Variant in idle_list:
		var tex_path: String = str(raw_path)
		if ResourceLoader.exists(tex_path):
			frames.add_frame("idle", load(tex_path) as Texture2D)
	var run_list: Array = BOSS_RUN_FRAMES.get(name_key, idle_list) as Array
	frames.add_animation("run")
	frames.set_animation_loop("run", true)
	frames.set_animation_speed("run", 8.0)
	for raw_path: Variant in run_list:
		var tex_path: String = str(raw_path)
		if ResourceLoader.exists(tex_path):
			frames.add_frame("run", load(tex_path) as Texture2D)
	if frames.get_frame_count("idle") > 0:
		animated_sprite.sprite_frames = frames
		animated_sprite.play("idle")
	var boss_s: float = float(BOSS_SCALE.get(name_key, 1.72))
	scale = Vector2.ONE * boss_s


func _request_buff_selection() -> void:
	if buff_selection_requested:
		return
	var level: Variant = get_parent()
	while level != null and not level.has_signal("blessing_selection_requested"):
		level = level.get_parent()
	if level == null or not level.has_signal("blessing_selection_requested"):
		return
	buff_selection_requested = true
	if level.has_method("set_gameplay_paused"):
		level.set_gameplay_paused(true)
	level.blessing_selection_requested.emit([])

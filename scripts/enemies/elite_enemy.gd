extends Enemy
class_name EliteEnemy

const BAT_SWARM_SCENE: PackedScene = preload("res://scenes/enemies/bat_swarm_enemy.tscn")

var floor_value: int = 1
var attack_pattern_index: int = 0
var summon_cooldown_left: float = 0.0
var pulse_time: float = 0.0


func _ready() -> void:
	super._ready()
	# Gold tint to distinguish from normal enemies
	animated_sprite.modulate = Color(1.0, 0.85, 0.3, 1.0)
	scale = Vector2(1.5, 1.5)


func configure_for_floor(player_target: CharacterBody2D, floor_number: int, loot_root: Node) -> void:
	target = player_target
	loot_parent = loot_root
	floor_value = floor_number
	# Base stats from normal enemy, then 3x HP and 2x ATK
	var normal: Dictionary = _get_normal_enemy_stats(floor_number)
	max_hp = int(normal["hp"]) * 3
	current_hp = max_hp
	damage = int(normal["damage"]) * 2
	speed = 35.0
	detection_range = 160.0
	attack_range = 28.0
	attack_cooldown = 1.2
	drop_table.clear()


func _physics_process(delta: float) -> void:
	summon_cooldown_left = max(summon_cooldown_left - delta, 0.0)
	pulse_time += delta
	if animated_sprite != null:
		animated_sprite.scale = Vector2.ONE * (1.0 + sin(pulse_time * 4.0) * 0.04)
	super._physics_process(delta)


func is_elite_enemy() -> bool:
	return true


func apply_chain_enhancement(multiplier: float) -> void:
	var new_max_hp: int = int(round(float(max_hp) * multiplier))
	var hp_ratio: float = float(current_hp) / float(maxi(max_hp, 1))
	max_hp = new_max_hp
	current_hp = int(round(float(max_hp) * hp_ratio))
	damage = int(round(float(damage) * multiplier))


func _drop_gold_loot() -> void:
	super._drop_gold_loot()


func _perform_attack() -> void:
	if target == null or not is_instance_valid(target):
		return
	match attack_pattern_index % 3:
		0:
			if target.has_method("take_damage"):
				target.take_damage(damage, (target.global_position - global_position).normalized())
		1:
			call_deferred("_perform_charge_attack")
		_:
			if summon_cooldown_left <= 0.0:
				_summon_bats()
				summon_cooldown_left = 10.0
			else:
				if target.has_method("take_damage"):
					target.take_damage(damage, (target.global_position - global_position).normalized())
	attack_pattern_index += 1


func _perform_charge_attack() -> void:
	if target == null or not is_instance_valid(target):
		return
	ai_paused = true
	velocity = Vector2.ZERO
	await get_tree().create_timer(0.5).timeout
	if is_dead or target == null or not is_instance_valid(target):
		ai_paused = false
		return
	var dash_target: Vector2 = global_position + (target.global_position - global_position).normalized() * 42.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position", dash_target, 0.18)
	await tween.finished
	if global_position.distance_to(target.global_position) <= attack_range + 20.0:
		if target.has_method("take_damage"):
			target.take_damage(int(round(damage * 1.2)), (target.global_position - global_position).normalized())
	ai_paused = false


func apply_knockback(direction: Vector2, force: float = 120.0) -> void:
	super.apply_knockback(direction, force * 0.1)


func die() -> void:
	if loot_parent != null:
		var shard_drop: LootDrop = LOOT_DROP_SCENE.instantiate() as LootDrop
		shard_drop.setup("talent_shard", 3)
		shard_drop.global_position = global_position
		loot_parent.add_child(shard_drop)
		var gem_id: String = _roll_elite_gem_drop()
		if gem_id != "":
			var gem_drop: LootDrop = LOOT_DROP_SCENE.instantiate() as LootDrop
			gem_drop.setup(gem_id, 1)
			gem_drop.global_position = global_position + Vector2(-8, -8)
			loot_parent.add_child(gem_drop)
		if randf() <= 0.75:
			var equipment_drop: LootDrop = LOOT_DROP_SCENE.instantiate() as LootDrop
			equipment_drop.global_position = global_position + Vector2(10, -4)
			loot_parent.add_child(equipment_drop)
			equipment_drop.setup_stack(DungeonLoot.generate_dungeon_equipment(floor_value))
	_maybe_trigger_elite_blessing()
	super.die()


func _roll_elite_gem_drop() -> String:
	var cycle_manager: Node = get_node_or_null("/root/CycleManager")
	var cycle: int = 1
	if cycle_manager != null:
		cycle = int(cycle_manager.get("current_cycle"))
	if cycle >= 2 and floor_value >= 20:
		if randf() < 0.08:
			return "gem_purple"
	if cycle >= 2 and floor_value >= 15:
		if randf() < 0.15:
			return "gem_blue"
	return ""


func _maybe_trigger_elite_blessing() -> void:
	var players: Array = get_tree().get_nodes_in_group("player")
	var blessed_guaranteed: bool = false
	if not players.is_empty():
		blessed_guaranteed = bool(players[0].get("elite_blessing_guaranteed"))
	var blessing_chance: float = 0.5
	if blessed_guaranteed:
		blessing_chance = 1.0
	if randf() >= blessing_chance:
		return
	var level: Node = get_parent()
	while level != null and not level.has_signal("blessing_selection_requested"):
		level = level.get_parent()
	if level == null or not level.has_signal("blessing_selection_requested"):
		return
	if level.has_method("set_gameplay_paused"):
		level.set_gameplay_paused(true)
	level.emit_signal("blessing_selection_requested", [])


func _summon_bats() -> void:
	if loot_parent == null or get_parent() == null:
		return
	for index in range(2):
		var bat: Enemy = BAT_SWARM_SCENE.instantiate() as Enemy
		if bat == null:
			continue
		bat.global_position = global_position + Vector2(14 + index * 10, -10 + index * 8)
		bat.configure_for_floor(target, max(floor_value - 1, 1), loot_parent)
		if bat.has_method("set_ai_paused"):
			bat.set_ai_paused(ai_paused)
		if get_parent() != null:
			get_parent().add_child(bat)

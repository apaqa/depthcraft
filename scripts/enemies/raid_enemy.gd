extends Enemy
class_name RaidEnemy

var core_target = null
var player_target = null
var building_system = null
var player_aggro_time_left: float = 0.0


func setup_raid(target_player, target_core, target_building_system, deepest_floor: int, hp_multiplier: float, loot_root: Node) -> void:
	if base_max_hp <= 0:
		base_max_hp = max_hp
	if base_damage <= 0:
		base_damage = damage
	if base_speed <= 0.0:
		base_speed = speed
	player_target = target_player
	core_target = target_core
	building_system = target_building_system
	loot_parent = loot_root
	target = target_player
	var floor_steps := int(max(deepest_floor - 1, 0) / 5)
	difficulty_multiplier = hp_multiplier
	max_hp = int(round(base_max_hp * difficulty_multiplier))
	current_hp = max_hp
	damage = int(round(base_damage * (1.0 + float(floor_steps) * 0.12)))
	speed = base_speed * (1.0 + float(floor_steps) * 0.04)
	modulate = Color(1.0, 0.38, 0.38, 1.0)
	_update_hp_bar()


func _physics_process(delta: float) -> void:
	if ai_paused or is_dead:
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		move_and_slide()
		return

	player_aggro_time_left = max(player_aggro_time_left - delta, 0.0)
	var active_target = _get_active_target()
	if active_target == null or not is_instance_valid(active_target):
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		move_and_slide()
		return

	attack_timer_left = max(attack_timer_left - delta, 0.0)
	var distance := global_position.distance_to(active_target.global_position)
	if distance <= attack_range:
		velocity = Vector2.ZERO
		if attack_timer_left <= 0.0:
			_do_attack_on_target(active_target)
	elif distance <= detection_range:
		var direction: Vector2 = (active_target.global_position - global_position).normalized()
		velocity = direction * speed
	else:
		velocity = Vector2.ZERO

	if velocity.x != 0.0:
		animated_sprite.flip_h = velocity.x < 0.0
	_update_animation(velocity)
	move_and_slide()


func take_damage(amount: int, hit_direction: Vector2 = Vector2.ZERO) -> void:
	player_aggro_time_left = 5.0
	super.take_damage(amount, hit_direction)


func _do_attack_on_target(active_target) -> void:
	if active_target == null:
		return
	if active_target.has_method("take_raid_damage"):
		active_target.take_raid_damage(damage)
	elif active_target.has_method("take_damage"):
		active_target.take_damage(damage, (active_target.global_position - global_position).normalized())
	attack_timer_left = attack_cooldown


func _get_active_target():
	if player_aggro_time_left > 0.0 and player_target != null and is_instance_valid(player_target):
		return player_target
	var structure_target = _get_structure_target()
	if structure_target != null:
		return structure_target
	return player_target


func _get_structure_target():
	if building_system == null or not building_system.has_method("get_raid_targets"):
		return core_target if core_target != null and is_instance_valid(core_target) else null
	var best_target = null
	var best_distance := INF
	for candidate in building_system.get_raid_targets():
		if candidate == null or not is_instance_valid(candidate):
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best_target = candidate
	return best_target


func _drop_loot() -> void:
	pass

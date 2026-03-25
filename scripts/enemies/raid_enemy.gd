extends Enemy
class_name RaidEnemy

var core_target = null
var player_target = null
var player_aggro_time_left: float = 0.0


func setup_raid(target_player, target_core, dungeon_runs_completed: int, loot_root: Node) -> void:
	if base_max_hp <= 0:
		base_max_hp = max_hp
	if base_damage <= 0:
		base_damage = damage
	if base_speed <= 0.0:
		base_speed = speed
	player_target = target_player
	core_target = target_core
	loot_parent = loot_root
	target = target_player
	difficulty_multiplier = 1.0 + float(dungeon_runs_completed) * 0.08
	max_hp = int(round(base_max_hp * difficulty_multiplier))
	current_hp = max_hp
	damage = int(round(base_damage * (1.0 + float(dungeon_runs_completed) * 0.06)))
	speed = base_speed * (1.0 + float(dungeon_runs_completed) * 0.04)
	modulate = Color(1.0, 0.7, 0.7, 1.0)
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
		active_target.take_damage(damage)
	attack_timer_left = attack_cooldown


func _get_active_target():
	if player_aggro_time_left > 0.0 and player_target != null and is_instance_valid(player_target):
		return player_target
	if core_target != null and is_instance_valid(core_target):
		return core_target
	return player_target


func _drop_loot() -> void:
	pass

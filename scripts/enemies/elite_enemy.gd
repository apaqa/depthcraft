extends Enemy
class_name EliteEnemy

var floor_value: int = 1
var use_charge_attack: bool = true


func configure_for_floor(player_target: CharacterBody2D, floor_number: int, loot_root: Node) -> void:
	target = player_target
	loot_parent = loot_root
	floor_value = floor_number
	max_hp = 100 + floor_number * 20
	current_hp = max_hp
	damage = 15 + floor_number * 3
	speed = 35.0
	detection_range = 140.0
	attack_range = 28.0
	attack_cooldown = 1.2
	animated_sprite.modulate = Color(1.0, 0.72, 0.72, 1.0)
	scale = Vector2(1.15, 1.15)


func is_elite_enemy() -> bool:
	return true


func _attack_target() -> void:
	if attack_timer.time_left > 0.0 or target == null or not is_instance_valid(target):
		return
	attack_timer.start(attack_cooldown)
	if use_charge_attack:
		use_charge_attack = false
		call_deferred("_perform_charge_attack")
		return
	use_charge_attack = true
	target.take_damage(damage)


func _perform_charge_attack() -> void:
	if target == null or not is_instance_valid(target):
		return
	ai_paused = true
	velocity = Vector2.ZERO
	await get_tree().create_timer(0.5).timeout
	if state == State.DEAD or target == null or not is_instance_valid(target):
		ai_paused = false
		return
	var dash_target := global_position + (target.global_position - global_position).normalized() * 42.0
	var tween := create_tween()
	tween.tween_property(self, "global_position", dash_target, 0.18)
	await tween.finished
	if global_position.distance_to(target.global_position) <= attack_range + 20.0:
		target.take_damage(int(round(damage * 1.2)))
	ai_paused = false

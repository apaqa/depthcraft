extends Enemy
class_name ShadowEnemy

const STEALTH_COOLDOWN: float = 5.0
const STEALTH_DURATION: float = 2.0
const SHADOW_VISIBLE_COLOR: Color = Color(0.34, 0.18, 0.44, 1.0)
const SHADOW_STEALTH_COLOR: Color = Color(0.34, 0.18, 0.44, 0.2)

var stealth_cooldown_left: float = STEALTH_COOLDOWN
var stealth_time_left: float = 0.0
var is_stealthed: bool = false
var next_attack_multiplier: float = 1.0


func _ready() -> void:
	super._ready()
	enemy_kind = "shadow"
	_refresh_visuals()


func configure_for_floor(player_target: CharacterBody2D, floor_number: int, loot_root: Node) -> void:
	super.configure_for_floor(player_target, floor_number, loot_root)
	enemy_kind = "shadow"
	max_hp = max(int(round(float(max_hp) * 0.72)), 22)
	damage = max(int(round(float(damage) * 1.05)), 16)
	speed = max(speed * 1.55, 92.0)
	detection_range = 220.0
	attack_range = 18.0
	attack_cooldown = 0.9
	drop_table = [
		{"id": "silver", "chance": 0.24, "quantity": 1},
		{"id": "talent_shard", "chance": 0.28, "quantity": 1},
	]
	stealth_cooldown_left = STEALTH_COOLDOWN
	stealth_time_left = 0.0
	is_stealthed = false
	next_attack_multiplier = 1.0
	current_hp = max_hp
	_refresh_visuals()
	_update_hp_bar()


func _physics_process(delta: float) -> void:
	if ai_paused or is_dead:
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		move_and_slide()
		return

	_update_timers(delta)
	if target == null or not is_instance_valid(target):
		_find_player()
		if target == null:
			velocity = Vector2.ZERO
			_update_animation(Vector2.ZERO)
			move_and_slide()
			return

	if not is_stealthed and stealth_cooldown_left <= 0.0:
		_enter_stealth()

	if is_stealthed:
		_process_stealth_movement(delta)
		return

	super._physics_process(delta)


func _perform_attack() -> void:
	if target == null or not is_instance_valid(target):
		return
	var attack_damage: int = damage
	if next_attack_multiplier > 1.0:
		attack_damage = int(round(float(damage) * next_attack_multiplier))
		next_attack_multiplier = 1.0
	if target.has_method("take_damage"):
		target.take_damage(attack_damage, (target.global_position - global_position).normalized())


func take_damage(amount: int, hit_direction: Vector2 = Vector2.ZERO) -> void:
	super.take_damage(amount, hit_direction)
	if not is_dead:
		call_deferred("_refresh_visuals")


func can_be_targeted() -> bool:
	return not is_stealthed


func _update_timers(delta: float) -> void:
	if is_stealthed:
		stealth_time_left = max(stealth_time_left - delta, 0.0)
		if stealth_time_left <= 0.0:
			_exit_stealth()
	else:
		stealth_cooldown_left = max(stealth_cooldown_left - delta, 0.0)


func _enter_stealth() -> void:
	is_stealthed = true
	stealth_time_left = STEALTH_DURATION
	stealth_cooldown_left = STEALTH_COOLDOWN
	_refresh_visuals()


func _exit_stealth() -> void:
	is_stealthed = false
	stealth_time_left = 0.0
	next_attack_multiplier = 2.0
	_refresh_visuals()


func _process_stealth_movement(delta: float) -> void:
	attack_timer_left = max(attack_timer_left - delta, 0.0)
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 520.0 * delta)
	if slow_time_left > 0.0:
		slow_time_left = max(slow_time_left - delta, 0.0)
	else:
		slow_multiplier = 1.0
	var direction: Vector2 = Vector2.ZERO
	if target != null and is_instance_valid(target):
		direction = (target.global_position - global_position).normalized()
		if direction.length_squared() > 0.0:
			facing_direction = direction
	var effective_speed: float = speed * slow_multiplier * 1.08
	velocity = direction * effective_speed + knockback_velocity
	if velocity.x != 0.0 and animated_sprite != null:
		animated_sprite.flip_h = velocity.x < 0.0
	_update_animation(velocity)
	move_and_slide()


func _refresh_visuals() -> void:
	if is_stealthed:
		modulate = SHADOW_STEALTH_COLOR
	else:
		modulate = SHADOW_VISIBLE_COLOR

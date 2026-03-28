extends Enemy
class_name ShadowAssassinEnemy

enum State {
	APPROACH,
	STEALTH,
	AMBUSH,
	RECOVER,
}

const STEALTH_DURATION: float = 2.0
const AMBUSH_DURATION: float = 0.28
const RECOVER_DURATION: float = 0.65
const STEALTH_COOLDOWN: float = 4.6
const AMBUSH_SPEED: float = 185.0

var _state: State = State.APPROACH
var _state_time_left: float = 0.0
var _stealth_cooldown_left: float = 1.2
var _ambush_direction: Vector2 = Vector2.RIGHT
var _ambush_hit: bool = false


func _ready() -> void:
	super._ready()
	if animated_sprite != null:
		animated_sprite.modulate = Color(0.64, 0.58, 0.88, 1.0)


func configure_for_floor(player_target: CharacterBody2D, floor_number: int, loot_root: Node) -> void:
	super.configure_for_floor(player_target, floor_number, loot_root)
	enemy_kind = "shadow_assassin"
	max_hp = max(int(round(float(max_hp) * 0.48)), 12)
	damage = max(int(round(float(damage) * 1.75)), 10)
	speed = max(speed * 1.35, 78.0)
	detection_range = 200.0
	attack_range = 18.0
	attack_cooldown = 1.35
	drop_table = [
		{"id": "silver", "chance": 0.28, "quantity": 1},
		{"id": "talent_shard", "chance": 0.32, "quantity": 1},
	]
	current_hp = max_hp
	_update_hp_bar()


func _physics_process(delta: float) -> void:
	if ai_paused or is_dead:
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		move_and_slide()
		return

	_stealth_cooldown_left = max(_stealth_cooldown_left - delta, 0.0)
	attack_timer_left = max(attack_timer_left - delta, 0.0)
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 520.0 * delta)
	if slow_time_left > 0.0:
		slow_time_left = max(slow_time_left - delta, 0.0)
	else:
		slow_multiplier = 1.0
	if target == null or not is_instance_valid(target):
		_find_player()
		if target == null:
			velocity = Vector2.ZERO
			_update_animation(Vector2.ZERO)
			move_and_slide()
			return

	if _state == State.STEALTH:
		_process_stealth(delta)
		return
	if _state == State.AMBUSH:
		_process_ambush(delta)
		return
	if _state == State.RECOVER:
		_process_recover(delta)
		return

	var distance: float = global_position.distance_to(target.global_position)
	if distance <= max(attack_range * 3.0, 84.0) and _stealth_cooldown_left <= 0.0:
		_enter_stealth()
		return

	if modulate.a < 0.95:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
	super._physics_process(delta)


func take_damage(amount: int, hit_direction: Vector2 = Vector2.ZERO) -> void:
	super.take_damage(amount, hit_direction)
	if not is_dead and _state == State.STEALTH:
		call_deferred("_restore_stealth_alpha")


func _perform_attack() -> void:
	if target == null or not is_instance_valid(target):
		return
	target.take_damage(damage, (target.global_position - global_position).normalized())


func _enter_stealth() -> void:
	_state = State.STEALTH
	_state_time_left = STEALTH_DURATION
	_stealth_cooldown_left = STEALTH_COOLDOWN
	velocity = Vector2.ZERO
	modulate = Color(1.0, 1.0, 1.0, 0.18)


func _process_stealth(delta: float) -> void:
	_state_time_left = max(_state_time_left - delta, 0.0)
	velocity = Vector2.ZERO
	modulate.a = 0.12 + absf(sin((STEALTH_DURATION - _state_time_left) * 8.0)) * 0.12
	_update_animation(Vector2.ZERO)
	move_and_slide()
	if _state_time_left <= 0.0:
		_state = State.AMBUSH
		_state_time_left = AMBUSH_DURATION
		_ambush_hit = false
		if target != null and is_instance_valid(target):
			_ambush_direction = (target.global_position - global_position).normalized()
			if _ambush_direction.length_squared() <= 0.0:
				_ambush_direction = Vector2.RIGHT
		else:
			_ambush_direction = Vector2.RIGHT
		modulate = Color(1.0, 1.0, 1.0, 1.0)


func _process_ambush(delta: float) -> void:
	_state_time_left = max(_state_time_left - delta, 0.0)
	velocity = _ambush_direction * AMBUSH_SPEED + knockback_velocity
	if velocity.x != 0.0 and animated_sprite != null:
		animated_sprite.flip_h = velocity.x < 0.0
	_update_animation(velocity)
	move_and_slide()
	if not _ambush_hit and target != null and is_instance_valid(target):
		if global_position.distance_to(target.global_position) <= attack_range + 12.0:
			target.take_damage(int(round(float(damage) * 1.35)), _ambush_direction)
			_ambush_hit = true
	if _state_time_left <= 0.0:
		_state = State.RECOVER
		_state_time_left = RECOVER_DURATION
		velocity *= 0.2


func _process_recover(delta: float) -> void:
	_state_time_left = max(_state_time_left - delta, 0.0)
	velocity = knockback_velocity
	_update_animation(Vector2.ZERO)
	move_and_slide()
	if _state_time_left <= 0.0:
		_state = State.APPROACH


func _restore_stealth_alpha() -> void:
	if not is_dead and _state == State.STEALTH:
		modulate = Color(1.0, 1.0, 1.0, 0.18)

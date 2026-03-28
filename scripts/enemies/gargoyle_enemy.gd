extends Enemy
class_name GargoyleEnemy

enum State {
	PERCHED,
	GLIDE,
}

const PERCH_DURATION: float = 1.8
const GLIDE_DURATION: float = 1.35

var _state: State = State.PERCHED
var _state_time_left: float = PERCH_DURATION
var _glide_direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	super._ready()
	_refresh_state_visuals()


func configure_for_floor(player_target: CharacterBody2D, floor_number: int, loot_root: Node) -> void:
	super.configure_for_floor(player_target, floor_number, loot_root)
	enemy_kind = "gargoyle"
	max_hp = max(int(round(float(max_hp) * 1.25)), 40)
	damage = max(int(round(float(damage) * 1.15)), 12)
	speed = max(speed * 0.9, 28.0)
	detection_range = 185.0
	attack_range = 24.0
	attack_cooldown = 1.3
	drop_table = [
		{"id": "stone", "chance": 0.55, "quantity": 1},
		{"id": "silver", "chance": 0.18, "quantity": 1},
	]
	current_hp = max_hp
	_update_hp_bar()
	_begin_perch()


func _physics_process(delta: float) -> void:
	if ai_paused or is_dead:
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		move_and_slide()
		return

	if target == null or not is_instance_valid(target):
		_find_player()
		if target == null:
			velocity = Vector2.ZERO
			_update_animation(Vector2.ZERO)
			move_and_slide()
			return

	attack_timer_left = max(attack_timer_left - delta, 0.0)
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 520.0 * delta)
	if slow_time_left > 0.0:
		slow_time_left = max(slow_time_left - delta, 0.0)
	else:
		slow_multiplier = 1.0

	if _state == State.PERCHED:
		_process_perch(delta)
	else:
		_process_glide(delta)


func take_damage(amount: int, hit_direction: Vector2 = Vector2.ZERO) -> void:
	if _state == State.PERCHED and knockback_velocity.length() < 5.0:
		modulate = Color(0.72, 0.72, 0.78, 1.0)
		var immunity_tween: Tween = create_tween()
		immunity_tween.tween_property(self, "modulate", Color.WHITE, 0.12)
		return
	super.take_damage(amount, hit_direction)


func _perform_attack() -> void:
	if target == null or not is_instance_valid(target):
		return
	target.take_damage(damage, (target.global_position - global_position).normalized())
	if _state == State.GLIDE:
		_begin_perch()


func _process_perch(delta: float) -> void:
	_state_time_left = max(_state_time_left - delta, 0.0)
	velocity = knockback_velocity
	if target != null and is_instance_valid(target):
		if global_position.distance_to(target.global_position) <= attack_range and attack_timer_left <= 0.0:
			_do_attack()
		elif global_position.distance_to(target.global_position) <= detection_range * 1.1 and _state_time_left <= 0.0:
			_begin_glide()
	if velocity.x != 0.0 and animated_sprite != null:
		animated_sprite.flip_h = velocity.x < 0.0
	_update_animation(Vector2.ZERO)
	move_and_slide()


func _process_glide(delta: float) -> void:
	_state_time_left = max(_state_time_left - delta, 0.0)
	if target != null and is_instance_valid(target):
		var to_target: Vector2 = (target.global_position - global_position).normalized()
		if to_target.length_squared() > 0.0:
			_glide_direction = _glide_direction.lerp(to_target, 0.16).normalized()
			facing_direction = _glide_direction
	var effective_speed: float = speed * slow_multiplier
	velocity = _glide_direction * effective_speed + knockback_velocity
	if velocity.x != 0.0 and animated_sprite != null:
		animated_sprite.flip_h = velocity.x < 0.0
	if target != null and is_instance_valid(target):
		if global_position.distance_to(target.global_position) <= attack_range + 10.0 and attack_timer_left <= 0.0:
			_do_attack()
	_update_animation(velocity)
	move_and_slide()
	if _state_time_left <= 0.0:
		_begin_perch()


func _begin_perch() -> void:
	_state = State.PERCHED
	_state_time_left = PERCH_DURATION
	velocity = Vector2.ZERO
	_refresh_state_visuals()


func _begin_glide() -> void:
	_state = State.GLIDE
	_state_time_left = GLIDE_DURATION
	if target != null and is_instance_valid(target):
		_glide_direction = (target.global_position - global_position).normalized()
		if _glide_direction.length_squared() <= 0.0:
			_glide_direction = Vector2.RIGHT
	_refresh_state_visuals()


func _refresh_state_visuals() -> void:
	if animated_sprite == null:
		return
	if _state == State.PERCHED:
		animated_sprite.modulate = Color(0.62, 0.62, 0.72, 1.0)
	else:
		animated_sprite.modulate = Color(0.92, 0.92, 1.0, 1.0)

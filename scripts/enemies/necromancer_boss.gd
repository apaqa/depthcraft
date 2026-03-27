extends BossEnemy
class_name NecromancerBoss

const SKELETON_SCENE: PackedScene = preload("res://scenes/enemies/melee_enemy.tscn")

const SUMMON_INTERVAL: float = 8.0
const TELEPORT_INTERVAL: float = 5.0
const KITE_MIN_DIST: float = 85.0
const KITE_MAX_DIST: float = 130.0
const TELEPORT_BEHIND_DIST: float = 75.0
const FAN_PROJECTILE_COUNT: int = 3
const FAN_HALF_SPREAD_DEG: float = 22.0
const WARNING_DURATION: float = 1.0
const WARNING_HALF_SIZE: float = 36.0

enum State { IDLE, CHASE, SUMMON, TELEPORT, SPELL_ATTACK }

var _state: State = State.IDLE
var _summon_timer: float = 4.0
var _teleport_timer: float = 3.0
var _action_locked: bool = false


func _ready() -> void:
	super._ready()
	if animated_sprite != null:
		animated_sprite.modulate = Color(0.55, 0.2, 0.9, 1.0)


func configure_for_floor(player_target: CharacterBody2D, floor_number: int, loot_root: Node) -> void:
	super.configure_for_floor(player_target, floor_number, loot_root)
	speed = 28.0
	keeps_distance = true
	preferred_distance = 110.0
	attack_range = 9999.0
	attack_cooldown = 9999.0


func _physics_process(delta: float) -> void:
	if ai_paused or is_dead:
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		move_and_slide()
		return

	if target == null or not is_instance_valid(target):
		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target = players[0] as CharacterBody2D
		if target == null:
			velocity = Vector2.ZERO
			_update_animation(Vector2.ZERO)
			move_and_slide()
			return

	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 520.0 * delta)
	if slow_time_left > 0.0:
		slow_time_left = max(slow_time_left - delta, 0.0)
	else:
		slow_multiplier = 1.0

	if _action_locked:
		velocity = knockback_velocity
		_update_animation(Vector2.ZERO)
		move_and_slide()
		return

	_summon_timer = max(_summon_timer - delta, 0.0)
	_teleport_timer = max(_teleport_timer - delta, 0.0)

	var dist: float = global_position.distance_to(target.global_position)
	var is_phase2: bool = float(current_hp) / float(max(max_hp, 1)) < 0.5

	if dist > detection_range * 1.1:
		_state = State.IDLE
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		move_and_slide()
		return

	if not is_phase2 and _summon_timer <= 0.0:
		_enter_summon()
		return

	if is_phase2 and _teleport_timer <= 0.0:
		_enter_teleport()
		return

	_state = State.CHASE
	_do_chase_movement(dist)


func _do_chase_movement(dist: float) -> void:
	var effective_speed: float = speed * slow_multiplier
	var to_target: Vector2 = (target.global_position - global_position).normalized()
	var move_dir: Vector2

	if dist < KITE_MIN_DIST:
		move_dir = -to_target
	elif dist > KITE_MAX_DIST:
		move_dir = to_target
	else:
		move_dir = Vector2(-to_target.y, to_target.x)

	if move_dir.length_squared() > 0.0:
		facing_direction = move_dir

	velocity = move_dir * effective_speed + knockback_velocity

	if velocity.x != 0.0:
		animated_sprite.flip_h = velocity.x < 0.0

	_update_animation(velocity)
	move_and_slide()


func _enter_summon() -> void:
	_state = State.SUMMON
	_action_locked = true
	_summon_timer = SUMMON_INTERVAL
	_spawn_warning_polygon(global_position, WARNING_HALF_SIZE * 2.5, Color(0.75, 0.1, 0.85, 0.4))
	var wait_timer: SceneTreeTimer = get_tree().create_timer(WARNING_DURATION)
	wait_timer.timeout.connect(_execute_summon)


func _execute_summon() -> void:
	if is_dead or not is_instance_valid(self):
		_action_locked = false
		return
	var count: int = randi_range(2, 3)
	for i: int in range(count):
		var offset_angle: float = TAU * float(i) / float(count)
		var spawn_offset: Vector2 = Vector2.RIGHT.rotated(offset_angle) * 44.0
		var skeleton: Node = SKELETON_SCENE.instantiate()
		get_parent().add_child(skeleton)
		skeleton.global_position = global_position + spawn_offset
		if skeleton.has_method("configure_for_floor"):
			skeleton.configure_for_floor(target, floor_value, loot_parent)
	_action_locked = false
	_state = State.CHASE


func _enter_teleport() -> void:
	if target == null or not is_instance_valid(target):
		return
	_state = State.TELEPORT
	_action_locked = true
	_teleport_timer = TELEPORT_INTERVAL
	var away_dir: Vector2 = (global_position - target.global_position).normalized()
	var dest: Vector2 = target.global_position + away_dir * TELEPORT_BEHIND_DIST
	_spawn_warning_polygon(dest, WARNING_HALF_SIZE, Color(0.9, 0.1, 0.1, 0.45))
	var wait_timer: SceneTreeTimer = get_tree().create_timer(WARNING_DURATION)
	wait_timer.timeout.connect(_execute_teleport.bind(dest))


func _execute_teleport(dest: Vector2) -> void:
	if is_dead or not is_instance_valid(self):
		_action_locked = false
		return
	global_position = dest
	_action_locked = false
	_enter_spell_attack()


func _enter_spell_attack() -> void:
	_state = State.SPELL_ATTACK
	_action_locked = true
	if target == null or not is_instance_valid(target):
		_action_locked = false
		_state = State.CHASE
		return
	_spawn_warning_polygon(target.global_position, WARNING_HALF_SIZE, Color(0.9, 0.1, 0.1, 0.45))
	var wait_timer: SceneTreeTimer = get_tree().create_timer(WARNING_DURATION)
	wait_timer.timeout.connect(_execute_spell_attack)


func _execute_spell_attack() -> void:
	if is_dead or not is_instance_valid(self):
		_action_locked = false
		return
	if target == null or not is_instance_valid(target):
		_action_locked = false
		_state = State.CHASE
		return
	var base_dir: Vector2 = (target.global_position - global_position).normalized()
	var half_spread: float = deg_to_rad(FAN_HALF_SPREAD_DEG)
	for i: int in range(FAN_PROJECTILE_COUNT):
		var t: float = float(i) / float(max(FAN_PROJECTILE_COUNT - 1, 1)) - 0.5
		var shot_dir: Vector2 = base_dir.rotated(t * half_spread * 2.0)
		var projectile: Node = PROJECTILE_SCENE.instantiate()
		projectile.setup(global_position + shot_dir * 24.0, shot_dir, int(round(float(damage) * 0.8)))
		get_parent().add_child(projectile)
	_action_locked = false
	_state = State.CHASE


func _spawn_warning_polygon(at_pos: Vector2, half_size: float, col: Color) -> void:
	var indicator: Polygon2D = Polygon2D.new()
	indicator.color = col
	var s: float = half_size
	indicator.polygon = PackedVector2Array([
		Vector2(-s, -s), Vector2(s, -s), Vector2(s, s), Vector2(-s, s)
	])
	indicator.global_position = at_pos
	indicator.z_index = -1
	get_parent().add_child(indicator)
	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(indicator, "modulate:a", 0.0, WARNING_DURATION)
	fade_tween.tween_callback(indicator.queue_free)

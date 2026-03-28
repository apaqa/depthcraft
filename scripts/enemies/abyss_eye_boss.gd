extends BossEnemy
class_name AbyssEyeBoss

const SWEEP_COOLDOWN: float = 7.5
const SWEEP_DURATION: float = 2.25
const LASER_LENGTH: float = 320.0
const LASER_HALF_WIDTH_RAD: float = 0.12
const LASER_DAMAGE_INTERVAL: float = 0.95
const BEAM_COUNT: int = 3
const BEAM_SPREAD_RAD: float = 0.18

var _sweep_cooldown_left: float = 3.5
var _sweep_active: bool = false
var _sweep_progress: float = 0.0
var _base_sweep_angle: float = 0.0
var _laser_root: Node2D = null
var _laser_lines: Array[Line2D] = []
var _laser_hit_timers: Dictionary = {}


func _ready() -> void:
	super._ready()
	scale = Vector2.ONE * 1.85
	if animated_sprite != null:
		animated_sprite.modulate = Color(0.72, 0.34, 0.95, 1.0)


func configure_for_floor(player_target: CharacterBody2D, floor_number: int, loot_root: Node) -> void:
	super.configure_for_floor(player_target, floor_number, loot_root)
	max_hp = int(round(float(max_hp) * 1.12))
	current_hp = max_hp
	damage = int(round(float(damage) * 1.05))
	speed = 20.0
	detection_range = 230.0
	attack_range = 9999.0
	attack_cooldown = 1.6
	keeps_distance = true
	preferred_distance = 104.0
	_update_hp_bar()


func setup_boss_arena(level_ref: Node, room: Rect2i) -> void:
	if level_ref != null and level_ref.has_method("spawn_abyss_cover_pillars"):
		level_ref.spawn_abyss_cover_pillars(room)


func _physics_process(delta: float) -> void:
	_tick_laser_hit_timers(delta)
	if ai_paused or is_dead:
		_hide_lasers()
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		move_and_slide()
		return

	_sweep_cooldown_left = max(_sweep_cooldown_left - delta, 0.0)
	if _sweep_active:
		_process_sweep(delta)
		return

	if target != null and is_instance_valid(target):
		if _sweep_cooldown_left <= 0.0 and global_position.distance_to(target.global_position) <= detection_range * 1.2:
			_begin_sweep()
			return

	super._physics_process(delta)


func _perform_attack() -> void:
	if target == null or not is_instance_valid(target):
		return
	var projectile_direction: Vector2 = (target.global_position - global_position).normalized()
	var projectile: EnemyProjectile = PROJECTILE_SCENE.instantiate() as EnemyProjectile
	if projectile == null:
		return
	projectile.speed = 170.0
	projectile.lifetime = 2.4
	projectile.setup(global_position + projectile_direction * 24.0, projectile_direction, int(round(float(damage) * 0.75)))
	get_parent().add_child(projectile)


func die() -> void:
	_hide_lasers()
	super.die()


func _begin_sweep() -> void:
	if target == null or not is_instance_valid(target):
		return
	_sweep_active = true
	_sweep_progress = 0.0
	_sweep_cooldown_left = SWEEP_COOLDOWN
	_base_sweep_angle = (target.global_position - global_position).angle()
	velocity = Vector2.ZERO
	_ensure_laser_root()


func _process_sweep(delta: float) -> void:
	_sweep_progress = min(_sweep_progress + delta / SWEEP_DURATION, 1.0)
	var sweep_ratio: float = lerpf(-1.0, 1.0, _sweep_progress)
	var sweep_angle: float = _base_sweep_angle + sweep_ratio * 1.1
	_update_laser_visuals(sweep_angle)
	_damage_players_for_sweep(sweep_angle)
	velocity = Vector2.ZERO
	_update_animation(Vector2.ZERO)
	move_and_slide()
	if _sweep_progress >= 1.0:
		_sweep_active = false
		_hide_lasers()


func _tick_laser_hit_timers(delta: float) -> void:
	var expired_ids: Array[int] = []
	for body_id_variant: Variant in _laser_hit_timers.keys():
		var body_id: int = int(body_id_variant)
		var time_left: float = max(float(_laser_hit_timers.get(body_id, 0.0)) - delta, 0.0)
		if time_left <= 0.0:
			expired_ids.append(body_id)
		else:
			_laser_hit_timers[body_id] = time_left
	for expired_id: int in expired_ids:
		_laser_hit_timers.erase(expired_id)


func _damage_players_for_sweep(sweep_angle: float) -> void:
	for player_ref_variant: Variant in get_tree().get_nodes_in_group("player"):
		var player_ref: Node2D = player_ref_variant as Node2D
		if player_ref == null or not is_instance_valid(player_ref):
			continue
		var to_player: Vector2 = player_ref.global_position - global_position
		if to_player.length() > LASER_LENGTH:
			continue
		if _is_player_covered(player_ref):
			continue
		for beam_index: int in range(BEAM_COUNT):
			var beam_angle: float = sweep_angle + (float(beam_index) - 1.0) * BEAM_SPREAD_RAD
			var angle_delta: float = absf(wrapf(to_player.angle() - beam_angle, -PI, PI))
			if angle_delta > LASER_HALF_WIDTH_RAD:
				continue
			var player_id: int = player_ref.get_instance_id()
			if float(_laser_hit_timers.get(player_id, 0.0)) > 0.0:
				break
			if player_ref.has_method("take_damage"):
				player_ref.take_damage(int(round(float(damage) * 0.85)), to_player.normalized())
				_laser_hit_timers[player_id] = LASER_DAMAGE_INTERVAL
			break


func _is_player_covered(player_ref: Node2D) -> bool:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.new()
	query.from = global_position
	query.to = player_ref.global_position
	query.collision_mask = 1
	query.exclude = [self]
	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty():
		return false
	var hit_position: Vector2 = result.get("position", global_position)
	return global_position.distance_to(hit_position) + 4.0 < global_position.distance_to(player_ref.global_position)


func _ensure_laser_root() -> void:
	if _laser_root != null and is_instance_valid(_laser_root):
		return
	_laser_root = Node2D.new()
	_laser_root.name = "LaserRoot"
	add_child(_laser_root)
	_laser_lines.clear()
	for _index: int in range(BEAM_COUNT):
		var line: Line2D = Line2D.new()
		line.width = 5.0
		line.default_color = Color(1.0, 0.2, 0.76, 0.88)
		line.points = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT * LASER_LENGTH])
		line.visible = false
		_laser_root.add_child(line)
		_laser_lines.append(line)


func _update_laser_visuals(sweep_angle: float) -> void:
	_ensure_laser_root()
	for beam_index: int in range(_laser_lines.size()):
		var beam_angle: float = sweep_angle + (float(beam_index) - 1.0) * BEAM_SPREAD_RAD
		var line: Line2D = _laser_lines[beam_index]
		line.visible = true
		line.rotation = beam_angle


func _hide_lasers() -> void:
	for laser_line: Line2D in _laser_lines:
		if laser_line != null and is_instance_valid(laser_line):
			laser_line.visible = false

extends Enemy
class_name RaidEnemy

const NORMAL_ZOMBIE_PREFIX: String = "tiny_zombie"
const BIG_ZOMBIE_PREFIX: String = "big_zombie"
const IDLE_ANIMATION_SPEED: float = 8.0
const RUN_ANIMATION_SPEED: float = 10.0
const NORMAL_BODY_SIZE: Vector2 = Vector2(12.0, 14.0)
const BIG_BODY_SIZE: Vector2 = Vector2(18.0, 22.0)
const NORMAL_HIT_RADIUS: float = 18.0
const BIG_HIT_RADIUS: float = 24.0

@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var hitbox_collision: CollisionShape2D = $HitBox/CollisionShape2D
@onready var hurtbox_collision: CollisionShape2D = $HurtBox/CollisionShape2D

var core_target: Variant = null
var player_target: Variant = null
var building_system: Variant = null
var player_aggro_time_left: float = 0.0
var is_heavy_variant: bool = false


func setup_raid(target_player, target_core, target_building_system, strength_value: float, hp_multiplier: float, heavy_variant: bool, loot_root: Node) -> void:
	if base_max_hp <= 0:
		base_max_hp = max_hp
	if base_damage <= 0:
		base_damage = damage
	if base_speed <= 0.0:
		base_speed = speed
	is_heavy_variant = heavy_variant
	player_target = target_player
	core_target = target_core
	building_system = target_building_system
	loot_parent = loot_root
	target = target_player
	enemy_kind = "zombie"
	difficulty_multiplier = hp_multiplier
	max_hp = int(round(base_max_hp * difficulty_multiplier))
	damage = int(round(base_damage * (1.0 + strength_value * 0.08)))
	speed = base_speed * (1.0 + strength_value * 0.02)
	if is_heavy_variant:
		max_hp = int(round(float(max_hp) * 1.6))
		damage = int(round(float(damage) * 1.25))
		speed *= 0.9
	current_hp = max_hp
	modulate = Color(1.0, 0.38, 0.38, 1.0)
	_apply_variant_visuals()
	_apply_variant_collision()
	_update_hp_bar()


func _physics_process(delta: float) -> void:
	if ai_paused or is_dead:
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		move_and_slide()
		return

	player_aggro_time_left = max(player_aggro_time_left - delta, 0.0)
	var active_target: Variant = _get_active_target()
	if active_target == null or not is_instance_valid(active_target):
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		move_and_slide()
		return

	attack_timer_left = max(attack_timer_left - delta, 0.0)
	var distance: float = global_position.distance_to(active_target.global_position)
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
	var structure_target: Variant = _get_structure_target()
	if structure_target != null:
		return structure_target
	return player_target


func _get_structure_target():
	if building_system == null or not building_system.has_method("get_raid_targets"):
		return core_target if core_target != null and is_instance_valid(core_target) else null
	var best_target: Variant = null
	var best_distance: float = INF
	for candidate: Variant in building_system.get_raid_targets():
		if candidate == null or not is_instance_valid(candidate):
			continue
		var distance: float = global_position.distance_squared_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best_target = candidate
	return best_target


func _drop_loot() -> void:
	pass


func _apply_variant_visuals() -> void:
	var sprite_frames: SpriteFrames = SpriteFrames.new()
	var prefix: String = BIG_ZOMBIE_PREFIX if is_heavy_variant else NORMAL_ZOMBIE_PREFIX
	_configure_animation_frames(sprite_frames, "idle", prefix, IDLE_ANIMATION_SPEED)
	_configure_animation_frames(sprite_frames, "run", prefix, RUN_ANIMATION_SPEED)
	animated_sprite.sprite_frames = sprite_frames
	animated_sprite.play("run" if velocity.length_squared() > 0.0 else "idle")


func _configure_animation_frames(sprite_frames: SpriteFrames, animation_name: String, prefix: String, animation_speed: float) -> void:
	sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_loop(animation_name, true)
	sprite_frames.set_animation_speed(animation_name, animation_speed)
	for frame_index: int in range(4):
		var frame_path: String = "res://assets/%s_%s_anim_f%d.png" % [prefix, animation_name, frame_index]
		var frame_texture: Texture2D = load(frame_path) as Texture2D
		if frame_texture != null:
			sprite_frames.add_frame(animation_name, frame_texture)


func _apply_variant_collision() -> void:
	var body_shape: RectangleShape2D = body_collision.shape as RectangleShape2D
	var hitbox_shape: CircleShape2D = hitbox_collision.shape as CircleShape2D
	var hurtbox_shape: CircleShape2D = hurtbox_collision.shape as CircleShape2D
	var target_body_size: Vector2 = BIG_BODY_SIZE if is_heavy_variant else NORMAL_BODY_SIZE
	var target_hit_radius: float = BIG_HIT_RADIUS if is_heavy_variant else NORMAL_HIT_RADIUS
	if body_shape != null:
		body_shape.size = target_body_size
	if hitbox_shape != null:
		hitbox_shape.radius = target_hit_radius
	if hurtbox_shape != null:
		hurtbox_shape.radius = target_hit_radius

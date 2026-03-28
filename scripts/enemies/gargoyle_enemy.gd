extends Enemy
class_name GargoyleEnemy

@export var activation_range: float = 64.0

var is_stone: bool = true


func _ready() -> void:
	super._ready()
	enemy_kind = "gargoyle"
	_refresh_visuals()


func configure_for_floor(player_target: CharacterBody2D, floor_number: int, loot_root: Node) -> void:
	super.configure_for_floor(player_target, floor_number, loot_root)
	enemy_kind = "gargoyle"
	max_hp = max(int(round(float(max_hp) * 1.45)), 70)
	damage = max(int(round(float(damage) * 1.2)), 20)
	speed = max(speed * 1.95, 74.0)
	detection_range = 240.0
	attack_range = 22.0
	attack_cooldown = 2.6
	drop_table = [
		{"id": "stone", "chance": 0.58, "quantity": 1},
		{"id": "silver", "chance": 0.16, "quantity": 1},
	]
	is_stone = true
	current_hp = max_hp
	velocity = Vector2.ZERO
	_refresh_visuals()
	_update_hp_bar()


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

	if is_stone:
		_process_stone_idle()
		return

	super._physics_process(delta)


func take_damage(amount: int, hit_direction: Vector2 = Vector2.ZERO) -> void:
	if is_stone:
		modulate = Color(0.84, 0.84, 0.84, 1.0)
		var immunity_tween: Tween = create_tween()
		immunity_tween.tween_property(self, "modulate", Color(0.55, 0.55, 0.55, 1.0), 0.12)
		return
	super.take_damage(amount, hit_direction)
	if not is_dead:
		call_deferred("_refresh_visuals")


func _process_stone_idle() -> void:
	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	_update_animation(Vector2.ZERO)
	move_and_slide()
	if target != null and is_instance_valid(target):
		if global_position.distance_to(target.global_position) <= activation_range:
			_activate()


func _activate() -> void:
	is_stone = false
	_refresh_visuals()


func _refresh_visuals() -> void:
	if is_stone:
		modulate = Color(0.55, 0.55, 0.55, 1.0)
	else:
		modulate = Color(0.82, 0.82, 0.82, 1.0)

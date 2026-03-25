extends CharacterBody2D
class_name Enemy

signal died(enemy_position: Vector2)
signal damaged(amount: int)

const LOOT_DROP_SCENE := preload("res://scenes/dungeon/loot_drop.tscn")
const PROJECTILE_SCENE := preload("res://scenes/enemies/projectile.tscn")

@export var max_hp: int = 30
@export var damage: int = 8
@export var speed: float = 45.0
@export var detection_range: float = 150.0
@export var attack_range: float = 18.0
@export var attack_cooldown: float = 1.0
@export var keeps_distance: bool = false
@export var preferred_distance: float = 60.0
@export var is_ranged: bool = false
@export var enemy_kind: String = "goblin"
@export var drop_table: Array[Dictionary] = []
@export var front_guard_enabled: bool = false
@export var zigzag_strength: float = 18.0
@export var group_spawn_min: int = 1
@export var group_spawn_max: int = 1

var current_hp: int = 0
var target: CharacterBody2D = null
var attack_timer_left: float = 0.0
var difficulty_multiplier: float = 1.0
var loot_parent: Node = null
var ai_paused: bool = false
var base_max_hp: int = 0
var base_damage: int = 0
var base_speed: float = 0.0
var is_dead: bool = false
var is_alerted: bool = false
var debug_state: String = "idle"
var _stuck_timer: float = 0.0
var _last_position: Vector2 = Vector2.ZERO
var hp_bar_root: Node2D = null
var hp_bar_bg: Polygon2D = null
var hp_bar_fill: Polygon2D = null
var knockback_velocity: Vector2 = Vector2.ZERO
var facing_direction: Vector2 = Vector2.RIGHT

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("enemies")
	base_max_hp = max_hp
	base_damage = damage
	base_speed = speed
	current_hp = max_hp
	_setup_hp_bar()
	call_deferred("_find_player")


func configure_for_floor(player_target: CharacterBody2D, floor_number: int, loot_root: Node) -> void:
	target = player_target
	loot_parent = loot_root
	if floor_number <= 3:
		max_hp = 30
		damage = 8
	elif floor_number <= 6:
		max_hp = 50
		damage = 12
	elif floor_number <= 10:
		max_hp = 80
		damage = 18
	else:
		max_hp = 100 + floor_number * 5
		damage = 22 + floor_number * 2
	current_hp = max_hp
	speed = speed * (1.0 + float(floor_number) * 0.05)
	_update_hp_bar()


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]


func _physics_process(delta: float) -> void:
	if ai_paused or is_dead:
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		move_and_slide()
		return

	if target == null or not is_instance_valid(target):
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target = players[0]
		else:
			velocity = Vector2.ZERO
			debug_state = "idle"
			_update_animation(Vector2.ZERO)
			move_and_slide()
			return

	attack_timer_left = max(attack_timer_left - delta, 0.0)
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 520.0 * delta)

	var distance: float = global_position.distance_to(target.global_position)
	if distance <= attack_range:
		is_alerted = true
		debug_state = "attack"
		velocity = Vector2.ZERO
		if attack_timer_left <= 0.0:
			_do_attack()
	elif distance <= detection_range or (is_alerted and distance <= detection_range * 3.0):
		is_alerted = true
		debug_state = "chase"
		var direction := (target.global_position - global_position).normalized()
		if keeps_distance and distance < preferred_distance:
			direction = -direction
		if enemy_kind == "bat":
			var perp := Vector2(-direction.y, direction.x)
			direction = (direction + perp * sin(Time.get_ticks_msec() / 130.0) * 0.55).normalized()
		if direction.length_squared() > 0.0:
			facing_direction = direction
		if global_position.distance_to(_last_position) < 1.0:
			_stuck_timer += delta
			if _stuck_timer > 0.5:
				var random_offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
				velocity = (direction + random_offset).normalized() * speed
				_stuck_timer = 0.0
			else:
				velocity = direction * speed
		else:
			_stuck_timer = 0.0
			velocity = direction * speed
	else:
		is_alerted = false
		debug_state = "idle"
		velocity = Vector2.ZERO

	if velocity.x != 0.0:
		animated_sprite.flip_h = velocity.x < 0.0
	velocity += knockback_velocity
	_update_animation(velocity)
	move_and_slide()
	_last_position = global_position


func _do_attack() -> void:
	_perform_attack()
	attack_timer_left = attack_cooldown


func _perform_attack() -> void:
	if target == null or not is_instance_valid(target):
		return
	if is_ranged:
		var projectile = PROJECTILE_SCENE.instantiate()
		var fire_direction := (target.global_position - global_position).normalized()
		projectile.setup(global_position + fire_direction * 20.0, fire_direction, damage)
		get_parent().add_child(projectile)
		return
	if target.has_method("take_damage"):
		target.take_damage(damage, (target.global_position - global_position).normalized())


func take_damage(amount: int, hit_direction: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
	var final_amount := amount
	if front_guard_enabled and hit_direction.length_squared() > 0.0:
		var incoming_from_attacker := -hit_direction.normalized()
		if incoming_from_attacker.dot(facing_direction.normalized()) > 0.35:
			final_amount = int(ceil(final_amount * 0.5))
	current_hp -= final_amount
	damaged.emit(final_amount)
	_update_hp_bar()
	modulate = Color(1, 0.3, 0.3, 1)
	if hit_direction.length_squared() > 0.0:
		apply_knockback(hit_direction, 120.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)
	if current_hp <= 0:
		die()


func die() -> void:
	if is_dead:
		return
	is_dead = true
	debug_state = "dead"
	velocity = Vector2.ZERO
	if hp_bar_root != null:
		hp_bar_root.visible = false
	died.emit(global_position)
	_drop_loot()
	_drop_gold_loot()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)


func set_ai_paused(paused: bool) -> void:
	ai_paused = paused


func _drop_loot() -> void:
	if loot_parent == null:
		return
	var loot_multiplier := 1.0
	if target != null and target.has_method("get_loot_drop_multiplier"):
		loot_multiplier = float(target.get_loot_drop_multiplier())
	var roll := randf()
	var running_total := 0.0
	for entry_variant in drop_table:
		var entry := entry_variant as Dictionary
		running_total += float(entry.get("chance", 0.0)) * loot_multiplier
		if roll > min(running_total, 1.0):
			continue
		var item_id := str(entry.get("id", ""))
		if item_id == "":
			return
		var drop = LOOT_DROP_SCENE.instantiate()
		drop.setup(item_id, int(entry.get("quantity", 1)))
		drop.global_position = global_position
		loot_parent.add_child(drop)
		return


func _drop_gold_loot() -> void:
	_drop_gold(randi_range(1, 3))


func _drop_gold(amount: int) -> void:
	if loot_parent == null or amount <= 0:
		return
	var drop = LOOT_DROP_SCENE.instantiate()
	drop.setup("gold", amount)
	drop.global_position = global_position + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
	loot_parent.add_child(drop)


func is_elite_enemy() -> bool:
	return false


func _setup_hp_bar() -> void:
	hp_bar_root = Node2D.new()
	hp_bar_root.position = Vector2(-12, -20)
	hp_bar_root.visible = false
	add_child(hp_bar_root)

	hp_bar_bg = Polygon2D.new()
	hp_bar_bg.color = Color(0.12, 0.12, 0.16, 0.9)
	hp_bar_bg.polygon = PackedVector2Array([Vector2.ZERO, Vector2(24, 0), Vector2(24, 4), Vector2(0, 4)])
	hp_bar_root.add_child(hp_bar_bg)

	hp_bar_fill = Polygon2D.new()
	hp_bar_fill.color = Color(0.88, 0.18, 0.18, 1.0)
	hp_bar_root.add_child(hp_bar_fill)
	_update_hp_bar()


func _update_hp_bar() -> void:
	if hp_bar_root == null or hp_bar_fill == null:
		return
	var ratio := clampf(float(current_hp) / float(max(max_hp, 1)), 0.0, 1.0)
	hp_bar_fill.polygon = PackedVector2Array([Vector2.ZERO, Vector2(24.0 * ratio, 0), Vector2(24.0 * ratio, 4), Vector2(0, 4)])
	hp_bar_root.visible = current_hp < max_hp and current_hp > 0


func _update_animation(direction: Vector2) -> void:
	if direction.length() > 0.1:
		animated_sprite.play("run")
	else:
		animated_sprite.play("idle")


func apply_knockback(direction: Vector2, force: float = 120.0) -> void:
	if direction.length_squared() <= 0.0:
		return
	knockback_velocity += direction.normalized() * force

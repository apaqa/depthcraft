extends CharacterBody2D
class_name Enemy

signal died(enemy_position: Vector2)
signal damaged(amount: int)

enum State {
	IDLE,
	CHASE,
	ATTACK,
	DEAD,
}

const LOOT_DROP_SCENE := preload("res://scenes/dungeon/loot_drop.tscn")
const PROJECTILE_SCENE := preload("res://scenes/enemies/projectile.tscn")

@export var max_hp: int = 30
@export var damage: int = 10
@export var speed: float = 40.0
@export var detection_range: float = 100.0
@export var attack_range: float = 20.0
@export var attack_cooldown: float = 1.0
@export var keeps_distance: bool = false
@export var preferred_distance: float = 60.0
@export var is_ranged: bool = false

var current_hp: int = 0
var target: CharacterBody2D = null
var state: int = State.IDLE
var wander_direction: Vector2 = Vector2.ZERO
var difficulty_multiplier: float = 1.0
var loot_parent: Node = null
var ai_paused: bool = false
var base_max_hp: int = 0
var base_damage: int = 0
var base_speed: float = 0.0
var hp_bar_root: Node2D = null
var hp_bar_bg: Polygon2D = null
var hp_bar_fill: Polygon2D = null

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_timer: Timer = $AttackTimer
@onready var wander_timer: Timer = $WanderTimer


func _ready() -> void:
	base_max_hp = max_hp
	base_damage = damage
	base_speed = speed
	current_hp = max_hp
	set_physics_process(true)
	if not attack_timer.timeout.is_connected(_on_attack_timer_timeout):
		attack_timer.timeout.connect(_on_attack_timer_timeout)
	if not wander_timer.timeout.is_connected(_pick_wander_direction):
		wander_timer.timeout.connect(_pick_wander_direction)
	_setup_hp_bar()
	_pick_wander_direction()
	call_deferred("_ensure_target")


func configure_for_floor(player_target: CharacterBody2D, floor_number: int, loot_root: Node) -> void:
	target = player_target
	loot_parent = loot_root
	difficulty_multiplier = 1.0 + float(floor_number) * 0.15
	max_hp = int(round(base_max_hp * difficulty_multiplier))
	current_hp = max_hp
	damage = int(round(base_damage * (1.0 + float(floor_number) * 0.1)))
	speed = base_speed * (1.0 + float(floor_number) * 0.05)
	_update_hp_bar()


func _physics_process(_delta: float) -> void:
	if ai_paused:
		velocity = Vector2.ZERO
		animated_sprite.play("idle")
		move_and_slide()
		return
	if state == State.DEAD:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if target == null or not is_instance_valid(target):
		velocity = Vector2.ZERO
		state = State.IDLE
		move_and_slide()
		return

	var to_target := target.global_position - global_position
	var distance := to_target.length()
	if distance <= attack_range:
		state = State.ATTACK
	elif distance <= detection_range:
		state = State.CHASE
	elif distance > detection_range * 1.5:
		state = State.IDLE

	match state:
		State.IDLE:
			velocity = wander_direction * speed * 0.2
		State.CHASE:
			var chase_direction := (target.global_position - global_position).normalized()
			if keeps_distance and global_position.distance_to(target.global_position) < preferred_distance:
				chase_direction = -chase_direction
			velocity = chase_direction * speed
		State.ATTACK:
			velocity = Vector2.ZERO
			_attack_target()

	if velocity.x != 0.0:
		animated_sprite.flip_h = velocity.x < 0.0
	animated_sprite.play("run" if velocity.length() > 0.1 else "idle")
	move_and_slide()


func take_damage(amount: int) -> void:
	if state == State.DEAD:
		return
	current_hp -= amount
	damaged.emit(amount)
	_update_hp_bar()
	var tween := create_tween()
	tween.tween_property(animated_sprite, "modulate", Color(1, 0.45, 0.45, 1), 0.05)
	tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 1), 0.1)
	if current_hp <= 0:
		die()


func die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	if hp_bar_root != null:
		hp_bar_root.visible = false
	died.emit(global_position)
	_drop_loot()
	queue_free()


func set_ai_paused(paused: bool) -> void:
	ai_paused = paused


func _attack_target() -> void:
	if attack_timer.time_left > 0.0 or target == null or not is_instance_valid(target):
		return
	attack_timer.start(attack_cooldown)
	if is_ranged:
		var projectile = PROJECTILE_SCENE.instantiate()
		projectile.setup(global_position, target.global_position - global_position, damage)
		get_parent().add_child(projectile)
	else:
		target.take_damage(damage)


func _on_attack_timer_timeout() -> void:
	pass


func _pick_wander_direction() -> void:
	wander_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	wander_timer.start(randf_range(0.6, 1.4))


func _drop_loot() -> void:
	if loot_parent == null:
		return
	var loot_multiplier := 1.0
	if target != null and target.has_method("get_loot_drop_multiplier"):
		loot_multiplier = float(target.get_loot_drop_multiplier())
	if randf() <= min(0.5 * loot_multiplier, 1.0):
		var shard = LOOT_DROP_SCENE.instantiate()
		shard.setup("talent_shard", 1)
		shard.global_position = global_position
		loot_parent.add_child(shard)
	elif randf() <= min(0.2 * loot_multiplier, 1.0):
		var resource_drop = LOOT_DROP_SCENE.instantiate()
		resource_drop.setup(["wood", "stone", "iron_ore"][randi() % 3], 1)
		resource_drop.global_position = global_position
		loot_parent.add_child(resource_drop)


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


func _ensure_target() -> void:
	if target != null and is_instance_valid(target):
		return
	await get_tree().process_frame
	var players: Array = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target = players[0]

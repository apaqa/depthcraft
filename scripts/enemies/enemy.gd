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

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_timer: Timer = $AttackTimer
@onready var wander_timer: Timer = $WanderTimer


func _ready() -> void:
	current_hp = max_hp
	if not attack_timer.timeout.is_connected(_on_attack_timer_timeout):
		attack_timer.timeout.connect(_on_attack_timer_timeout)
	if not wander_timer.timeout.is_connected(_pick_wander_direction):
		wander_timer.timeout.connect(_pick_wander_direction)
	_pick_wander_direction()


func configure_for_floor(player_target: CharacterBody2D, floor_number: int, loot_root: Node) -> void:
	target = player_target
	loot_parent = loot_root
	difficulty_multiplier = 1.0 + float(floor_number) * 0.1
	max_hp = int(round(max_hp * difficulty_multiplier))
	current_hp = max_hp
	damage = int(round(damage * difficulty_multiplier))
	speed *= difficulty_multiplier


func _physics_process(_delta: float) -> void:
	if state == State.DEAD:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if target == null or not is_instance_valid(target):
		state = State.IDLE
	else:
		var to_target := target.global_position - global_position
		var distance := to_target.length()
		if distance <= attack_range:
			state = State.ATTACK
		elif distance <= detection_range:
			state = State.CHASE
		else:
			state = State.IDLE

	match state:
		State.IDLE:
			velocity = wander_direction * speed * 0.45
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
	var tween := create_tween()
	tween.tween_property(animated_sprite, "modulate", Color(1, 0.45, 0.45, 1), 0.05)
	tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 1), 0.1)
	if current_hp <= 0:
		die()


func die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	died.emit(global_position)
	_drop_loot()
	queue_free()


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
	if randf() <= 0.5:
		var shard = LOOT_DROP_SCENE.instantiate()
		shard.setup("talent_shard", 1)
		shard.global_position = global_position
		loot_parent.add_child(shard)
	elif randf() <= 0.2:
		var resource_drop = LOOT_DROP_SCENE.instantiate()
		resource_drop.setup(["wood", "stone", "iron_ore"][randi() % 3], 1)
		resource_drop.global_position = global_position
		loot_parent.add_child(resource_drop)

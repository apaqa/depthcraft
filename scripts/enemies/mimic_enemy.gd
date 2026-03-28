extends Enemy
class_name MimicEnemy

const DUNGEON_LOOT: Script = preload("res://scripts/dungeon/dungeon_loot.gd")

var floor_value: int = 1
var is_disguised: bool = true
var is_revealing: bool = false

@onready var interaction_area: Area2D = $InteractionArea


func _ready() -> void:
	super._ready()
	enemy_kind = "mimic"
	interaction_area.monitoring = true
	interaction_area.monitorable = true
	_update_animation(Vector2.ZERO)


func configure_for_floor(player_target: CharacterBody2D, floor_number: int, loot_root: Node) -> void:
	target = player_target
	loot_parent = loot_root
	floor_value = floor_number
	enemy_kind = "mimic"
	max_hp = int(round(float(300 + floor_number * 40) * 0.8))
	current_hp = max_hp
	damage = int(round(float(25 + floor_number * 5) * 1.5))
	speed = 42.0
	detection_range = 150.0
	attack_range = 24.0
	attack_cooldown = 1.15
	drop_table.clear()
	is_disguised = true
	is_revealing = false
	modulate = Color.WHITE
	_update_hp_bar()
	_update_animation(Vector2.ZERO)


func _physics_process(delta: float) -> void:
	if is_disguised or is_revealing:
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		move_and_slide()
		return
	super._physics_process(delta)


func interact(_player) -> void:
	if is_dead or not is_disguised or is_revealing:
		return
	_reveal()


func get_interaction_prompt() -> String:
	if is_dead or not is_disguised or is_revealing:
		return ""
	return "[E] Open chest"


func take_damage(amount: int, hit_direction: Vector2 = Vector2.ZERO) -> void:
	if is_disguised or is_revealing:
		return
	super.take_damage(amount, hit_direction)


func can_be_targeted() -> bool:
	return not is_disguised and not is_revealing


func is_hidden_on_minimap() -> bool:
	return is_disguised or is_revealing


func is_disguised_mimic() -> bool:
	return is_disguised or is_revealing


func die() -> void:
	if loot_parent != null:
		var equipment_drop: LootDrop = LOOT_DROP_SCENE.instantiate() as LootDrop
		equipment_drop.global_position = global_position + Vector2(10.0, -4.0)
		loot_parent.add_child(equipment_drop)
		equipment_drop.setup_stack(DUNGEON_LOOT.generate_dungeon_equipment(floor_value))
	super.die()


func _update_animation(direction: Vector2) -> void:
	if animated_sprite == null:
		return
	if is_revealing:
		if animated_sprite.animation != "reveal":
			animated_sprite.play("reveal")
		return
	if is_disguised:
		animated_sprite.play("idle")
		return
	if direction.length() > 0.1:
		animated_sprite.play("run")
	else:
		animated_sprite.play("open_idle")


func _reveal() -> void:
	is_disguised = false
	is_revealing = true
	interaction_area.monitoring = false
	interaction_area.monitorable = false
	_update_animation(Vector2.ZERO)
	await animated_sprite.animation_finished
	if is_dead:
		return
	is_revealing = false
	attack_timer_left = 0.0
	_update_animation(Vector2.ZERO)

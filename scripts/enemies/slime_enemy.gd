extends Enemy
class_name SlimeEnemy

const SLIME_SCENE: PackedScene = preload("res://scenes/enemies/slime_enemy.tscn")
const SPLIT_OFFSETS: Array[Vector2] = [Vector2(-14.0, -8.0), Vector2(14.0, 8.0)]

@export var split_generation: int = 0
@export var max_split_generation: int = 1

var floor_value: int = 1


func _ready() -> void:
	super._ready()
	_refresh_variant_visuals()


func configure_for_floor(player_target: CharacterBody2D, floor_number: int, loot_root: Node) -> void:
	super.configure_for_floor(player_target, floor_number, loot_root)
	floor_value = floor_number
	enemy_kind = "slime"
	if split_generation <= 0:
		max_hp = max(int(round(float(max_hp) * 0.78)), 18)
		damage = max(int(round(float(damage) * 0.72)), 3)
		speed = max(speed * 0.92, 40.0)
		drop_table = [
			{"id": "fiber", "chance": 0.6, "quantity": 1},
			{"id": "talent_shard", "chance": 0.2, "quantity": 1},
		]
	else:
		max_hp = max(int(round(float(max_hp) * 0.42)), 8)
		damage = max(int(round(float(damage) * 0.55)), 1)
		speed = max(speed * 1.12, 48.0)
		drop_table = [
			{"id": "fiber", "chance": 0.35, "quantity": 1},
		]
	current_hp = max_hp
	_refresh_variant_visuals()
	_update_hp_bar()


func die() -> void:
	if is_dead:
		return
	if split_generation < max_split_generation:
		_spawn_split_slimes()
	super.die()


func _spawn_split_slimes() -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var level_node: Node = parent_node.get_parent()
	for split_index: int in range(SPLIT_OFFSETS.size()):
		var split_slime: SlimeEnemy = SLIME_SCENE.instantiate() as SlimeEnemy
		if split_slime == null:
			continue
		split_slime.split_generation = split_generation + 1
		split_slime.global_position = global_position + SPLIT_OFFSETS[split_index]
		parent_node.add_child(split_slime)
		split_slime.configure_for_floor(target, floor_value, loot_parent)
		if level_node != null and level_node.has_method("_on_enemy_died"):
			split_slime.died.connect(level_node._on_enemy_died.bind(split_slime))
		if split_slime.has_method("set_ai_paused"):
			split_slime.set_ai_paused(ai_paused)


func _refresh_variant_visuals() -> void:
	if split_generation > 0:
		scale = Vector2.ONE * 0.72
		if animated_sprite != null:
			animated_sprite.modulate = Color(0.72, 1.0, 0.82, 1.0)
	else:
		scale = Vector2.ONE
		if animated_sprite != null:
			animated_sprite.modulate = Color(0.52, 0.88, 0.64, 1.0)

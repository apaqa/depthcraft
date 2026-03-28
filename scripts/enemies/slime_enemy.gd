extends Enemy
class_name SlimeEnemy

const SLIME_SCENE: PackedScene = preload("res://scenes/enemies/slime_enemy.tscn")
const SPLIT_OFFSETS: Array[Vector2] = [Vector2(-14.0, -8.0), Vector2(14.0, 8.0)]

@export var split_generation: int = 0
@export var max_split_generation: int = 1

var floor_value: int = 1
var inherited_max_hp: int = 0
var inherited_damage: int = 0
var inherited_scale: float = 1.0


func _ready() -> void:
	super._ready()
	enemy_kind = "slime"
	_refresh_variant_visuals()


func configure_for_floor(player_target: CharacterBody2D, floor_number: int, loot_root: Node) -> void:
	super.configure_for_floor(player_target, floor_number, loot_root)
	floor_value = floor_number
	enemy_kind = "slime"
	detection_range = 128.0
	attack_range = 16.0
	attack_cooldown = 1.4
	max_hp = max(int(round(float(max_hp) * 1.75)), 40)
	damage = max(int(round(float(damage) * 0.7)), 4)
	speed = max(speed * 0.62, 26.0)
	drop_table = [
		{"id": "fiber", "chance": 0.55, "quantity": 1},
		{"id": "talent_shard", "chance": 0.16, "quantity": 1},
	]
	if split_generation > 0:
		if inherited_max_hp > 0:
			max_hp = inherited_max_hp
		if inherited_damage > 0:
			damage = inherited_damage
		scale = Vector2.ONE * inherited_scale
	else:
		scale = Vector2.ONE
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
	var child_max_hp: int = max(1, int(round(float(max_hp) * 0.5)))
	var child_damage: int = max(1, int(round(float(damage) * 0.5)))
	var child_scale: float = max(scale.x * 0.5, 0.35)
	for split_index: int in range(SPLIT_OFFSETS.size()):
		var split_slime: SlimeEnemy = SLIME_SCENE.instantiate() as SlimeEnemy
		if split_slime == null:
			continue
		split_slime.split_generation = split_generation + 1
		split_slime.inherited_max_hp = child_max_hp
		split_slime.inherited_damage = child_damage
		split_slime.inherited_scale = child_scale
		split_slime.global_position = global_position + SPLIT_OFFSETS[split_index]
		parent_node.add_child(split_slime)
		split_slime.configure_for_floor(target, floor_value, loot_parent)
		if level_node != null and level_node.has_method("_on_enemy_died"):
			split_slime.died.connect(level_node._on_enemy_died.bind(split_slime))
		if split_slime.has_method("set_ai_paused"):
			split_slime.set_ai_paused(ai_paused)


func _refresh_variant_visuals() -> void:
	if animated_sprite == null:
		return
	if split_generation > 0:
		animated_sprite.modulate = Color(0.62, 0.94, 0.68, 1.0)
	else:
		animated_sprite.modulate = Color(0.36, 0.82, 0.42, 1.0)

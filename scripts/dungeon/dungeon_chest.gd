extends Area2D
class_name DungeonChest

const LOOT_DROP_SCENE := preload("res://scenes/dungeon/loot_drop.tscn")
const DUNGEON_LOOT := preload("res://scripts/dungeon/dungeon_loot.gd")

@export var floor_number: int = 1
@export var resource_rolls_min: int = 1
@export var resource_rolls_max: int = 3
@export var equipment_drop_chance: float = 0.25
@export var chest_open_texture: Texture2D

var is_open: bool = false
var loot_root: Node = null

@onready var sprite: Sprite2D = $Sprite2D


func interact(_player) -> void:
	if is_open:
		return
	is_open = true
	if chest_open_texture != null and sprite != null:
		sprite.texture = chest_open_texture
	_drop_loot()


func get_interaction_prompt() -> String:
	return "" if is_open else "[E] Open Chest"


func setup(target_loot_root: Node, target_floor_number: int) -> void:
	loot_root = target_loot_root
	floor_number = target_floor_number


func _drop_loot() -> void:
	if loot_root == null:
		loot_root = get_parent()
	var resources := ["wood", "stone", "iron_ore", "fiber", "talent_shard"]
	var roll_count := randi_range(resource_rolls_min, resource_rolls_max)
	for _idx in range(roll_count):
		var drop = LOOT_DROP_SCENE.instantiate()
		drop.global_position = global_position + Vector2(randf_range(-8.0, 8.0), randf_range(-6.0, 6.0))
		drop.setup(resources.pick_random(), randi_range(1, 2))
		loot_root.add_child(drop)
	if randf() <= equipment_drop_chance:
		var equip_drop = LOOT_DROP_SCENE.instantiate()
		equip_drop.global_position = global_position + Vector2(0, -8)
		equip_drop.setup_stack(DUNGEON_LOOT.generate_dungeon_equipment(floor_number))
		loot_root.add_child(equip_drop)

extends Area2D
class_name DungeonChest

const LOOT_DROP_SCENE = preload("res://scenes/dungeon/loot_drop.tscn")
const DUNGEON_LOOT = preload("res://scripts/dungeon/dungeon_loot.gd")
const COMMON_CLOSED_TEXTURE = preload("res://assets/chest_closed.png")
const COMMON_OPEN_TEXTURE = preload("res://assets/chest_open_full.png")
const GOLDEN_CLOSED_TEXTURE = preload("res://assets/chest_golden_closed.png")
const GOLDEN_OPEN_TEXTURE = preload("res://assets/chest_golden_open_full.png")
const SILVER_CHEST_MODULATE: Color = Color(0.8, 0.8, 0.9, 1.0)

@export var floor_number: int = 1
@export var resource_rolls_min: int = 1
@export var resource_rolls_max: int = 3
@export var equipment_drop_chance: float = 0.25
@export var chest_open_texture: Texture2D = COMMON_OPEN_TEXTURE

var is_open: bool = false
var loot_root: Node = null
var chest_tier: String = "common"

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_apply_visuals()


func interact(_player) -> void:
	if is_open:
		return
	is_open = true
	_apply_visuals()
	_drop_loot()


func get_interaction_prompt() -> String:
	return "" if is_open else "[E] ?��?寶箱"


func setup(target_loot_root: Node, target_floor_number: int) -> void:
	loot_root = target_loot_root
	floor_number = target_floor_number
	apply_floor_tier(target_floor_number)


func apply_floor_tier(target_floor_number: int) -> void:
	floor_number = target_floor_number
	if target_floor_number >= 21:
		chest_tier = "gold"
	elif target_floor_number >= 11:
		chest_tier = "silver"
	else:
		chest_tier = "common"
	_apply_visuals()


func _apply_visuals() -> void:
	modulate = Color.WHITE
	if sprite == null:
		return
	var closed_texture: Texture2D = COMMON_CLOSED_TEXTURE
	var open_texture: Texture2D = chest_open_texture
	var chest_modulate: Color = Color.WHITE
	match chest_tier:
		"silver":
			chest_modulate = SILVER_CHEST_MODULATE
		"gold":
			closed_texture = GOLDEN_CLOSED_TEXTURE
			open_texture = GOLDEN_OPEN_TEXTURE
	sprite.texture = open_texture if is_open else closed_texture
	sprite.modulate = chest_modulate


func _drop_loot() -> void:
	if loot_root == null:
		loot_root = get_parent()
	var resources: Array[String] = ["wood", "stone", "iron_ore", "fiber", "talent_shard"]
	var roll_count: int = randi_range(resource_rolls_min, resource_rolls_max)
	for _idx in range(roll_count):
		var drop: Node2D = LOOT_DROP_SCENE.instantiate() as Node2D
		drop.global_position = global_position + Vector2(randf_range(-24, 24), randf_range(-24, 24))
		drop.setup(resources.pick_random(), randi_range(1, 2))
		loot_root.add_child(drop)
	if randf() <= equipment_drop_chance:
		var equip_drop: Node2D = LOOT_DROP_SCENE.instantiate() as Node2D
		equip_drop.global_position = global_position + Vector2(randf_range(-24, 24), randf_range(-24, 24))
		equip_drop.setup_stack(DUNGEON_LOOT.generate_dungeon_equipment(floor_number))
		loot_root.add_child(equip_drop)
	var gold_drop: Node2D = LOOT_DROP_SCENE.instantiate() as Node2D
	gold_drop.global_position = global_position + Vector2(randf_range(-24, 24), randf_range(-24, 24))
	gold_drop.setup("copper", randi_range(2, 5))
	loot_root.add_child(gold_drop)

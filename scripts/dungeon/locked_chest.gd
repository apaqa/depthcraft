extends Area2D
class_name LockedChest

const LOOT_DROP_SCENE = preload("res://scenes/dungeon/loot_drop.tscn")
const DUNGEON_LOOT = preload("res://scripts/dungeon/dungeon_loot.gd")
const LOCKED_CLOSED_TEXTURE = preload("res://assets/chest_golden_closed.png")
const LOCKED_OPEN_TEXTURE = preload("res://assets/chest_golden_open_full.png")

var is_locked: bool = true
var is_open: bool = false
var loot_root: Node = null
var floor_number: int = 1

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_apply_visuals()


func get_interaction_prompt() -> String:
	if is_open:
		return ""
	if is_locked:
		return "[E] 需要擊敗 Boss"
	return "[E] 開啟寶箱"


func interact(_player) -> void:
	if is_locked or is_open:
		return
	is_open = true
	_apply_visuals()
	_drop_loot()


func unlock() -> void:
	is_locked = false


func setup(target_loot_root: Node, target_floor_number: int) -> void:
	loot_root = target_loot_root
	floor_number = target_floor_number


func _apply_visuals() -> void:
	modulate = Color.WHITE
	if sprite == null:
		return
	sprite.texture = LOCKED_OPEN_TEXTURE if is_open else LOCKED_CLOSED_TEXTURE
	sprite.modulate = Color.WHITE


func _drop_loot() -> void:
	if loot_root == null:
		loot_root = get_parent()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var equip: Dictionary = DUNGEON_LOOT.generate_dungeon_equipment_min_rarity(floor_number, "Rare", rng)
	var equip_drop: Node2D = LOOT_DROP_SCENE.instantiate() as Node2D
	equip_drop.global_position = global_position + Vector2(randf_range(-24, 24), randf_range(-24, 24))
	equip_drop.setup_stack(equip)
	loot_root.add_child(equip_drop)
	var gold_amount: int = randi_range(20, 50) + floor_number * 3
	var gold_drop: Node2D = LOOT_DROP_SCENE.instantiate() as Node2D
	gold_drop.global_position = global_position + Vector2(randf_range(-24, 24), randf_range(-24, 24))
	gold_drop.setup("copper", gold_amount)
	loot_root.add_child(gold_drop)

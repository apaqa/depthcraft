extends Area2D
class_name DungeonChest

const LOOT_DROP_SCENE = preload("res://scenes/dungeon/loot_drop.tscn")
const DUNGEON_LOOT = preload("res://scripts/dungeon/dungeon_loot.gd")
const COMMON_CLOSED_TEXTURE = preload("res://assets/chest_closed.png")
const COMMON_OPEN_TEXTURE = preload("res://assets/chest_open_full.png")
const GOLDEN_CLOSED_TEXTURE = preload("res://assets/chest_golden_closed.png")
const GOLDEN_OPEN_TEXTURE = preload("res://assets/chest_golden_open_full.png")
const SILVER_CHEST_MODULATE: Color = Color(0.8, 0.8, 0.9, 1.0)
const MIMIC_TEXTURE: Texture2D = preload("res://assets/chest_mimic_open_anim_f0.png")
const ELITE_ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/elite_enemy.tscn")

@export var floor_number: int = 1
@export var resource_rolls_min: int = 1
@export var resource_rolls_max: int = 3
@export var equipment_drop_chance: float = 0.25
@export var chest_open_texture: Texture2D = COMMON_OPEN_TEXTURE

var is_open: bool = false
var loot_root: Node = null
var chest_tier: String = "common"
var _is_mimic: bool = false
var _player_ref: Variant = null

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_apply_visuals()


func interact(_player) -> void:
	if is_open:
		return
	_player_ref = _player
	is_open = true
	if _is_mimic:
		_spawn_mimic()
		_apply_visuals()
		return
	_apply_visuals()
	_drop_loot()


func get_interaction_prompt() -> String:
	return "" if is_open else "[E] ?��?寶箱"


func setup(target_loot_root: Node, target_floor_number: int) -> void:
	loot_root = target_loot_root
	floor_number = target_floor_number
	apply_floor_tier(target_floor_number)
	_roll_mimic()


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


func _roll_mimic() -> void:
	var cycle_mgr: Node = get_node_or_null("/root/CycleManager")
	if cycle_mgr == null:
		return
	var current_cycle: int = int(cycle_mgr.get("current_cycle"))
	if current_cycle < 2:
		return
	if randf() < 0.20:
		_is_mimic = true


func _spawn_mimic() -> void:
	if sprite != null:
		sprite.texture = MIMIC_TEXTURE
	var parent_node: Node = loot_root if loot_root != null else get_parent()
	if parent_node == null:
		return
	var enemy: Node = ELITE_ENEMY_SCENE.instantiate()
	enemy.global_position = global_position
	if _player_ref != null and is_instance_valid(_player_ref):
		if enemy.has_method("configure_for_floor"):
			enemy.configure_for_floor(_player_ref, floor_number, parent_node)
		# 1.5x HP for mimic
		var base_hp: int = int(enemy.get("max_hp"))
		enemy.set("max_hp", int(round(float(base_hp) * 1.5)))
		enemy.set("current_hp", int(enemy.get("max_hp")))
	enemy.modulate = Color(0.85, 0.55, 0.55, 1.0)
	parent_node.add_child(enemy)
	# Mimic drops better loot on death
	if enemy.has_signal("died"):
		enemy.died.connect(_on_mimic_died)


func _on_mimic_died(_pos: Vector2) -> void:
	# Drop 50% better loot than normal chest
	if loot_root == null:
		loot_root = get_parent()
	var resources: Array[String] = ["wood", "stone", "iron_ore", "fiber", "talent_shard"]
	for _idx: int in range(randi_range(3, 5)):
		var drop: Node2D = LOOT_DROP_SCENE.instantiate() as Node2D
		drop.global_position = global_position + Vector2(randf_range(-24, 24), randf_range(-24, 24))
		drop.setup(resources.pick_random(), randi_range(2, 4))
		loot_root.add_child(drop)
	# Better equipment drop
	var equip_drop: Node2D = LOOT_DROP_SCENE.instantiate() as Node2D
	equip_drop.global_position = global_position + Vector2(randf_range(-24, 24), randf_range(-24, 24))
	equip_drop.setup_stack(DUNGEON_LOOT.generate_dungeon_equipment_min_rarity(floor_number, "Uncommon"))
	loot_root.add_child(equip_drop)
	var gold_drop: Node2D = LOOT_DROP_SCENE.instantiate() as Node2D
	gold_drop.global_position = global_position + Vector2(randf_range(-24, 24), randf_range(-24, 24))
	gold_drop.setup("copper", randi_range(5, 12))
	loot_root.add_child(gold_drop)

extends Area2D
class_name DungeonStairway

signal descend_requested
signal return_surface_requested

@export var prompt_text: String = "prompt_descend_default"
@export var uses_secondary_input: bool = false
@export var stair_variant: String = "down"
@export var is_locked: bool = false
@export var locked_prompt_text: String = "prompt_locked"

const DOWN_TEXTURE: Texture2D = preload("res://assets/floor_stairs.png")
const UP_TEXTURE: Texture2D = preload("res://assets/stairs_top.png")
const STAIR_SCALE: Vector2 = Vector2(1.5, 1.5)

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_apply_stair_visual()


func get_interaction_prompt() -> String:
	var key: String = locked_prompt_text if is_locked else prompt_text
	return LocaleManager.L(key) if not key.begins_with("[") else key


func interact(_player) -> void:
	if is_locked:
		return
	if not uses_secondary_input:
		descend_requested.emit()


func secondary_interact(_player) -> void:
	if is_locked:
		return
	if uses_secondary_input:
		return_surface_requested.emit()


func set_stair_variant(variant: String) -> void:
	stair_variant = variant
	_apply_stair_visual()


func set_locked(locked: bool, unlocked_prompt: String = "", new_locked_prompt: String = "") -> void:
	is_locked = locked
	if unlocked_prompt != "":
		prompt_text = unlocked_prompt
	if new_locked_prompt != "":
		locked_prompt_text = new_locked_prompt
	_apply_stair_visual()


func _apply_stair_visual() -> void:
	if sprite == null:
		return
	sprite.scale = STAIR_SCALE
	if stair_variant == "up":
		sprite.texture = UP_TEXTURE
		sprite.modulate = Color(0.82, 0.88, 1.0, 1.0)
		sprite.flip_v = false
	else:
		sprite.texture = DOWN_TEXTURE
		sprite.modulate = Color(0.72, 0.72, 0.72, 1.0) if is_locked else Color(1.0, 1.0, 1.0, 1.0)
		sprite.flip_v = false


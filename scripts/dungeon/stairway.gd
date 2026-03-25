extends Area2D
class_name DungeonStairway

signal descend_requested
signal return_surface_requested

@export var prompt_text: String = "[E] Descend"
@export var uses_secondary_input: bool = false
@export var stair_variant: String = "down"

const DOWN_TEXTURE := preload("res://assets/floor_stairs.png")
const UP_TEXTURE := preload("res://assets/stairs_top.png")

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_apply_stair_visual()


func get_interaction_prompt() -> String:
	return prompt_text


func interact(_player) -> void:
	if not uses_secondary_input:
		descend_requested.emit()


func secondary_interact(_player) -> void:
	if uses_secondary_input:
		return_surface_requested.emit()


func set_stair_variant(variant: String) -> void:
	stair_variant = variant
	_apply_stair_visual()


func _apply_stair_visual() -> void:
	if sprite == null:
		return
	if stair_variant == "up":
		sprite.texture = UP_TEXTURE
		sprite.modulate = Color(0.82, 0.88, 1.0, 1.0)
		sprite.flip_v = false
	else:
		sprite.texture = DOWN_TEXTURE
		sprite.modulate = Color(1, 1, 1, 1)
		sprite.flip_v = false

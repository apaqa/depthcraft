extends StaticBody2D
class_name LevelPortal

@export var target_level_id: String = "dungeon"
@export var prompt_text: String = "[E] Enter Portal"

const DOWN_TEXTURE := preload("res://assets/floor_stairs.png")

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	if sprite != null:
		sprite.texture = DOWN_TEXTURE
		sprite.modulate = Color(0.95, 0.95, 0.95, 1.0)


func get_interaction_prompt() -> String:
	return prompt_text


func interact(player) -> void:
	if player != null:
		player.portal_requested.emit(target_level_id)

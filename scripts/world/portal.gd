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
	if target_level_id == "dungeon" and _is_dungeon_locked():
		return "突襲中無法進入"
	return prompt_text


func interact(player) -> void:
	if target_level_id == "dungeon" and _is_dungeon_locked():
		if player != null and player.has_method("show_status_message"):
			player.show_status_message("突襲中無法進入", Color(1.0, 0.35, 0.35, 1.0), 1.5)
		return
	if player != null:
		player.portal_requested.emit(target_level_id)


func _is_dungeon_locked() -> bool:
	var level = get_parent()
	return level != null and level.has_method("is_raid_active") and level.is_raid_active()

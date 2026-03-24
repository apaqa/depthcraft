extends StaticBody2D
class_name LevelPortal

@export var target_level_id: String = "dungeon"
@export var prompt_text: String = "[E] Enter Portal"


func get_interaction_prompt() -> String:
	return prompt_text


func interact(player) -> void:
	if player != null:
		player.portal_requested.emit(target_level_id)

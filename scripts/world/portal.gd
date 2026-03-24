extends StaticBody2D
class_name LevelPortal

@export var target_level_id: String = "dungeon"
@export var prompt_text: String = "[F] Enter Portal"


func get_interaction_prompt() -> String:
	return prompt_text

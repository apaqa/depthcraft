extends Area2D
class_name DungeonStairway

signal descend_requested
signal return_surface_requested

@export var prompt_text: String = "[E] Descend"
@export var uses_secondary_input: bool = false


func get_interaction_prompt() -> String:
	return prompt_text


func interact(_player) -> void:
	if not uses_secondary_input:
		descend_requested.emit()


func secondary_interact(_player) -> void:
	if uses_secondary_input:
		return_surface_requested.emit()

extends "res://scripts/building/building_base.gd"
class_name TavernFacility

const INTERACTION_PROMPT: String = "[E] 酒館"


func get_interaction_prompt() -> String:
	return INTERACTION_PROMPT


func interact(player: Node) -> void:
	if player == null:
		return
	var main_node: Node = player.get_tree().current_scene
	if main_node != null and main_node.has_method("enter_tavern"):
		main_node.enter_tavern(player.global_position)


func requires_home_core() -> bool:
	return true
